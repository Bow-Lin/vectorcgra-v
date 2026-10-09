"""Migration-only export of unmodified ac96 DMA/Im2col reference RTL."""
import argparse, hashlib, importlib.metadata, json, os, re, subprocess, sys, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT.parent))
from pymtl3 import mk_bits, clog2
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.mem.dma.DmaEngineRTL import DmaEngineRTL
from VectorCGRA.fu.others.Im2colEngineRTL import Im2colEngineRTL
from reference_model import type_schema
BASELINE='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--kind',choices=['dma','dma-small','im2col','im2col-wide'],required=True)
  ap.add_argument('--output',type=Path)
  a=ap.parse_args()
  out=(a.output or ROOT/'sv/reference/phase4/peripheral'/a.kind).resolve()
  if out.exists(): ap.error(f'Frozen output exists: {out}')
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  if changed: raise RuntimeError(f'Original Python changed: {changed}')
  types={}
  if a.kind.startswith('dma'):
    small=a.kind=='dma-small'
    params=dict(SPM_DATA_W=32,DRAM_DATA_W=128,DRAM_ADDR_W=16 if small else 64,
      SPM_ADDR_W=8 if small else 32,BYTES_W=8 if small else 32,TAG_W=4 if small else 8)
    dut=DmaEngineRTL(*params.values())
  else:
    wide=a.kind=='im2col-wide'
    params=dict(COLS=2,ROWS=2,DATA_W=64 if wide else 32,CTRL_DEPTH=8,REG_DEPTH=16,
      GLOBAL_ADDR_W=7,SCRATCH_DEPTH=32 if wide else 64)
    Data=mk_data(params['DATA_W'],1);Ctrl=mk_ctrl(4,2,4,4,16)
    Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3));Host=mk_intra_cgra_pkt(1,1,4,Payload)
    image=[(i*17+3)^(0x80000000 if i%7==0 else 0) for i in range(25)]
    if wide: image=[v|(i<<40) for i,v in enumerate(image)]
    dut=Im2colEngineRTL(Data,Host,Payload,params['SCRATCH_DEPTH'],image)
    params['preload_image']=image
    types={name:type_schema(Type) for name,Type in [('data',Data),('ctrl',Ctrl),('payload',Payload),('host',Host)]}
  top='Phase4'+''.join(x.title() for x in a.kind.split('-'))
  out.mkdir(parents=True);os.chdir(out)
  manifest=dict(kind=a.kind,top=top,parameters=params,types=types,baseline_commit=BASELINE,
    export_checkout_commit=git('rev-parse','HEAD'),exporter_sha256=sha(__file__),
    python_executable=sys.executable,python_version=sys.version,
    pymtl3_version=importlib.metadata.version('pymtl3'),
    pymtl3_direct_url=importlib.metadata.distribution('pymtl3').read_text('direct_url.json'))
  try:
    dut.elaborate();dut.set_metadata(VerilogTranslationPass.enable,True)
    dut.set_metadata(VerilogTranslationPass.explicit_module_name,top);dut.apply(VerilogTranslationPass())
    rtl=out/(top+'.v');Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve().rename(rtl)
    header=re.search(r'module '+top+r'\s*\((.*?)\n\);',rtl.read_text(),re.S).group(1)
    manifest.update(status='translated',rtl=rtl.name,rtl_sha256=sha(rtl),top_port_declarations=header.strip().splitlines())
    (out/'top_ports.txt').write_text(header.strip()+'\n',newline='\n')
  except Exception:
    manifest.update(status='translation-failed',error=traceback.format_exc())
    (out/'failure.txt').write_text(manifest['error'],newline='\n')
    raise
  finally:
    sources={}
    for module in list(sys.modules.values()):
      p=getattr(module,'__file__',None)
      if not p or Path(p).suffix!='.py':continue
      try:rel=Path(p).resolve().relative_to(ROOT)
      except ValueError:continue
      sources[rel.as_posix()]=sha(p)
    manifest['source_sha256']=dict(sorted(sources.items()))
    (out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
    print(json.dumps(dict(kind=a.kind,status=manifest['status'],output=str(out))),flush=True)
if __name__=='__main__':main()
