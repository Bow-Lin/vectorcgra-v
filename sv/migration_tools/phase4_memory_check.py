"""Bounded SV frontend synthesis check for the validated asymmetric memory."""
import json,os,re,subprocess
from pathlib import Path
from phase4_noc_check import inspect,sha

SV=Path(__file__).resolve().parents[1]
tools=SV.parents[2]/'sys_lib/tools'
build=SV/'build/phase4/memory/synthesis';build.mkdir(parents=True,exist_ok=True)
sources=[SV/l for l in (SV/'filelists/phase4_noc.f').read_text().splitlines() if l and not l.startswith('+')]
sources += [SV/'rtl/noc/cgra_xbar.sv',SV/'rtl/common/cgra_register_file.sv',
  SV/'rtl/mem/cgra_data_bank.sv',SV/'rtl/mem/cgra_data_memory.sv']
sources=list(dict.fromkeys(sources))
params=json.loads((SV/'reference/phase4/memory/r1w3/manifest.json').read_text())['parameters']
converted=build/'memory.v'
with (build/'sv2v.log').open('w') as log:
  subprocess.run([str(tools/'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'),'-I'+str(SV/'rtl/common'),
    '--write='+str(converted),*map(str,sources)],stdout=log,stderr=subprocess.STDOUT,check=True)
top='cgra_data_memory';before=build/'before.json';after=build/'after.json';script=build/'check.ys';logpath=build/'yosys.log'
flow=[f'read_verilog -defer "{converted.as_posix()}"',
  'chparam '+' '.join(f'-set {k} {v}' for k,v in params.items())+' '+top,f'hierarchy -check -top {top}','proc',
  f'write_json "{before.as_posix()}"','flatten','opt','check -assert',f'write_json "{after.as_posix()}"','stat']
script.write_text('\n'.join(flow)+'\n',newline='\n')
yosys=tools/'oss-cad-suite/bin/yosys.exe';env=os.environ.copy()
env['PATH']=str(yosys.parent)+';'+str(yosys.parent.parent/'lib')+';'+env['PATH']
with logpath.open('w') as log:subprocess.run([str(yosys),'-Q','-T','-s',str(script)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
bp,_,_=inspect(before,top);ap,cells,blackboxes=inspect(after,top)
assert bp==ap and blackboxes==0
assert re.findall(r'Found and reported (\d+) problems',logpath.read_text())[-1]=='0'
result=dict(status='pass',profile='r1w3',flow='sv2v -> hierarchy/proc/flatten/opt -> check -assert',
  full_generic_synthesis=False,top_ports_preserved=True,blackbox_modules=0,final_problems=0,cells=cells,
  source_sha256={p.relative_to(SV).as_posix():sha(p) for p in sources},
  profile_header_sha256={p.relative_to(SV).as_posix():sha(p) for p in (SV/'rtl/common').glob('*.svh')},
  log_sha256=sha(logpath),area_measured=False,frequency_measured=False)
(SV/'tests/phase4/memory/synthesis_results.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('PHASE4_MEMORY_SYNTHESIS_FRONTEND_PASS r1w3',flush=True)
