"""Exercise native replay and fail-closed evidence checks with a real fixture."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--fixtures',type=Path,default=Path(__file__).parent/'fixtures')
  args=ap.parse_args()
  runner=Path(__file__).parent/'run.py'
  command=[sys.executable,str(runner),'--ids','149','--replay-only',
           '--fixtures',str(args.fixtures),'--output',str(args.output)]
  def run(expected):
    result=subprocess.run(command,capture_output=True,text=True)
    report=json.loads((args.output/'149/result.json').read_text())
    assert report['status']==expected,(result.stdout,result.stderr,report)
    assert (result.returncode==0)==(expected=='passed')
    return report
  good=run('passed')
  assert all(r['negative']['exit_code']!=0 for r in good['replays'])
  trace=args.output/'149/capture/dut000/vectors.txt'
  original=trace.read_bytes()
  try:
    trace.write_bytes(original+b'0 0\n')
    run('adapter_failed')
  finally:trace.write_bytes(original)
  reference=args.output/'149/capture/result.json'
  original=reference.read_bytes()
  try:
    failed=json.loads(original);failed['status']='failed';failed['error']='Injected unfinished reference'
    reference.write_text(json.dumps(failed))
    run('python_failed')
  finally:reference.write_bytes(original)
  try:
    supplemental=json.loads(original);supplemental['reference_variant']='supplementary_program'
    reference.write_text(json.dumps(supplemental))
    assert run('passed')['diagnostic_only']
  finally:reference.write_bytes(original)
  command.append('--contract')
  try:run('adapter_failed')  # A contract cannot silently apply to an unreviewed case.
  finally:command.pop()
  run('passed')
  report=args.output/'partial-report.json'
  result=subprocess.run([sys.executable,str(runner.parent/'report.py'),
    '--root',str(args.output),'--output',str(report),
    '--evidence-dir',str(args.output/'evidence')],capture_output=True,text=True)
  summary=json.loads(report.read_text())
  assert result.returncode!=0 and not summary['all_passed']
  assert summary['counts']['not_run']==summary['total']-1
  saved=next(row for row in summary['cases'] if row['id']==149)
  assert (report.parent/saved['replays'][0]['run']['log']).is_file()
  from report import is_diagnostic
  assert not is_diagnostic(good)
  assert is_diagnostic(dict(diagnostic_only=True))
  assert is_diagnostic(dict(replays=[dict(mode='compatibility')]))
  assert is_diagnostic(dict(reference_variant='supplementary_program'))
  print('ORIGINAL_RUNNER_GUARDS_PASS native negative corrupted_trace failed_reference missing_cases portable_logs diagnostic_gate supplemental_gate unreviewed_contract')


if __name__=='__main__':main()
