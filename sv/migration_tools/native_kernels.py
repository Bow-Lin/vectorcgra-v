"""Build native kernel candidates without modifying pinned Python or traces.

GEMM/GEMV adapt frozen programs to token-based register lifetimes. SPMV
repairs PHI, loop-exit and store-completion dependencies in the captured 4x4
mapping. No Python RTL simulation is claimed; the SV runner verifies results.
"""
import argparse
import contextlib
import importlib
import io
import sys
import types
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
FIELDS=lambda r:[('read_idx',r,4),('read_src',2,4),('write_idx',r,4),('write_src',2,4),('last',1,1),('vf',3,1),('fu_out',2,8),('route',4,8),('fu_in',3,4),('op',7,1)]
def decode(v,r):
 d={}
 for n,w,num in FIELDS(r):
  d[n]=[(v>>(i*w))&((1<<w)-1) for i in range(num)];v>>=w*num
 return d
def encode(d,r):
 v=0;shift=0
 for n,w,num in FIELDS(r):
  for x in d[n]:v|=x<<shift;shift+=w
 return v
def repair(kernel, m, spmv_nnz=8):
 p=m['parameters'];rw=(p['REG_DEPTH']-1).bit_length();ca=(p['CTRL_DEPTH']-1).bit_length();cb=39+8*6+8*rw;pb=6+35+p['GLOBAL_ADDR_W']+cb+ca;idw=max(1,(p['MULTI_ROWS']*p['MULTI_COLS']-1).bit_length());dstshift=pb+9+2*(idw+max(1,(p['MULTI_COLS']-1).bit_length())+max(1,(p['MULTI_ROWS']-1).bit_length()))
 packets=[int(x,16) for x in m['configuration_packets']];program={};packet_index={};changes=[]
 for i,v in enumerate(packets):
  cmd=(v>>(pb-6))&63;tile=(v>>dstshift)&31;pc=v&((1<<ca)-1)
  if cmd==3:program.setdefault(tile,{})[pc]=decode((v>>ca)&((1<<cb)-1),rw);packet_index[tile,pc]=i
 # Two independent source/destination values share one bank's write port.
 # Move the destination to the otherwise unused fourth register bank.
 tile,oldidx={'gemv':(5,2),'gemm':(9,1),'spmv':(9,0)}[kernel]
 renamed_routing_reads=set()
 for pc,c in program[tile].items():
  assert c['read_src'][3]==c['write_src'][3]==c['route'][7]==c['fu_out'][7]==0
  if c['read_src'][0] and c['read_idx'][0]==oldidx:
   if c['read_src'][0]&2:renamed_routing_reads.add(pc)
   assert 4 not in c['fu_in'],(kernel,tile,pc,'occupied fourth input')
   c['read_src'][3]=c['read_src'][0];c['read_idx'][3]=0;c['read_src'][0]=0
   c['fu_in']=[4 if x==1 else x for x in c['fu_in']]
   c['route']=[8 if x==5 else x for x in c['route']]
   changes.append(dict(tile=tile,pc=pc,kind='rename_read',old_register=oldidx,new_register=24))
  if c['write_src'][0] and c['write_idx'][0]==oldidx:
   source=c['write_src'][0];assert source in [1,2]
   key='route' if source==1 else 'fu_out'
   c[key][7]=c[key][4];c[key][4]=0
   c['write_src'][3]=source;c['write_idx'][3]=0;c['write_src'][0]=0
   changes.append(dict(tile=tile,pc=pc,kind='rename_write',old_register=oldidx,new_register=24))
 # Prologue selectors name physical crossbar inputs, not logical registers.
 for i,v in enumerate(packets):
  if (v>>(pb-6))&63==6 and (v>>dstshift)&31==tile and (v&((1<<ca)-1)) in renamed_routing_reads:
   c=decode((v>>ca)&((1<<cb)-1),rw)
   if c['route'][0]==5:
    c['route'][0]=8
    packets[i]=(v&~(((1<<cb)-1)<<ca))|(encode(c,rw)<<ca)
    changes.append(dict(tile=tile,pc=v&((1<<ca)-1),kind='rename_routing_prologue',old_input=5,new_input=8))
 if kernel=='spmv':
  for tile,prog in program.items():
   for pc,c in prog.items():
    if c['op']==[84]:
     c['op']=[105]
     changes.append(dict(tile=tile,pc=pc,kind='predicated_phi_start',opcode=105))
    elif c['op']==[17] and sum(x!=0 for x in c['fu_in'])>2:
     c['op']=[104]
     changes.append(dict(tile=tile,pc=pc,kind='multi_input_phi',opcode=104))
  if spmv_nnz>0 and spmv_nnz%4==0:
   # The compile-time no-tail exit must wait for the main loop's exit token.
   # Slot 13 already merges that token; save it in the unused fourth bank.
   # Slot 7 consumes it on the next II, retaining the original mesh schedule.
   c=program[4][13]
   assert c['write_src'][3]==c['fu_out'][7]==0
   c['write_src'][3]=2;c['write_idx'][3]=0;c['fu_out'][7]=1
   c=program[4][7]
   assert c['read_src'][3]==0
   c['read_src'][3]=1;c['read_idx'][3]=0;c['fu_in']=[4,4,0,0]
   changes.append(dict(tile=4,kind='no_tail_return_dependency',producer_pc=13,consumer_pc=7,register=24,compile_time_nnz=spmv_nnz))
  # Join post-store tokens using existing routing crossbars. An unarmed register
  # supplies a val token even for a predicated-off store; its payload is unused.
  # Ret's predicate also traverses the crossbar, whose all-input join prevents
  # the FU from returning before *both* store chains have arrived.
  # The west link carries the loop-exit token before its new completion token.
  # Move Ret after slot 13 so it cannot consume that loop token as an ack.
  # Move slot 14's GEP to slot 11, using $25 to avoid the simultaneous $2 write.
  ret=program[4][11];gep=program[4][14]
  assert ret['op']==[64] and gep['op']==[25]
  ret_route=ret['route'][:]
  gep['route']=ret_route;gep['write_src'][0]=1;gep['write_idx'][0]=2;gep['fu_out'][4]=0
  gep['write_src'][3]=2;gep['write_idx'][3]=1;gep['fu_out'][7]=1
  ret['route']=[0]*8;ret['write_src']=[0]*4;ret['write_idx']=[0]*4
  program[4][11]=gep;program[4][14]=ret
  load=program[4][0];load['read_src'][0]=0;load['read_src'][3]=1;load['read_idx'][3]=1;load['fu_in'][0]=4
  for i,v in enumerate(packets):
   if (v>>(pb-6))&63 in [4,5] and (v>>dstshift)&31==4 and (v&((1<<ca)-1))==11:
    packets[i]=(v&~(((1<<35)-1)<<(p['GLOBAL_ADDR_W']+cb+ca)))|(4<<(p['GLOBAL_ADDR_W']+cb+ca))
  joins=[(3,11,2,8),(2,12,2,8),(2,12,4,4),(1,13,0,4),
         (5,14,2,2),(12,12,1,8),(8,13,1,1),
         (4,14,5,1),(4,14,6,6),(4,14,7,4)]
  prologues=set()
  for tile,pc,dst,src in joins:
   c=program[tile][pc];assert c['route'][dst]==0,(tile,pc,dst)
   c['route'][dst]=src
   if src==8:
    assert c['read_src'][3]==0;c['read_src'][3]=2;c['read_idx'][3]=0
   if (tile,pc,src)!=(4,14,6):prologues.add((tile,pc,src))
  c=program[4][14];assert c['read_src'][1]==1 and c['fu_in'][0]==2
  c['read_src'][1]=2;c['fu_in'][0]=3
  for tile,pc,src in sorted(prologues):
   c=decode(0,rw);c['route'][0]=src
   packets.insert(0,(tile<<dstshift)|(6<<(pb-6))|(12<<(p['GLOBAL_ADDR_W']+cb+ca))|(encode(c,rw)<<ca)|pc)
  for cmd in [4,5]:
   packets.insert(0,(4<<dstshift)|(cmd<<(pb-6))|(12<<(p['GLOBAL_ADDR_W']+cb+ca))|14)
  # Packet indices shifted after prepending the additional prologue commands.
  packet_index={key:value+len(prologues)+2 for key,value in packet_index.items()}
  changes.append(dict(tile=4,kind='reschedule_return',return_pc=[11,14],gep_pc=[14,11],address_register=25))
  changes.append(dict(kind='store_completion_join',routes=[dict(tile=t,pc=pc,output=dst,input=src) for t,pc,dst,src in joins],claim='Existing crossbar val/rdy tokens; no new memory or return opcode'))
 # Static liveness over the original II: retain values with a later read
 # before their next write, using the existing register->routing->register path.
 pending=[]
 for tile,prog in program.items():
  for pc,c in prog.items():
   for bank in range(4):
    if not c['read_src'][bank]:continue
    idx=c['read_idx'][bank]
    if c['write_src'][bank] and c['write_idx'][bank]==idx:continue
    preserve=False
    for delta in range(1,len(prog)+1):
     nxt=prog[(pc+delta)%len(prog)]
     if nxt['read_src'][bank] and nxt['read_idx'][bank]==idx:preserve=True;break
     if nxt['write_src'][bank] and nxt['write_idx'][bank]==idx:break
    if preserve:
     assert not c['write_src'][bank] and not c['route'][4+bank],(kernel,tile,pc,bank)
     pending.append((tile,pc,bank,idx))
 for tile,pc,bank,idx in pending:
  c=program[tile][pc];c['read_src'][bank]|=2;c['write_src'][bank]=1;c['write_idx'][bank]=idx;c['route'][4+bank]=5+bank
  changes.append(dict(tile=tile,pc=pc,kind='retain_live_register',bank=bank,index=idx))
 for tile,prog in program.items():
  for pc,c in prog.items():
   i=packet_index[tile,pc];packets[i]=(packets[i]&~(((1<<cb)-1)<<ca))|(encode(c,rw)<<ca)
 if kernel=='gemm':
  for tile in [4,6]:
   packets.insert(0,(tile<<dstshift)|(43<<(pb-6))|(((4<<3)|4)<<(p['GLOBAL_ADDR_W']+cb+ca)))
   changes.append(dict(tile=tile,kind='GEP_stride',stride=4))
 return packets, changes, program, cb, ca

