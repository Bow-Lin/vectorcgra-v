"""Capture unchanged DataMemRTL, including its lazy-preload/write latch defects."""
import argparse
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import random
import sys
import types

ROOT=Path(__file__).resolve().parents[2]
package=types.ModuleType('VectorCGRA'); package.__path__=[str(ROOT)]
sys.modules['VectorCGRA']=package
from pymtl3 import DefaultPassGroup, mk_bits
from VectorCGRA.lib.messages import mk_data
from VectorCGRA.mem.data.DataMemRTL import DataMemRTL

PROFILES=[('original',19,20,1,1,True,True),('multi',35,5,3,2,True,False),
          ('wide',67,3,2,3,False,False)]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def packed(items):
  value=0
  for x,w in items: value=(value<<w)|int(x.to_bits() if hasattr(x,'to_bits') else x)
  return value

def word(bits,i,original):
  return (i<<3)|4 if original else (1<<(bits-1))|(0x12345+i*0x913)

class Trace:
  def __init__(self,profile):
    self.name,self.bits,self.depth,self.rd,self.wr,self.preload,self.original=profile
    self.aw=(self.depth-1).bit_length();self.rows=[]
  def sample(self,m,label):
    ins=[(m.reset,1)];outs=[]
    for a,d in zip(m.recv_raddr,m.send_rdata):
      ins.extend([(a.msg,self.aw),(a.val,1),(d.rdy,1)])
      outs.extend([(a.rdy,1),(d.val,1),(d.msg,self.bits)])
    for a,d in zip(m.recv_waddr,m.recv_wdata):
      ins.extend([(a.msg,self.aw),(a.val,1),(d.msg,self.bits),(d.val,1)])
      outs.extend([(a.rdy,1),(d.rdy,1)])
    self.rows.append((packed(ins),packed(outs),label))
  def write(self,root):
    d=root/self.name;d.mkdir(parents=True,exist_ok=True)
    (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o,_ in self.rows))
    (d/'labels.json').write_text(json.dumps([x[2] for x in self.rows],indent=2)+'\n')
    ib=1+self.rd*(self.aw+2)+self.wr*(self.aw+self.bits+2)
    manifest=dict(parameters=dict(DATA_BITS=self.bits,DEPTH=self.depth,RD_PORTS=self.rd,
      WR_PORTS=self.wr,PRELOAD_ENABLE=int(self.preload),ORIGINAL=int(self.original)),
      cycles=len(self.rows),input_bits=ib,output_bits=self.rd*(self.bits+2)+2*self.wr,
      reset_samples=sum(i>>(ib-1) for i,_,_ in self.rows),
      python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
      source_sha256={p:digest(ROOT/p) for p in ['mem/data/DataMemRTL.py','lib/messages.py',
        'mem/data/test/DataMemRTL_test.py']},generator_sha256=digest(Path(__file__)),
      vectors_sha256=digest(d/'vectors.txt'),
      notes=['Original Python behavior, including invalid outputs and ignored reset.',
        'Preload reads write even with val=0; write-enable latches when address valid falls.',
        'Synthetic traffic intentionally separates address/data and changes stalled reads to expose source behavior.'])
    (d/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('DATA_MEM_PYTHON_FROZEN',self.name,len(self.rows),flush=True)

def original(root,profile):
  tests=importlib.import_module('VectorCGRA.mem.data.test.DataMemRTL_test')
  trace=Trace(profile);saved=tests.run_sim
  def capture(th,max_cycles=10):
    th.elaborate();th.apply(DefaultPassGroup())
    th.reset @= 1
    for n in range(3):
      th.sim_eval_combinational();trace.sample(th.dataMem,'original_reset');th.sim_tick()
    th.reset @= 0
    count=0
    while not th.done() and count<max_cycles:
      th.sim_eval_combinational();trace.sample(th.dataMem,'original_source_sink');th.sim_tick();count+=1
    assert count<max_cycles
    for n in range(3):
      th.sim_eval_combinational();trace.sample(th.dataMem,'original_drain');th.sim_tick()
  try:
    tests.run_sim=capture
    with contextlib.redirect_stdout(io.StringIO()): tests.test_const_queue()
  finally: tests.run_sim=saved
  trace.write(root)

def synthetic(root,profile):
  t=Trace(profile);D=mk_data(t.bits-3,1);B=mk_bits(t.bits)
  m=DataMemRTL(D,t.depth,t.rd,t.wr,
    [D.from_bits(B(word(t.bits,i,t.original))) for i in range(t.depth)] if t.preload else None)
  m.apply(DefaultPassGroup());rng=random.Random(27100+t.bits)
  def tick(label,reads=None,writes=None,reset=0):
    m.reset @= reset
    for i in range(t.rd):
      a,v,r=reads[i] if reads else (0,0,0)
      m.recv_raddr[i].msg @= a;m.recv_raddr[i].val @= v;m.send_rdata[i].rdy @= r
    for i in range(t.wr):
      a,av,d,dv=writes[i] if writes else (0,0,0,0)
      m.recv_waddr[i].msg @= a;m.recv_waddr[i].val @= av
      m.recv_wdata[i].msg @= D.from_bits(B(d));m.recv_wdata[i].val @= dv
    m.sim_eval_combinational();t.sample(m,label);m.sim_tick()
  tick('reset',reset=1)
  tick('invalid_read_overwrites_new_write',writes=[(0,1,0x55,1)]*t.wr)
  tick('observe_preload_collision',reads=[(0,1,1)]*t.rd)
  tick('prime_write_latches',writes=[(1,1,0x88+i,1) for i in range(t.wr)])
  tick('last_port_wins',reads=[(1,1,0)]*t.rd,
    writes=[(1,1,0xaa,1)]+[(0,0,0,0)]*(t.wr-1))
  tick('unpaired_address',writes=[(2,1,0xdd,0)]*t.wr)
  tick('unpaired_data',writes=[(2,0,0xee,1)]*t.wr)
  tick('reset_ignored',reset=1,reads=[(1,1,1)]*t.rd)
  for n in range(240):
    tick('mixed:'+str(n),[(rng.randrange(t.depth),rng.randrange(2),rng.randrange(2)) for _ in range(t.rd)],
      [(rng.randrange(t.depth),rng.randrange(2),rng.getrandbits(t.bits),rng.randrange(2)) for _ in range(t.wr)],
      reset=int(n%31==0))
  t.write(root)

def main():
  p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/data_memory')
  args=p.parse_args();args.output_root.mkdir(parents=True,exist_ok=True)
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items(): assert digest(ROOT/path)==h,path
  original(args.output_root,PROFILES[0])
  for profile in PROFILES[1:]: synthetic(args.output_root,profile)
  try: DataMemRTL(mk_data(32,1),1).apply(DefaultPassGroup())
  except AssertionError as e:
    (args.output_root/'python_boundaries.json').write_text(json.dumps(dict(
      single_word_depth='rejected by original mk_bits(clog2(1))',exception=type(e).__name__,
      source_guard_count=len(target['source_sha256']),original_test='passed with original Source/Sink assertions'),indent=2)+'\n')
  else: raise AssertionError('single-word Python boundary changed')
  print('DATA_MEM_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__': main()
