"""Freeze a heterogeneous ac96 Template instance and explicit SV architecture tables.

Migration-only. The maintained DUT consumes static parameters; no Python is used
by its normal builds. Unmodified map_fu2rtl set order is captured, not guessed.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from reference_model import ROOT, BASELINE, type_schema, hex_bits
from pymtl3 import DefaultPassGroup, mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.multi_cgra.MeshMultiCgraTemplateRTL import MeshMultiCgraTemplateRTL
from VectorCGRA.cgra.CgraTemplateRTL import map_fu2rtl
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt, mk_inter_cgra_pkt
from VectorCGRA.lib.util.cgra.Tile import Tile
from VectorCGRA.lib.util.cgra.DataSPM import DataSPM
from VectorCGRA.lib.util.cgra.cgra_helper import get_links

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def packed(values,width):return sum(int(v)<<width*i for i,v in enumerate(values))

def main():
  ref=ROOT/'sv/reference/phase4/template/heterogeneous'
  out=ROOT/'sv/tests/phase4/template/heterogeneous'
  assert not ref.exists() and not out.exists(), 'Use fresh frozen directories'
  ref.mkdir(parents=True);out.mkdir(parents=True)
  (ref/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  git=lambda *x:subprocess.check_output(['git',*x],cwd=ROOT,text=True).strip()
  assert not [p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  sizes=[2,3,2,2]; tiles={};links={};mem={};shapes={};depths={}
  for c,size in enumerate(sizes):
    grid=[[Tile(x,y,16,['add','mul','mem']+(['logic'] if c==1 and x==1 and y==0 else [])) for x in range(size)] for y in range(size)]
    tiles[c]=[t for row in grid for t in row];links[c]=get_links(grid)
    # Exercise disabled directed edges without changing the four-Tile arithmetic loop.
    for link in links[c]:
      if not link.isFromMem() and not link.isToMem() and link.srcPort==5:
        link.disabled=True;link.validatePorts()
    mem[c]=DataSPM(2*size-1,2*size-1);shapes[c]=[size,size];depths[c]=8
  Data=mk_data(32,1);Ctrl=mk_ctrl(4,2,8,8,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3))
  Host=mk_intra_cgra_pkt(2,2,9,Payload);Noc=mk_inter_cgra_pkt(2,2,9,5,Payload)
  def design():
    return MeshMultiCgraTemplateRTL(Payload,2,2,8,128,16,2,16,8,8,FlexibleFuRTL,[],
      {c:[32*c,32*c+31] for c in range(4)},depths,shapes,tiles,links,mem,True,True)
  os.chdir(ref);d=design();d.elaborate()
  d.set_metadata(VerilogTranslationPass.enable,True)
  d.set_metadata(VerilogTranslationPass.explicit_module_name,'Phase4Heterogeneous')
  d.apply(VerilogTranslationPass())
  Path(d.get_metadata(VerilogTranslationPass.translated_filename)).rename(ref/'original.v')
  kinds={'AdderRTL':0,'MulRTL':1,'MemUnitRTL':2,'NahRTL':3,'LogicRTL':6}
  architectures=[]
  for c,size in enumerate(sizes):
    internal=[];rd=[0xffffffff]*5;wr=[0xffffffff]*5;ins=[0]*9;outs=[0]*9
    for link in links[c]:
      if link.isFromMem():
        if not link.disabled:rd[link.getMemReadPort()]=link.dstTile.getIndex(tiles[c])
      elif link.isToMem():
        if not link.disabled:wr[link.getMemWritePort()]=link.srcTile.getIndex(tiles[c])
      else:internal.append(dict(src=link.srcTile.getIndex(tiles[c]),dst=link.dstTile.getIndex(tiles[c]),sp=link.srcPort,dp=link.dstPort,enabled=int(not link.disabled)))
    for t in range(size*size):
      x,y=t%size,t//size
      for direction,boundary in [(0,y==size-1),(3,x==size-1)]:
        if boundary:
          if direction not in tiles[c][t].getInvalidInPorts():ins[t]|=1<<direction
          if direction not in tiles[c][t].getInvalidOutPorts():outs[t]|=1<<direction
      if y==0 and c//2>0:ins[t]|=2;outs[t]|=2
      if x==0 and c%2>0:ins[t]|=4;outs[t]|=4
    fu_names=[[type(f).__name__ for f in tile.element.fu] for tile in d.cgra[c].tile]
    architectures.append(dict(size=size,links=internal,read_ports=rd,write_ports=wr,boundary_in=ins,boundary_out=outs,fu_names=fu_names))
  sources={}
  for m in list(sys.modules.values()):
    p=getattr(m,'__file__',None)
    if not p or Path(p).suffix!='.py':continue
    try:rel=Path(p).resolve().relative_to(ROOT)
    except ValueError:continue
    if not str(rel).startswith('sv'):sources[rel.as_posix()]=sha(p)
  manifest=dict(baseline=BASELINE,export_commit=git('rev-parse','HEAD'),top='Phase4Heterogeneous',
    original_sha256=sha(ref/'original.v'),exporter_sha256=sha(__file__),source_sha256=sources,
    architectures=architectures,types={k:type_schema(v) for k,v in [('host',Host),('noc',Noc),('ctrl',Ctrl)]})
  (ref/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
  maxlinks=max(len(a['links']) for a in architectures)
  hdr='// Static architecture from the unmodified ac96 elaboration; no generated RTL.\n'
  hdr+=f'localparam int ARCH_LINKS={maxlinks};\n'
  def array(name,values,count,width):
    nonlocal hdr
    hdr+=f"localparam logic [{count-1}:0][{width-1}:0] {name}={count*width}'h{packed(values,width):x};\n"
  array('ARCH_SIZES',sizes,4,32)
  array('ARCH_COUNTS',[packed([len(fs) for fs in a['fu_names']]+[0]*(9-len(a['fu_names'])),32) for a in architectures],4,9*32)
  array('ARCH_FUS',[packed([packed([kinds[f] for f in fs],8) for fs in a['fu_names']]+[0]*(9-len(a['fu_names'])),40) for a in architectures],4,9*40)
  for key,name in [('src','SRC_TILE'),('sp','SRC_PORT'),('dst','DST_TILE'),('dp','DST_PORT')]:
    array('ARCH_'+name,[packed([x[key] for x in a['links']],32) for a in architectures],4,maxlinks*32)
  array('ARCH_ENABLED',[packed([x['enabled'] for x in a['links']],1) for a in architectures],4,maxlinks)
  for key,name,width in [('read_ports','READ',160),('write_ports','WRITE',160),('boundary_in','BIN',72),('boundary_out','BOUT',72)]:
    array('ARCH_'+name,[packed(a[key],32 if width==160 else 8) for a in architectures],4,width)
  (out/'architecture.svh').write_text(hdr,encoding='utf-8',newline='\n')
  print('EXPORTED heterogeneous',Host.nbits,Noc.nbits,flush=True)
  def ctrl(op,incoming=None,outgoing=None):
    r=[mk_bits(4)(0) for _ in range(12)];f=[mk_bits(2)(0) for _ in range(12)]
    if incoming is not None:r[8]=mk_bits(4)(incoming+1)
    if outgoing is not None:f[outgoing]=mk_bits(2)(1)
    return Ctrl(operation=op,fu_in=[mk_bits(3)(i+1) for i in range(4)],routing_xbar_outport=r,fu_xbar_outport=f)
  def pkt(cmd,c=0,t=0,value=0,pred=0,addr=0,control=None,pc=0):
    return Host(dst=t,dst_cgra_id=c,payload=Payload(cmd=cmd,data=Data(value&0xffffffff,pred),data_addr=addr,ctrl=Ctrl() if control is None else control,ctrl_addr=pc))
  packets=[];queries=[]
  for c in range(4):packets += [pkt(12,value=7+7*c,pred=1,addr=32*c+15),pkt(12,value=0xdeadbeef,pred=1,addr=32*c+16)]
  for c,size in enumerate(sizes):
    programs={0:[ctrl(28,outgoing=3),ctrl(58,incoming=0)],1:[ctrl(25,2,0)],size+1:[ctrl(29,1,2)],size:[ctrl(25,3,1)]}
    for t in range(size*size):
      prog=programs.get(t,[ctrl(1)])
      consts=[32*((c+1)%4)+15,32*((c+1)%4)+16] if t==0 else [5] if t==1 else [3] if t==size+1 else [-8] if t==size else []
      packets += [pkt(13,c,t,k,1) for k in consts]
      packets += [pkt(cmd,c,t,len(prog)) for cmd in [8,7]]
      packets += [pkt(3,c,t,control=p,pc=pc) for pc,p in enumerate(prog)]
  for c,size in enumerate(sizes):packets += [pkt(0,c,t) for t in reversed(range(size*size))]
  for c in range(4):queries += [pkt(10,addr=32*c+16),pkt(10,addr=32*c+15)]
  (out/'program.hex').write_text('\n'.join(hex_bits(p) for p in packets+queries)+'\n')
  d=design();d.elaborate();d.apply(DefaultPassGroup())
  ins=[];outs=[]
  def sample():
    ins.append(int(d.reset)|(int(d.recv_from_cpu_pkt.val)<<1)|(int(d.recv_from_cpu_pkt.msg.to_bits())<<2)|(int(d.send_to_cpu_pkt.rdy)<<(Host.nbits+2)))
    outs.append(int(d.recv_from_cpu_pkt.rdy)|(int(d.send_to_cpu_pkt.val)<<1)|(int(d.send_to_cpu_pkt.msg.to_bits())<<2))
  d.recv_from_cpu_pkt.val @= 0;d.recv_from_cpu_pkt.msg @= Host();d.send_to_cpu_pkt.rdy @= 0;d.reset @= 1
  for _ in range(3):d.sim_eval_combinational();sample();d.sim_tick()
  d.reset @= 0;pi=qi=hold=0;complete=[];responses=[];done=None
  for cycle in range(1500):
    querying=pi==len(packets) and len(complete)==21
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
          pair=(int(p.src_cgra_id),int(p.src));assert pair not in complete;complete.append(pair)
        else:
          addr=int(p.payload.data_addr);owner=addr//32;v=7+7*owner;expected=(v+5)*3-8 if addr%32==16 else v
          assert int(p.payload.cmd)==11 and int(p.payload.data.payload)==expected and int(p.src_cgra_id)==owner,str(p)
          responses.append(dict(address=addr,data=expected,owner=owner))
    if len(complete)==21 and len(responses)==8:
      if done is None:done=cycle
      if cycle>=done+10:d.sim_tick();break
    d.sim_tick()
  else:raise RuntimeError(f'stall pi={pi} qi={qi} completions={complete} responses={responses}')
  for name,data,width in [('inputs',ins,Host.nbits+3),('outputs',outs,Host.nbits+2)]:
    (out/f'{name}.hex').write_text('\n'.join(format(v,f'0{(width+3)//4}x') for v in data)+'\n')
  result=dict(samples=len(ins),cycles=cycle+1,completions=complete,responses=responses,input_bits=Host.nbits+3,output_bits=Host.nbits+2)
  (out/'results.json').write_text(json.dumps(result,indent=2)+'\n');(out/'samples.txt').write_text(str(len(ins))+'\n')
  print('PASS',json.dumps(result),flush=True)

if __name__=='__main__':main()
