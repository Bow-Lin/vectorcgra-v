"""Freeze the pinned project's PipeQueueRTL, including reset-cycle data writes."""
import argparse
import hashlib
import json
from pathlib import Path
import random
import sys
import types
ROOT=Path(__file__).resolve().parents[2]
p=types.ModuleType('VectorCGRA');p.__path__=[str(ROOT)];sys.modules['VectorCGRA']=p
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.basic.val_rdy.queues import PipeQueueRTL

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pack(items):
  v=0
  for x,w in items:v=(v<<w)|int(x)
  return v

def freeze(root,bits,depth):
  m=PipeQueueRTL(mk_bits(bits),depth);m.apply(DefaultPassGroup())
  rng=random.Random(32000+bits+depth);rows=[];labels=[];cw=depth.bit_length()
  def tick(label,valid=0,msg=0,ready=0,reset=0):
    m.reset @= reset;m.recv.val @= valid;m.recv.msg @= msg;m.send.rdy @= ready
    m.sim_eval_combinational()
    ins=pack([(m.reset,1),(m.recv.val,1),(m.recv.msg,bits),(m.send.rdy,1)])
    outs=pack([(m.recv.rdy,1),(m.send.val,1),(m.send.msg,bits),(m.count,cw)])
    rows.append((ins,outs));labels.append(label);m.sim_tick()
  tick('reset_with_valid',1,0x55,1,1)
  tick('empty_after_reset')
  for n in range(depth):tick('fill',1,n+1,0)
  for n in range(5):tick('full_replace',1,0x80+n,1)
  for n in range(3):tick('stall',1,0x99,0)
  tick('release_stall',1,0x99,1)
  for n in range(300):tick('random:'+str(n),rng.randrange(2),rng.getrandbits(bits),rng.randrange(2),int(n%37==0))
  d=root/f'b{bits}_d{depth}';d.mkdir(parents=True,exist_ok=True)
  (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows))
  (d/'labels.json').write_text(json.dumps(labels,indent=2)+'\n')
  (d/'manifest.json').write_text(json.dumps(dict(parameters=dict(DATA_BITS=bits,DEPTH=depth),
    cycles=len(rows),input_bits=bits+3,output_bits=bits+cw+2,reset_samples=10,
    source_sha256={'lib/basic/val_rdy/queues.py':sha(ROOT/'lib/basic/val_rdy/queues.py')},
    generator_sha256=sha(Path(__file__)),vectors_sha256=sha(d/'vectors.txt'),
    python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
    notes=['Original queue implementation; full simultaneous pop/push does not create a bubble.',
      'All outputs compared, including invalid payload and reset-cycle ready/data writes.',
      'No standalone project PipeQueue test was found; these traces drive the original model directly.']),indent=2)+'\n')
  print('PIPE_QUEUE_PYTHON_FROZEN',bits,depth,len(rows))

def main():
  p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/pipe_queue')
  a=p.parse_args();a.output_root.mkdir(parents=True,exist_ok=True)
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
  for b,d in [(8,1),(35,2),(67,3),(19,5)]:freeze(a.output_root,b,d)
  try:PipeQueueRTL(mk_bits(35),0).apply(DefaultPassGroup())
  except AssertionError:
    (a.output_root/'python_boundary.json').write_text(json.dumps(dict(zero_depth='rejected by original Python',pinned_python_files=len(target['source_sha256'])),indent=2)+'\n')
  else:raise AssertionError('zero-depth boundary changed')
  print('PIPE_QUEUE_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
