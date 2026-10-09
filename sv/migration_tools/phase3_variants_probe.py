"""Read-only baseline elaboration probes for the phase-three Tile variants."""
from pathlib import Path
import json
import sys
import traceback

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT.parent))
from pymtl3 import mk_bits, clog2
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt
from VectorCGRA.tile.TileWithStreamingLoadRTL import TileWithStreamingLoadRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.StreamingMemUnitRTL import StreamingMemUnitRTL
from VectorCGRA.fu.single.NahRTL import NahRTL

out=ROOT/'sv/reference/phase3/tile_variants/probes'
out.mkdir(parents=True,exist_ok=True)
results=[]
for ports in [4,8]:
  Data=mk_data(32,1)
  Ctrl=mk_ctrl(4,2,ports,ports,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3))
  Host=mk_intra_cgra_pkt(1,1,4,Payload)
  entry=dict(tile_ports=ports,control_bits=Ctrl.nbits,host_bits=Host.nbits)
  try:
    dut=TileWithStreamingLoadRTL(Host,8,128,8,8,4,2,ports,ports,1,4,16,
      FlexibleFuRTL,[AdderRTL,MulRTL,StreamingMemUnitRTL,NahRTL])
    dut.elaborate()
    entry['elaboration']='passed'
  except Exception as error:
    entry['elaboration']='failed'
    entry['exception_type']=type(error).__name__
    entry['exception']=str(error)
    (out/f'streaming-{ports}-ports-failure.txt').write_text(traceback.format_exc(),newline='\n')
  results.append(entry)
  print(json.dumps(entry),flush=True)
(out/'elaboration.json').write_text(json.dumps(results,indent=2)+'\n',newline='\n')
