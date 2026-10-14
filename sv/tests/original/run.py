"""Run every selected original-test replay, retaining failures and continuing.

The capture stage uses pinned original Python tests and assertions. The replay
stage builds only native SV. A failed/unfinished reference cannot produce PASS.
"""
import argparse
import hashlib
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
SV = ROOT/'sv'


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def split_items(text):
  result = []
  start = depth = 0
  for i, char in enumerate(text):
    if char in '([{':
      depth += 1
    elif char in ')]}':
      depth -= 1
    elif char == ',' and depth == 0:
      result.append(text[start:i].strip())
      start = i+1
  result.append(text[start:].strip())
  return result


def section(text, start):
  depth = 0
  for end in range(start, len(text)):
    if text[end] == '(':
      depth += 1
    elif text[end] == ')':
      depth -= 1
      if depth == 0:
        return text[start+1:end], end+1
  raise ValueError('Unbalanced module header')


def module_header(text, module):
  text = re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.S)
  start = re.search(r'\bmodule\s+'+re.escape(module)+r'\b', text).end()
  first = text.index('(', start)
  if '#' in text[start:first]:
    parameters, end = section(text, first)
    port_text, end = section(text, text.index('(', end))
  else:
    parameters = ''
    port_text, end = section(text, first)
  ports = {}
  direction = kind = None
  for entry in split_items(port_text):
    match = re.match(r'(input|output|inout)\s+(.+)', entry, re.S)
    if match:
      direction, entry = match.groups()
    match = re.match(r'(.+?)\b([A-Za-z_]\w*)\s*((?:\[[^\]]+\]\s*)*)$', entry, re.S)
    if match and match[1].strip():
      kind, name, shape = match.groups()
    else:
      match = re.fullmatch(r'([A-Za-z_]\w*)\s*((?:\[[^\]]+\]\s*)*)', entry)
      if not match:
        raise ValueError('Cannot parse port '+entry)
      name, shape = match.groups()
    ports[name] = dict(direction=direction, declaration=f'{kind} {name} {shape}'.strip())
  return parameters, ports


