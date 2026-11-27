#!/usr/bin/env python3
"""Reproducible control-transport comparison against the fixed 03db4c7 ring."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

SV = Path(__file__).resolve().parents[2]
BASELINE = '03db4c735dc9573ee19d5080eb123cc106333ba3'


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def clean_compiler_objects(binary):
  # Run only after linking has finished. Executables, generated source, logs
  # and JSON evidence remain; PCH/object archives alone can exceed 140 MiB.
  for path in Path(binary).parent.iterdir():
    if path.is_file() and (path.suffix in {'.o','.a','.gch','.d'} or '.gch' in path.name):
      path.unlink()


def command(argv, log, timeout=300):
  log = Path(log)
  if log.exists():
    i = 1
    while log.with_name(log.name + f'.attempt{i}').exists():
      i += 1
    log.rename(log.with_name(log.name + f'.attempt{i}'))
  started = time.monotonic()
  with log.open('w') as stream:
    try:
      status = subprocess.run([str(x) for x in argv], cwd=SV,
          stdout=stream, stderr=subprocess.STDOUT, timeout=timeout).returncode
    except subprocess.TimeoutExpired:
      status = 124
  return dict(argv=[str(x) for x in argv], exit_code=status,
      seconds=round(time.monotonic()-started, 3), log=str(log), log_sha256=sha(log))


def source_files():
  result = [SV/'filelists/control_network.f', SV/'rtl/common/cgra_profile_defs.svh',
      SV/'rtl/common/cgra_profile.svh', SV/'rtl/common/cgra_ctrl_commands.svh',
      SV/'tests/current/tb_control_network.sv']
  result += [SV/line.strip() for line in (SV/'filelists/control_network.f').read_text().splitlines()
      if line.strip() and not line.startswith('+')]
  return result


def main():
  ap = argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output', type=Path, required=True)
  ap.add_argument('--geometries', default='2x2,3x3,4x4,2x3,3x2')
  ap.add_argument('--backends', default='0,1,2')
  ap.add_argument('--jobs', type=int, default=2)
  ap.add_argument('--multicast', action='store_true')
  args = ap.parse_args()
  output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
  previous = output/'results.json'
  if previous.exists():
    previous.rename(output/f'previous-results-{time.time_ns()}.json')
  verilator = os.environ.get('VERILATOR', 'verilator')
  version = subprocess.check_output([verilator, '--version'], text=True).strip()
  sources = {str(p.relative_to(SV)): sha(p) for p in source_files()}
  # Compare actual primitive blobs to the specified commit, not to a local
  # FPGA experiment or a moving branch. The wrapper's new parameter is unused
  # by the original transport, whose queue/router/arbitration RTL is unchanged.
  pinned = {}
  for path in source_files():
    if '/rtl/noc/cgra_ctrl_' in str(path) or path.suffix != '.sv' or '/rtl/' not in str(path):
      continue
    name = str(path.relative_to(SV.parent))
    blob = subprocess.check_output(['git', 'show', f'{BASELINE}:{name}'], cwd=SV)
    assert hashlib.sha256(blob).hexdigest() == sha(path), f'Changed original primitive: {name}'
    pinned[name] = sha(path)
  report = dict(schema=1, baseline=BASELINE, evidence='RTL simulation only',
      verilator=version, sources=sources, original_primitive_sha256=pinned, cases=[])
  def save():
    (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')
  for shape in args.geometries.split(','):
    cols, rows = map(int, shape.split('x'))
    for backend in map(int, args.backends.split(',')):
      if args.multicast and backend==0:
        raise ValueError('Original ring does not implement native CONFIG multicast')
      # Include shared maximum geometry larger than the actual instance in
      # both orientations. The root remains NUM_TILES, not MAX_TILES.
      max_cols = cols+1 if shape in {'2x3','3x2'} else cols
      params = dict(COLS=cols, ROWS=rows, MAX_COLS=max_cols, MAX_ROWS=rows, BACKEND=backend,
          CTRL_MULTICAST=int(args.multicast))
      key = hashlib.sha256(json.dumps([params, sources, version], sort_keys=True).encode()).hexdigest()[:16]
      folder=output/f'{shape}-backend{backend}';folder.mkdir(exist_ok=True)
      build=output/'build'/key;build.mkdir(parents=True, exist_ok=True)
      binary=build/'Vtb_control_network'
      identity=build/'identity.json'
      row=dict(parameters=params, status='running', runs=[],negatives=[]);report['cases'].append(row);save()
      if not binary.exists():
        row['build']=command([verilator,'--binary','--timing','-j',str(args.jobs),'-Wno-fatal',
          '-f','filelists/control_network.f','--top-module','tb_control_network','--Mdir',build,
          *[f'-G{k}={v}' for k,v in params.items()], 'tests/current/tb_control_network.sv'],folder/'compile.log')
        if row['build']['exit_code']==0 and binary.exists():
          identity.write_text(json.dumps(dict(key=key,binary_sha256=sha(binary)),indent=2)+'\n')
      elif identity.exists():
        saved=json.loads(identity.read_text())
        assert saved['key']==key and saved['binary_sha256']==sha(binary),'Changed cached binary'
      if not binary.exists():
        row['status']='build_failed';save();continue
      clean_compiler_objects(binary)
      row['binary_sha256']=sha(binary)
      for mode in ['normal','backpressure']:
        result=folder/f'{mode}.json'
        record=command([binary,f'+RESULT={result}']+(['+BACKPRESSURE'] if mode=='backpressure' else []),folder/f'{mode}.log')
        record['mode']=mode
        record['passed']=record['exit_code']==0 and (folder/f'{mode}.log').read_text().count('CTRL_NETWORK_PASS')==2
        if record['passed']:
          record['metrics']=json.loads(result.read_text())
          record['passed']=(record['metrics']['backend']==backend and record['metrics']['cols']==cols
              and record['metrics']['rows']==rows and record['metrics']['multicast']==int(args.multicast))
        row['runs'].append(record)
      negatives={'BAD_EXPECTED':'CTRL_NETWORK_DOWN_MISMATCH'}
      if backend:
        negatives['INVALID_TARGET']='CTRL_NETWORK_INVALID_TARGET'
        if not args.multicast:negatives['DISABLED_MULTICAST']='CTRL_MULTICAST_DISABLED'
        else:
          negatives.update(ZERO_MASK='CTRL_MULTICAST_TARGETS',UNLOADED_MASK='CTRL_MULTICAST_TARGETS',
              INVALID_MASK_WORD='CTRL_MULTICAST_MASK_WORD')
          if cols*rows%32:negatives['BAD_MASK_PADDING']='CTRL_MULTICAST_MASK_WORD'
      for flag,marker in negatives.items():
        log=folder/f'negative-{flag}.log'
        record=command([binary,'+'+flag],log,30)
        record.update(flag=flag,expected_marker=marker)
        record['passed']=record['exit_code'] not in {0,124} and marker in log.read_text()
        row['negatives'].append(record)
      row['status']='passed' if all(r['passed'] for r in row['runs']+row['negatives']) else 'failed'
      print(f'CONTROL_NETWORK {shape} backend={backend}: {row["status"]}',flush=True);save()
  assert sources == {str(p.relative_to(SV)):sha(p) for p in source_files()}, 'Sources changed during run'
  report['all_passed']=bool(report['cases']) and all(c['status']=='passed' for c in report['cases'])
  save()
  return int(not report['all_passed'])


if __name__ == '__main__':
  raise SystemExit(main())
