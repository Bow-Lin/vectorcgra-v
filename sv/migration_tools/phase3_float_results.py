"""Collect already executed FP evidence; never part of the native HDL build."""
import hashlib
import json
from pathlib import Path
import re

SV=Path(__file__).resolve().parents[1]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
profiles=[]
for label in ['add-e8-s23','mul-e8-s23','add-e4-s11','mul-e4-s11']:
    folder=SV/'build/phase3/float'/label
    text=(folder/'run.log').read_text()
    banner=re.search(r'PHASE3_FLOAT_PASS[^\n]+',text).group(0)
    assert 'samples=1170' in banner and 'arithmetic_checks=168' in banner
    profiles.append(dict(profile=label,status='passed',banner=banner,
        samples=1170,finite_math_checks=160,special_checks=8,
        logs={p.name:sha(p) for p in folder.glob('*.log')}))
negative=(SV/'build/phase3/float/add-e8-s23/negative.log').read_text()
assert 'FP arithmetic' in negative and 'PHASE3_FLOAT_PASS' not in negative
paths=[SV/line for line in (SV/'filelists/phase3_float.f').read_text().splitlines() if line and not line.startswith('+')]
paths+=list((SV/'rtl/vendor/hardfloat').glob('*.vi'))
paths+=list((SV/'rtl/common').glob('cgra_profile*.svh'))
paths+=[SV/'filelists/phase3_float.f']+list((SV/'tests/phase3/float').glob('*'))
report=dict(schema=1,status='passed',baseline_commit='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b',
    profiles=profiles,negative_control='Wrong arithmetic expectation caused nonzero simulation exit in the normal checker; runner checked error text.',
    source_sha256={p.relative_to(SV).as_posix():sha(p) for p in paths if p.is_file()},
    comparison='Raw complete FU outputs, including invalid messages; frozen original HDL uses the same original HardFloat IP.',
    independent_oracle='Integer-based exact finite arithmetic plus independently constructed special-value expectations.',
    synthesis_summary='phase3-float-synthesis.json',
    limitations=['Finite two-state verification, not exhaustive/four-state proof.',
      'No pure-Python simulation claim for external Verilog placeholders.',
      'ac96 exp/sig mapping and FINC=0.5 behavior intentionally preserved.',
      'No standard-cell mapping, area comparison or frequency measurement.'])
(SV/'results/phase3-float.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('PHASE3_FLOAT_EVIDENCE_COLLECTED')
