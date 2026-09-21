"""Freeze unmodified ac96 Tile-variant components; migration-only, not a build step."""
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import traceback

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT.parent))
from pymtl3 import clog2, mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.mem.ctrl.ContextSwitchRTL import ContextSwitchRTL
from VectorCGRA.tile.TileWithContextSwitchRTL import TileWithContextSwitchRTL
from VectorCGRA.tile.TileWithStreamingLoadRTL import TileWithStreamingLoadRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.StreamingMemUnitRTL import StreamingMemUnitRTL
from VectorCGRA.fu.single.PhiRTL import PhiRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from reference_model import type_schema

BASELINE='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()

def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--kind',choices=['context','streaming','context-tile','streaming-tile'],required=True)
  ap.add_argument('--data-width',type=int,default=32)
  ap.add_argument('--ctrl-depth',type=int,default=8)
  ap.add_argument('--reg-depth',type=int,default=16)
  ap.add_argument('--output',type=Path)
  a=ap.parse_args()
  tile_ports=8 if a.kind.startswith('streaming') else 4
  label=f'{a.kind}-w{a.data_width}-c{a.ctrl_depth}-r{a.reg_depth}'
  out=(a.output or ROOT/'sv/reference/phase3/tile_variants'/label).resolve()
  if out.exists(): ap.error(f'Frozen output already exists: {out}')
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  if changed: raise RuntimeError(f'Baseline Python changed: {changed}')
  Data=mk_data(a.data_width,1)
  Ctrl=mk_ctrl(4,2,tile_ports,tile_ports,a.reg_depth)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(clog2(a.ctrl_depth)))
  Host=mk_intra_cgra_pkt(1,1,4,Payload)
  fu_list=[PhiRTL,AdderRTL,MulRTL,MemUnitRTL,NahRTL] if a.kind=='context-tile' else [AdderRTL,MulRTL,StreamingMemUnitRTL,NahRTL]
  if a.kind=='context': dut=ContextSwitchRTL(a.data_width,clog2(a.ctrl_depth))
  elif a.kind=='streaming': dut=StreamingMemUnitRTL(Host,4,2)
  else:
    Tile=TileWithContextSwitchRTL if a.kind=='context-tile' else TileWithStreamingLoadRTL
    dut=Tile(Host,a.ctrl_depth,128,8,8,4,2,tile_ports,tile_ports,1,4,a.reg_depth,FlexibleFuRTL,fu_list)
  top='Phase3'+''.join(word.title() for word in a.kind.split('-'))+f'W{a.data_width}C{a.ctrl_depth}R{a.reg_depth}'
  out.mkdir(parents=True)
  try:
    os.chdir(out)
    dut.elaborate()
    dut.set_metadata(VerilogTranslationPass.enable,True)
    dut.set_metadata(VerilogTranslationPass.explicit_module_name,top)
    dut.apply(VerilogTranslationPass())
    generated=Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
    rtl=out/(top+'.v')
    generated.rename(rtl)
    # The reference is the exact translator output. No RTL correction/renaming.
    sources={}
    for module in list(sys.modules.values()):
      path=getattr(module,'__file__',None)
      if not path or Path(path).suffix!='.py': continue
      try: relative=Path(path).resolve().relative_to(ROOT)
      except ValueError: continue
      sources[relative.as_posix()]=sha(path)
    params=dict(COLS=2,ROWS=2,DATA_W=a.data_width,CTRL_DEPTH=a.ctrl_depth,REG_DEPTH=a.reg_depth,
      BANK_DEPTH=16,NUM_BANKS=2,GLOBAL_ADDR_W=7,NUM_CTRL=8,TOTAL_STEPS=8,TILE_PORTS=tile_ports)
    header=re.search(r'module '+top+r'\s*\((.*?)\n\);',rtl.read_text(),re.S).group(1)
    manifest=dict(status='translated',baseline_commit=BASELINE,export_checkout_commit=git('rev-parse','HEAD'),
      kind=a.kind,top=top,rtl=rtl.name,rtl_sha256=sha(rtl),parameters=params,
      fu_list=[fu.__name__ for fu in fu_list] if a.kind.endswith('tile') else [],
      python_executable=sys.executable,python_version=sys.version,pymtl3_version=importlib.metadata.version('pymtl3'),
      pymtl3_direct_url=importlib.metadata.distribution('pymtl3').read_text('direct_url.json'),
      source_sha256=dict(sorted(sources.items())),exporter_sha256=sha(__file__),
      types={name:type_schema(Type) for name,Type in [('data',Data),('control',Ctrl),('payload',Payload),('host',Host)]},
      top_port_declarations=header.strip().splitlines())
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
    (out/'top_ports.txt').write_text(header.strip()+'\n',newline='\n')
    print(json.dumps(dict(kind=a.kind,top=top,rtl=str(rtl),data_bits=Data.nbits,ctrl_bits=Ctrl.nbits,host_bits=Host.nbits)),flush=True)
  except Exception:
    (out/'failure.txt').write_text(traceback.format_exc(),newline='\n')
    raise

if __name__=='__main__': main()
