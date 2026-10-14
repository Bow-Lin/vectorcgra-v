"""Export the follow-up review without overwriting initial failed evidence."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from report import copy_evidence
from run import ROOT


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--work-root',type=Path,required=True)
  ap.add_argument('--output',type=Path,default=Path(__file__).parent/'followup.json')
  args=ap.parse_args();base=args.output.parent;work=args.work_root
  evidence=base/'evidence/followup';evidence.mkdir(parents=True,exist_ok=True)
  def read(path):return json.loads(path.read_text())
  def saved(path,name=None):
    dest=evidence/(name or path.name);dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(path,dest)
    return dict(path=str(dest.relative_to(base)),sha256=sha(dest))
  def replay(path,group):
    row=read(path);assert row['status']=='passed',path
    copy_evidence(row,evidence/group,base)
    return row
  contract_ids=[32,39,72,128,*range(137,144)]
  contracts=[replay(work/'original-contract'/str(i)/'result.json','contracts') for i in contract_ids]
  assert all(not r['diagnostic_only'] and r['acceptance_contract'] for r in contracts)
  functional=[]
  for group in ['arithmetic','fabric']:
    for r in read(work/'original-native-review'/group/'results.json')['checks']:
      assert r['status']=='passed' and r['exit_code']==0
      assert sha(Path(r['log']))==r['log_sha256']
      r['evidence']=saved(Path(r['log']),'native/'+r['name']+'.log')
      functional.append(r)
  native_ids={i for r in functional for i in r['case_ids']}
  assert len(native_ids)==14 and not native_ids.intersection(contract_ids)
  construction=replay(work/'original-no-control-ring/3/result.json','construction')
  assert construction['coverage']=='construction_only_original_done_is_unconditional'
  regressions=[replay(work/'control-ring-regression'/str(i)/'result.json','regression') for i in [0,1,2]]
  ring=replay(work/'ring-completion-reference/166/result.json','ring')
  assert ring['diagnostic_only'] and ring['reference_variant']=='supplemental_ring_remote_program'
  ring['python_reference']=read(work/'ring-completion-reference/166/capture/result.json')
  assert ring['python_reference']['status']=='passed'
  backpressure=read(work/'ring-completion-reference/166/backpressure.json')
  assert backpressure['status']=='passed' and sha(Path(backpressure['log']))==backpressure['log_sha256']
  ring['backpressure']=dict(backpressure,evidence=saved(Path(backpressure['log']),'ring/backpressure.log'))
  ring['frozen_replay']=replay(work/'ring-frozen-check/166/result.json','ring-frozen')
  assert ring['frozen_replay']['diagnostic_only']
  # Freeze this supplementary trace in a different directory, retaining its label.
  source=work/'ring-completion-reference/166/capture'
  target=base/'followup_fixtures/166';target.mkdir(parents=True,exist_ok=True)
  shutil.copyfile(source/'result.json',target/'result.json')
  for name in ring['python_reference']['captures']:
    dest=target/name;dest.mkdir(exist_ok=True)
    data=(source/name/'vectors.txt').read_bytes();meta=read(source/name/'manifest.json')
    assert hashlib.sha256(data).hexdigest()==meta['vectors_sha256']
    shutil.copyfile(source/name/'manifest.json',dest/'manifest.json')
    (dest/'vectors.txt.gz').write_bytes(gzip.compress(data,mtime=0))
  matrix=read(work/'matrix-counterexamples/results.json')
  assert len(matrix['checks'])==5 and all(r['expected_counterexample'] for r in matrix['checks'])
  for r in matrix['checks']:
    path=Path(r['log']);assert sha(path)==r['log_sha256']
    stem='matrix/'+r['kernel']+'/'+r['variant']
    r['evidence']=saved(path,stem+'/run.log')
    r['program']=saved(path.parent/'program.hex',stem+'/program.hex')
    for name in ['expected.hex','return.hex']:saved(path.parent/name,stem+'/'+name)
  math_log=work/'original-matrix-review.log';math_text=math_log.read_text()
  assert 'NATIVE_SPMV_MATRIX_PASS' in math_text
  for name in ['gemm','gemv','spmv']:
    assert f'NATIVE_KERNEL_MATH_PASS program=reference/native/kernels/{name} ' in math_text
    assert f'NATIVE_KERNEL_NEGATIVE_PASS kernel={name}' in math_text
  matrix['corrected_native_programs']=saved(math_log,'matrix/native-math.log')
  generated=read(work/'matrix-regenerated/checks.json')
  assert len(generated)==12 and all(r['identical'] for r in generated)
  matrix['regenerated_artifacts']=generated
  guards=work/'original-followup-guards.log'
  assert 'supplemental_gate unreviewed_contract' in guards.read_text()
  pin=read(ROOT/'sv/reference/current/target.json')
  for name,digest in pin['source_sha256'].items():assert sha(ROOT/name)==digest,name
  result=dict(schema=1,base_rtl_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    modified_rtl_sha256={'sv/rtl/cgra/cgra_system.sv':sha(ROOT/'sv/rtl/cgra/cgra_system.sv')},
    original_source_files_checked=len(pin['source_sha256']),
    initial_report=dict(path='results.json',sha256=sha(base/'results.json')),
    reviewed=dict(explicit_reset_and_valid_payload=11,native_functional_contract=14,construction_only=1),
    unresolved_original_cases=[10,11,12,166],all_original_tests_passed=False,commit_allowed=False,
    contracts=contracts,native_functional_checks=functional,construction=construction,
    control_ring_regressions=regressions,supplementary_ring=ring,matrix=matrix,
    runner_guards=saved(guards,'runner-guards.log'))
  files=list(base.glob('*.py'))+list((ROOT/'sv/migration_tools').glob('original_test_*.py'))+[ROOT/'sv/migration_tools/ring_completion_reference.py']
  result['tool_files_sha256']={str(p.resolve().relative_to(ROOT)):sha(p) for p in sorted(files)}
  args.output.write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps({k:result[k] for k in ['reviewed','unresolved_original_cases','all_original_tests_passed','commit_allowed']},indent=2))


if __name__=='__main__':main()
