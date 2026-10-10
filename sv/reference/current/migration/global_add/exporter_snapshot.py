"""Freeze a small legal global-add program on the unmodified four-CGRA mesh."""
import argparse,json,sys,time,traceback
from pathlib import Path
from current_migration_trace import ROOT,BASELINE,sha,save,bits,type_schema
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.multi_cgra.MeshMultiCgraRTL import MeshMultiCgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.RetRTL import RetRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from VectorCGRA.fu.vector.VectorAllReduceRTL import VectorAllReduceRTL


def main():
  ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--label',default='global_add');a=ap.parse_args()
  out=ROOT/'sv/reference/current/migration'/a.label
  if out.exists():ap.error('Frozen evidence exists')
  out.mkdir(parents=True);(out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  Data=mk_data(32,1);Ctrl=mk_ctrl(4,2,4,4,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3));Host=mk_intra_cgra_pkt(2,2,4,Payload)
  fus=[MemUnitRTL,VectorAllReduceRTL,RetRTL,NahRTL]
  d=MeshMultiCgraRTL(Payload,2,2,2,2,8,128,16,2,16,8,8,True,FlexibleFuRTL,fus,'Mesh',
    {0:[0,31],1:[32,63],2:[64,95],3:[96,127]},False)
  def packet(cmd,cgra=0,tile=0,value=0,pred=0,addr=0,ctrl=None,pc=0):
    return Host(dst=tile,dst_cgra_id=cgra,dst_cgra_x=cgra%2,dst_cgra_y=cgra//2,
      payload=Payload(cmd,data=Data(value&0xffffffff,pred),data_addr=addr,ctrl=ctrl or Ctrl(),ctrl_addr=pc))
  def ctrl(op):
    c=Ctrl();c.operation=mk_bits(7)(op)
    for i in range(4):c.fu_in[i]=mk_bits(3)(i+1)
    return c
  load_base=ctrl(28);load_base.fu_xbar_outport[5]=mk_bits(2)(1);load_base.write_reg_from[1]=mk_bits(2)(2)
  reduce=ctrl(78);reduce.routing_xbar_outport[4]=mk_bits(4)(1)
  reduce.read_reg_towards[1]=mk_bits(2)(1);reduce.fu_xbar_outport[3]=mk_bits(2)(1)
  load_vector=ctrl(28);load_vector.fu_xbar_outport[1]=mk_bits(2)(1)
  ret=ctrl(35);ret.routing_xbar_outport[4]=mk_bits(4)(3)
  packets=[packet(17,value=2,pred=1)]
  expected={0:53,3:31}
  for c,packed,base in [(0,0x04030201,17),(3,0x08070605,-5)]:
    packets += [packet(12,value=packed,pred=1,addr=32*c),packet(12,value=base,pred=1,addr=32*c+1)]
    for t,program,constants,total in [(0,[load_base,reduce],[32*c+1],2),(1,[ret],[],100),(2,[load_vector],[32*c],1)]:
      packets += [packet(13,c,t,k,1) for k in constants]
      packets += [packet(8,c,t,len(program)),packet(7,c,t,total)]
      packets += [packet(3,c,t,ctrl=control,pc=i) for i,control in enumerate(program)]
  for c in (3,0):
    packets += [packet(0,c,t) for t in (1,0,2)]
  info=dict(label=a.label,baseline_commit=BASELINE,oracle='pinned current Python full MeshMultiCgraRTL',
    hdl_equivalence=False,status='recording',exporter_sha256=sha(__file__),host=type_schema(Host),
    parameters=dict(DATA_W=32,COLS=2,ROWS=2,MULTI_COLS=2,MULTI_ROWS=2,TILE_PORTS=4,CTRL_DEPTH=8,
      GLOBAL_ADDR_W=7,BANK_DEPTH=16,NUM_BANKS=2,REG_DEPTH=16,NUM_CTRL=8,TOTAL_STEPS=8,TILE_VARIANT=0),
    fu_list=[f.__name__ for f in fus],fu_kinds=[2,21,13,3],
    independent_math=dict(lanes=[[1,2,3,4],[5,6,7,8]],global_sum=36,bases=[17,-5],expected_returns=[53,31]),
    configuration_packets=[f'{bits(p):0{(Host.nbits+3)//4}x}' for p in packets])
  save(out/'manifest.json',info);start=time.monotonic();rows=[];events=[]
  try:
    d.apply(DefaultPassGroup());print('ELABORATED global-add',flush=True)
    inputs=[('reset',1,lambda:d.reset,'reset'),('host_recv_msg',Host.nbits,lambda:d.recv_from_cpu_pkt.msg,'recv_from_cpu_pkt__msg'),
      ('host_recv_val',1,lambda:d.recv_from_cpu_pkt.val,'recv_from_cpu_pkt__val'),('host_send_rdy',1,lambda:d.send_to_cpu_pkt.rdy,'send_to_cpu_pkt__rdy')]
    outputs=[('host_recv_rdy',1,lambda:d.recv_from_cpu_pkt.rdy,'recv_from_cpu_pkt__rdy'),
      ('host_send_msg',Host.nbits,lambda:d.send_to_cpu_pkt.msg,'send_to_cpu_pkt__msg'),('host_send_val',1,lambda:d.send_to_cpu_pkt.val,'send_to_cpu_pkt__val')]
    for c in range(4):
      for direction,member in [('recv','recv_from_inter_cgra_noc'),('send','send_to_inter_cgra_noc')]:
        port=getattr(d.cgra[c],member)
        for field,width in [('msg',port.msg.to_bits().nbits),('val',1),('rdy',1)]:
          native='send' if direction=='recv' else 'recv'
          outputs.append((f'cgra{c}_noc_{direction}_{field}',width,lambda port=port,field=field:getattr(port,field),f'dut.noc_{native}_{field}[{c}]'))
    def schema(fields):return [dict(name=n,width=w,sv=s) for n,w,_,s in fields]
    def pack(fields):
      value=0
      for _,width,get,_ in fields:value=(value<<width)|bits(get())
      return value
    info.update(inputs=schema(inputs),outputs=schema(outputs));save(out/'manifest.json',info)
    ib=sum(w for _,w,_,_ in inputs);ob=sum(w for _,w,_,_ in outputs)
    sent=0;complete=[];returns={};hold=0;done=None;requests=[];replies=[]
    trace=(out/'cycles.txt').open('w',newline='\n')
    for local in range(-3,350):
      d.reset @=local<0
      active=packets[sent] if local>=0 and sent<len(packets) else None
      d.recv_from_cpu_pkt.val @=active is not None;d.recv_from_cpu_pkt.msg @=active or Host()
      d.send_to_cpu_pkt.rdy @=local>=0 and hold>=8 and local%7>=2
      d.sim_eval_combinational();row=len(rows)
      line=f'{pack(inputs):0{(ib+3)//4}x} {pack(outputs):0{(ob+3)//4}x}'
      trace.write(line+'\n');rows.append(line)
      if active is not None and d.recv_from_cpu_pkt.rdy:sent+=1
      if local>=0:
        if d.send_to_cpu_pkt.val:
          if hold<8:hold+=1
          if d.send_to_cpu_pkt.rdy:
            p=d.send_to_cpu_pkt.msg;key=(int(p.src_cgra_id),int(p.src))
            assert int(p.payload.cmd)==14 and key not in complete,(row,p)
            complete.append(key)
            if key[1]==1:
              assert int(p.payload.data.payload)==expected[key[0]] and int(p.payload.data.predicate)==1,(row,p)
              returns[key[0]]=int(p.payload.data.payload)
            events.append(dict(cycle=row,event='complete',cgra=key[0],tile=key[1],data=int(p.payload.data.payload),predicate=int(p.payload.data.predicate)))
        for c in range(4):
          p=d.cgra[c].send_to_inter_cgra_noc
          if p.val and p.rdy and int(p.msg.payload.cmd) in (18,20):
            event=dict(cycle=row,event='reduce-request' if int(p.msg.payload.cmd)==18 else 'reduce-response',
              cgra=c,src=int(p.msg.src),dst=int(p.msg.dst),data=int(p.msg.payload.data.payload),predicate=int(p.msg.payload.data.predicate))
            (requests if int(p.msg.payload.cmd)==18 else replies).append(event);events.append(event)
        if len(complete)==6 and len(returns)==2 and sent==len(packets):
          if done is None:done=local
          if local>=done+8:d.sim_tick();break
      if local%25==0:trace.flush();print(f'GLOBAL cycle={local} sent={sent} complete={complete} requests={len(requests)} replies={len(replies)} seconds={time.monotonic()-start:.1f}',flush=True)
      d.sim_tick()
    else:raise RuntimeError(f'global-add timeout sent={sent} complete={complete} requests={requests} replies={replies}')
    trace.close()
    assert sorted((x['cgra'],x['data']) for x in requests)==[(0,10),(3,26)],requests
    assert len(replies)==2 and all(x['data']==36 and x['predicate']==1 for x in replies),replies
    assert returns==expected and set(complete)=={(c,t) for c in (0,3) for t in (0,1,2)}
    info.update(status='recorded',cycles=len(rows),input_bits=ib,output_bits=ob,events=events,host_inputs=sent,completions=6,
      host_backpressure_samples=hold,returns=returns,seconds=time.monotonic()-start,trace_sha256=sha(out/'cycles.txt'))
    print(f'PYTHON_GLOBAL_ADD_PASS cycles={len(rows)} returns={returns}',flush=True)
  except Exception:
    info.update(status='failed',failure=traceback.format_exc(),cycles_recorded=len(rows),seconds=time.monotonic()-start)
    (out/'failure.txt').write_text(info['failure'],newline='\n');raise
  finally:
    info['source_sha256']={Path(m.__file__).resolve().relative_to(ROOT).as_posix():sha(m.__file__)
      for m in list(sys.modules.values()) if getattr(m,'__file__',None) and Path(m.__file__).suffix=='.py' and Path(m.__file__).resolve().is_relative_to(ROOT)}
    save(out/'manifest.json',info)


if __name__=='__main__':main()
