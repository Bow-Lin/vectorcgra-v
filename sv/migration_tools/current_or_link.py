"""Freeze the unchanged N-input OrLink, including OR of invalid input words."""
import argparse,contextlib,hashlib,importlib,io,json,random,sys,types
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=types.ModuleType('VectorCGRA');p.__path__=[str(ROOT)];sys.modules['VectorCGRA']=p
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data
from VectorCGRA.noc.OrLinkRTL import OrLinkRTL

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pack(items):
  v=0
  for x,w in items:v=(v<<w)|int(x.to_bits() if hasattr(x,'to_bits') else x)
  return v

def freeze(root,width,count):
  D=mk_data(width,1);B=mk_bits(D.nbits);m=OrLinkRTL(D,count,width)
  m.apply(DefaultPassGroup());rng=random.Random(30000+width+count);rows=[]
  for n in range(320):
    m.reset @= int(n%53==0);m.send.rdy @= n&1
    for i in range(count):
      m.recv[i].val @= (n>>i)&1
      m.recv[i].msg @= D.from_bits(B(rng.getrandbits(D.nbits)))
    m.sim_eval_combinational()
    ins=[(m.reset,1),(m.send.rdy,1)]
    outs=[(m.send.val,1),(m.send.msg,D.nbits)]
    for x in m.recv:ins.extend([(x.val,1),(x.msg,D.nbits)]);outs.append((x.rdy,1))
    rows.append((pack(ins),pack(outs)));m.sim_tick()
  d=root/f'w{width}_n{count}';d.mkdir(parents=True,exist_ok=True)
  (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows))
  (d/'manifest.json').write_text(json.dumps(dict(parameters=dict(DATA_W=width,NUM_INPUTS=count),
    cycles=len(rows),input_bits=2+count*(D.nbits+1),output_bits=1+D.nbits+count,reset_samples=7,
    notes=['All input payloads and predicates are ORed regardless of their valid bits.',
      'All-invalid output is zero; bypass/delay outputs zero; ready broadcasts even during reset.'],
    source_sha256={p:sha(ROOT/p) for p in ['noc/OrLinkRTL.py','noc/test/OrLinkRTL_test.py','lib/messages.py']},
    generator_sha256=sha(Path(__file__)),vectors_sha256=sha(d/'vectors.txt'),
    python_target='cd7aad878915e389cecf8cc01ff6987d156bd019'),indent=2)+'\n')
  print('OR_LINK_PYTHON_FROZEN',width,count,len(rows))

def main():
  p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/or_link')
  a=p.parse_args();a.output_root.mkdir(parents=True,exist_ok=True)
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
  stream=io.StringIO()
  with contextlib.redirect_stdout(stream):importlib.import_module('VectorCGRA.noc.test.OrLinkRTL_test').test_simple()
  (a.output_root/'original_test.txt').write_text(stream.getvalue())
  for w,n in [(16,3),(32,5),(64,8)]:freeze(a.output_root,w,n)
  try:OrLinkRTL(mk_data(32,1),1,32).apply(DefaultPassGroup())
  except AssertionError:
    (a.output_root/'python_boundary.json').write_text(json.dumps(dict(single_input='Original unused mk_bits(clog2(1)) rejects Bits0; SV supports this degenerate case.',
      original_test='passed unmodified with Source/Sink assertions',pinned_python_files=len(target['source_sha256'])),indent=2)+'\n')
  else:raise AssertionError('original single-input boundary changed')
  print('OR_LINK_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
