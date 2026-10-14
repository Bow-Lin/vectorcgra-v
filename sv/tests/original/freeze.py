"""Freeze captured original stimuli; never edits existing reference directories."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--root',type=Path,action='append',required=True)
  ap.add_argument('--output',type=Path,default=Path(__file__).parent/'fixtures')
  args=ap.parse_args()
  cases=json.loads((Path(__file__).parent/'cases.json').read_text())['cases']
  index=[]
  for case in cases:
    candidates=[p/str(case['id'])/'capture' for p in args.root if (p/str(case['id'])/'capture/result.json').exists()]
    if not candidates:continue
    assert len(candidates)==1, f"Ambiguous source for {case['id']}"
    source=candidates[0];result=json.loads((source/'result.json').read_text())
    assert result['status']!='running',f"Capture still running: {case['id']}"
    assert result['source_sha256']==case['source_sha256']
    target=args.output/str(case['id']);target.mkdir(parents=True,exist_ok=True)
    (target/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    for name in result['captures']:
      meta=json.loads((source/name/'manifest.json').read_text())
      data=(source/name/'vectors.txt').read_bytes()
      assert hashlib.sha256(data).hexdigest()==meta['vectors_sha256']
      dest=target/name;dest.mkdir(exist_ok=True)
      (dest/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
      (dest/'vectors.txt.gz').write_bytes(gzip.compress(data,mtime=0))
    index.append(dict(id=case['id'],python_status=result['status'],traces=len(result['captures'])))
  root=Path(__file__).resolve().parents[3]
  pin=root/'sv/reference/current/target.json'
  files=list((root/'sv/tests/original').glob('*.py'))+list((root/'sv/migration_tools').glob('original_test_*.py'))
  provenance=dict(schema=1,cases=index,
    python_target=json.loads(pin.read_text())['python_target_commit'],
    rtl_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
    source_pin_sha256=hashlib.sha256(pin.read_bytes()).hexdigest(),
    tool_files_sha256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)})
  (args.output/'index.json').write_text(json.dumps(provenance,indent=2)+'\n')
  print(f'Frozen {len(index)} cases / {sum(r["traces"] for r in index)} traces')


if __name__=='__main__':main()