def render(meta, parameters, native_ports):
  ports = meta['ports']
  contract = meta.get('acceptance_contract')
  bindings = meta.get('bindings', {})
  for port in ports:
    port['signal'] = bindings.get(port['name'], port['name'])
    if meta.get('single_underscore'):
      port['signal']=port['signal'].replace('__','_')
    if port['name'] in meta.get('switch_observables',{}):
      branch='legacy.arbitrated' if meta['parameters'].get('LEGACY_PYTHON') else 'native_switch'
      port['signal']='dut.'+branch+'.'+meta['switch_observables'][port['name']]
      continue
    base = port['signal'].split('[')[0]
    if base not in native_ports:
      raise ValueError('No native port for '+port['path']+' -> '+port['signal'])
  declarations = [p['declaration']+';' for p in native_ports.values()]
  names = ','.join('.'+n+'('+n+')' for n in native_ports)
  param_bind = ','.join(f'.{k}({k})' for k in meta['parameters'])
  code = ['`timescale 1ns/1ps', f'module tb_original #({parameters});']+declarations
  code += [f'{meta["module"]} #({param_bind}) dut({names});',
           'string vectors;', 'integer fd,rc,edge_flag,sample_count=0,error_count=0,negative_injected=0;',
           'integer reset_checks=0, valid_payload_checks=0, control_transfers=0;',
           'integer expected_samples;', 'initial begin', 'clk=0;']
  for name, port in native_ports.items():
    if port['direction'] == 'input' and name != 'clk':
      # Assignment patterns recursively initialize native-only array ports.
      shape=port['declaration'].split(name)[-1]
      dims=shape.count('[')
      indices=[f'i{x}' for x in range(dims)]
      loop=f'foreach({name}[{",".join(indices)}]) ' if dims else ''
      code.append(loop+name+''.join(f'[{i}]' for i in indices)+"='0;")
  for port in ports:
    code.append(f'if($bits({port["signal"]})!={port["width"]}) $fatal(1,"PORT_WIDTH {port["path"]} native=%0d original={port["width"]}",$bits({port["signal"]}));')
  code += ['if(!$value$plusargs("VECTORS=%s",vectors)) $fatal(1,"Missing vectors");',
           'if(!$value$plusargs("SAMPLES=%d",expected_samples)) $fatal(1,"Missing sample count");',
           'fd=$fopen(vectors,"r"); if(!fd)$fatal(1,"Missing original trace");',
           'while(sample_count<expected_samples) begin', 'rc=$fscanf(fd,"%d",edge_flag);',
           'if(rc!=1)$fatal(1,"Malformed edge flag");']
  expected_declarations = []
  for i, port in enumerate(ports):
    expected_declarations.append(f'logic [{port["width"]-1}:0] value_{i};')
    code.append(f'rc=$fscanf(fd,"%h",value_{i}); if(rc!=1)$fatal(1,"Malformed trace field {i}");')
    if port['direction'] == 'input':
      code.append(f'{port["signal"]}=value_{i};')
  if contract:
    for i, port in enumerate(ports):
      if port['path'] in contract['reset_zero']:
        code.append(f'if(reset)begin value_{i}=0;reset_checks++;if($test$plusargs("BAD_RESET"))value_{i}=1;end')
  code += ['#5;', 'if($test$plusargs("NEGATIVE") && !reset && sample_count>=4 && !negative_injected) begin']
  first_output = next(i for i, p in enumerate(ports) if p['direction'] == 'output' and not p['path'].endswith('.msg'))
  code += [f'value_{first_output}^=1;negative_injected=1;', 'end']
  for i, port in enumerate(ports):
    if port['direction'] != 'output':
      continue
    active='!reset'
    compare='1'
    if port['path'].endswith('.msg'):
      val=next((j for j,p in enumerate(ports) if p['path']==port['path'][:-4]+'.val'),None)
      if val is not None:
        active+=f' && value_{val}'
        if contract:
          compare=f'value_{val}'
          code.append(f'if(value_{val} && !reset)valid_payload_checks++;')
    if not contract:compare=f'(!$test$plusargs("ACTIVE") || ({active}))'
    code += [f'if(({compare}) && {port["signal"]}!==value_{i}) begin',
             f'if(error_count<12)$display("ORIGINAL_MISMATCH sample=%0d port={port["path"]} actual=%h expected=%h",sample_count,{port["signal"]},value_{i});',
             'error_count++; end']
  if contract and contract['activity']=='one_prologue_control':
    code.append('if(edge_flag && !reset && recv_opt__val && recv_opt__rdy)control_transfers++;')
  code += ['if(edge_flag)begin clk=1;#5;clk=0;end', 'sample_count++;', 'end']
  if contract:
    if contract['reset_zero']:
      code.append('if(!reset_checks)$fatal(1,"ORIGINAL_CONTRACT_NO_RESET_CHECKS");')
    if contract['activity']=='one_prologue_control':
      code.append('if(control_transfers!=1 || valid_payload_checks!=0)$fatal(1,"ORIGINAL_CONTRACT_PROLOGUE_COUNT");')
    else:code.append('if(!valid_payload_checks)$fatal(1,"ORIGINAL_CONTRACT_NO_VALID_PAYLOAD");')
    code.append('$display("ORIGINAL_CONTRACT_CHECKS reset=%0d valid_payload=%0d control=%0d",reset_checks,valid_payload_checks,control_transfers);')
  code += [
           'rc=$fscanf(fd,"%d",edge_flag);if(rc==1)$fatal(1,"Unexpected trailing sample");',
           'if(sample_count!=expected_samples)$fatal(1,"Incomplete replay");',
           'if(error_count)$fatal(1,"ORIGINAL_REPLAY_FAILED errors=%0d samples=%0d",error_count,sample_count);',
           '$display("ORIGINAL_REPLAY_PASS samples=%0d",sample_count);$finish;', 'end', 'endmodule']
  code[2:2] = expected_declarations
  return '\n'.join(code)+'\n'


