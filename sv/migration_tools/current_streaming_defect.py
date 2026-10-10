"""Reproduce the shared Streaming Tile completion bug without changing Python."""
import hashlib
import json
from pathlib import Path
import sys
import types

ROOT=Path(__file__).resolve().parents[2]
pkg=types.ModuleType('VectorCGRA');pkg.__path__=[str(ROOT)];sys.modules['VectorCGRA']=pkg
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.tile.TileWithStreamingLoadRTL import TileWithStreamingLoadRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.GrantRTL import GrantRTL
from VectorCGRA.fu.single.NahRTL import NahRTL

out=ROOT/'sv/reference/current'
target=json.loads((out/'target.json').read_text())
for path,sha in target['source_sha256'].items():
  assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
D=mk_data(32,1);C=mk_ctrl(4,2,8,8,16)
P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));H=mk_intra_cgra_pkt(1,1,4,P)
d=TileWithStreamingLoadRTL(H,8,128,2,4,4,2,8,8,1,4,16,FlexibleFuRTL,[GrantRTL,NahRTL])
d.apply(DefaultPassGroup())
c=C();c.operation=mk_bits(7)(88);c.fu_xbar_outport[0]=mk_bits(2)(1);c.routing_xbar_outport[1]=mk_bits(4)(1)
def pkt(cmd,data=0,addr=0,ctrl=None):
  return H(payload=P(cmd=cmd,data=D(data,1),ctrl_addr=addr,ctrl=ctrl or C()))
program=[pkt(13,10),pkt(13,20),pkt(3,addr=0,ctrl=c),pkt(3,addr=1,ctrl=c),pkt(7,4),pkt(8,2),pkt(0)]
command=0;injected=0;events=[]
for cycle in range(120):
  d.reset @= cycle<3;d.cgra_id @= 0;d.tile_id @= 0
  d.recv_from_controller_pkt.val @= cycle>=3 and command<len(program)
  d.recv_from_controller_pkt.msg @= program[command] if command<len(program) else H()
  d.send_to_controller_pkt.rdy @= 1
  d.to_mem_raddr.rdy @= 1;d.to_mem_waddr.rdy @= 1;d.to_mem_wdata.rdy @= 1
  d.from_mem_rdata.val @= 0;d.from_mem_rdata.msg @= D()
  for i in range(8):
    d.recv_data[i].msg @= D(101+injected,1) if i==0 else D()
    d.recv_data[i].val @= i==0 and injected<4 and cycle>=3
    d.send_data[i].rdy @= i!=1 or cycle>45
  d.sim_eval_combinational()
  if d.recv_from_controller_pkt.val and d.recv_from_controller_pkt.rdy:command+=1
  if d.recv_data[0].val and d.recv_data[0].rdy:injected+=1
  for i in range(2):
    if d.send_data[i].val and d.send_data[i].rdy:
      events.append(dict(cycle=cycle,port=i,data=int(d.send_data[i].msg.to_bits())))
  d.sim_tick()
state={n:int(getattr(d,n)) for n in ['element_done','fu_crossbar_done','routing_crossbar_done']}
assert sum(e['port']==0 for e in events)==1 and state['element_done']==1 and state['fu_crossbar_done']==0,(events,state)
result=dict(python_commit=target['python_target_commit'],cycles=120,events=events,final_state=state,
            conclusion='Python stalls after first scalar grant: FU completed, FU crossbar completion was lost.',
            native_regression='tests/current/tb_current_pe.sv VARIANT=2',
            native_expected='Four grant outputs and four routing outputs, followed by completion.')
(out/'streaming_defect.json').write_text(json.dumps(result,indent=2)+'\n')
print('CURRENT_PYTHON_STREAMING_DEFECT_REPRODUCED',state)
