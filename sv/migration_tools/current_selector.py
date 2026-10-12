"""Capture unmodified SelectorRTL, including retained ready on unselected ports."""
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
p=types.ModuleType('VectorCGRA');p.__path__=[str(ROOT)];sys.modules['VectorCGRA']=p
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data
from VectorCGRA.noc.SelectorRTL import SelectorRTL

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pack(items):
  v=0
  for x,w in items:v=(v<<w)|int(x.to_bits() if hasattr(x,'to_bits') else x)
  return v

def freeze(root,bits,count):
  D=mk_data(bits-3,1);B=mk_bits(bits);m=SelectorRTL(D,count)
  m.apply(DefaultPassGroup());rng=random.Random(31000+bits+count);rows=[]
  for n in range(320):
    m.reset @= int(n%53==0);m.send.rdy @= int(n%3!=1);m.recv_from @= n%count
    for i in range(count):
      m.recv[i].val @= (n>>i)&1;m.recv[i].msg @= D.from_bits(B(rng.getrandbits(bits)))
    m.sim_eval_combinational()
    ins=[(m.reset,1),(m.send.rdy,1),(m.recv_from,(count-1).bit_length())]
    outs=[(m.send.val,1),(m.send.msg,bits)]
    for x in m.recv:ins.extend([(x.val,1),(x.msg,bits)]);outs.append((x.rdy,1))
    rows.append((pack(ins),pack(outs)));m.sim_tick()
  d=root/f'b{bits}_n{count}';d.mkdir(parents=True,exist_ok=True)
  (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows))
  (d/'manifest.json').write_text(json.dumps(dict(parameters=dict(DATA_BITS=bits,NUM_INPUTS=count),
    cycles=len(rows),input_bits=2+(count-1).bit_length()+count*(bits+1),output_bits=1+bits+count,
    reset_samples=7,source_sha256={p:sha(ROOT/p) for p in ['noc/SelectorRTL.py','noc/test/SelectorRTL_test.py','lib/messages.py']},
    generator_sha256=sha(Path(__file__)),vectors_sha256=sha(d/'vectors.txt'),
    python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
    notes=['Changing selection retains ready on previously selected ports, including reset cycles.',
      'Every output bit compared, including invalid message fields; synthetic selection changes expose source latch behavior.']),indent=2)+'\n')
  print('SELECTOR_PYTHON_FROZEN',bits,count,len(rows))

def main():
  p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/selector')
  a=p.parse_args();a.output_root.mkdir(parents=True,exist_ok=True)
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
  out=io.StringIO()
  with contextlib.redirect_stdout(out):importlib.import_module('VectorCGRA.noc.test.SelectorRTL_test').test_simple()
  (a.output_root/'original_test.json').write_text(json.dumps(dict(result='passed unmodified with Source/Sink assertions',stdout=out.getvalue()),indent=2)+'\n')
  for b,n in [(19,3),(35,5),(67,8)]:freeze(a.output_root,b,n)
  try:SelectorRTL(mk_data(32,1),1).apply(DefaultPassGroup())
  except AssertionError:
    (a.output_root/'python_boundary.json').write_text(json.dumps(dict(single_input='Original mk_bits(clog2(1)) rejects Bits0; native SV supports one input.',pinned_python_files=len(target['source_sha256'])),indent=2)+'\n')
  else:raise AssertionError('original single-input boundary changed')
  print('SELECTOR_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
