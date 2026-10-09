"""Replay SV stimuli through original ac96 Python and freeze every output bit."""
import argparse,json,sys,traceback
from pathlib import Path
from phase4_peripheral_export import ROOT,BASELINE,git,sha,DmaEngineRTL
from pymtl3 import DefaultPassGroup,mk_bits
def main():
  ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--kind',choices=['dma','dma-small'],required=True)
  ap.add_argument('--stimulus',type=Path,required=True);a=ap.parse_args()
  out=ROOT/'sv/reference/phase4/peripheral'/f'{a.kind}-pytrace'
  if out.exists():ap.error(f'Frozen directory exists: {out}')
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  if changed:raise RuntimeError(f'Original Python changed: {changed}')
  m=json.loads((out.parent/a.kind/'manifest.json').read_text());p=m['parameters']
  fields=json.loads((ROOT/'sv/tests/phase4/peripheral'/('tb_'+a.kind.replace('-','_')+'_ports.json')).read_text())
  d=DmaEngineRTL(*p.values());d.apply(DefaultPassGroup())
  def port(name):
    obj=d
    for piece in name.split('__'):obj=getattr(obj,piece)
    return obj
  def pack(names):
    value=0
    for name,w in names:
      obj=port(name);bits=obj.to_bits() if hasattr(obj,'to_bits') else obj
      value=(value<<w)|int(bits)
    return value
  out.mkdir(parents=True);lines=[]
  try:
    for cycle,line in enumerate(a.stimulus.read_text().splitlines()):
      iv,expected=[int(x,16) for x in line.split()];rest=iv
      for name,w in reversed(fields['inputs']):
        val=rest&((1<<w)-1);rest>>=w;obj=port(name);T=type(obj)
        obj @= T.from_bits(mk_bits(w)(val)) if hasattr(T,'from_bits') else T(val)
      assert rest==0
      d.sim_eval_combinational();observed=pack(fields['outputs'])
      if observed!=expected:raise AssertionError(f'Actual Python/native mismatch cycle={cycle}: Python={observed:x}, native={expected:x}')
      lines.append(f'{iv:0{(sum(w for _,w in fields["inputs"])+3)//4}x} {observed:0{(sum(w for _,w in fields["outputs"])+3)//4}x}')
      d.sim_tick()
    (out/'trace.hex').write_text('\n'.join(lines)+'\n',newline='\n')
    sources={}
    for module in list(sys.modules.values()):
      path=getattr(module,'__file__',None)
      if not path or Path(path).suffix!='.py':continue
      try:rel=Path(path).resolve().relative_to(ROOT)
      except ValueError:continue
      sources[rel.as_posix()]=sha(path)
    report=dict(status='actual-unmodified-python-replay-passed',cycles=len(lines),baseline_commit=BASELINE,
      parameters=p,fields=fields,input_bits=sum(w for _,w in fields['inputs']),output_bits=sum(w for _,w in fields['outputs']),
      trace_sha256=sha(out/'trace.hex'),stimulus_sha256=sha(a.stimulus),exporter_sha256=sha(__file__),source_sha256=dict(sorted(sources.items())),
      scope='BASELINE_TRANSLATED_SLICES=0 explicit Python-semantics mode. Default hardware mode independently compares frozen generated HDL; its narrow-index bug is retained.')
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    (out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes());print(json.dumps(dict(kind=a.kind,cycles=len(lines),status=report['status'])))
  except Exception:
    (out/'failure.txt').write_text(traceback.format_exc(),newline='\n');raise
if __name__=='__main__':main()
