"""Build once per architecture, execute external programs, retain every result."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import copy
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import time
import traceback

from common import ROOT, SV, program, python_hashes, rtl_hashes, sha, write_json
from generate import generate, ALGORITHMS, SEEDS
from oracle import check
from structure import audit

HERE = Path(__file__).resolve().parent


def command(argv, log, timeout=1200, cwd=SV):
  start = time.monotonic()
  if log.exists():
    history=log.parent/'history';history.mkdir(exist_ok=True)
    shutil.copyfile(log,history/(log.name+'.'+str(time.time_ns())))
  with log.open('w') as output:
    try:
      result = subprocess.run([str(x) for x in argv], cwd=cwd, stdout=output,
                              stderr=subprocess.STDOUT, timeout=timeout)
      code = result.returncode
    except subprocess.TimeoutExpired:
      code = 124
  return dict(exit_code=code, seconds=round(time.monotonic()-start, 3),
              log=str(log), sha256=sha(log))


def bench(entry):
  config = entry['normalized']; p = config['parameters']
  top = 'cgra_multi_template' if config['top']=='multi' else 'cgra_system'
  text = (SV/'rtl/cgra'/f'{top}.sv').read_text()
  ports = re.search(r'\) \(\n(.*?)\n\);', text, re.S)[1]
  code = ['`timescale 1ns/1ps', 'module tb_parameterization;',
          '`include "architecture.svh"']
  for name in sorted(dict(p, **config['widths'])):
    code.append(f'localparam int {name}=CFG_{name};')
  code += ['`include "cgra_profile.svh"']
  ties = []
  for line in ports.splitlines():
    line = line.strip().rstrip(',')
    if not line: continue
    direction, declaration = line.split(' ', 1)
    code.append(declaration+';')
    if direction!='input': continue
    names = re.sub(r'^logic\s*(\[[^]]+\])?\s*', '', declaration)
    for token in names.split(','):
      name = token.strip().split()[0]
      if name in {'clk', 'reset', 'recv_from_cpu_pkt__msg', 'recv_from_cpu_pkt__val',
                  'send_to_cpu_pkt__rdy'} or '_on_boundary_' in name: continue
      value = str(p['NUM_BANKS']*p['BANK_DEPTH']-1) if name=='address_upper' else "'0"
      ties.append(f'assign {name}={value};')
  size = 2*(p['COLS']+p['ROWS']) if config['top']=='system' else 1
  code += [f'localparam int BOUNDARIES={size};',
    'logic [DATA_BITS-1:0] bin_msg[0:BOUNDARIES-1],bout_msg[0:BOUNDARIES-1];',
    'logic bin_val[0:BOUNDARIES-1],bin_rdy[0:BOUNDARIES-1];',
    'logic bout_val[0:BOUNDARIES-1],bout_rdy[0:BOUNDARIES-1];']
  if config['top']=='system':
    offset = 0
    for side, length in [('north', p['COLS']), ('south', p['COLS']),
                         ('west', p['ROWS']), ('east', p['ROWS'])]:
      for index in range(length):
        for port, signal in [('recv','bin'), ('send','bout')]:
          for field in ['msg','val','rdy']:
            public = f'{port}_data_on_boundary_{side}__{field}[{index}]'
            flat = f'{signal}_{field}[{offset+index}]'
            left, right = (public, flat) if (port=='recv') != (field=='rdy') else (flat,public)
            ties.append(f'assign {left}={right};')
      offset += length
  else:
    ties += ["assign bin_rdy[0]=0;assign bout_val[0]=0;assign bout_msg[0]='0;"]
  code += ties + [f'{top} #(', '`include "bindings.svh"', ') dut(.*);',
     'initial clk=0;', '`include "driver.svh"', 'endmodule']
  return '\n'.join(code)+'\n'


def build(folder, entry, jobs):
  tb = folder/'tb_parameterization.sv'; tb.write_text(bench(entry))
  fingerprint = dict(rtl=rtl_hashes(), bench=sha(tb), driver=sha(HERE/'driver.svh'),
    architecture=sha(folder/'generated/architecture.svh'), bindings=sha(folder/'generated/bindings.svh'),
    filelist=sha(SV/'filelists/native.f'), verilator=os.environ.get('VERILATOR','verilator'))
  stamp = folder/'build.json'; obj = folder/'obj'; executable = obj/'Vtb_parameterization'
  if stamp.exists():
    old = json.loads(stamp.read_text())
    if old.get('fingerprint')==fingerprint and old.get('exit_code')==0 and executable.exists():
      assert old['binary_sha256']==sha(executable), 'Changed executable'
      return old
  obj.mkdir(exist_ok=True)
  compiler = os.environ.get('CXX','c++')
  result = command([os.environ.get('VERILATOR','verilator'), '--binary', '--timing',
      '--compiler', os.environ.get('COMPILER','gcc'), '-j', jobs, '-MAKEFLAGS',
      f'CXX={compiler} LINK={compiler}', '-CFLAGS', '-O0', '--output-split', '8000',
      '--output-split-cfuncs', '2000', '--top-module', 'tb_parameterization',
      '--Mdir', obj, '-Wno-fatal', '-Irtl/common', '-I'+str(folder/'generated'),
      '-I'+str(HERE), '-f', 'filelists/native.f', tb], folder/'compile.log')
  result['fingerprint'] = fingerprint
  if result['exit_code']==0:
    result['binary_sha256'] = sha(executable)
    # Remove only rebuildable compiler intermediates owned by this test run.
    for path in obj.iterdir():
      if path.suffix in {'.o','.a','.gch','.d'} or '.gch' in path.name: path.unlink()
  write_json(stamp,result)
  return result


def structure(folder, entry):
  xml = folder/'structure.xml'
  outcome = command([os.environ.get('VERILATOR','verilator'),'--xml-only','--timing',
      '--xml-output',xml,'--top-module','tb_parameterization','--Mdir',folder/'xml',
      '-Wno-fatal','-Irtl/common','-I'+str(folder/'generated'),'-I'+str(HERE),
      '-f','filelists/native.f',folder/'tb_parameterization.sv'],folder/'structure.log')
  outcome['status']='failed'
  if outcome['exit_code']==0:
    try:
      outcome.update(audit(xml,entry));outcome['xml_sha256']=sha(xml)
    except Exception:outcome['failure']=traceback.format_exc()
  return outcome


def execute(folder, entry, case, schedule, suffix='', extra=(), wall_timeout=600):
  spec = json.loads((case/'specification.json').read_text())
  trace = case/f'trace_{schedule}{suffix}.txt'; log = case/f'run_{schedule}{suffix}.log'
  executable = folder/'obj/Vtb_parameterization'
  args = [executable, f'+VECTORS={case}', f'+TRACE={trace}', f'+SCHEDULE={schedule}',
    f'+COMPLETIONS={len(spec["expected_completions"])}',
    f'+READS={spec["capacity"]*len(spec["address_map"])}',
    f'+BOUNDARY_OUTPUTS={int(spec["streaming"])}', *extra]
  # Large fabrics need more wall time to reach the unchanged 20,000-cycle
  # hardware deadline. A process timeout never counts as a detected negative.
  result = command(args, log, timeout=wall_timeout)
  result.update(binary_sha256=sha(executable), program_sha256=sha(case/'program.hex'),
                schedule=schedule, status='failed')
  if result['exit_code']==0:
    try:
      result['observations'] = check(entry,spec,trace)
      try: check(entry,spec,trace,corrupt=True)
      except AssertionError: result['wrong_expected_rejected']=True
      else: raise AssertionError('Oracle accepted corrupted expected memory')
      result['trace_sha256'] = sha(trace); result['status']='passed'
    except Exception:
      result['failure'] = traceback.format_exc()
  return result


def mutations(folder, entry):
  source = folder/'affine_23'; results = {}
  layout = program.layouts(entry['normalized'])['host']
  original = [int(line,16) for line in (source/'program.hex').read_text().splitlines()]
  for variant in ['last_tile_operation', 'register_index_alias']:
    target = folder/('negative_'+variant); target.mkdir(exist_ok=True)
    for name in ['barriers.txt','boundary.txt','specification.json']:
      shutil.copyfile(source/name,target/name)
    words = []; changed = 0
    last = entry['paths'][0][-1]
    last_pc = entry['normalized']['parameters']['CTRL_DEPTH']-1
    for value in original:
      packet = program.unpack(layout,value); payload = packet['payload']
      if payload['cmd']==program.COMMANDS['CONFIG']:
        control = payload['ctrl']
        if variant=='last_tile_operation' and packet['dst_cgra_id']==0 and packet['dst']==last and payload['ctrl_addr']==last_pc:
          control['operation'] = program.OPCODES['INC']; changed+=1
        if variant=='register_index_alias':
          for key in ['read_reg_idx','write_reg_idx']:
            changed += sum(v!=0 for v in control[key]);control[key]=[0]*4
      words.append(program.pack(layout,packet))
    assert changed
    (target/'program.hex').write_text(''.join(f'{v:x}\n' for v in words))
    result = execute(folder,entry,target,0)
    result['detected'] = result['status']=='failed' and (
      'Memory mismatch' in result.get('failure','') or 'Boundary mismatch' in result.get('failure','') or
      'PARAM_TIMEOUT' in Path(result['log']).read_text())
    result['changed_fields'] = changed;results[variant]=result
  result = execute(folder,entry,source,37,'_permanent_stall',extra=['+STALL_FOREVER'])
  result['detected'] = result['exit_code']!=0 and 'PARAM_TIMEOUT' in Path(result['log']).read_text()
  results['permanent_stall']=result
  return results


def reference(folder, entry, algorithm, interpreter, adopted):
  case=folder/(algorithm+'_23');record=case/'python_result.json'
  pid=adopted.get(str(case));waited=False
  if pid:
    start=time.monotonic()
    while Path(f'/proc/{pid}/cmdline').exists():
      args=Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
      if not args or not args[0]:break  # Finished/zombie awaiting reaping.
      assert any(b'parameterization_reference.py' in a for a in args)
      assert b'--case' in args and Path(os.fsdecode(args[args.index(b'--case')+1]))==case
      if time.monotonic()-start>1800:
        return dict(exit_code=124,result=dict(status='failed',failure='Adopted reference did not finish'))
      time.sleep(1)
    waited=True
  if record.exists():
    old=json.loads(record.read_text());trace=case/'python_trace.txt'
    if (old.get('status')=='passed' and old.get('architecture_sha256')==sha(folder/'architecture.json')
        and old.get('program_sha256')==sha(case/'program.hex')
        # Early frozen captures did not record a schedule field. They can
        # establish accepted-packet equivalence, not new scheduling evidence.
        and ('schedule' not in old or old['schedule']==37)
        and old.get('python_target')==python_hashes()['python_target_commit']):
      assert sha(trace)==old['trace_sha256'], 'Corrupt original reference trace'
      spec=json.loads((case/'specification.json').read_text())
      assert check(entry,spec,trace)==check(entry,spec,case/'trace_37.txt')
      log=case/'python_revalidated.log'
      log.write_text('REFERENCE_REVALIDATED original source pin, architecture, program, trace SHA, independent math and current native full packets\n')
      return dict(exit_code=0,cached=True,adopted_running_reference=waited,log=str(log),
                  sha256=sha(log),capture_schedule_recorded='schedule' in old,result=old)
  if waited:
    return dict(exit_code=1,adopted_running_reference=True,result=json.loads(record.read_text())
                if record.exists() else dict(status='failed',failure='Adopted reference exited without a result'))
  ref=command([interpreter,'-B',SV/'migration_tools/parameterization_reference.py',
      '--architecture',folder/'architecture.json','--case',case,'--schedule','37'],
      case/'python_reference.log',timeout=1800,cwd=ROOT)
  ref['result']=json.loads(record.read_text()) if record.exists() else dict(status='failed')
  if ref['exit_code']!=0 and ref['result'].get('status')=='passed':
    ref['result']=dict(status='failed',previous_reference_status='passed',
        failure=f'Reference invocation failed (exit {ref["exit_code"]}); old PASS cannot satisfy this run')
  return ref


def matrix_passed(summary, catalog):
  cases={f'{a}_{seed}_schedule{s}' for a in catalog['algorithms']
         for seed in catalog['seeds'] for s in catalog['schedules']}
  negatives={'last_tile_operation','register_index_alias','permanent_stall'}
  return bool(summary['full_matrix'] and set(summary['profiles'])==set(catalog['architectures']) and all(
    p['build']['exit_code']==0 and p.get('structure',{}).get('status')=='passed' and set(p['cases'])==cases and
    all(x['status']=='passed' for x in p['cases'].values()) and set(p['negatives'])==negatives and
    all(x['detected'] for x in p['negatives'].values()) and set(p['references'])==set(catalog['algorithms']) and
    all(x.get('exit_code')==0 and x.get('result',{}).get('status')=='passed'
        for x in p['references'].values()) for p in summary['profiles'].values()))


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output', required=True, type=Path)
  parser.add_argument('--profiles', help='Comma-separated architecture names')
  parser.add_argument('--jobs',type=int,default=2)
  parser.add_argument('--python', help='Original PyMTL interpreter; omit to record references as not_run')
  parser.add_argument('--reference-jobs',type=int,default=3)
  parser.add_argument('--adopt-references',type=Path,help='Explicit case-directory to PID map for already running references')
  parser.add_argument('--smoke',action='store_true',help='Only add_23 schedule0; never full acceptance')
  args = parser.parse_args(); resource.setrlimit(resource.RLIMIT_CORE,(0,0))
  root = args.output.resolve(); generate(root)
  pin = python_hashes(); frozen_rtl = rtl_hashes()
  catalog = json.loads((root/'matrix.json').read_text())
  selected = args.profiles.split(',') if args.profiles else catalog['architectures']
  assert set(selected)<=set(catalog['architectures'])
  summary = dict(python_target=pin['python_target_commit'], rtl=frozen_rtl,
      full_matrix=False, all_passed=False, profiles={}, original_failures_preserved=[10,11,12,166])
  reference_jobs=[]
  for name in selected:
    print('BUILD',name,flush=True)
    folder = root/name;entry = json.loads((folder/'architecture.json').read_text())
    result = dict(build=build(folder,entry,args.jobs), cases={}, negatives={}, references={})
    summary['profiles'][name]=result
    if result['build']['exit_code']!=0:
      print('BUILD_FAILED',name,flush=True);write_json(root/'results.json',summary);continue
    result['structure']=structure(folder,entry)
    print('STRUCTURE',name,result['structure']['status'],flush=True)
    for algorithm in (['add'] if args.smoke else ALGORITHMS):
      for seed in ([23] if args.smoke else SEEDS):
        for schedule in ([0] if args.smoke else catalog['schedules']):
          case = folder/f'{algorithm}_{seed}'
          key = f'{algorithm}_{seed}_schedule{schedule}'
          outcome = execute(folder,entry,case,schedule);result['cases'][key]=outcome
          print(outcome['status'].upper(),name,key,flush=True)
          if outcome.get('failure'): print(outcome['failure'].splitlines()[-1],flush=True)
          write_json(root/'results.json',summary)
    if not args.smoke:
      result['negatives'] = mutations(folder,entry)
      for algorithm in ALGORITHMS:
        if args.python:
          reference_jobs.append((folder,entry,algorithm))
        else: result['references'][algorithm]=dict(status='not_run')
    assert rtl_hashes()==frozen_rtl, 'RTL changed during parameterization acceptance'
    python_hashes()
    write_json(root/'results.json',summary)
  adopted=json.loads(args.adopt_references.read_text()) if args.adopt_references else {}
  # Largest models start first. Each worker owns a distinct case directory.
  reference_jobs.sort(key=lambda x:-sum(len(path) for path in x[1]['paths']))
  with ThreadPoolExecutor(max_workers=args.reference_jobs) as pool:
    futures={pool.submit(reference,folder,entry,algorithm,args.python,adopted):(folder.name,algorithm)
             for folder,entry,algorithm in reference_jobs}
    for future in as_completed(futures):
      name,algorithm=futures[future]
      try:ref=future.result()
      except Exception:ref=dict(exit_code=1,result=dict(status='failed',failure=traceback.format_exc()))
      summary['profiles'][name]['references'][algorithm]=ref
      print('PYTHON',name,algorithm,ref['result']['status'],'revalidated' if ref.get('cached') else 'executed',flush=True)
      write_json(root/'results.json',summary)
  assert rtl_hashes()==frozen_rtl
  python_hashes()
  summary['full_matrix'] = not args.smoke and set(selected)==set(catalog['architectures'])
  summary['all_passed'] = matrix_passed(summary,catalog)
  summary['commit_allowed']=False  # Four previously unresolved originals remain open.
  write_json(root/'results.json',summary)
  print('PARAMETERIZATION_RESULT',root/'results.json','all_passed=',summary['all_passed'],flush=True)
  return 0 if summary['all_passed'] else 1


if __name__=='__main__': sys.exit(main())