def capture_spmv():
  pkg=types.ModuleType('VectorCGRA');pkg.__path__=[str(ROOT)];sys.modules['VectorCGRA']=pkg
  captured={}
  from pymtl3 import b7
  sg=importlib.import_module('VectorCGRA.validation.script_generator')
  sg.yaml_to_VectorCGRA_map=dict(sg.yaml_to_VectorCGRA_map,ICMP_ULT=b7(102))
  sg.yaml_to_VectorCGRA_map_const=dict(sg.yaml_to_VectorCGRA_map_const,ICMP_ULT=b7(103),AND=b7(100),OR=b7(101))
  mod=importlib.import_module('VectorCGRA.cgra.test.CgraRTL_spmv_test_from_yaml')
  class Capture:
   def __init__(self,*args): self.args=args; self.dut=types.SimpleNamespace(set_metadata=lambda *a:None)
   def elaborate(self):pass
  class Done(Exception):pass
  mod.TestHarness=Capture
  mod.init_trace_logger=lambda *args,**kwargs:None
  mod.close_trace_logger=lambda *args,**kwargs:None
  mod.config_model_with_cmdline_opts=lambda x,*a,**k:x
  def run(th,**kwargs):
   a=th.args
   p=dict(COLS=a[5],ROWS=a[6],CTRL_DEPTH=a[7],GLOBAL_ADDR_W=(a[8]-1).bit_length(),BANK_DEPTH=a[9],NUM_BANKS=a[10],REG_DEPTH=a[11],NUM_CTRL=a[13],TOTAL_STEPS=a[14],MEM_COMBINATIONAL=int(a[15]),MULTI_ROWS=a[19],MULTI_COLS=a[20])
   kinds=dict(AdderRTL=0,MulRTL=1,DivRTL=16,LogicRTL=6,ShifterRTL=7,PhiRTL=9,ConstRTL=4,CompRTL=5,GrantRTL=10,MemUnitRTL=2,SelRTL=8,RetRTL=13,GepRTL=11,NahRTL=3)
   m=dict(kernel='spmv',parameters=p,fu_kinds=[kinds[x.__name__] for x in a[2]]+[3],configuration_packets=[f'{int(x.to_bits()):x}' for x in a[12]],expected_packets=[f'{int(x.to_bits()):x}' for x in a[18]])
   captured.update(m)
   raise Done()
  mod.run_sim=run
  try:
   with contextlib.redirect_stdout(io.StringIO()):
    mod.test_homogeneous_4x4_spmv_combinational_mem_access_return({})
  except Done:pass
  return captured


