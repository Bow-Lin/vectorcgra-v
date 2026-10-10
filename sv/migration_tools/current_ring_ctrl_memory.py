"""Freeze unchanged RingMultiCtrlMemDynamicRTL, including its dummy-event defect."""
import argparse
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import random
import subprocess
import sys
import types

ROOT=Path(__file__).resolve().parents[2]
package=types.ModuleType('VectorCGRA')
package.__path__=[str(ROOT)]
sys.modules['VectorCGRA']=package
from pymtl3 import DefaultPassGroup, mk_bits
from VectorCGRA.lib.messages import mk_ctrl, mk_data, mk_cgra_payload, mk_intra_cgra_pkt
from VectorCGRA.mem.ctrl.RingMultiCtrlMemDynamicRTL import RingMultiCtrlMemDynamicRTL

PROFILES=[
  ('original',dict(COLS=2,ROWS=2,DATA_W=16,DATA_ADDR_W=4,CTRL_DEPTH=16,REG_DEPTH=16,
                   NUM_CTRL=12,TOTAL_STEPS=12,FU_INPUTS=2,FU_OUTPUTS=2,TILE_INPUTS=4,TILE_OUTPUTS=4)),
  ('nonpower',dict(COLS=3,ROWS=1,DATA_W=32,DATA_ADDR_W=7,CTRL_DEPTH=6,REG_DEPTH=8,
                   NUM_CTRL=3,TOTAL_STEPS=6,FU_INPUTS=4,FU_OUTPUTS=2,TILE_INPUTS=4,TILE_OUTPUTS=4)),
  ('wide',dict(COLS=1,ROWS=2,DATA_W=64,DATA_ADDR_W=9,CTRL_DEPTH=8,REG_DEPTH=16,
               NUM_CTRL=4,TOTAL_STEPS=5,FU_INPUTS=4,FU_OUTPUTS=2,TILE_INPUTS=8,TILE_OUTPUTS=8)),
  ('single',dict(COLS=1,ROWS=1,DATA_W=32,DATA_ADDR_W=5,CTRL_DEPTH=3,REG_DEPTH=4,
                 NUM_CTRL=2,TOTAL_STEPS=4,FU_INPUTS=1,FU_OUTPUTS=2,TILE_INPUTS=3,TILE_OUTPUTS=5))]


