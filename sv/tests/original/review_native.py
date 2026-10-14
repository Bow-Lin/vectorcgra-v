"""Run native-contract checks for the fourteen substantive source differences.

Original strict failures and compatibility evidence remain separate. A native
contract check does not turn the old raw trace into a cycle-equivalence pass.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

from run import ROOT, command


CHECKS = [
  ('ieee_math', 'arithmetic', [42, 43], 'run_native_math.sh', {}),
  ('inclusive_div', 'arithmetic', [95], 'run_arithmetic_boundaries.sh',
   {'ARITHMETIC_PROFILE_FILTER': 'inclusive_w32_l4'}),
  ('vector_reduce', 'arithmetic', [122], 'run_vector_reduce.sh', {}),
  ('vector_arithmetic', 'arithmetic', [123], 'run_vector_arithmetic.sh', {}),
  ('memory', 'fabric', [134, 135], 'run_memory_boundaries.sh', {}),
  ('switch', 'fabric', list(range(175, 182)), 'run_noc_primitives.sh', {}),
]


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output', type=Path, required=True)
  parser.add_argument('--group', choices=['arithmetic', 'fabric'])
  args = parser.parse_args()
  args.output.mkdir(parents=True, exist_ok=True)
  results = []
  for name, group, case_ids, script, variables in CHECKS:
    if args.group and group != args.group:
      continue
    env = dict(os.environ, JOBS='1', **variables)
    argv = ['bash', 'sv/tests/current/'+script]
    print('NATIVE_REVIEW_START', name, flush=True)
    record = command(argv, args.output/(name+'.log'), 1800, cwd=ROOT, env=env)
    record.update(name=name, case_ids=case_ids, argv=argv, variables=variables,
      status='passed' if record['exit_code']==0 else 'failed',
      test_sha256=hashlib.sha256((ROOT/argv[1]).read_bytes()).hexdigest())
    results.append(record)
    (args.output/'results.json').write_text(json.dumps(dict(schema=1,
      coverage='native_functional_contract_not_raw_cycle_equivalence', checks=results), indent=2)+'\n')
    print('NATIVE_REVIEW_RESULT', name, record['status'], flush=True)
  return int(any(r['status']!='passed' for r in results))


if __name__=='__main__':raise SystemExit(main())
