"""Freeze unmodified ac96 full 2x2 Context/KingMesh Streaming CGRA traces."""
import argparse,json,sys,traceback
from pathlib import Path
from collections import Counter
from phase3_variants_export import (ROOT,BASELINE,git,sha,mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt,
  FlexibleFuRTL,PhiRTL,AdderRTL,MulRTL,MemUnitRTL,StreamingMemUnitRTL,NahRTL)
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.cgra.CgraWithContextSwitchRTL import CgraWithContextSwitchRTL
from VectorCGRA.cgra.CgraWithStreamingLoadRTL import CgraWithStreamingLoadRTL
from VectorCGRA.lib.messages import mk_inter_cgra_pkt

def main():
  ap=argparse.ArgumentParser();ap.add_argument('--kind',choices=['context','streaming'],required=True)
  ap.add_argument('--label',default='cgra-pyreplay');a=ap.parse_args()
  stream=a.kind=='streaming';ports=8 if stream else 4;mask=2**32-1
  out=ROOT/'sv/reference/phase3/tile_variants'/f'{a.kind}-{a.label}'
  if out.exists():ap.error('Frozen output exists')
  assert not [p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  out.mkdir(parents=True)
  try:
    Data=mk_data(32,1);Ctrl=mk_ctrl(4,2,ports,ports,16)
    Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3));Host=mk_intra_cgra_pkt(1,1,4,Payload)
    Noc=mk_inter_cgra_pkt(1,1,4,3,Payload)
    Fus=[AdderRTL,MulRTL,StreamingMemUnitRTL,NahRTL] if stream else [PhiRTL,AdderRTL,MulRTL,MemUnitRTL,NahRTL]
    Cgra=CgraWithStreamingLoadRTL if stream else CgraWithContextSwitchRTL
    d=Cgra(Payload,1,1,2,2,8,128,16,2,16,8,8,True,FlexibleFuRTL,Fus,
      'KingMesh' if stream else 'Mesh',{0:[0,31]},{0:[0,0]},is_multi_cgra=False)
    d.apply(DefaultPassGroup())
    def ctrl(op,incoming=None,outgoing=()):
      c=Ctrl();c.operation=mk_bits(7)(op)
      for i in range(4):c.fu_in[i]=mk_bits(3)(i+1)
      if incoming is not None:c.routing_xbar_outport[ports]=mk_bits(4)(incoming+1)
      for o in outgoing:c.fu_xbar_outport[o]=mk_bits(2)(1)
      return c
    def packet(cmd,tile=0,value=0,pred=0,addr=0,control=None,pc=0):
      return Host(dst=tile,payload=Payload(cmd,data=Data(value&mask,pred),data_addr=addr,ctrl=control or Ctrl(),ctrl_addr=pc))
    if stream:
      programs={0:[ctrl(1),ctrl(88,outgoing=[5])],3:[ctrl(25,7,[1])],1:[ctrl(29,0,[4])],2:[ctrl(25,6,[2])]}
      constants={0:[],3:[5],1:[3],2:[-8]}
      link_specs=[(0,5,3),(3,1,1),(1,4,2)]
    else:
      programs={0:[ctrl(28,outgoing=[3]),ctrl(58,0)],1:[ctrl(25,2,[0])],3:[ctrl(29,1,[2])],2:[ctrl(25,3,[1,2])]}
      constants={0:[15,16],1:[5],3:[3],2:[-8]}
      link_specs=[(0,3,1),(1,0,3),(3,2,2),(2,1,0)]
    def configuration(values):
      packets=[packet(12,value=v,pred=1,addr=10+2*i) for i,v in enumerate(values)] if stream else [packet(12,value=values[0],pred=1,addr=15),packet(12,value=0xdeadbeef,pred=1,addr=16)]
      if stream:packets += [packet(23,0,10),packet(24,0,2),packet(25,0,18)]
      for tile in range(4):
        packets += [packet(13,tile,k,1) for k in constants[tile]]
        packets += [packet(8,tile,len(programs[tile])),packet(7,tile,(2 if tile==0 else 5) if stream else len(programs[tile]))]
        packets += [packet(3,tile,control=c,pc=pc) for pc,c in enumerate(programs[tile])]
      packets += [packet(0,tile) for tile in ([2,1,3,0] if stream else [2,3,1,0])]
      queries=[packet(10,addr=10),packet(10,addr=18)] if stream else [packet(10,addr=16),packet(10,addr=15)]
      return packets,queries
    inputs=[('reset',1),('cgra_id',1),('address_lower',7),('address_upper',7),
      ('recv_from_cpu_pkt__msg',Host.nbits),('recv_from_cpu_pkt__val',1),('send_to_cpu_pkt__rdy',1),
      ('recv_from_inter_cgra_noc__msg',Noc.nbits),('recv_from_inter_cgra_noc__val',1),('send_to_inter_cgra_noc__rdy',1)]
    outputs=[('recv_from_cpu_pkt__rdy',1),('send_to_cpu_pkt__msg',Host.nbits),('send_to_cpu_pkt__val',1)]
    for direction in ['north','south','west','east']:
      for i in range(2):
        for field,w in [('msg',Data.nbits),('val',1),('rdy',1)]:
          (outputs if field=='rdy' else inputs).append((f'recv_data_on_boundary_{direction}__{field}[{i}]',w))
          (inputs if field=='rdy' else outputs).append((f'send_data_on_boundary_{direction}__{field}[{i}]',w))
    def port(name):
      if '[' in name:
        base,index=name.split('[');iface,field=base.split('__')
        return getattr(getattr(d,iface)[int(index[:-1])],field)
      obj=d
      for p in name.split('__'):obj=getattr(obj,p)
      return obj
    def pack(fields):
      bits=0
      for name,width in fields:
        value=port(name);bits=(bits<<width)|int(value.to_bits() if hasattr(value,'to_bits') else value)
      return bits
    traces=[];events=[];summaries=[];packets_saved=[]
    for scenario in range(2):
      values=([1,2,3,4,5] if scenario==0 else [-5,-4,-3,-2,-1]) if stream else ([7] if scenario==0 else [-6])
      expected=[((v+5)*3-8)&mask for v in values]
      packets,queries=configuration(values);packets_saved.append([int(p.to_bits()) for p in packets+queries])
      sent=queried=host_hold=west_hold=0;completed=[];responses=[];west=[];links=[];done=None
      d.cgra_id @= 0;d.address_lower @= 0;d.address_upper @=31
      d.recv_from_inter_cgra_noc.val @= 0;d.recv_from_inter_cgra_noc.msg @= Noc();d.send_to_inter_cgra_noc.rdy @=0
      for direction in ['north','south','west','east']:
        for i in range(2):
          recv=getattr(d,'recv_data_on_boundary_'+direction)[i];send=getattr(d,'send_data_on_boundary_'+direction)[i]
          recv.msg @= Data();recv.val @=0;send.rdy @=1
      for local in range(-3,1000):
        d.reset @= local<0
        querying=sent==len(packets) and len(completed)==4
        active=None if local<0 else (packets[sent] if sent<len(packets) else queries[queried] if querying and queried<2 else None)
        d.recv_from_cpu_pkt.val @= active is not None;d.recv_from_cpu_pkt.msg @=active or Host()
        d.send_to_cpu_pkt.rdy @= local>=0 and host_hold>=6 and local%7>=2
        d.send_data_on_boundary_west[1].rdy @= local>=0 and west_hold>=8 and local%5 not in (1,2)
        d.sim_eval_combinational()
        cycle=len(traces)
        traces.append(f'{pack(inputs):0{(sum(w for _,w in inputs)+3)//4}x} {pack(outputs):0{(sum(w for _,w in outputs)+3)//4}x}')
        if active is not None and d.recv_from_cpu_pkt.rdy:
          if querying:queried+=1
          else:sent+=1
        if d.send_to_cpu_pkt.val:
          if host_hold<6:host_hold+=1
          if d.send_to_cpu_pkt.rdy:
            p=d.send_to_cpu_pkt.msg
            if int(p.payload.cmd)==14:
              assert int(p.src) not in completed and int(p.dst)==4
              completed.append(int(p.src));events.append(dict(cycle=cycle,event='complete',tile=int(p.src),scenario=scenario))
            else:
              assert int(p.payload.cmd)==11
              responses.append((int(p.payload.data_addr),int(p.payload.data.payload),int(p.payload.data.predicate)))
              events.append(dict(cycle=cycle,event='host-read',data=responses[-1],scenario=scenario))
        for direction in ['north','south','west','east']:
          for i in range(2):
            port_out=getattr(d,'send_data_on_boundary_'+direction)[i]
            if port_out.val:
              assert (direction,i)==('west',1),(scenario,local,direction,i)
              assert int(port_out.msg.payload)==expected[len(west)] and int(port_out.msg.predicate)==1,(scenario,local,port_out.msg,expected)
              if west_hold<8:west_hold+=1
              if port_out.rdy:
                west.append(int(port_out.msg.payload));events.append(dict(cycle=cycle,event='west',data=west[-1],scenario=scenario))
        for index,(src,direction,dst) in enumerate(link_specs):
          channel=d.tile[src].send_data[direction]
          if channel.val and channel.rdy:
            event_number=sum(1 for l in links if l['src']==src)
            v=values[event_number] if stream else values[0]
            value=[v,v+5,(v+5)*3,(v+5)*3-8][index]&mask
            assert int(channel.msg.payload)==value and int(channel.msg.predicate)==1
            links.append(dict(src=src,dst=dst,data=value,cycle=cycle));events.append(dict(event='link',scenario=scenario,**links[-1]))
        if len(completed)==4 and len(responses)==2 and len(west)==len(expected):
          if done is None:done=local
          if local>=done+8:d.sim_tick();break
        d.sim_tick()
      else:raise RuntimeError(f'Reference stalled scenario={scenario} sent={sent} completed={completed} west={west} links={links}')
      expected_reads=[(10,values[0]&mask,1),(18,values[-1]&mask,1)] if stream else [(16,expected[0],1),(15,values[0]&mask,1)]
      assert responses==expected_reads,(responses,expected_reads)
      assert Counter((l['src'],l['dst']) for l in links)==Counter({(src,dst):(5 if stream else 1) for src,_,dst in link_specs})
      summaries.append(dict(scenario=scenario,values=values,expected=expected,cycles=local+4,completed=completed,responses=responses,links=links))
      print(json.dumps(summaries[-1]),flush=True)
    (out/'cycles.txt').write_text('\n'.join(traces)+'\n',newline='\n')
    manifest=dict(baseline_commit=BASELINE,kind=a.kind,reference='unmodified full Python CgraWith variant; no HDL translation claimed',cycles=len(traces),
      parameters=dict(COLS=2,ROWS=2,DATA_W=32,TILE_PORTS=ports,CTRL_DEPTH=8,REG_DEPTH=16,NUM_CTRL=8,TOTAL_STEPS=8),
      fu_list=[f.__name__ for f in Fus],inputs=inputs,outputs=outputs,events=events,scenarios=summaries,packets=packets_saved,
      excluded_outputs=['recv_from_inter_cgra_noc__rdy','send_to_inter_cgra_noc__val','send_to_inter_cgra_noc__msg'],
      exclusion_reason='Single CGRA is_multi_cgra=False: original undriven external inter-CGRA endpoints; internal loopback is exercised by host memory commands.',
      source_sha256={str(Path(module.__file__).resolve().relative_to(ROOT)).replace('\\','/'):sha(module.__file__)
        for module in list(sys.modules.values()) if getattr(module,'__file__',None) and Path(module.__file__).suffix=='.py' and Path(module.__file__).resolve().is_relative_to(ROOT)},
      trace_sha256=sha(out/'cycles.txt'),exporter_sha256=sha(__file__))
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
    print(f'{a.kind} CGRA reference PASS {len(traces)} cycles',flush=True)
  except Exception:
    (out/'failure.txt').write_text(traceback.format_exc(),newline='\n');raise

if __name__=='__main__':main()
