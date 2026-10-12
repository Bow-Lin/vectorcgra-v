#!/usr/bin/env python3
"""Run the same native regression shards locally and in CI; Python stdlib only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

SV = Path(__file__).resolve().parents[1]


def catalog(root=SV):
  data = json.loads((root / 'scripts/regression.json').read_text())
  shards = data['shards']
  targets = [target for group in shards.values() for target in group]
  if len(targets) != len(set(targets)):
    raise ValueError('A regression target is assigned to multiple shards')
  make = (root / 'Makefile').read_text()
  declared = set(re.findall(r'(?m)^([a-z][a-z0-9-]*):', make))
  required = {name for name in declared if name.startswith(('current-', 'native-'))
              or name in {'current', 'config-tools', 'program-tools', 'baseline'}}
  required -= set(data['excluded_aliases'])
  if set(targets) != required:
    raise ValueError(f'Regression catalog mismatch: omitted={sorted(required-set(targets))}, unknown={sorted(set(targets)-required)}')
  return data


def fingerprint(root=SV):
  result = {}
  for directory in ['rtl', 'filelists', 'tests', 'tools', 'scripts', 'reference', 'examples']:
    for path in sorted((root / directory).rglob('*')):
      if not path.is_file() or '__pycache__' in path.parts or path.suffix == '.pyc':
        continue
      result[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
  result['Makefile'] = hashlib.sha256((root / 'Makefile').read_bytes()).hexdigest()
  return result


def versions():
  commands = {
    'verilator': [os.environ.get('VERILATOR', 'verilator'), '--version'],
    'yosys': [os.environ.get('YOSYS', 'yosys'), '-V'],
    'sv2v': [os.environ.get('SV2V', 'sv2v'), '--version'],
    'cxx': [os.environ.get('CXX', 'c++'), '--version'],
  }
  output = {'python': sys.version.splitlines()[0]}
  for name, command in commands.items():
    process = subprocess.run(command, text=True, capture_output=True, check=True)
    output[name] = (process.stdout or process.stderr).splitlines()[0]
  return output


def save(path, record):
  temporary = path.with_suffix('.tmp')
  temporary.write_text(json.dumps(record, indent=2) + '\n')
  temporary.replace(path)


def run_shard(name, targets, destination, make='make'):
  destination.mkdir(parents=True, exist_ok=True)
  output = destination / 'result.json'
  before = fingerprint()
  record = dict(schema=1, shard=name, status='running', tool_versions=versions(),
                input_sha256=before, started_at_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                jobs=os.environ.get('JOBS', '2'), steps=[])
  save(output, record)
  for target in targets:
    log = destination / (target + '.log')
    command = [make, '-C', str(SV), target]
    print(f'REGRESSION_START shard={name} target={target}', flush=True)
    started = time.monotonic()
    try:
      with log.open('w') as stream:
        status = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT).returncode
    except OSError as error:
      log.write_text(str(error) + '\n')
      status = 127
    step = dict(target=target, command=command, exit_code=status,
                seconds=round(time.monotonic()-started, 3),
                log=log.name, log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
    record['steps'].append(step)
    save(output, record)
    if status:
      record['status'] = 'failed'
      record['not_run'] = targets[len(record['steps']):]
      save(output, record)
      print(log.read_text(errors='replace')[-6000:], file=sys.stderr)
      print(f'REGRESSION_FAIL shard={name} target={target} exit={status}', file=sys.stderr)
      return 1
    print(f'REGRESSION_STEP_PASS shard={name} target={target}', flush=True)
  after = fingerprint()
  if after != before:
    record['status'] = 'source_changed_during_run'
    record['changed_inputs'] = sorted(p for p in set(before)|set(after) if before.get(p) != after.get(p))
    save(output, record)
    print('REGRESSION_FAIL source changed during execution', file=sys.stderr)
    return 1
  record['status'] = 'passed'
  record['completed_at_utc'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
  save(output, record)
  print(f'REGRESSION_SHARD_PASS shard={name} targets={len(targets)}', flush=True)
  return 0


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  group = parser.add_mutually_exclusive_group(required=True)
  group.add_argument('--list', action='store_true', help='Print native shard names as a JSON array')
  group.add_argument('--check-catalog', action='store_true')
  group.add_argument('--all', action='store_true')
  group.add_argument('--shard')
  group.add_argument('--source-audit', action='store_true', help='Requires the original project Python source files')
  parser.add_argument('--dry-run', action='store_true')
  parser.add_argument('--output', type=Path, default=SV/'build/regression')
  args = parser.parse_args()
  try:
    data = catalog()
    if args.list:
      print(json.dumps(list(data['shards'])))
      return 0
    if args.check_catalog:
      print('REGRESSION_CATALOG_PASS shards=%d targets=%d' % (len(data['shards']), sum(map(len, data['shards'].values()))))
      return 0
    if args.source_audit:
      selected = {'source-audit': [data['source_audit']['target']]}
    elif args.all:
      selected = data['shards']
    elif args.shard in data['shards']:
      selected = {args.shard: data['shards'][args.shard]}
    else:
      raise ValueError('Unknown regression shard: ' + str(args.shard))
    if args.dry_run:
      print(json.dumps(selected, indent=2))
      return 0
    for name, targets in selected.items():
      if run_shard(name, targets, args.output/name):
        return 1
    return 0
  except (OSError, ValueError, subprocess.CalledProcessError) as error:
    print('REGRESSION_ERROR ' + str(error), file=sys.stderr)
    return 2


if __name__ == '__main__':
  raise SystemExit(main())
