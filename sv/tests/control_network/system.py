#!/usr/bin/env python3
"""Real all-PE runtime programs; frozen baseline packing and all-memory oracle."""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
SV=HERE.parents[1]
sys.path.insert(0,str(SV/'tests/parameterization'))
from common import configuration as cfg,program,rtl_hashes,sha
from generate import snake,workload
from oracle import check
spec=importlib.util.spec_from_file_location('parameterization_runner',SV/'tests/parameterization/run.py')
base_run=importlib.util.module_from_spec(spec);spec.loader.exec_module(base_run)
spec=importlib.util.spec_from_file_location('control_runner',HERE/'run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)


def baseline_tools(output):
  folder=output/'baseline-tools';folder.mkdir(exist_ok=True)
  for name in ['cgra_config.py','cgra_program.py','abi.json']:
    blob=subprocess.check_output(['git','show',f'{runner.BASELINE}:sv/tools/{name}'],cwd=SV)
    (folder/name).write_bytes(blob)
  spec=importlib.util.spec_from_file_location('pinned_program',folder/'cgra_program.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  return module


def architecture(cols,rows,backend,multicast=0,wide=False):
  p=dict(CTRL_DEPTH=6,REG_DEPTH=5,NUM_CTRL=6,TOTAL_STEPS=6,BANK_DEPTH=8,NUM_BANKS=4,
      CTRL_NETWORK=backend)
  if multicast:p['CTRL_MULTICAST']=multicast
  if wide:p.update(DATA_W=64,MAX_COLS=cols+1,MAX_ROWS=rows)
  document=dict(schema=1,top='system',default_fus=['ADDER','MUL','CONST','MEM','NAH'],
      parameters=p,architectures=[dict(cols=cols,rows=rows)])
  return document


def staged_document(entry,algorithm,seed,multicast=False):
  # Explicitly define one prelaunch CONFIG batch. Move unrelated PE setup
  # before it, preserving each PE's original ordered stream; no launch or
  # other command is moved through the batch by the multicast compiler.
  doc,spec=workload(entry,algorithm,seed)
  _,words,barriers=program.compile_program(entry['normalized'],doc)
  host=program.layouts(entry['normalized'])['host']
  packets=[program.unpack(host,x) for x in words]
  start=next(i for i,p in enumerate(packets) if p['payload']['cmd']==0)
  controls=[p for p in packets[:start] if p['payload']['cmd']==3]
  setup=[p for p in packets[:start] if p['payload']['cmd']!=3]
  steps=[dict(kind='packet',packet=p) for p in setup]
  if multicast:
    steps.append(dict(kind='config_batch',multicast=True,writes=[dict(tile=p['dst'],
      address=p['payload']['ctrl_addr'],ctrl=p['payload']['ctrl']) for p in controls]))
  else:steps += [dict(kind='packet',packet=p) for p in controls]
  for i,p in enumerate(packets[start:],start):
    steps += [dict(kind='barrier',completions=b['completions']) for b in barriers if b['before_packet']==i]
    steps.append(dict(kind='packet',packet=p))
  steps += [dict(kind='barrier',completions=b['completions']) for b in barriers if b['before_packet']==len(packets)]
  # Reference meaning is per-PE order, including CONST and launch, not an
  # arbitrary global ordering between independent prelaunch destinations.
  staged=[p for p in setup+controls+packets[start:]]
  for t in range(entry['normalized']['widths']['NUM_TILES']):
    before=[p for p in packets if p['dst']==t and p['payload']['cmd'] not in {10,12}]
    after=[p for p in staged if p['dst']==t and p['payload']['cmd'] not in {10,12}]
    assert before==after,'Prelaunch staging changed per-PE order'
  return dict(schema=1,steps=steps),spec,staged


def build(folder,entry,jobs,legacy=None):
  generated=folder/'generated';generated.mkdir(exist_ok=True)
  emitter=cfg if legacy is None else legacy.configuration
  for name,text in emitter.emit(entry['normalized']).items():(generated/name).write_text(text)
  tb=folder/'tb_parameterization.sv'
  tb.write_text(base_run.bench(entry).replace('`include "driver.svh"',
      '`include "monitor.svh"\n`include "driver.svh"'))
  verilator=os.environ.get('VERILATOR','verilator')
  version=subprocess.check_output([verilator,'--version'],text=True).strip()
  fingerprint=dict(rtl=rtl_hashes(),bench=sha(tb),monitor=sha(HERE/'monitor.svh'),
      driver=sha(SV/'tests/parameterization/driver.svh'),architecture=sha(generated/'architecture.svh'),
      binding=sha(generated/'bindings.svh'),filelist=sha(SV/'filelists/native.f'),verilator=version)
  include=SV/'rtl/common';filelist=SV/'filelists/native.f'
  if legacy is not None:
    # Materialize the exact commit, never the moving work branch. All compiler
    # paths are absolute, so the original DUT cannot pick up edited local RTL.
    snapshot=folder/'baseline';snapshot.mkdir(exist_ok=True)
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',runner.BASELINE,
        'sv/rtl','sv/filelists/native.f'],cwd=SV.parent,text=True).splitlines()
    hashes={}
    for name in names:
      blob=subprocess.check_output(['git','show',f'{runner.BASELINE}:{name}'],cwd=SV)
      path=snapshot/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(blob)
      hashes[name]=hashlib.sha256(blob).hexdigest()
    original=snapshot/'sv/filelists/native.f';filelist=snapshot/'absolute.f'
    filelist.write_text('\n'.join('+incdir+'+str(snapshot/'sv'/x[len('+incdir+'):]) if x.startswith('+incdir+')
        else str(snapshot/'sv'/x) for x in original.read_text().splitlines() if x.strip())+'\n')
    include=snapshot/'sv/rtl/common'
    fingerprint.update(rtl=hashes,filelist=sha(original),baseline=runner.BASELINE)
  key=hashlib.sha256(json.dumps(fingerprint,sort_keys=True).encode()).hexdigest()[:16]
  obj=folder/'build'/key;obj.mkdir(parents=True,exist_ok=True)
  binary=obj/'Vtb_parameterization'
  identity=obj/'identity.json'
  result=dict(fingerprint=fingerprint,binary=str(binary))
  if not binary.exists():
    result.update(runner.command([verilator,'--binary','--timing','-j',str(jobs),'-CFLAGS','-O0',
      '--output-split','8000','--output-split-cfuncs','2000','-Wno-fatal',
      '-I'+str(include),'-I'+str(generated),'-I'+str(HERE),'-I'+str(SV/'tests/parameterization'),
      '-f',filelist,'--top-module','tb_parameterization','--Mdir',obj,tb],folder/'compile.log',1200))
  else:
    result['exit_code']=0
    if identity.exists():
      saved=json.loads(identity.read_text())
      assert saved['fingerprint']==fingerprint and saved['binary_sha256']==sha(binary),'Changed cached system binary'
  if binary.exists() and result['exit_code']==0:
    result['binary_sha256']=sha(binary)
    identity.write_text(json.dumps(dict(fingerprint=fingerprint,binary_sha256=sha(binary)),indent=2)+'\n')
    runner.clean_compiler_objects(binary)
  return result,binary


