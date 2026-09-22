"""Freeze SV configuration headers from measured ac96 packet field offsets."""
import json
from pathlib import Path

SV=Path(__file__).resolve().parents[1]
for manifest in sorted((SV/'reference/phase4/noc').glob('*/manifest.json')):
  info=json.loads(manifest.read_text())
  if info['status']!='exported':continue
  out=SV/'tests/phase4/noc'/info['label']
  out.mkdir(parents=True,exist_ok=True)
  text=[f'// Measured via original PyMTL packet packer; source manifest: {manifest.parent.name}',
    f'`define PHASE4_NOC_GOLD {info["top"]}',f'localparam string PROFILE_LABEL="{info["label"]}";',
    f'localparam bit IS_RING={int(info["network"]=="ring")};']
  text += [f'localparam int {name}={value};' for name,value in info['parameters'].items()]
  (out/'profile.svh').write_text('\n'.join(text)+'\n',newline='\n')
  (out/'profile.json').write_text(json.dumps(dict(label=info['label'],network=info['network'],parameters=info['parameters'],
    rtl_sha256=info['rtl_sha256']),indent=2)+'\n',newline='\n')
  print('PROFILE '+info['label'])
