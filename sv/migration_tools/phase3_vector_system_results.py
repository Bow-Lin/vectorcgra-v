"""Freeze completed vector-system replay evidence; no simulation or RTL edits."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
SV=ROOT/'sv'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
  build=SV/'build/phase3/system/vector'
  ref=SV/'reference/phase3/system/vector/2x2'
  vectors=SV/'vectors/phase3/system/vector/2x2'
  reference=json.loads((ref/'manifest.json').read_text())
  oracle=json.loads((vectors/'manifest.json').read_text())
  layout=json.loads((vectors/'replay_layout.json').read_text())
  run=(build/'run.log').read_text()
  match=re.search(r'PHASE3_PROGRAMMABLE_VECTOR_PASS .*',run)
  assert match and 'cycles=134 pymtl_cycles=134 bits=489' in match[0]
  assert 'intentional negative control: West result mismatch' in (build/'negative.log').read_text()
  assert 'TIMEOUT scenario=' in (build/'timeout.log').read_text()
  assert sha(ref/reference['rtl'])==reference['rtl_sha256']
  assert sha(vectors/'baseline_trace.jsonl')==oracle['trace_sha256']
  for side in ['inputs','outputs']:
    info=layout['layouts'][side]
    assert sha(vectors/info['file'])==info['sha256']
  # Verilator records every source's byte count and second-granularity mtime.
  # Refuse to silently attach a new SHA to a file changed after compilation.
  runtime={}; timestamp_file=build/'Vtb_programmable_vector__verFiles.dat'
  for line in timestamp_file.read_text().splitlines():
    if not line.startswith('S '): continue
    quoted=re.findall(r'"([^"]*)"',line)
    path=Path(quoted[-1].replace('\\','/'))
    if not path.is_absolute(): path=SV/path
    try: rel=path.resolve().relative_to(ROOT)
    except ValueError: continue
    values=line.split()
    assert path.stat().st_size==int(values[1]),('compiled-source-size-changed',rel)
    assert int(path.stat().st_mtime)==int(values[5]),('compiled-source-mtime-changed',rel)
    runtime[rel.as_posix()]=sha(path)
  for p in [SV/'filelists/phase3.f',SV/'tests/phase3/system/run_vector.sh']:
    runtime[p.relative_to(ROOT).as_posix()]=sha(p)
  result=dict(status='pass',baseline_commit=reference['baseline_commit'],
    source_checkout_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    collected_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    parameters=oracle['parameters'],functional_units=reference['fixed_options']['functional_units'],
    vector_lanes=4,lane_width=8,program='load bank0[15]; independent 8-bit lane add 0x05040302; scalar multiply by3 modulo32; lane subtract 0x08070605; store bank1[16]; multicast west[1]',
    pass_banner=match[0],input_bits=505,output_bits=489,samples=134,
    scenarios=oracle['scenarios'],
    comparison_contract='All 489 active raw output bits, including invalid messages, match original Python trace and separately frozen ac96 HDL at 134 pre-edge observations. All 505 recorded input bits also match. Two-state simulation.',
    excluded_outputs=layout['excluded_outputs'],
    independent_assertions=['Per-lane integer arithmetic before/after scalar multiply; exact expected value on every native/gold internal chain link.',
      'Exactly four Tile completions, one west multicast, readback address16 result and unchanged address15 input in each reset-separated scenario.',
      '26 independently packed configuration/query packets per scenario equal canonical ac96 packet words.',
      'Host output stable under backpressure; west held for 8 valid cycles; host held for 6 then periodic stalls.',
      'EXPECT_FAILURE perturbs only independent expected result and must fail; STALL_FOREVER/MAX_CYCLES=200 must fail with timeout.'],
    commands=[
      dict(command='python sv/migration_tools/phase3_vector_system_scaffold.py',exit_code=0),
      dict(command='python sv/migration_tools/phase3_vector_system_export.py --cols 2 --rows 2',exit_code=0),
      dict(command='C:/msys64/usr/bin/bash.exe sv/tests/phase3/system/run_vector.sh',exit_code=0),
      dict(command='build/phase3/system/vector/system_test.exe +VECTORS=<absolute vector directory> +EXPECT_FAILURE',exit_code=1,expected_failure=True),
      dict(command='build/phase3/system/vector/system_test.exe +VECTORS=<absolute vector directory> +STALL_FOREVER +MAX_CYCLES=200',exit_code=1,expected_failure=True)],
    runtime_source_sha256=runtime,
    compiled_source_timestamp_record=dict(path=timestamp_file.relative_to(ROOT).as_posix(),sha256=sha(timestamp_file)),
    oracle_artifacts_sha256={p.relative_to(ROOT).as_posix():sha(p) for directory in [ref,vectors] for p in directory.rglob('*') if p.is_file()},
    logs_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in build.glob('*.log')},
    limitations=['Single-CGRA base Tile 2x2, 32-bit data, four lanes; finite workload, not exhaustive equivalence.',
      'No VectorMulCombo is used; no claim of repairing or masking its original high-lane routing limitation.',
      'Three externally inactive inter-CGRA outputs are excluded exactly as earlier single-CGRA reference contract; no additional output masking.',
      'No area/frequency or full technology-mapping result is claimed by this integration test.'],
    source_changes='No project Python or existing RTL changed by this test delivery',collector_sha256=sha(Path(__file__)))
  output=SV/'results/phase3-vector-system.json'
  output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
  print('VECTOR_SYSTEM_RESULTS_PASS runtime_files='+str(len(runtime)))


if __name__=='__main__': main()
