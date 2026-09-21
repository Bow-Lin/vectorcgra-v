"""Collect completed native SV runs; never generates or simulates RTL."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SV = ROOT/'sv'
TESTS = SV/'tests/phase3/vector_combo'
BUILD = SV/'build/phase3/vector_combo'
REF = SV/'reference/phase3/vector_combo'

def sha(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()

profiles = []
for definition in sorted(TESTS.glob('*/test.json')):
  info = json.loads(definition.read_text())
  label = info['label']
  build = BUILD/label
  result = json.loads((build/'result.json').read_text())
  log = (build/'run.log').read_text()
  assert 'P3_VECTOR_PASS' in log and '%Fatal' not in log, label
  assert result['status']=='pass' and result['cycles']==640 and result['arithmetic_checks']==640, label
  assert all(result['operation_hits']), label
  manifest = json.loads((REF/label/'manifest.json').read_text())
  assert sha(REF/label/'reference.v')==manifest['rtl_sha256'], label
  record = dict(**result, opcodes=info['opcodes'], parameters=info['parameters'],
    oracle='translated_hdl', python_equivalence=False if info['case']=='vector_mul_combo' else 'not_claimed',
    legacy_ctrl_adapter=info['legacy_ctrl_adapter'],
    reference_sha256=manifest['rtl_sha256'], bench_sha256=sha(definition.parent/'tb.sv'),
    run_log_sha256=sha(build/'run.log'), run_log=str((build/'run.log').relative_to(SV)).replace('\\','/'))
  if info['case']=='vector_mul_combo':
    record['discrepancy_witness']=next(line for line in log.splitlines() if line.startswith('HDL_SHIFT_WITNESS'))
    record['frozen_shift_expressions']=[dict(line=n,expression=line.strip()) for n,line in
      enumerate((REF/label/'reference.v').read_text().splitlines(),1)
      if 'send_out__msg' in line and 'temp_result[' in line and ' = ' in line]
  profiles.append(record)
assert len(profiles)==30, len(profiles)
multp_log=(BUILD/'multp/run.log').read_text()
assert 'MULTP_PASS configurations=9 total_samples=18432' in multp_log
multp_cases=[dict(zip(('A_W','B_W','OUT_W','samples'),map(int,match))) for match in
  re.findall(r'MULTP_CASE_PASS A=(\d+) B=(\d+) O=(\d+) samples=(\d+)',multp_log)]
assert len(multp_cases)==9
synth=(BUILD/'synthesis/yosys.log').read_text()
assert 'ERROR:' not in synth
assert len(re.findall('Found and reported 0 problems',synth))==7
negative=(BUILD/'vector_adder_w32_l4_b8_v0/negative.log').read_text()
assert 'intentional negative control: corrupt independent expected result' in negative
assert 'independent leaf arithmetic cycle=64' in negative and '%Fatal' in negative
sources=sorted((SV/'rtl/fu/vector').glob('*.sv'))+sorted((SV/'rtl/fu/combo').glob('*.sv'))
report=dict(schema=1,baseline_commit='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b',
  collected_utc=datetime.now(timezone.utc).isoformat(), status='pass',
  profile_count=30, total_fu_cycles=sum(p['cycles'] for p in profiles),
  independent_fu_arithmetic_checks=sum(p['arithmetic_checks'] for p in profiles),
  raw_invalid_comparison=True, simulation='Verilator 5.050 two-state',
  formal_equivalence=False, source_hash_capture='Final native source tree, collected after profile runs.',
  native_source_sha256={str(p.relative_to(SV)).replace('\\','/'):sha(p) for p in sources},
  profiles=profiles,
  multp=dict(status='pass',samples=18432,exact_partial_outputs=True,independent_signed_unsigned_product=True,
    cases=multp_cases,bench_sha256=sha(TESTS/'tb_multp.sv'),log_sha256=sha(BUILD/'multp/run.log')),
  synthesis=dict(status='pass',profiles=7,flow='sv2v -> Yosys proc; opt; check -assert; stat',
    scope='Native cgra_multp and MAC only', area_measured=False,frequency_measured=False,
    log_sha256=sha(BUILD/'synthesis/yosys.log')),
  negative=dict(status='pass',profile='vector_adder_w32_l4_b8_v0',
    mechanism='Independent expected payload bit is flipped at cycle64; ordinary arithmetic checker fatals.',
    log_sha256=sha(BUILD/'vector_adder_w32_l4_b8_v0/negative.log')),
  baseline_exceptions=[
    dict(case='prl_mul_adder',failed_profile='prl_mul_adder_w32_l4_b8_v0',
      reason='ac96 4-input Ctrl selector is wider than the two-input child selector; zext fails.',
      compatible_domain='Original ctrl2 HDL with explicit field adapter to native ctrl4.'),
    dict(case='vector_mul_combo',oracle='translated_hdl',python_equivalence=False,
      evidence='python_hdl_discrepancy.json',reason='Narrow RTLIR shift-count multiplication truncates.')])
(TESTS/'results.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print(f"P3_VECTOR_RESULTS_PASS profiles={len(profiles)} FU_cycles={report['total_fu_cycles']} multp_samples=18432")
