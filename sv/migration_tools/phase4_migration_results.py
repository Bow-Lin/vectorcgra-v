"""Collect system/memory replay evidence and verify the exact compiled sources."""
import hashlib,json,re
from pathlib import Path

SV=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def compiled_sources(build):
  hashes={}
  assert (build/'result.json').stat().st_mtime >= (build/'compiled_sources.sha256').stat().st_mtime, 'Result predates this compilation'
  for line in (build/'compiled_sources.sha256').read_text().splitlines():
    match=re.fullmatch(r'([a-f0-9]{64}) [ *](.+)',line)
    assert match,('unexpected sha256sum record',line)
    expected,name=match.groups()
    actual=sha(SV/name)
    assert actual==expected,('compiled source changed; rebuild required',name,expected,actual)
    hashes[name]=expected
  return hashes


def main():
  summaries=[]
  for label in ('dynamic_fir','global_add'):
    ref=SV/'reference/phase4/migration'/label;build=SV/'build/phase4/migration'/label
    oracle=json.loads((ref/'manifest.json').read_text());result=json.loads((build/'result.json').read_text())
    assert oracle['status']=='recorded' and result['status']=='pass'
    assert result['cycles']==oracle['cycles'] and result['raw_bits_per_cycle']==oracle['output_bits']
    assert sha(ref/'cycles.txt')==oracle['trace_sha256']
    assert sha(ref/'exporter_snapshot.py')==oracle['exporter_sha256']
    assert 'MATH_RESULT mismatch intentional negative control' in (build/'negative.log').read_text()
    result.update(label=label,oracle='unmodified ac96 Python full system',hdl_equivalence=False,
      independent_math=oracle['independent_math'],trace_sha256=oracle['trace_sha256'],
      source_sha256=compiled_sources(build),oracle_manifest_sha256=sha(ref/'manifest.json'),
      log_sha256=sha(build/'run.log'),negative_log_sha256=sha(build/'negative.log'),
      test_profile=json.loads((SV/'tests/phase4/migration'/label/'test_profile.json').read_text()))
    summaries.append(result)
  result=dict(status='pass',profiles=summaries,total_cycles=sum(r['cycles'] for r in summaries),
    total_raw_compared_bits=sum(r['cycles']*r['raw_bits_per_cycle'] for r in summaries),
    limitations=['Two-state SV replay of the original Python model; no four-state or translated-HDL system equivalence claim.',
      'The dynamic FIR uses the original source/sink scheduling; global-add additionally applies host backpressure.',
      'Dynamic FIR exercises one active inter-CGRA physical boundary direction; every boundary signal is raw-compared.',
      'The original caller FuList is recorded before elaboration; test_profile explicitly adds the original implicit final Nah unit.'])
  (SV/'tests/phase4/migration/results.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')
  build=SV/'build/phase4/memory/r1w3';ref=SV/'reference/phase4/memory/r1w3'
  memory=json.loads((build/'result.json').read_text());gold=json.loads((ref/'manifest.json').read_text())
  assert memory['status']=='pass' and memory['cycles']==464 and memory['stall_samples']>=8
  assert sha(ref/'reference.v')==gold['rtl_sha256'] and sha(ref/'exporter_snapshot.py')==gold['exporter_sha256']
  assert 'MEM_MATH_MISMATCH intentional negative control' in (build/'negative.log').read_text()
  failed=json.loads((SV/'reference/phase4/memory/r3w1/manifest.json').read_text())
  assert failed['status']=='baseline_export_failed'
  memory.update(label='r1w3',oracle='unmodified ac96 translated HDL, all raw output bits including invalid cycles',
    source_sha256=compiled_sources(build),reference_sha256=gold['rtl_sha256'],oracle_manifest_sha256=sha(ref/'manifest.json'),
    log_sha256=sha(build/'run.log'),negative_log_sha256=sha(build/'negative.log'),
    baseline_failure=dict(label='r3w1',stage='Verilog translation after successful elaboration',
      reason='DataMemControllerRTL.py:508 truncates a 1-bit write-crossbar source to a larger 2-bit NoC remote-src-port; RTLIR rejects it.',
      native_baseline_equivalence_claimed=False),limitations=['Two-state execution; no X-state equivalence claim.',
      'The last 300 cycles are arbitrary differential traffic, not transaction-scoreboard coverage.'])
  (SV/'tests/phase4/memory/results.json').write_text(json.dumps(memory,indent=2)+'\n',newline='\n')
  print('PHASE4_SYSTEM_MEMORY_RESULTS_PASS current compiled sources match')


if __name__=='__main__':main()