def digest(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def packed(items):
  value=0
  for x,w in items:
    value=(value<<w)|int(x.to_bits() if hasattr(x,'to_bits') else x)
  return value


def types_for(p):
  C=mk_ctrl(p['FU_INPUTS'],p['FU_OUTPUTS'],p['TILE_INPUTS'],p['TILE_OUTPUTS'],p['REG_DEPTH'])
  D=mk_data(p['DATA_W'],1)
  P=mk_cgra_payload(D,mk_bits(p['DATA_ADDR_W']),C,mk_bits((p['CTRL_DEPTH']-1).bit_length()))
  H=mk_intra_cgra_pkt(1,1,p['COLS']*p['ROWS'],P)
  return C,D,P,H


class Trace:
  def __init__(self,p):
    self.p=p
    self.C,self.D,self.P,self.H=types_for(p)
    self.n=p['COLS']*p['ROWS']
    self.rows=[]
    self.stats=dict(ctrl_transfers=[0]*self.n,return_commands={},held_return_changes=0,source_stalls=0)
    self.held=None

  def sample(self,m,label):
    ins=[(m.reset,1),(m.recv_pkt_from_controller.val,1),(m.recv_pkt_from_controller.msg,self.H.nbits),
         (m.send_to_controller_pkt.rdy,1)]+[(x.rdy,1) for x in m.send_ctrl]
    outs=[(m.recv_pkt_from_controller.rdy,1),(m.send_to_controller_pkt.val,1),
          (m.send_to_controller_pkt.msg,self.H.nbits)]
    for x in m.send_ctrl: outs.extend([(x.val,1),(x.msg,self.C.nbits)])
    self.rows.append((packed(ins),packed(outs),label))
    if not int(m.reset):
      for i,x in enumerate(m.send_ctrl): self.stats['ctrl_transfers'][i]+=int(x.val & x.rdy)
      self.stats['source_stalls']+=int(m.recv_pkt_from_controller.val & ~m.recv_pkt_from_controller.rdy)
      port=m.send_to_controller_pkt
      if self.held is not None and (not int(port.val) or self.held != int(port.msg.to_bits())):
        self.stats['held_return_changes']+=1
      if int(port.val & port.rdy):
        cmd=str(int(port.msg.payload.cmd))
        self.stats['return_commands'][cmd]=self.stats['return_commands'].get(cmd,0)+1
      self.held=int(port.msg.to_bits()) if int(port.val & ~port.rdy) else None
    else: self.held=None

  def write(self,root,name,notes):
    d=root/name;d.mkdir(parents=True,exist_ok=True)
    (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o,_ in self.rows))
    (d/'labels.json').write_text(json.dumps([x[2] for x in self.rows],indent=2)+'\n')
    m=dict(parameters=self.p,cycles=len(self.rows),input_bits=self.H.nbits+self.n+3,
      output_bits=self.H.nbits+2+self.n*(self.C.nbits+1),ctrl_bits=self.C.nbits,
      reset_samples=sum(i>>(self.H.nbits+self.n+2) for i,_,_ in self.rows),
      packet_bits=self.H.nbits,stats=self.stats,notes=notes,
      python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
      generator_sha256=digest(Path(__file__)),vectors_sha256=digest(d/'vectors.txt'),
      source_sha256={s:digest(ROOT/s) for s in ('mem/ctrl/RingMultiCtrlMemDynamicRTL.py',
        'mem/ctrl/CtrlMemDynamicRTL.py','mem/ctrl/test/RingCtrlMemDynamicRTL_test.py',
        'lib/messages.py','lib/basic/val_rdy/queues.py')},
      submodule_commits={'noc/PyOCN':subprocess.check_output(
        ['git','-C',str(ROOT/'noc/PyOCN'),'rev-parse','HEAD'],text=True).strip()})
    (d/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    print('RING_CTRL_PYTHON_FROZEN',name,len(self.rows),self.stats,flush=True)


def original(root,p):
  tests=importlib.import_module('VectorCGRA.mem.ctrl.test.RingCtrlMemDynamicRTL_test')
  trace=Trace(p)
  saved=tests.run_sim
  def capture(th,max_cycles=40):
    th.elaborate();th.apply(DefaultPassGroup())
    th.reset @= 1
    for n in range(3):
      th.sim_eval_combinational();trace.sample(th.dut,'original_reset');th.sim_tick()
    th.reset @= 0
    count=0
    while not th.done() and count<max_cycles:
      th.sim_eval_combinational();trace.sample(th.dut,'original_test');th.sim_tick();count+=1
    assert count<max_cycles
    for n in range(3):
      th.sim_eval_combinational();trace.sample(th.dut,'original_drain');th.sim_tick()
    assert trace.stats['ctrl_transfers']==[2]*trace.n
  tests.run_sim=capture
  try: tests.test_Ctrl()
  finally: tests.run_sim=saved
  trace.write(root,'original_test',['Original test stimuli and Source/Sink assertions retained; only runner instrumented.',
    'All cycles and output bits, including reset and invalid messages, are frozen.'])


def synthetic(root,name,p):
  t=Trace(p); C,D,P,H=t.C,t.D,t.P,t.H
  m=RingMultiCtrlMemDynamicRTL(H,P,p['COLS'],p['ROWS'],p['CTRL_DEPTH'],p['FU_INPUTS'],
     p['FU_OUTPUTS'],p['TILE_INPUTS'],p['TILE_OUTPUTS'],p['NUM_CTRL'],p['TOTAL_STEPS'])
  m.apply(DefaultPassGroup())
  rng=random.Random(26000+t.n+p['DATA_W'])
  def tick(label,packet=None,ready=None,host=1,reset=0):
    m.reset @= reset
    m.recv_pkt_from_controller.val @= int(packet is not None)
    m.recv_pkt_from_controller.msg @= H() if packet is None else packet
    m.send_to_controller_pkt.rdy @= host
    for i,port in enumerate(m.send_ctrl): port.rdy @= 0 if ready is None else ready[i]
    m.sim_eval_combinational();t.sample(m,label)
    accept=int(m.recv_pkt_from_controller.val & m.recv_pkt_from_controller.rdy)
    m.sim_tick()
    return accept
  def packet(dst,cmd,addr=0,data=0,control=None):
    return H(t.n,dst,0,0,0,0,0,0,0,0,P(cmd,D(data,1,1,1),0,C() if control is None else control,addr))
  def send(label,pkt):
    for n in range(300):
      if tick(label,pkt): return
    raise AssertionError('source timeout '+label)
  for _ in range(3):tick('reset',reset=1)
  for node in range(t.n):
    for slot in (1,2):
      word=C.from_bits(mk_bits(C.nbits)(rng.getrandbits(C.nbits)))
      word.operation=2+slot
      send('configure_full_word',packet(node,3,slot,control=word))
    for cmd,value in [(8,2),(9,1),(7,5)]:send('bounds_and_budget',packet(node,cmd,data=value))
    send('fu_prologue',packet(node,4,1,data=1))
    side=C();side.routing_xbar_outport[0]=3;side.fu_xbar_outport[0]=1
    for cmd in (5,6):send('unexposed_crossbar_prologue',packet(node,cmd,1,2,side))
    for cmd in (1,22,16,43):send('accepted_unexposed_command',packet(node,cmd,data=3))
  for node in range(t.n):send('launch',packet(node,0))
  for n in range(260):
    tick('execution_and_dummy_events',ready=[int(n%5 != i%5) for i in range(t.n)],host=int(n>=70 and n%4!=1))
  assert t.stats['ctrl_transfers']==[5]*t.n,t.stats
  assert t.stats['return_commands'].get('0',0)>10,t.stats
  assert t.stats['return_commands'].get('14',0)==0,t.stats
  before=list(t.stats['ctrl_transfers'])
  # Terminate clears the budget but preserves PC and program; set PC explicitly.
  send('terminate',packet(0,2))
  send('restart_lower',packet(0,9,data=1))
  send('restart_total',packet(0,7,data=3))
  send('resume',packet(0,15))
  for n in range(90):tick('resumed',ready=[1]*t.n,host=int(n%3!=0))
  assert t.stats['ctrl_transfers'][0]==before[0]+3,t.stats
  # A reset cancels queued traffic and run state; program contents persist.
  for _ in range(3):tick('midstream_reset',reset=1)
  for _ in range(24):tick('reset_drain',ready=[1]*t.n)
  # Controller self-addressed packets bypass memories; exercise every payload bit.
  selfword=C.from_bits(mk_bits(C.nbits)(rng.getrandbits(C.nbits)))
  send('controller_loopback',packet(t.n,12,data=(1<<(p['DATA_W']-1))|123,control=selfword))
  for _ in range(30):tick('loopback_drain',ready=[1]*t.n)
  assert t.stats['return_commands'].get('12',0)==1
  t.write(root,name,['Unmodified Python wrapper; no adapter or monkey-patch of hardware.',
    'Dummy zero events starve COMPLETE despite exactly five retired controls per node.',
    'Runtime reset preserves program storage; cancels ring traffic and execution metadata.'])


def main():
  parser=argparse.ArgumentParser()
  parser.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/ring_ctrl_memory')
  args=parser.parse_args()
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items():assert digest(ROOT/path)==h,path
  original(args.output_root,PROFILES[0][1])
  for name,p in PROFILES:synthetic(args.output_root,name,p)
  print('RING_CTRL_SOURCE_GUARD_PASS',len(target['source_sha256']))


if __name__=='__main__':main()
