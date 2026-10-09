"""Migration-only ac96 multi-CGRA reference and remote-memory kernel evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from reference_model import ROOT, BASELINE, type_schema, hex_bits
from pymtl3 import DefaultPassGroup, mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.multi_cgra.MeshMultiCgraRTL import MeshMultiCgraRTL
from VectorCGRA.multi_cgra.RingMultiCgraRTL import RingMultiCgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt, mk_inter_cgra_pkt

def sha(p):
  return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--topology', choices=['mesh','ring'], default='mesh')
  ap.add_argument('--tiles', type=int, default=2)
  ap.add_argument('--registered-memory', action='store_true')
  ap.add_argument('--label')
  ap.add_argument('--hdl-only',action='store_true',help='Freeze original HDL without the optional expensive Python cycle trace')
  a=ap.parse_args()
  cols=rows=a.tiles
  mc,mr=(2,2) if a.topology=='mesh' else (4,1)
  n=mc*mr; nt=cols*rows
  label=a.label or f'{a.topology}4-tiles{a.tiles}'+('-registered' if a.registered_memory else '')
  ref=ROOT/'sv/reference/phase4/system'/label
  out=ROOT/'sv/tests/phase4/system'/label
  assert not ref.exists() and not out.exists(), 'Frozen export requires fresh directories'
  ref.mkdir(parents=True); out.mkdir(parents=True)
  (ref/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
  assert not [p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  Data=mk_data(32,1); Ctrl=mk_ctrl(4,2,4,4,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3))
  Host=mk_intra_cgra_pkt(mc,mr,nt,Payload)
  Noc=mk_inter_cgra_pkt(mc,mr,nt,cols+rows-1,Payload)
  def design():
    args=[Payload,mr,mc,rows,cols,8,128,16,2,16,8,8,not a.registered_memory,
      FlexibleFuRTL,[AdderRTL,MulRTL,MemUnitRTL,NahRTL]]
    if a.topology=='mesh': args+=['Mesh']
    args += [{i:[32*i,32*i+31] for i in range(n)}]
    return (MeshMultiCgraRTL if a.topology=='mesh' else RingMultiCgraRTL)(*args)
  top='Phase4'+''.join(x.capitalize() for x in label.split('-'))
  os.chdir(ref)
  d=design(); d.elaborate()
  d.set_metadata(VerilogTranslationPass.enable,True)
  d.set_metadata(VerilogTranslationPass.explicit_module_name,top)
  d.apply(VerilogTranslationPass())
  raw=ref/'original.v'
  Path(d.get_metadata(VerilogTranslationPass.translated_filename)).rename(raw)
  sources={}
  for m in list(sys.modules.values()):
    p=getattr(m,'__file__',None)
    if not p or Path(p).suffix!='.py': continue
    try: rel=Path(p).resolve().relative_to(ROOT)
    except ValueError: continue
    if not str(rel).startswith('sv'): sources[rel.as_posix()]=sha(p)
  manifest=dict(baseline=BASELINE,export_commit=git('rev-parse','HEAD'),top=top,
    original_sha256=sha(raw),exporter_sha256=sha(__file__),source_sha256=sources,
    parameters=dict(COLS=cols,ROWS=rows,MULTI_COLS=mc,MULTI_ROWS=mr,TOPOLOGY=int(a.topology=='ring'),MEM_COMBINATIONAL=int(not a.registered_memory)),
    types={k:type_schema(v) for k,v in [('data',Data),('ctrl',Ctrl),('payload',Payload),('host',Host),('noc',Noc)]})
  (ref/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
  print('EXPORTED',label,Host.nbits,Noc.nbits,flush=True)
  if a.hdl_only:
    (out/'README.md').write_text('This profile uses frozen original HDL and an independent native SV program oracle; no Python cycle trace is requested.\n')
    print('HDL_ONLY_EXPORT_PASS',label,flush=True)
    return
  chain=[0]
  for y in range(rows): chain.extend(y*cols+x for x in (range(1,cols) if y%2==0 else range(cols-1,0,-1)))
  chain.extend(y*cols for y in range(rows-1,0,-1))
  def direction(src,dst):
    return {(0,1):0,(0,-1):1,(-1,0):2,(1,0):3}[(dst%cols-src%cols,dst//cols-src//cols)]
  def ctrl(op,incoming=None,outgoing=()):
    r=[mk_bits(4)(0) for _ in range(8)]; f=[mk_bits(2)(0) for _ in range(8)]
    if incoming is not None:r[4]=mk_bits(4)(incoming+1)
    for p in outgoing:f[p]=mk_bits(2)(1)
    return Ctrl(operation=op,fu_in=[mk_bits(3)(i+1) for i in range(4)],routing_xbar_outport=r,fu_xbar_outport=f)
  def packet(cmd,cgra=0,tile=0,value=0,pred=0,addr=0,control=None,pc=0):
    return Host(dst=tile,dst_cgra_id=cgra,payload=Payload(cmd=cmd,data=Data(value&0xffffffff,pred),
      data_addr=addr,ctrl=Ctrl() if control is None else control,ctrl_addr=pc))
  programs={0:[ctrl(28,outgoing=[3]),ctrl(58,incoming=0)]}
  for i,t in enumerate(chain[1:],1):programs[t]=[ctrl(29 if i==2 else 25,direction(t,chain[i-1]),[direction(t,chain[(i+1)%nt])])]
  d=design();d.elaborate();d.apply(DefaultPassGroup())
  inputs=[];outputs=[];results=[]
  def sample():
    inputs.append(int(d.reset)|(int(d.recv_from_cpu_pkt.val)<<1)|(int(d.recv_from_cpu_pkt.msg.to_bits())<<2)|(int(d.send_to_cpu_pkt.rdy)<<(Host.nbits+2)))
    outputs.append(int(d.recv_from_cpu_pkt.rdy)|(int(d.send_to_cpu_pkt.val)<<1)|(int(d.send_to_cpu_pkt.msg.to_bits())<<2))
  for scenario in range(2):
    packets=[];queries=[]
    values=[(7+7*i if scenario==0 else -6-3*i)&0xffffffff for i in range(n)]
    expected=lambda value:((value+5)*3-8*(nt-3))&0xffffffff
    for i in range(n):
      packets += [packet(12,value=values[i],pred=1,addr=i*32+15),packet(12,value=0xdeadbeef,pred=1,addr=i*32+16)]
    for c in range(n):
      remote=(c+1)%n
      for t in range(nt):
        ix=chain.index(t)
        constants=[remote*32+15,remote*32+16] if t==0 else [5 if ix==1 else 3 if ix==2 else -8]
        packets += [packet(13,c,t,k,1) for k in constants]
        packets += [packet(cmd,c,t,len(programs[t])) for cmd in [8,7]]
        packets += [packet(3,c,t,control=p,pc=pc) for pc,p in enumerate(programs[t])]
    for c in range(n):packets += [packet(0,c,t) for t in reversed(chain)]
    for c in range(n):queries += [packet(10,addr=c*32+16),packet(10,addr=c*32+15)]
    (out/f'program{scenario}.hex').write_text('\n'.join(hex_bits(p) for p in packets+queries)+'\n')
    d.recv_from_cpu_pkt.val @= 0;d.recv_from_cpu_pkt.msg @= Host();d.send_to_cpu_pkt.rdy @= 0;d.reset @= 1
    for _ in range(3):d.sim_eval_combinational();sample();d.sim_tick()
    d.reset @= 0
    pi=qi=hold=0;completed=[];responses=[];done=None
    for cycle in range(10000):
      querying=pi==len(packets) and len(completed)==n*nt
      active=packets[pi] if pi<len(packets) else queries[qi] if querying and qi<len(queries) else None
      d.recv_from_cpu_pkt.val @= int(active is not None);d.recv_from_cpu_pkt.msg @= Host() if active is None else active
      d.send_to_cpu_pkt.rdy @= int(hold>=8 and cycle%7>=2)
      d.sim_eval_combinational();sample()
      if active is not None and d.recv_from_cpu_pkt.rdy:
        if querying:qi+=1
        else:pi+=1
      if d.send_to_cpu_pkt.val:
        if hold<8:hold+=1
        if d.send_to_cpu_pkt.rdy:
          p=d.send_to_cpu_pkt.msg
          if int(p.payload.cmd)==14:
            pair=(int(p.src_cgra_id),int(p.src)); assert pair not in completed; completed.append(pair)
          else:
            assert int(p.payload.cmd)==11,str(p)
            addr=int(p.payload.data_addr);owner=addr//32
            want=expected(values[owner]) if addr%32==16 else values[owner]
            assert int(p.payload.data.payload)==want and int(p.payload.data.predicate)==1,(str(p),want)
            assert int(p.src_cgra_id)==owner and int(p.dst_cgra_id)==0,str(p)
            responses.append(dict(cycle=cycle,address=addr,data=want,owner=owner))
      if len(completed)==n*nt and len(responses)==2*n:
        if done is None:done=cycle
        if cycle>=done+10:d.sim_tick();break
      d.sim_tick()
    else:raise RuntimeError(f'stall pi={pi} qi={qi} done={completed} responses={responses}')
    result=dict(scenario=scenario,cycles=cycle+1,packets=len(packets),queries=len(queries),completed=completed,responses=responses)
    results.append(result);print('SCENARIO',json.dumps(result),flush=True)
  for name,data,width in [('inputs',inputs,Host.nbits+3),('outputs',outputs,Host.nbits+2)]:
    (out/f'{name}.hex').write_text('\n'.join(format(x,f'0{(width+3)//4}x') for x in data)+'\n')
  summary=dict(label=label,samples=len(inputs),input_bits=Host.nbits+3,output_bits=Host.nbits+2,scenarios=results,oracle='unmodified ac96 Python plus exported HDL')
  (out/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
  (out/'samples.txt').write_text(str(len(inputs))+'\n')
  print('PASS',label,len(inputs),flush=True)

if __name__=='__main__':main()
