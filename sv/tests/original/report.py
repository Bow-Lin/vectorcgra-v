"""Aggregate all selected original cases without dropping failures or omissions."""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import shutil


def is_diagnostic(row):
  return bool(row.get('diagnostic_only') or row.get('reference_variant') or any(
    replay.get('mode') == 'compatibility' for replay in row.get('replays', [])))


def copy_evidence(row, destination, report_directory):
  """Keep portable logs next to a report, checking recorded hashes first."""
  for replay in row.get('replays', []):
    target = destination/str(row['id'])/replay['trace']
    for stage in ['run', 'negative', 'negative_memory', 'negative_reset']:
      if stage not in replay:
        continue
      record = replay[stage]
      source = Path(record['log'])
      assert hashlib.sha256(source.read_bytes()).hexdigest() == record['log_sha256'], source
      target.mkdir(parents=True, exist_ok=True)
      saved = target/source.name
      shutil.copyfile(source, saved)
      record['log'] = os.path.relpath(saved, report_directory)
      if stage == 'run' and (source.parent/'transactions.json').exists():
        saved = target/'transactions.json'
        shutil.copyfile(source.parent/'transactions.json', saved)
        replay['transaction_evidence'] = dict(
          path=os.path.relpath(saved, report_directory),
          sha256=hashlib.sha256(saved.read_bytes()).hexdigest())


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--root',type=Path,action='append',required=True)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--evidence-dir',type=Path,
    help='Copy checked replay logs; paths in the report become relative to its directory')
  args=ap.parse_args()
  catalog=json.loads((Path(__file__).parent/'cases.json').read_text())['cases']
  rows=[]
  for case in catalog:
    found=[p/str(case['id'])/'result.json' for p in args.root if (p/str(case['id'])/'result.json').is_file()]
    assert len(found)<=1, f"Multiple acceptance results for case {case['id']}"
    row=json.loads(found[0].read_text()) if found else dict(id=case['id'],status='not_run')
    row.update(group=case['group'],file=case['file'],function=case['function'],parameters=case['parameters'])
    if found:
      logs=list(found[0].parent.glob('capture/dut*/sv.log'))
      row['first_failure']=next((line for p in logs for line in p.read_text().splitlines()
        if any(s in line for s in ['ORIGINAL_MISMATCH','ORIGINAL_TRANSACTION_MISMATCH','ORIGINAL_TRANSACTION_EXTRA','ORIGINAL_TRANSACTION_TIMEOUT','PORT_WIDTH'])),'')
    if is_diagnostic(row):
      row['diagnostic_only'] = True
    if args.evidence_dir:
      copy_evidence(row, args.evidence_dir, args.output.parent)
    rows.append(row)
  counts=dict(collections.Counter(r['status'] for r in rows))
  result=dict(schema=1,total=len(rows),counts=counts,
    all_passed=all(r['status']=='passed' and not is_diagnostic(r) for r in rows),cases=rows)
  args.output.parent.mkdir(parents=True,exist_ok=True)
  args.output.write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))
  return int(not result['all_passed'])


if __name__=='__main__':raise SystemExit(main())