def command(argv, log, timeout, cwd=SV, env=None):
  start = time.monotonic()
  with log.open('w') as out:
    try:
      proc = subprocess.run(argv, cwd=cwd, env=env, stdout=out, stderr=subprocess.STDOUT, timeout=timeout)
      status = proc.returncode
    except subprocess.TimeoutExpired:
      status = 124
  return dict(exit_code=status, seconds=round(time.monotonic()-start, 2),
              log=str(log), log_sha256=sha(log))


def main():
  ap = argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output', type=Path, required=True)
  ap.add_argument('--python', default=sys.executable)
  ap.add_argument('--ids', help='Comma-separated catalog case IDs')
  ap.add_argument('--group')
  ap.add_argument('--capture-only', action='store_true')
  ap.add_argument('--replay-only', action='store_true')
  ap.add_argument('--transactions', action='store_true',help='Use original system transaction queues; retain cycle replay for components')
  ap.add_argument('--active',action='store_true',help='Diagnostic: omit reset and invalid output payload comparisons')
  ap.add_argument('--compat',action='store_true',help='Explicit original-semantics diagnostic; never native acceptance')
  ap.add_argument('--contract',action='store_true',help='Reviewed per-case reset/valid-payload acceptance; keep all other comparisons')
  ap.add_argument('--fixtures',type=Path,default=Path(__file__).parent/'fixtures')
  ap.add_argument('--wall-seconds', type=int, default=1800)
  ap.add_argument('--reference-verilator', type=Path,
                  help='Original PyMTL Verilator prefix (separate from native VERILATOR)')
  args = ap.parse_args()
  assert not (args.contract and (args.active or args.compat or args.transactions)), 'Contract replay cannot use diagnostic or transaction modes'
  output = args.output.resolve()
  output.mkdir(parents=True, exist_ok=True)
  cases = json.loads((Path(__file__).parent/'cases.json').read_text())['cases']
  if args.ids:
    ids = set(map(int, args.ids.split(',')))
    cases = [c for c in cases if c['id'] in ids]
  if args.group:
    cases = [c for c in cases if c['group'] == args.group]
  assert cases, 'No selected original tests'
  verilator = os.environ.get('VERILATOR', 'verilator')
  preprocessed = output/'native-preprocessed.sv'
  if not args.capture_only:
    check = command([verilator, '-E', '-P', '-Irtl/common', '-f', 'filelists/native.f'], preprocessed, 120)
    if check['exit_code']:
      raise RuntimeError('Native preprocessing failed')
    native = preprocessed.read_text()
  results = []
  def save():
    if results:
      result=results[-1]
      (output/str(result['id'])/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    (output/'summary.json').write_text(json.dumps(dict(schema=1, cases=results,
      all_passed=bool(results) and all(r['status']=='passed' for r in results)), indent=2)+'\n')
  for case in cases:
    directory = output/str(case['id'])
    directory.mkdir(exist_ok=True)
    (directory/'case.json').write_text(json.dumps(case, indent=2)+'\n')
    result = dict(id=case['id'], file=case['file'], function=case['function'],
                  parameters=case['parameters'], status='running')
    results.append(result)
    save()
    print('ORIGINAL_START', case['id'], case['file'], case['function'], flush=True)
    try:
      if case.get('blocked_reference'):
        ref=ROOT/case['blocked_reference']['path']
        assert sha(ref)==case['blocked_reference']['sha256'],'Changed incomplete reference'
        evidence=json.loads(ref.read_text())
        result.update(status='reference_incomplete',reason=evidence['termination'],
          evidence=case['blocked_reference'],compared_prefix_cycles=evidence['cycles'],complete_kernel=False)
        save()
        print('ORIGINAL_RESULT',case['id'],result['status'],flush=True)
        continue
      if args.replay_only and not (directory/'capture/result.json').exists():
        frozen=args.fixtures/str(case['id'])
        captured=json.loads((frozen/'result.json').read_text())
        assert captured['source_sha256']==case['source_sha256'],'Stale original source pin'
        (directory/'capture').mkdir(exist_ok=True)
        shutil.copyfile(frozen/'result.json',directory/'capture/result.json')
        for name in captured['captures']:
          dest=directory/'capture'/name;dest.mkdir(exist_ok=True)
          shutil.copyfile(frozen/name/'manifest.json',dest/'manifest.json')
          (dest/'vectors.txt').write_bytes(gzip.decompress((frozen/name/'vectors.txt.gz').read_bytes()))
      if not args.replay_only:
        python_work = directory/'python-work'
        python_work.mkdir(exist_ok=True)
        if not (python_work/'validation').exists():
          (python_work/'validation').symlink_to(ROOT/'validation', target_is_directory=True)
        env = os.environ.copy()
        if args.reference_verilator:
          prefix = args.reference_verilator.resolve()
          env['PATH'] = str(prefix/'bin')+os.pathsep+env.get('PATH', '')
          env['PKG_CONFIG_PATH'] = str(prefix/'share/pkgconfig')+os.pathsep+env.get('PKG_CONFIG_PATH', '')
          env['PYMTL_VERILATOR_INCLUDE_DIR'] = str(prefix/'share/verilator/include')
          env.pop('VERILATOR_ROOT', None)
        result['capture'] = command([args.python, str(SV/'migration_tools/original_test_capture.py'),
          '--case', str(directory/'case.json'), '--output', str(directory/'capture'),
          '--wall-seconds', str(args.wall_seconds)], directory/'capture.log', args.wall_seconds+30,
          cwd=python_work, env=env)
      captured = json.loads((directory/'capture/result.json').read_text())
      result['python_status'] = captured['status']
      if 'original_function_status' in captured:
        result['original_function_status']=captured['original_function_status']
      result['diagnostic_only']=bool(args.active or args.compat)
      if captured.get('reference_variant'):
        result['reference_variant']=captured['reference_variant']
        result['diagnostic_only']=True
      if 'error' in captured:
        result['python_error'] = captured['error']
      result['replays'] = []
      for name in captured['captures']:
        trace = directory/'capture'/name
        meta = json.loads((trace/'manifest.json').read_text())
        if args.capture_only:
          continue
        assert captured['source_sha256']==case['source_sha256'],'Stale original source pin'
        assert sha(trace/'vectors.txt') == meta['vectors_sha256']
        parameters, native_ports = module_header(native, meta['module'])
        if args.contract:
          from contracts import contract_for
          meta['acceptance_contract']=contract_for(case,meta)
          result['acceptance_contract']=meta['acceptance_contract']
        if args.compat:
          for flag in ['LEGACY_PYTHON','FP_LEGACY_PYTHON','MEMORY_LEGACY_PYTHON','NOC_LEGACY_PYTHON','REDUCE_LEGACY_PYTHON']:
            if re.search(r'\b'+flag+r'\s*=',parameters):meta['parameters'][flag]=1
          meta['mode']='compatibility'
        if meta.get('original_has_ctrl_ring') is False:
          # Older frozen manifests predate this native construction parameter.
          assert meta['module']=='cgra_system' and 'HAS_CTRL_RING' in parameters
          meta['parameters']['HAS_CTRL_RING']=0
          result['coverage']='construction_only_original_done_is_unconditional'
        if args.transactions and meta.get('transaction_replay') and not meta.get('elaboration_only') and meta.get('original_has_ctrl_ring') is not False:
          from transactions import render_transactions
          bench=render_transactions(meta,parameters,native_ports,trace)
        else:
          bench = render(meta, parameters, native_ports)
        key = hashlib.sha256((bench+json.dumps(meta['parameters'], sort_keys=True)+native).encode()).hexdigest()[:20]
        build = output/'build'/key
        build.mkdir(parents=True, exist_ok=True)
        source = build/'tb_original.sv'
        source.write_text(bench)
        binary = build/'obj/Vtb_original'
        replay = dict(trace=name, module=meta['module'], parameters=meta['parameters'], mode=meta['mode'])
        if args.contract:replay['coverage']='reviewed_reset_and_valid_payload'
        replay['native_source_sha256']=hashlib.sha256(native.encode()).hexdigest()
        replay['trace_sha256']=meta['vectors_sha256']
        result['replays'].append(replay)
        if not binary.is_file():
          replay['build'] = command([verilator, '--binary', '--timing', '--compiler', 'gcc', '-j', '2',
            '-MAKEFLAGS', 'CXX=c++ LINK=c++', '-CFLAGS', '-O0', '--output-split', '10000',
            '--output-split-cfuncs', '2000', '-Wno-fatal', '-Irtl/common', '--top-module', 'tb_original',
            '--Mdir', str(build/'obj'), '-f', 'filelists/native.f', str(source)] +
            [f'-G{k}={v}' for k, v in meta['parameters'].items()], build/'compile.log', 900)
        if not binary.is_file():
          replay['status'] = 'build_failed'
          continue
        runtime=[str(binary), '+VECTORS='+str(trace/'vectors.txt'), '+SAMPLES='+str(meta['samples'])]
        if args.active:runtime+=['+ACTIVE']
        replay['run'] = command(runtime, trace/'sv.log', 120)
        replay['status'] = 'passed' if replay['run']['exit_code']==0 else 'failed'
        if meta.get('elaboration_only'):
          replay['coverage']='elaboration_only'
        if replay['status'] == 'passed' and not meta.get('elaboration_only'):
          negative = command(runtime+['+NEGATIVE'], trace/'negative.log', 120)
          replay['negative'] = negative
          if not negative['exit_code'] or not re.search('ORIGINAL_(TRANSACTION_)?MISMATCH', (trace/'negative.log').read_text()):
            replay['status'] = 'negative_check_failed'
          if args.contract and meta['acceptance_contract']['reset_zero']:
            bad_reset=command(runtime+['+BAD_RESET'],trace/'negative-reset.log',120)
            replay['negative_reset']=bad_reset
            if not bad_reset['exit_code'] or 'ORIGINAL_MISMATCH' not in (trace/'negative-reset.log').read_text():
              replay['status']='negative_reset_check_failed'
          if meta.get('memory_final') and args.transactions:
            negative_memory=command(runtime+['+BAD_MEMORY'],trace/'negative-memory.log',120)
            replay['negative_memory']=negative_memory
            if not negative_memory['exit_code'] or 'ORIGINAL_MEMORY_MISMATCH' not in (trace/'negative-memory.log').read_text():
              replay['status']='negative_memory_check_failed'
        # Retain executable, source and logs; generated compiler intermediates
        # are disposable and very large for complete CGRA fabrics.
        for artifact in (build/'obj').iterdir():
          if artifact.is_file() and artifact!=binary:artifact.unlink()
      if result['status']=='unsupported_architecture':
        pass
      elif args.capture_only:
        result['status'] = 'captured' if captured['status']=='passed' else 'adapter_failed' if captured['status']=='adapter_failed' else 'python_failed'
      elif captured['status'] != 'passed':
        result['status'] = 'adapter_failed' if captured['status']=='adapter_failed' else 'python_failed'
      elif not result['replays']:
        result['status'] = 'no_sv_replay'
      elif any(r['status']=='build_failed' for r in result['replays']):
        result['status']='build_failed'
      else:
        result['status'] = 'passed' if all(r['status']=='passed' for r in result['replays']) else 'sv_failed'
    except Exception as error:
      result.update(status='adapter_failed', error=repr(error))
    save()
    print('ORIGINAL_RESULT', case['id'], result['status'], result.get('error', result.get('python_error', ''))[:180], flush=True)
  success='captured' if args.capture_only else 'passed'
  return int(not all(r['status']==success for r in results))


if __name__ == '__main__':
  sys.exit(main())
