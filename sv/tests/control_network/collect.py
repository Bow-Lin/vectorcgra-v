#!/usr/bin/env python3
"""Freeze compact, hash-checked evidence; no binaries or generated RTL are copied."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('control_runner',HERE/'run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
SV=r.SV
SUITES=['network-final','multicast-final','pinned-system','system-stage-a',
    'system-stage-b','system-large','reduction','guards','synth']


def digest(value):
  import hashlib
  return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()


def portable(value,root):
  if isinstance(value,dict):return {k:portable(v,root) for k,v in value.items()}
  if isinstance(value,list):return [portable(v,root) for v in value]
  if isinstance(value,str):return value.replace(str(root),'$BUILD').replace(str(SV.parent),'$REPO')
  return value


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--input',type=Path,default=SV/'build/control-network')
  ap.add_argument('--output',type=Path,default=SV/'results/control-network')
  ap.add_argument('--check',action='store_true')
  args=ap.parse_args();root=args.input.resolve();out=args.output.resolve()
  if args.check:
    manifest=json.loads((out/'manifest.json').read_text())
    for name,hash_value in manifest['source_sha256'].items():assert r.sha(SV.parent/name)==hash_value,name
    for name,hash_value in manifest['evidence_sha256'].items():assert r.sha(out/name)==hash_value,name
    print('CONTROL_EVIDENCE_VERIFIED sources='+str(len(manifest['source_sha256'])));return 0
  out.mkdir(parents=True,exist_ok=True)
  data={name:json.loads((root/name/'results.json').read_text()) for name in SUITES}
  for name,d in data.items():assert d['baseline']==r.BASELINE and d['all_passed'],name
  # A report from a different source revision cannot be labelled current.
  for name,d in data.items():
    for path,value in d.get('sources',{}).items():assert r.sha(SV/path)==value,(name,path)
    for case in d['cases']:
      build=case.get('build',{});fp=build.get('fingerprint',{})
      for path,value in fp.get('rtl',{}).items():
        if 'baseline' in fp:
          import hashlib
          blob=subprocess.check_output(['git','show',f'{r.BASELINE}:{path}'],cwd=SV)
          assert hashlib.sha256(blob).hexdigest()==value,path
        else:assert r.sha(SV.parent/path)==value,path
      binary=build.get('binary')
      if binary:assert r.sha(binary)==build['binary_sha256'],binary
      if case.get('binary_sha256') and 'parameters' in case and name in SUITES[:2]:
        # Transport binary identities were already checked on every invocation.
        assert all(x['passed'] for x in case['runs']+case['negatives'])
  # Compare complete host packets across all candidate backends/streams and
  # exact-commit original hardware, permitting independent-PE completion order.
  original={};comparisons=0
  for c in data['pinned-system']['cases']:
    for x in c['runs']:
      key=(c['parameters']['COLS'],c['parameters']['ROWS'],x['algorithm'],x['seed'],x['schedule'])
      original[key]=x['math']
  groups={}
  for name in ['system-stage-a','system-stage-b','system-large']:
    for c in data[name]['cases']:
      for x in c['runs']:
        key=(c['parameters']['COLS'],c['parameters']['ROWS'],x['algorithm'],x['seed'],x['schedule'])
        if key in original:assert x['math']==original[key],(name,key);comparisons+=1
        if key in groups:assert x['math']==groups[key],(name,key)
        groups[key]=x['math']
  saved={};logs={}
  def save(name,value,normalize=True):
    path=out/name;path.write_text(json.dumps(portable(value,root) if normalize else value,indent=2)+'\n');saved[name]=r.sha(path)
  def freeze_logs(value):
    if isinstance(value,dict):
      if 'log' in value and 'log_sha256' in value:
        path=Path(value['log']);assert r.sha(path)==value['log_sha256'],path
        # Exclude compiler output. Preserve all test logs and named negatives.
        if path.name not in {'compile.log','synth.log','sv2v.log'}:
          logs[str(path.relative_to(root))]=path.read_text()
      for x in value.values():freeze_logs(x)
    elif isinstance(value,list):
      for x in value:freeze_logs(x)
  for name,d in data.items():
    freeze_logs(d)
    compact=copy.deepcopy(d);compact.pop('sources',None)
    for c in compact['cases']:
      if 'build' in c:
        b=c['build'];c['build_identity_sha256']=digest(b.get('fingerprint',b));c['binary_sha256']=b.get('binary_sha256',c.get('binary_sha256'))
        c.pop('build')
      for x in c.get('runs',[]):
        if 'math' in x:
          m=x['math'];x['full_host_packets_sha256']=digest(m)
          if 'responses' in m:x['math']={k:v for k,v in m.items() if k in {'checked_words','active_tiles'}}
        if 'cycles' in x:
          # The shared baseline driver prints the zero-based final index.
          x['driver_elapsed_cycles']=x['cycles']+1
          x['driver_final_cycle_index']=x.pop('cycles')
        for arg in x.get('argv',[]):
          if arg.startswith(('+TRACE=','+CONTROL_TRACE=')):
            path=Path(arg.split('=',1)[1]);x.setdefault('trace_sha256',{})[path.name]=r.sha(path)
    save(name+'.json',compact)
  checks=[];acceptance=root/'acceptance';acceptance.mkdir(exist_ok=True)
  commands=[('config-program-yaml',[sys.executable,'-m','unittest','discover','-s','tests/config','-p','test_*.py','-v']),
      ('control-tools',[sys.executable,'-m','unittest','discover','-s','tests/control_network','-p','test_*.py','-v']),
      ('regression-scripts',[sys.executable,'-m','unittest','discover','-s','tests/scripts','-p','test_*.py','-v']),
      ('catalog',[sys.executable,'scripts/regression.py','--check-catalog']),
      ('python-source-inventory',[sys.executable,'migration_tools/inventory.py','--check']),
      ('diff-check',['git','diff','--check'])]
  for name,cmd in commands:
    x=r.command(cmd,acceptance/(name+'.log'),120);assert x['exit_code']==0,name
    x['name']=name;checks.append(x)
  save('checks.json',checks);freeze_logs(checks)
  if (root/'prerequisites/results.json').exists():
    d=json.loads((root/'prerequisites/results.json').read_text());assert d['all_passed']
    save('prerequisites.json',d);freeze_logs(d)
  # Existing PE regression is independently run, not part of the new transport
  # matrix. Export it when present; do not manufacture a pass if absent.
  pe=[]
  for path in sorted((SV/'build/current/pe-interfaces/rtl').glob('*/run.log')):
    text=path.read_text();assert 'CURRENT_PE_PASS' in text or 'CURRENT_STREAM_LOAD_PASS' in text,path
    name=str(path.relative_to(SV));logs[name]=text
    pe.append(dict(profile=path.parent.name,log=name,log_sha256=r.sha(path)))
  if pe:save('existing-pe.json',pe)
  save('logs.json',logs,normalize=False)
  summary=dict(baseline=r.BASELINE,all_passed=True,exact_baseline_host_packet_comparisons=comparisons,
      transport_profiles=sum(len(data[x]['cases']) for x in SUITES[:2]),
      transport_positive_runs=sum(len(c['runs']) for x in SUITES[:2] for c in data[x]['cases']),
      transport_negative_checks=sum(len(c['negatives']) for x in SUITES[:2] for c in data[x]['cases']),
      system_runs=sum(len(c['runs']) for n in ['pinned-system','system-stage-a','system-stage-b','system-large'] for c in data[n]['cases']),
      reduction_and_repeated_runs=sum(len(c['runs']) for c in data['reduction']['cases']),
      profile_rejections=len(data['guards']['cases']),synthesis_profiles=len(data['synth']['cases']),
      physical_evidence=dict(part=None,XDC=None,place_route=False,setup=None,hold=None,board=False))
  save('validation.json',summary)
  files=set(r.source_files())
  files.update(SV.glob('rtl/**/*.sv'));files.update(SV.glob('rtl/**/*.svh'));files.update(SV.glob('rtl/**/*.v'))
  files.update(HERE.glob('*.py'));files.update(HERE.glob('*.sv'));files.update(HERE.glob('*.svh'))
  files.update([SV/'tools/cgra_program.py',SV/'tools/cgra_config.py',SV/'tools/abi.json',
      SV/'filelists/native.f',SV/'tests/current/run_control_network.sh',SV/'tests/parameterization/driver.svh',
      SV/'tests/parameterization/generate.py',SV/'tests/parameterization/oracle.py',SV/'tests/parameterization/run.py',SV/'tests/parameterization/common.py'])
  manifest=dict(baseline=r.BASELINE,source_sha256={str(p.relative_to(SV.parent)):r.sha(p) for p in sorted(files)},evidence_sha256=saved)
  (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
  print(json.dumps(summary,indent=2));return 0


if __name__=='__main__':raise SystemExit(main())
