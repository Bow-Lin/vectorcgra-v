"""Bounded synthesis evidence with streaming JSON inspection, not RTL generation."""
import argparse,hashlib,json,os,re,subprocess
from pathlib import Path

SV=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def inspect(path,top):
  """Read only the small top-port dictionary; never load a mapped netlist object."""
  ports=None;current=None;port_lines=None;cells=0;blackboxes=0
  with path.open(encoding='utf-8') as stream:
    for line in stream:
      module=re.match(r'^    "([^"]+)": \{$',line.rstrip())
      if module:current=module.group(1)
      if line.startswith('        "blackbox":') and int(line.split(':',1)[1].strip().rstrip(',').strip('"'),2):blackboxes+=1
      if line.startswith('          "type":'):cells+=1
      if current==top and line.startswith('      "ports": {'):
        port_lines=['{'+line];continue
      if port_lines is not None:
        if line.startswith('      },'):
          port_lines.append('      }}')
          ports=json.loads(''.join(port_lines))['ports'];port_lines=None
        else:port_lines.append(line)
  assert ports is not None,(path,top)
  return {k:(v['direction'],len(v['bits'])) for k,v in ports.items()},cells,blackboxes


def main():
  ap=argparse.ArgumentParser();ap.add_argument('--tool-root',type=Path,required=True);a=ap.parse_args()
  build=SV/'build/phase4/noc/synthesis';build.mkdir(parents=True,exist_ok=True)
  sources=[SV/l for l in (SV/'filelists/phase4_noc.f').read_text().splitlines() if l and not l.startswith('+')]
  sourcehash={p.relative_to(SV).as_posix():sha(p) for p in sources}
  sv2v=a.tool_root/'sv2v-v0.0.13/sv2v-Windows/sv2v.exe';yosys=a.tool_root/'oss-cad-suite/bin/yosys.exe'
  converted=build/'native_streaming_check.v'
  with (build/'sv2v_streaming_check.log').open('w') as log:
    subprocess.run([str(sv2v),'--write='+str(converted),*map(str,sources)],stdout=log,stderr=subprocess.STDOUT,check=True)
  same_conversion=(build/'native.v').exists() and sha(converted)==sha(build/'native.v')
  env=os.environ.copy();env['PATH']=str(yosys.parent)+';'+str(yosys.parent.parent/'lib')+';'+env['PATH']
  results=[]
  for definition in sorted((SV/'tests/phase4/noc').glob('*/profile.json')):
    cfg=json.loads(definition.read_text());p=cfg['parameters'];label=cfg['label'];top='cgra_inter_'+cfg['network']
    full=cfg['network']=='mesh' or label=='ring_2_l1_w32'
    prefix=label if full else label+'-frontend'
    before=build/(prefix+'-before.json');after=build/(prefix+'-after.json');logpath=build/(prefix+'.log')
    oldlog=logpath.read_text() if logpath.exists() else ''
    checks=re.findall(r'Found and reported (\d+) problems',oldlog)
    reuse=full and same_conversion and before.exists() and after.exists() and checks and checks[-1]=='0' and 'ERROR:' not in oldlog
    if not reuse:
      names=['WIDTH','NODES','DST_LSB','DST_WIDTH','VC_LSB','VC_WIDTH','CHANNEL_LATENCY'] if cfg['network']=='ring' else \
        ['WIDTH','COLS','ROWS','DST_X_LSB','DST_Y_LSB','X_WIDTH','Y_WIDTH','CHANNEL_LATENCY']
      flow=[f'read_verilog -defer "{converted.as_posix()}"',
        'chparam '+' '.join(f'-set {n} {p[n]}' for n in names)+' '+top,f'hierarchy -check -top {top}','proc',
        f'write_json "{before.as_posix()}"','flatten']
      flow += [f'synth -noabc -top {top}'] if full else ['opt']
      flow += ['check -assert',f'write_json "{after.as_posix()}"','stat']
      script=build/(prefix+'.ys');script.write_text('\n'.join(flow)+'\n',newline='\n')
      with logpath.open('w') as log:subprocess.run([str(yosys),'-Q','-T','-s',str(script)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    ports_before,_,_=inspect(before,top);ports_after,cells,blackboxes=inspect(after,top)
    assert ports_before==ports_after and blackboxes==0,(label,ports_before,ports_after,blackboxes)
    checks=re.findall(r'Found and reported (\d+) problems',logpath.read_text())
    assert checks and checks[-1]=='0',label
    results.append(dict(label=label,status='pass',flow='full synth -noabc' if full else 'hierarchy/proc/flatten/opt frontend',
      full_generic_synthesis=full,reused_completed_log=bool(reuse),final_problems=0,top_ports_preserved=True,
      blackbox_modules=blackboxes,cells=cells,log_sha256=sha(logpath),netlist_sha256=sha(after)))
    print(f'PHASE4_NOC_SYNTHESIS_PASS {label} full={full} reuse={bool(reuse)} cells={cells}',flush=True)
  result=dict(schema=2,status='pass',profiles=results,source_sha256=sourcehash,
    unchanged_previous_conversion=same_conversion,converted_sha256=sha(converted),
    summary='Four Mesh shapes and Ring2 pass complete generic synth -noabc; other Ring shapes pass the parameterized structural synthesis frontend. No technology mapping or PPA claim.',
    area_measured=False,frequency_measured=False)
  (SV/'tests/phase4/noc/synthesis_results.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')


if __name__=='__main__':main()
