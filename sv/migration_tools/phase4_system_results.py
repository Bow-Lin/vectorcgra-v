"""Archive final system evidence; this script is migration-only, never a build dependency."""
import hashlib, json, re
from datetime import datetime, timezone
from pathlib import Path

SV = Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')

def compiled(build, prefix):
  hashes={}
  for line in (build/'compiled_sources.sha256').read_text().splitlines():
    m=re.fullmatch(r'([a-f0-9]{64}) [ *](.+)',line)
    assert m, line
    expected,name=m.groups();assert sha(SV/name)==expected, ('changed source',name)
    hashes[name]=expected
  assert (build/'run.log').stat().st_mtime >= (build/'compiled_sources.sha256').stat().st_mtime
  # Verilator records every consumed header and reference, not just the explicit filelist.
  metadata=build/(prefix+'__verFiles.dat')
  consumed={}
  for line in metadata.read_text().splitlines():
    m=re.fullmatch(r'S\s+(\d+)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+"[^"]*" "([^"]+)"',line)
    if not m:continue
    size,mtime,name=m.groups();name=name.replace('\\','/')
    if Path(name).is_absolute():continue
    p=SV/name
    assert p.stat().st_size==int(size) and int(p.stat().st_mtime)==int(mtime), ('Verilator input changed',name)
    consumed[name]=sha(p)
  return dict(source_sha256=hashes, consumed_source_sha256=consumed, verilator_metadata_sha256=sha(metadata))

def final_system(label, template=False):
  family='template' if template else 'system'
  build=SV/'build/phase4'/family/label; ref=SV/'reference/phase4'/family/label
  log=(build/'run.log').read_text(); manifest=read(ref/'manifest.json')
  marker='PHASE4_TEMPLATE_PASS' if template else 'PHASE4_MULTI_PASS'
  banner=re.search(r'^'+marker+r' .+$',log,re.M);assert banner, label
  metrics={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',banner.group())}
  python=label!='mesh4-tiles4'
  if not template:assert f'PHASE4_ORACLE hdl=1 independent_math=1 python={int(python)}' in log
  assert sha(ref/'original.v')==manifest['original_sha256']
  assert sha(ref/'exporter_snapshot.py')==manifest['exporter_sha256']
  negative_name='negative.log'
  timeout_name='timeout-negative.log'
  negative=(build/negative_name).read_text()
  expected='Template Python mismatch sample=20' if template else ('Python mismatch sample=20' if python else 'HDL oracle mismatch sample=20')
  assert expected in negative, (label,expected)
  logs={}
  for name in ('run.log',negative_name,'verilate.log','compile.log'):
    logs[str((build/name).relative_to(SV)).replace('\\','/')]=sha(build/name)
  if not template:
    assert 'TIMEOUT' in (build/timeout_name).read_text()
    logs[str((build/timeout_name).relative_to(SV)).replace('\\','/')]=sha(build/timeout_name)
  runtime_manifest=build/'runtime_inputs.sha256'
  assert runtime_manifest.exists() and (build/'run.log').stat().st_mtime >= runtime_manifest.stat().st_mtime
  runtime_hashes={}
  for line in runtime_manifest.read_text().splitlines():
    m=re.fullmatch(r'([a-f0-9]{64}) [ *](.+)',line);assert m,line
    digest,name=m.groups();assert sha(SV/name)==digest,name
    runtime_hashes[name]=digest
  assert runtime_hashes
  assert (build/'replay-input-check.log').stat().st_mtime >= (build/'run.log').stat().st_mtime
  logs[str(runtime_manifest.relative_to(SV)).replace('\\','/')]=sha(runtime_manifest)
  logs[str((build/'replay-input-check.log').relative_to(SV)).replace('\\','/')]=sha(build/'replay-input-check.log')
  if python:
    result=read(SV/'tests/phase4'/family/label/'results.json')
    assert result['samples']==metrics['samples'] and result['output_bits']==metrics['bits']
  out=dict(label=label,status='passed',metrics=metrics,oracle=dict(frozen_original_hdl=True,unmodified_python=python,independent_math_and_transactions=True),
    reference_manifest_sha256=sha(ref/'manifest.json'),reference_hdl_sha256=manifest['original_sha256'],
    testbench_negative_controls=['oracle_bit_flip_at_sample_20']+([] if template else ['permanent_host_stall_timeout']),
    logs_sha256=logs,runtime_inputs_sha256=runtime_hashes,runtime_inputs_consumed=python,**compiled(build,'Vtb_template' if template else 'Vtb_multi'))
  if not python:out['python_trace_status']=read(ref/'python-trace-status.json')
  return out

def main():
  profiles=[final_system(label) for label in ['mesh4-tiles2','ring4-tiles2','mesh4-tiles2-registered','mesh4-tiles4']]
  profiles.append(final_system('heterogeneous',True))
  result=dict(schema=1,status='passed',collected_utc=datetime.now(timezone.utc).isoformat(),profiles=profiles,
    total_samples=sum(p['metrics']['samples'] for p in profiles),
    total_raw_output_bits=sum(p['metrics']['samples']*p['metrics']['bits'] for p in profiles),
    scope='Two-state bounded program/cycle tests; not formal or universal-parameter equivalence.')
  save(SV/'results/phase4-system-simulation.json',result)
  print('PHASE4_FINAL_SYSTEM_RESULTS_PASS profiles=5 current_source_hashes_verified')
if __name__=='__main__':main()
