"""Normalize only diagnostic `line filenames in frozen Windows FP gold RTL."""
from pathlib import Path
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
for folder in sorted((ROOT/'reference/phase3/float').iterdir()):
    source=folder/'gold.v'
    if not source.exists():
        continue
    text=source.read_text()
    changes=[]
    def normalize(match):
        before=match[0]
        after=match[1]+match[2].replace('\\','/')+match[3]
        if before!=after:
            changes.append(dict(before=before,after=after))
        return after
    portable=re.sub(r'(?m)^(`line\s+\d+\s+")([^"]+)("\s+\d+\s*)$',normalize,text)
    # Reconstruct the complete original namespace file before accepting output.
    restored=portable
    for item in changes:
        restored=restored.replace(item['after'],item['before'],1)
    assert restored==text
    target=folder/'gold_portable.v'
    target.write_text(portable,newline='\n')
    report=dict(parent='gold.v',parent_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        derived='gold_portable.v',derived_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        changes=changes,roundtrip_verified=True,
        reason='Unescaped Windows paths in original diagnostic `line directives are rejected by Verilator; only filenames use forward slashes.')
    (folder/'portable_manifest.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    print(f'FLOAT_PORTABLE_PASS {folder.name} line_changes={len(changes)}')
