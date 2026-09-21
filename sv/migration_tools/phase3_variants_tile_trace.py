"""Freeze actual unmodified ac96 Tile simulation, including every idle port bit."""
import argparse, hashlib, json, re, sys, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT.parent))
from pymtl3 import DefaultPassGroup,mk_bits
from phase3_variants_export import (mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt,
  TileWithContextSwitchRTL,TileWithStreamingLoadRTL,FlexibleFuRTL,
  PhiRTL,AdderRTL,MulRTL,MemUnitRTL,StreamingMemUnitRTL,NahRTL,git,BASELINE,sha)

def main():
  ap=argparse.ArgumentParser(); ap.add_argument('--kind',choices=['context','streaming'],required=True)
  ap.add_argument('--label',default='tile-pyreplay'); ap.add_argument('--clear-tail',action='store_true'); a=ap.parse_args()
  stream=a.kind=='streaming'; n=8 if stream else 4
  out=ROOT/'sv/reference/phase3/tile_variants'/f'{a.kind}-{a.label}'
  if out.exists(): ap.error(f'frozen output exists {out}')
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  if changed:raise RuntimeError(f'baseline Python changed: {changed}')
  out.mkdir(parents=True)
  try:
    Data=mk_data(32,1); Ctrl=mk_ctrl(4,2,n,n,16)
    Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3)); Host=mk_intra_cgra_pkt(1,1,4,Payload)
    Fus=[AdderRTL,MulRTL,StreamingMemUnitRTL,NahRTL] if stream else [PhiRTL,AdderRTL,MulRTL,MemUnitRTL,NahRTL]
    Tile=TileWithStreamingLoadRTL if stream else TileWithContextSwitchRTL
    d=Tile(Host,8,128,2 if stream else 1,2 if stream else 6,4,2,n,n,1,4,16,FlexibleFuRTL,Fus)
    d.apply(DefaultPassGroup())
    def pkt(cmd,data=0,ctrl=None,addr=0):return Host(payload=Payload(cmd,data=Data(data,1),ctrl=ctrl or Ctrl(),ctrl_addr=addr))
    control=Ctrl(); control.operation=88 if stream else 32
    control.fu_xbar_outport[0]=1
    if not stream:
      control.fu_in[0]=1;control.routing_xbar_outport[4]=1
    if stream:
      nah=Ctrl();nah.operation=1
      program=[pkt(23,10),pkt(24,2),pkt(25,18),pkt(3,ctrl=nah,addr=0),pkt(3,ctrl=control,addr=1),pkt(0)]
    else:
      program=[pkt(3,ctrl=control),pkt(13,0),pkt(16),pkt(0),pkt(13),pkt(1),pkt(13),pkt(15),pkt(13),pkt(13)]
    # Port order is explicit and retained in the manifest/SV bench.
    inputs=[('reset',1),('cgra_id',1),('tile_id',3),('from_mem_rdata__msg',Data.nbits),('from_mem_rdata__val',1),
      ('recv_from_controller_pkt__msg',Host.nbits),('recv_from_controller_pkt__val',1),('send_to_controller_pkt__rdy',1),
      ('to_mem_raddr__rdy',1),('to_mem_waddr__rdy',1),('to_mem_wdata__rdy',1)]
    outputs=[('from_mem_rdata__rdy',1),('recv_from_controller_pkt__rdy',1),('send_to_controller_pkt__msg',Host.nbits),
      ('send_to_controller_pkt__val',1),('to_mem_raddr__msg',7),('to_mem_raddr__val',1),
      ('to_mem_waddr__msg',7),('to_mem_waddr__val',1),('to_mem_wdata__msg',Data.nbits),('to_mem_wdata__val',1)]
    for i in range(n):
      inputs.extend([(f'recv_data__msg[{i}]',Data.nbits),(f'recv_data__val[{i}]',1),(f'send_data__rdy[{i}]',1)])
      outputs.extend([(f'recv_data__rdy[{i}]',1),(f'send_data__msg[{i}]',Data.nbits),(f'send_data__val[{i}]',1)])
    def port(name):
      m=re.match(r'(\w+)__(\w+)\[(\d+)\]',name)
      if m:return getattr(getattr(d,m[1])[int(m[3])],m[2])
      obj=d
      for piece in name.split('__'):obj=getattr(obj,piece)
      return obj
    def pack(fields):
      value=0
      for name,width in fields:
        obj=port(name);bits=obj.to_bits() if hasattr(obj,'to_bits') else obj
        value=(value<<width)|int(bits)
      return value
    traces=[];events=[];command=0;operand=0;pending=[];output_count=0;complete_count=0;req_count=0
    expected_context=[Data(0,1),Data(1,1),Data(0,0),Data(0,0),Data(2,1),Data(3,1)]
    for cycle in range(190):
      local=cycle%95;round_id=cycle//95
      reset=local<3
      if local==0: command=0;operand=0;pending=[];output_count=0;req_count=0;complete_count=0
      d.reset @= reset;d.cgra_id @= 0;d.tile_id @= 0
      d.recv_from_controller_pkt.msg @= program[command] if command<len(program) else Host()
      d.recv_from_controller_pkt.val @= not reset and command<len(program)
      d.send_to_controller_pkt.rdy @= not reset and (round_id==0 or local%7!=2)
      d.to_mem_raddr.rdy @= not reset and (local%3!=0)
      d.to_mem_waddr.rdy @= 1;d.to_mem_wdata.rdy @= 1
      d.from_mem_rdata.val @= bool(pending and cycle>=pending[0][1])
      d.from_mem_rdata.msg @= Data(pending[0][0]*7+1,1,1,1) if pending else Data()
      for i in range(n):
        d.recv_data[i].msg @= Data([999,1,2,3,4,3][operand],1) if i==0 and operand<6 and not stream else Data()
        d.recv_data[i].val @= (not stream and i==0 and operand<6 and not reset)
        d.send_data[i].rdy @= not reset and (round_id==0 or local%5 not in (1,2))
      d.sim_eval_combinational()
      traces.append(f'{pack(inputs):0{(sum(w for _,w in inputs)+3)//4}x} {pack(outputs):0{(sum(w for _,w in outputs)+3)//4}x}')
      if d.recv_from_controller_pkt.val and d.recv_from_controller_pkt.rdy:command+=1
      if d.recv_data[0].val and d.recv_data[0].rdy:operand+=1
      if d.to_mem_raddr.val and d.to_mem_raddr.rdy:
        address=int(d.to_mem_raddr.msg)
        assert stream and address==10+2*req_count and req_count<5,(cycle,address,req_count)
        pending.append((address,cycle+4));req_count+=1
        events.append(dict(cycle=cycle,event='request',address=address))
      if d.from_mem_rdata.val and d.from_mem_rdata.rdy:pending.pop(0)
      for i in range(n):
        if d.send_data[i].val and d.send_data[i].rdy:
          data=d.send_data[i].msg
          assert i==0,(cycle,i)
          if stream:assert int(data.payload)==(10+2*output_count)*7+1 and int(data.predicate)==1,(cycle,data,output_count)
          elif round_id==0:assert data==expected_context[output_count],(cycle,data,expected_context[output_count])
          events.append(dict(cycle=cycle,event='output',bits=int(data.to_bits()),port=i));output_count+=1
      if d.send_to_controller_pkt.val and d.send_to_controller_pkt.rdy:
        assert int(d.send_to_controller_pkt.msg.payload.cmd)==14
        complete_count+=1;events.append(dict(cycle=cycle,event='complete'))
      if local==94:
        assert output_count==(5 if stream else 6) and complete_count==1,(cycle,output_count,complete_count)
        if stream:assert req_count==5 and not pending
      d.sim_tick()
    if a.clear_tail:
      assert not stream
      for cycle in range(190,210):
        d.reset @= 0
        d.recv_from_controller_pkt.msg @= pkt(2) if cycle==194 else Host()
        d.recv_from_controller_pkt.val @= cycle==194
        d.from_mem_rdata.val @= 0;d.from_mem_rdata.msg @= Data()
        for i in range(n):
          d.recv_data[i].msg @= Data(100+i,1)
          d.recv_data[i].val @= cycle<194
          d.send_data[i].rdy @= 0
        d.sim_eval_combinational()
        traces.append(f'{pack(inputs):0{(sum(w for _,w in inputs)+3)//4}x} {pack(outputs):0{(sum(w for _,w in outputs)+3)//4}x}')
        if cycle==193:assert all(not p.rdy for p in d.recv_data)
        if cycle==195:assert all(p.rdy for p in d.recv_data)
        if cycle==194:events.append(dict(cycle=cycle,event='terminate-clear-full-channels'))
        d.sim_tick()
    (out/'cycles.txt').write_text('\n'.join(traces)+'\n',newline='\n')
    manifest=dict(baseline_commit=BASELINE,reference='unmodified PyMTL simulation (translation failure separately retained)',kind=a.kind,cycles=len(traces),
      parameters=dict(TILE_PORTS=n,DATA_W=32,CTRL_DEPTH=8,REG_DEPTH=16,NUM_CTRL=2 if stream else 1,TOTAL_STEPS=2 if stream else 6),
      fu_list=[f.__name__ for f in Fus],inputs=inputs,outputs=outputs,events=events,trace_sha256=sha(out/'cycles.txt'),exporter_sha256=sha(__file__),
      source_sha256={str(Path(module.__file__).resolve().relative_to(ROOT)).replace('\\','/'):sha(module.__file__)
        for module in list(sys.modules.values()) if getattr(module,'__file__',None) and Path(module.__file__).suffix=='.py' and Path(module.__file__).resolve().is_relative_to(ROOT)})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
    print(json.dumps(dict(kind=a.kind,status='passed',cycles=len(traces),events=len(events))),flush=True)
  except Exception:
    (out/'failure.txt').write_text(traceback.format_exc(),newline='\n');raise

if __name__=='__main__':main()