def spmv_ablations(root):
  """Remove one repair at a time; the native runner must reject every fixture."""
  for name,nnz in [('wrong_prologue',8),('legacy_start',8),('binary_phi',3),
                   ('missing_loop_exit',8),('dropped_store_ack',1)]:
    source=root if nnz==8 else root/'scenarios'/f'nnz{nnz}'
    packets=[];mutations=0;ret_ctrl=None
    for raw in (source/'program.hex').read_text().split():
      v=int(raw,16);cmd=(v>>157)&63;tile=(v>>182)&31;pc=v&15
      c=decode((v>>4)&((1<<111)-1),3);changed=False
      if name=='wrong_prologue' and (cmd,tile,pc)==(6,9,8) and c['route'][0]==8:
        c['route'][0]=5;changed=True
      if cmd==3:
        if name=='legacy_start' and c['op']==[105]:c['op']=[84];changed=True
        if name=='binary_phi' and c['op']==[104]:c['op']=[17];changed=True
        if name=='missing_loop_exit' and (tile,pc)==(4,7):
          c['fu_in']=[1,1,0,0];changed=True
        if name=='dropped_store_ack' and (tile,pc)==(12,12):
          c['route'][1]=0;changed=True
        if c['op']==[64]:ret_ctrl=encode(c,3)
      if changed:
        mutations+=1;v=(v&~(((1<<111)-1)<<4))|(encode(c,3)<<4)
      packets.append(v)
    assert mutations and ret_ctrl is not None,name
    ret=int((source/'return.hex').read_text(),16)
    ret=(ret&~(((1<<111)-1)<<4))|(ret_ctrl<<4)
    out=root/'negative'/name;out.mkdir(parents=True,exist_ok=True)
    files={'program.hex':''.join(f'{v:x}\n' for v in packets),'return.hex':f'{ret:x}\n',
           'expected.hex':(source/'expected.hex').read_text(),'nnz.txt':f'{nnz}\n'}
    for filename,data in files.items():(out/filename).write_text(data)
    (out/'manifest.json').write_text(json.dumps(dict(status='must_fail',ablation=name,nnz=nnz,
        mutations=mutations,fixture_sha256={n:hashlib.sha256(d.encode()).hexdigest() for n,d in files.items()}),indent=2)+'\n')


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('kernels',nargs='+',choices=['gemm','gemv','spmv'])
  ap.add_argument('--spmv-nnz',type=int,default=8)
  ap.add_argument('--spmv-matrix',action='store_true',help='Generate nnz 0..8 scenarios alongside the original eight-entry program.')
  ap.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/native/kernels')
  args=ap.parse_args()
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for name,expected in target['source_sha256'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,name
  jobs=[(kernel,n) for kernel in args.kernels for n in (range(9) if kernel=='spmv' and args.spmv_matrix else [args.spmv_nnz])]
  for kernel,spmv_nnz in jobs:
    source=ROOT/'sv/reference/current/kernels'/kernel/'manifest.json'
    m=capture_spmv() if kernel=='spmv' else json.loads(source.read_text())
    if kernel=='spmv':
      assert 0<=spmv_nnz<=8,'This fixture covers nnz 0 through 8.'
      geometry=dict(COLS=4,ROWS=4,CTRL_DEPTH=16,REG_DEPTH=8,GLOBAL_ADDR_W=7,MULTI_ROWS=1,MULTI_COLS=4)
      assert all(m['parameters'][key]==value for key,value in geometry.items()),m['parameters']
      # Only the two compile-time nnz constants change; preserve the YAML map.
      updated=[];count=0
      for raw in m['configuration_packets']:
        v=int(raw,16)
        if (v>>157)&63==13 and (v>>182)&31 in [0,1] and (v>>122)&((1<<35)-1)==68:
          v=(v&~(((1<<35)-1)<<122))|((spmv_nnz*8+4)<<122);count+=1
        updated.append(f'{v:x}')
      assert count==2,count
      m['configuration_packets']=updated
    packets,changes,program,cb,ca=repair(kernel,m,spmv_nnz)
    if kernel=='spmv':
      changes[:0]=[dict(kind='native_opcodes',ULT=102,ULT_CONST=103,AND_CONST=100,OR_CONST=101,PHI_N=104,PHI_START_PRED=105)]
    p=m['parameters']
    if kernel=='gemv':
      expected=[sum((4*i+k+1)*(k+1) for k in range(4)) for i in range(4)]
      memory_base=20
    elif kernel=='gemm':
      expected=[((i*j)%13)+sum(((i*(k+1))%17)*((k*(j+2))%19) for k in range(4)) for i in range(4) for j in range(4)]
      memory_base=32
    else:
      # Check untouched words too, so stray/tail stores cannot pass unnoticed.
      expected=[i+i*i if i<spmv_nnz else i for i in range(32)]
      memory_base=0
    # A return carries the executed ctrl word, even for RET_VOID.
    returns=[encode(c,(p['REG_DEPTH']-1).bit_length()) for prog in program.values() for c in prog.values() if c['op']==[64]]
    assert len(returns)==1,(kernel,returns)
    ret=int(m['expected_packets'][0],16)
    ret=(ret&~(((1<<cb)-1)<<ca))|(returns[0]<<ca)
    changes.append(dict(kind='return_oracle',reason='RetRTL preserves the executed control word in CMD_COMPLETE payload.ctrl; original YAML sink omitted it.'))
    out=args.output_root/kernel
    if kernel=='spmv' and args.spmv_matrix and spmv_nnz!=8:out=out/'scenarios'/f'nnz{spmv_nnz}'
    out.mkdir(parents=True,exist_ok=True)
    files={'program.hex':''.join(f'{v:x}\n' for v in packets),
           'return.hex':f'{ret:x}\n',
           'expected.hex':''.join(f'{memory_base+i} {v:x}\n' for i,v in enumerate(expected))}
    kinds=m['fu_kinds'];fu_bits=sum(v<<(8*i) for i,v in enumerate(kinds))
    flags=[f'-G{k}={v}' for k,v in p.items()]+[f'-GFU_COUNT={len(kinds)}',f"-GFU_KINDS={8*len(kinds)}'h{fu_bits:x}"]
    files['verilator.args']='\n'.join(flags)+'\n'
    for name,data in files.items():(out/name).write_text(data)
    meta=dict(kernel=kernel,status='native_candidate',parameters=p,fu_kinds=kinds,
              source_manifest=str(source.relative_to(ROOT)),
              source_manifest_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              changes=changes,expected_memory_base=memory_base,expected_memory=expected,
              expected_return_packet=f'{ret:x}',
              claim='Native configuration repair/extension; not Python RTL equivalence',
              known_limitations=(['Original workload aliases all arrays at base zero; only identity-index input is used here.',
                                  'Native PHI extensions and compile-time return dependency repair are not Python equivalence.'] if kernel=='spmv' else []),
              fixture_sha256={name:hashlib.sha256(data.encode()).hexdigest() for name,data in files.items()})
    if kernel=='spmv':
      meta['nnz']=spmv_nnz
      meta['yaml_sha256']=hashlib.sha256((ROOT/'validation/test/spmv.yaml').read_bytes()).hexdigest()
    (out/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(f'NATIVE_KERNEL_GENERATED kernel={kernel} packets={len(packets)} changes={len(changes)}')
  if args.spmv_matrix and 'spmv' in args.kernels:spmv_ablations(args.output_root/'spmv')

if __name__=='__main__':main()
