"""Read scalar migration evidence and freeze its hashes; performs no simulation."""
import datetime
import json
from pathlib import Path
import re
import subprocess
from phase3_scalar_export import ROOT, BASELINE, MODULES, write, sha
from phase3_scalar_port import snake


def main():
  base=ROOT/'sv/build/phase3/scalar'
  result=dict(status='pass',baseline_commit=BASELINE,
    source_checkout_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    collected_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    scope='15 remaining scalar FUs, standard 4-in/2-out profile; no Python source changes',
    runtime_entrypoints=['sv/tests/phase3/scalar/run.sh w32','sv/tests/phase3/scalar/run.sh w64','sv/tests/phase3/scalar/check_synthesis.sh'],
    profiles={},runtime_source_sha256={},logs_sha256={},reference_manifest_sha256={},
    limitations=[
      'Two-state Verilator simulation, finite directed/random stimulus; not exhaustive formal or four-state X equivalence.',
      'Pipeline dividers are 32-bit baseline Verilog placeholders; HDL-vs-HDL plus independent 50/7 quotient/remainder assertions, no Python pipeline simulation claim.',
      'Pipeline default LATENCY=2/4 tested; arbitrary latency parameters and non-power-of-two CTRL_DEPTH not tested.',
      'Combinational Div zero divisor excluded because original Python raises; no defined result claimed.',
      'Gep/LoopCounter/ExtractPredicate references use audited isolated translation adapters, checked against original Python every cycle.',
      'Div exporter adds process-local unsigned FloorDiv lowering; original Python // traces are a separate numerical oracle.',
      'Inherited LoopControl and pipeline input latches, no-clear states, and original control/ready semantics retained.',
      'Yosys evidence is process lowering plus optimized structural check, not technology mapping, physical area, frequency or latch-free proof.'],
    commands=[
      dict(command='python sv/migration_tools/phase3_scalar_export.py --profile w32',outcome='partial: four direct translation errors; interrupted Windows placeholder root traversal hang'),
      dict(command='python sv/migration_tools/phase3_scalar_export.py --profile w32 --resume',outcome='pass after isolated adapters and host-only placeholder fix; original exported bytes retained'),
      dict(command='python sv/migration_tools/phase3_scalar_export.py --profile w64',outcome='13 exported, 2 explicitly unsupported fixed-width pipeline dividers'),
      dict(command='python sv/migration_tools/phase3_scalar_port.py',outcome='initial parameterized native migration aid; subsequently fixed Ret width and comparison sign constant naming'),
      dict(command='python sv/migration_tools/phase3_scalar_vectors.py --profile w32',outcome='pass, final actual stdout captured in python-w32.log'),
      dict(command='python sv/migration_tools/phase3_scalar_vectors.py --profile w64',outcome='pass, final actual stdout captured in python-w64.log'),
      dict(command='python sv/migration_tools/phase3_scalar_testbench.py w32',outcome='checked-in SV scaffold generated'),
      dict(command='python sv/migration_tools/phase3_scalar_testbench.py w64',outcome='checked-in SV scaffold generated'),
      dict(command='C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/run.sh w32',outcome='pass normal run, oracle-bit fault negative, watchdog negative'),
      dict(command='C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/run.sh w64',outcome='pass normal run, oracle-bit fault negative, watchdog negative'),
      dict(command='C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/check_synthesis.sh',outcome='28 parameterized module checks, zero reported problems')],
    resolved_failures=[
      dict(category='baseline_translation',detail='Gep/LoopCounter short Data constructors, ExtractPredicate dynamic type expression, Div missing FloorDiv lowering',evidence='sv/reference/phase3/scalar/w32/{Gep,LoopCounter,ExtractPredicate,Div}/export_failure.log'),
      dict(category='host_tool',detail='Installed PlaceholderPass Unix-root traversal loop on Windows; interrupted; isolated pass fallback used without installed-tool/source changes'),
      dict(category='test_scaffold',detail='First vector generator used nonexistent OPT_DIV_START alias and then untyped bitstruct-array elements; corrected before recorded trace generation'),
      dict(category='host_runner',detail='MSYS2 PATH needed initialization before dirname/bash/mkdir; corrected runner, no RTL change'),
      dict(category='host_hdl_diagnostic',detail='Frozen placeholder `line used backslash paths rejected by Verilator; test copies normalize diagnostic path only',evidence='sv/build/phase3/scalar/w32/failure_01_windows_line.log'),
      dict(category='native_implementation',detail='First scalar_comp sign-mask declaration lost its generated suffix; fixed before successful runs',evidence='sv/build/phase3/scalar/w32/failure_02_sign_flip.log'),
      dict(category='native_width_review',detail='Before first successful test, Ret context compare and RET_VOID zero-data field generalized to CTRL_ADDR_W/DATA_BITS'),
      dict(category='provenance_helper',detail='First audit helper passed string to Path-only hash function; fixed before any manifest writes, then reran successfully'),
      dict(category='host_tool',detail='Yosys DLL loader needed bundled lib directory on PATH',evidence='sv/build/phase3/scalar/synthesis/failure_01_dll.log')])
  for profile in ['w32','w64']:
    ref=ROOT/'sv/reference/phase3/scalar'/profile
    vm=json.loads((ref/'vectors/manifest.json').read_text())
    em=json.loads((ref/'manifest.json').read_text())
    for name,h in vm['files_sha256'].items(): assert sha(ref/'vectors'/name)==h,(profile,name)
    for r in em['modules']:
      for name,key in [('rtl','rtl_sha256'),('namespaced','namespaced_sha256')]:
        assert sha(ref/r[name])==r[key],(profile,r['module'],name)
    run=(base/profile/'run.log').read_text()
    banner=re.search(r'^SCALAR_PASS .*$',run,re.M)[0].strip()
    assert f'cycles={vm["cycles"]}' in banner
    neg=(base/profile/'negative.log').read_text(); timeout=(base/profile/'timeout.log').read_text()
    assert 'SCALAR_NEGATIVE_CONTROL' in neg and 'SCALAR_PYTHON_MISMATCH' in neg
    assert 'SCALAR_TIMEOUT' in timeout
    pylog=(base/f'python-{profile}.log').read_text(encoding='utf-8-sig')
    assert f'SCALAR_PYTHON_PASS profile={profile}' in pylog
    checks=[]
    for name in MODULES if profile=='w32' else MODULES[:-2]:
      log=base/'synthesis'/f'{profile}_{snake(name)}.log'
      content=log.read_text()
      assert 'Found and reported 0 problems.' in content and 'ERROR:' not in content
      cells=re.findall(r'^\s+(\d+)\s+(\$\w+)\s*$',content,re.M)
      checks.append(dict(module='scalar_'+snake(name),check_problems=0,
        stat_cell_types_final={n:int(v) for v,n in cells},log=log.relative_to(ROOT).as_posix()))
    result['profiles'][profile]=dict(parameters=em['parameters'],cycles=vm['cycles'],
      hdl_modules=len(em['modules']),python_modules=13,raw_output_bits=vm['output_bits'],
      pass_banner=banner,independent_python_checks=vm['independent_checks'],coverage=vm['coverage'],
      negative_control='normal comparator detected mutated oracle bit; nonzero exit',
      timeout_control='watchdog assertion; nonzero exit',structural_checks=checks)
    for path in [ref/'manifest.json',ref/'vectors/manifest.json']:
      result['reference_manifest_sha256'][path.relative_to(ROOT).as_posix()]=sha(path)
  runtime=[ROOT/'sv/rtl/common/cgra_profile_defs.svh',ROOT/'sv/rtl/common/cgra_profile.svh']
  runtime+=sorted((ROOT/'sv/rtl/fu/scalar').glob('*.sv'))
  runtime+=sorted(p for p in (ROOT/'sv/tests/phase3/scalar').rglob('*') if p.is_file() and p.suffix in ('.sv','.sh','.f'))
  for path in runtime:
    assert b'\r\n' not in path.read_bytes(),('new runtime must be LF',path)
    result['runtime_source_sha256'][path.relative_to(ROOT).as_posix()]=sha(path)
  for path in sorted(base.rglob('*.log')): result['logs_sha256'][path.relative_to(ROOT).as_posix()]=sha(path)
  for profile in ['w32','w64']:
    for path in (ROOT/'sv/reference/phase3/scalar'/profile).rglob('export_failure.log'):
      result['logs_sha256'][path.relative_to(ROOT).as_posix()]=sha(path)
  binaries=['C:/msys64/ucrt64/bin/verilator_bin.exe','C:/msys64/clang64/bin/clang++.exe',
    'D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite/bin/yosys.exe',
    'D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe']
  result['tools_sha256']={p:sha(Path(p)) for p in binaries}
  result['tool_versions']={'verilator':'5.050 (2026-07-01)','clang':'22.1.8',
    'yosys':'See exact bundled binary hash and log banner','sv2v':'v0.0.13'}
  result['collector_sha256']=sha(Path(__file__))
  result['python_executable']='D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe'
  write(ROOT/'sv/results/phase3-scalar.json',json.dumps(result,indent=2)+'\n')
  print('SCALAR_RESULTS_PASS profiles=2 checks=28 runtime_files='+str(len(runtime)))


if __name__=='__main__': main()