def observations(config,path,reference):
  types=program.layouts(config);host=types['host'];n=config['widths']['NUM_TILES']
  expected={t:[] for t in range(n)};want_write={t:[] for t in range(n)}
  for p in reference:
    # Compare wire values, including the zero defaults of generated responses.
    p=program.unpack(host,program.pack(host,p))
    cmd=p['payload']['cmd'];t=p['dst']
    if cmd not in {program.COMMANDS[x] for x in program.ABI['control_network']['controller_forward_commands']}:continue
    expected[t].append(p['payload'])
    if cmd==3:want_write[t].append((p['payload']['ctrl_addr'],program.pack(types['ctrl'],p['payload']['ctrl'])))
  actual={t:[] for t in range(n)};writes={t:[] for t in range(n)};events={}
  last_write={};first_step={};host_packets=0;commands={k:{} for k in ['H','I','D','U','O']}
  special={k:[] for k in ['host_config','mask_setup','target_config','host_launch','target_launch','host_complete','host_read','read_result']}
  for line in path.read_text().splitlines():
    row=line.split();kind=row[0];cycle=int(row[1]);events.setdefault(kind,[]).append(cycle)
    if kind=='H':host_packets+=1
    if kind in commands:
      packed_value=row[3] if kind in {'D','U'} else row[2]
      pp=program.unpack(host,int(packed_value,16));cmd=pp['payload']['cmd']
      commands[kind][str(cmd)]=commands[kind].get(str(cmd),0)+1
      if kind=='H' and cmd in {3,60}:special['host_config'].append(cycle)
      if kind=='H' and cmd==59:special['mask_setup'].append(cycle)
      if kind=='D' and cmd==3:special['target_config'].append(cycle)
      if kind=='H' and cmd==0:special['host_launch'].append(cycle)
      if kind=='D' and cmd==0:special['target_launch'].append(cycle)
      if kind=='O' and cmd==14:special['host_complete'].append(cycle)
      if kind=='H' and cmd==10:special['host_read'].append(cycle)
      if kind=='O' and cmd==11:special['read_result'].append(cycle)
    if kind=='D':actual[int(row[2])].append(program.unpack(host,int(row[3],16))['payload'])
    elif kind=='W':
      t=int(row[2]);writes[t].append((int(row[3]),int(row[4],16)));last_write[t]=cycle
    elif kind=='E':first_step.setdefault(int(row[2]),cycle)
  assert actual==expected,'PE command order/content differs from unicast reference'
  assert writes==want_write,'Actual control-memory writes differ from original configuration'
  assert all(last_write[t]<=first_step[t] for t in range(n) if want_write[t]),'Control execution preceded required CONFIG writes'
  assert all(t in first_step for t in range(n) if want_write[t]),'Configured task did not execute'
  def span(kind):
    v=events.get(kind,[]);return None if not v else dict(first=v[0],last=v[-1],span=v[-1]-v[0]+1)
  phase_spans={k:None if not v else dict(first=v[0],last=v[-1],span=v[-1]-v[0]+1) for k,v in special.items()}
  assert not events.get('S') or max(events['S'])<=max(special['host_complete']),'Collected task completion preceded last store acceptance'
  return dict(host_packets=host_packets,commands_by_boundary=commands,phase_spans=phase_spans,
      prepare_to_first_retirement=min(events['E'])-min(events['H'])+1,
      host_launch_to_first_retirement=min(events['E'])-min(special['host_launch'])+1,
      task_to_all_completions=max(special['host_complete'])-min(events['H'])+1,
      readback_span=None if not special['host_read'] else max(special['read_result'])-min(special['host_read'])+1,
      config_host_to_last_write=None if not special['host_config'] else max(last_write.values())-min(special['host_config']+special['mask_setup'])+1,
      return_drain=None if not events.get('U') else max(special['host_complete'])-min(events['U'])+1,
      configuration_writes=sum(map(len,writes.values())),
      target_receive=span('D'),control_writes=span('W'),control_execution=span('E'),
      kernel_store_acceptance=span('S'),PE_return_acceptance=span('U'),host_responses=span('O'),
      network_ingress=span('I'),per_PE_last_config=last_write,per_PE_first_step=first_step,
      note='Intervals may overlap. Total driver cycles include data preload, public result reads and 32 post-result observation cycles. E spans control-step retirements; S is PE write acceptance, not an external-memory commit.')


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--cases',default='2x2:0:0,2x2:1:0,2x2:2:0')
  ap.add_argument('--jobs',type=int,default=1)
  ap.add_argument('--baseline-rtl',action='store_true',help='Build exact 03db4c73 RTL and bindings, ring only')
  args=ap.parse_args();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
  previous=output/'results.json'
  if previous.exists():
    previous.rename(output/f'previous-results-{time.time_ns()}.json')
  pinned=baseline_tools(output)
  report=dict(baseline=runner.BASELINE,evidence='RTL simulation; normal host configuration and all-memory readback',cases=[])
  for description in args.cases.split(','):
    shape,b,mc=description.split(':');cols,rows=map(int,shape.split('x'));backend=int(b);multicast=int(mc)
    wide=shape=='2x3'
    document=architecture(cols,rows,backend,multicast,wide)
    if args.baseline_rtl:
      assert backend==0 and multicast==0,'Pinned baseline implements only the original ring'
      for k in ['CTRL_NETWORK','CTRL_MULTICAST']:document['parameters'].pop(k,None)
    config=(pinned.configuration if args.baseline_rtl else cfg).normalize(document)
    entry=dict(config=document,normalized=config,paths=[snake(cols,rows)],python_model='regular')
    folder=output/f'{shape}-b{backend}-mc{multicast}';folder.mkdir(exist_ok=True)
    row=dict(parameters=config['parameters'],runs=[],status='running');report['cases'].append(row)
    (folder/'config.json').write_text(json.dumps(document,indent=2)+'\n')
    row['build'],binary=build(folder,entry,args.jobs,pinned if args.baseline_rtl else None)
    if row['build']['exit_code']!=0:row['status']='build_failed'
    else:
      for algorithm in ['add','affine']:
        # Same elaborated hardware runs a different route as well as different
        # operations, constants and runtime inputs.
        entry['paths']=[snake(cols,rows)] if algorithm=='add' else [[x+y*cols for x in range(cols)
            for y in (range(rows) if x%2==0 else reversed(range(rows)))]]
        for seed in [0,23]:
          plain,specification,reference=staged_document(entry,algorithm,seed,False)
          # The existing independent oracle consumes the JSON schema (owner
          # keys are strings), exactly as its original runner does.
          specification=json.loads(json.dumps(specification))
          original_doc=copy.deepcopy(document)
          for k in ['CTRL_NETWORK','CTRL_MULTICAST']:original_doc['parameters'].pop(k,None)
          original_config=pinned.configuration.normalize(original_doc)
          original_files,_=pinned.encode_outputs(original_config,plain)
          streams=['unicast','multicast'] if multicast else ['unicast']
          for stream in streams:
            doc,_,_=staged_document(entry,algorithm,seed,stream=='multicast')
            files,metadata=program.encode_outputs(config,doc)
            if stream=='unicast':
              for name in ['program.hex','control.hex','constants.hex','preload.hex','barriers.txt']:
                assert files[name]==original_files[name],f'Baseline encoding changed: {name}'
            case=folder/f'{algorithm}-{seed}-{stream}';case.mkdir(exist_ok=True)
            for name,text in files.items():(case/name).write_text(text)
            (case/'boundary.txt').write_text('')
            (case/'specification.json').write_text(json.dumps(specification,indent=2)+'\n')
            (case/'program.json').write_text(json.dumps(doc,indent=2)+'\n')
            for schedule in [0,37]:
              trace=case/f'outputs-{schedule}.txt';control=case/f'control-{schedule}.txt'
              run=runner.command([binary,f'+VECTORS={case}',f'+TRACE={trace}',f'+CONTROL_TRACE={control}',
                f'+SCHEDULE={schedule}',f'+COMPLETIONS={len(specification["expected_completions"])}',
                f'+READS={specification["capacity"]}', '+BOUNDARY_OUTPUTS=0'],case/f'run-{schedule}.log',600)
              run.update(algorithm=algorithm,seed=seed,stream=stream,schedule=schedule,status='failed',
                binary_sha256=sha(binary),program_sha256=sha(case/'program.hex'),packet_count=metadata['packet_count'])
              if run['exit_code']==0:
                try:
                  run['math']=check(entry,specification,trace)
                  run['control']=observations(config,control,reference)
                  try:check(entry,specification,trace,corrupt=True)
                  except AssertionError:run['wrong_expected_rejected']=True
                  else:raise AssertionError('Bad mathematical expectation accepted')
                  run['cycles']=int(re.search(r'PARAM_TRANSPORT_PASS cycles=(\d+)',Path(run['log']).read_text())[1])
                  run['status']='passed'
                except Exception as error:run['error']=repr(error)
              row['runs'].append(run)
              print(f'CONTROL_SYSTEM {description} {algorithm}/{seed}/{stream}/{schedule}: {run["status"]}',flush=True)
      row['status']='passed' if all(r['status']=='passed' for r in row['runs']) else 'failed'
    (output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  report['all_passed']=all(r['status']=='passed' for r in report['cases'])
  (output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  return int(not report['all_passed'])


if __name__=='__main__':raise SystemExit(main())
