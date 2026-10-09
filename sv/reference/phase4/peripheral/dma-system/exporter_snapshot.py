"""Freeze original integrated peripheral/CGRA hardware; migration-only."""
import argparse,importlib.metadata,json,os,re,sys,traceback
from pathlib import Path
from phase4_peripheral_export import ROOT,BASELINE,sha,git,mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from pymtl3 import mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.cgra.test.IntegratedCgraWithDmaRTL_test import make_dut as dma_dut
from VectorCGRA.cgra.IntegratedIm2ColWithCgraRTL import IntegratedIm2ColWithCgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from VectorCGRA.lib.util.common import MESH
from VectorCGRA.lib.util.cgra.Tile import Tile
from VectorCGRA.lib.util.cgra.cgra_helper import get_links
from reference_model import type_schema
def construct(kind):
  tile_ports=8 if kind=='dma-system' else 4
  Data=mk_data(32,1);Ctrl=mk_ctrl(4,2,tile_ports,tile_ports,16)
  Payload=mk_cgra_payload(Data,mk_bits(6),Ctrl,mk_bits(3));Host=mk_intra_cgra_pkt(1,1,4,Payload)
  p=dict(COLS=2,ROWS=2,DATA_W=32,TILE_PORTS=tile_ports,CTRL_DEPTH=8,REG_DEPTH=16,
    BANK_DEPTH=16,NUM_BANKS=4,GLOBAL_ADDR_W=6,NUM_CTRL=1,TOTAL_STEPS=1,HAS_DMA=int(kind=='dma-system'),HAS_IM2COL=int(kind!='dma-system'))
  if kind=='dma-system':
    d=dma_dut();p.update(FU_COUNT=3,FU_KINDS=[0,2,13],CUSTOM_TOPOLOGY=1)
    tiles=[[Tile(x,y,16,['add','mem','return']) for x in range(2)] for y in range(2)]
    flat=sum(tiles,[]);links=get_links(tiles);internal=[];read=[-1]*3;write=[-1]*3
    for link in links:
      if link.fromMem:read[link.memPort]=flat.index(link.dstTile)
      elif link.toMem:write[link.memPort]=flat.index(link.srcTile)
      else:internal.append(dict(src_tile=flat.index(link.srcTile),src_port=link.srcPort,dst_tile=flat.index(link.dstTile),dst_port=link.dstPort,enabled=not link.disabled))
    p.update(links=internal,READ_PORT_TILE=read,WRITE_PORT_TILE=write)
  else:
    p.update(FU_COUNT=4,FU_KINDS=[0,1,2,3],SCRATCH_DEPTH=64,preload_image=[3+17*i for i in range(25)])
    d=IntegratedIm2ColWithCgraRTL(Payload,1,1,2,2,8,64,16,4,16,1,1,True,
      FlexibleFuRTL,[AdderRTL,MulRTL,MemUnitRTL,NahRTL],MESH,{0:[0,63]},{0:[0,0]},64,p['preload_image'])
  return d,p,dict(data=Data,ctrl=Ctrl,payload=Payload,host=Host)
def main():
  ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--kind',choices=['dma-system','im2col-system'],required=True);a=ap.parse_args()
  out=ROOT/'sv/reference/phase4/peripheral'/a.kind
  if out.exists():ap.error(f'Frozen output exists: {out}')
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  if changed:raise RuntimeError(f'Original Python changed: {changed}')
  d,p,types=construct(a.kind);top='Phase4'+''.join(x.title() for x in a.kind.split('-'))
  out.mkdir(parents=True);os.chdir(out)
  report=dict(kind=a.kind,top=top,parameters=p,baseline_commit=BASELINE,export_checkout_commit=git('rev-parse','HEAD'),
    types={k:type_schema(v) for k,v in types.items()},exporter_sha256=sha(__file__),python_version=sys.version,
    pymtl3_version=importlib.metadata.version('pymtl3'))
  try:
    d.elaborate();d.set_metadata(VerilogTranslationPass.enable,True);d.set_metadata(VerilogTranslationPass.explicit_module_name,top)
    d.apply(VerilogTranslationPass());rtl=out/(top+'.v');Path(d.get_metadata(VerilogTranslationPass.translated_filename)).resolve().rename(rtl)
    header=re.search(r'module '+top+r'\s*\((.*?)\n\);',rtl.read_text(),re.S).group(1)
    report.update(status='translated',rtl=rtl.name,rtl_sha256=sha(rtl),top_port_declarations=header.strip().splitlines())
    (out/'top_ports.txt').write_text(header.strip()+'\n',newline='\n')
  except Exception:
    report.update(status='translation-failed',error=traceback.format_exc());(out/'failure.txt').write_text(report['error'],newline='\n');raise
  finally:
    sources={}
    for module in list(sys.modules.values()):
      path=getattr(module,'__file__',None)
      if not path or Path(path).suffix!='.py':continue
      try:rel=Path(path).resolve().relative_to(ROOT)
      except ValueError:continue
      sources[rel.as_posix()]=sha(path)
    report['source_sha256']=dict(sorted(sources.items()));(out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print(json.dumps(dict(kind=a.kind,status=report['status'])),flush=True)
if __name__=='__main__':main()
