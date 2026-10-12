"""Freeze unchanged current vector combo arithmetic, including source defects."""
import argparse,contextlib,importlib,io,json,random
from pathlib import Path
from current_vector_reduce import ROOT,sha,layout,port,packed
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.fu.vector.VectorAdderComboRTL import VectorAdderComboRTL
from VectorCGRA.fu.vector.VectorMulComboRTL import VectorMulComboRTL
PROFILES=[('add',32,1),('add',32,4),('add',64,8),('mul',32,4),('mul',64,4),('mul',64,8)]
def freeze(root,kind,width,lanes):
 D=mk_data(width,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));T=mk_intra_cgra_pkt(1,1,4,P)
 cls=VectorAdderComboRTL if kind=='add' else VectorMulComboRTL
 m=cls(T,4,2,num_lanes=lanes);m.apply(DefaultPassGroup());ins,outs=layout(D.nbits,C.nbits,P.nbits)
 rng=random.Random(37000+width+lanes+(kind=='mul'));rows=[];labels=[]
 ops=[51,71,53,73,52,72,54,74,0,127] if kind=='add' else [55,75,0,127]
 for n in range(320):
  c=C.from_bits(mk_bits(C.nbits)(rng.getrandbits(C.nbits)));c.operation @= ops[n%len(ops)]
  values={name:rng.getrandbits(w) for name,w in ins}
  values.update(reset=int(n%61==0),clear=int(n%43==0),recv_opt__msg=c,recv_opt__val=int(n<12) or rng.randrange(2))
  if n<12:
   values['recv_in__msg[0]']=D((1<<width)-1,1).to_bits();values['recv_in__msg[1]']=D(1,1).to_bits()
   values['recv_const__msg']=D(1,1).to_bits();values['recv_in__val[0]']=1;values['recv_in__val[1]']=1;values['recv_const__val']=1
  for name,w in ins:
   value=values[name]
   if name=='recv_opt__msg':value=c
   elif '__msg' in name:
    typ=P if name=='recv_from_ctrl_mem__msg' else D
    value=typ.from_bits(mk_bits(typ.nbits)(value))
   signal=port(m,name);signal @= value
  m.sim_eval_combinational();rows.append((packed(m,ins),packed(m,outs)));labels.append(f'op{int(c.operation)}:'+str(n));m.sim_tick()
 d=root/f'{kind}_w{width}_l{lanes}';d.mkdir(parents=True,exist_ok=True)
 (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows))
 (d/'labels.json').write_text(json.dumps(labels,indent=2)+'\n')
 sources=[f'fu/vector/{cls.__name__}.py',f'fu/vector/Vector{"Adder" if kind=="add" else "Mul"}RTL.py',f'fu/vector/test/{cls.__name__}_test.py','lib/messages.py']
 (d/'manifest.json').write_text(json.dumps(dict(kind=kind,parameters=dict(DATA_W=width,LANES=lanes),cycles=len(rows),reset_samples=6,
  inputs=ins,outputs=outs,input_bits=sum(w for _,w in ins),output_bits=sum(w for _,w in outs),
  source_sha256={p:sha(ROOT/p) for p in sources},generator_sha256=sha(Path(__file__)),
  generator_helper_sha256=sha(ROOT/'sv/migration_tools/current_vector_reduce.py'),vectors_sha256=sha(d/'vectors.txt'),
  python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
  notes=['Unmodified Python simulation; complete outputs, including reset, invalid data and originally undriven zeros.',
   'Adder combined-constant carry remains broken; eight-lane multiplier retains only the original four routed lanes.']),indent=2)+'\n')
 print('VECTOR_ARITHMETIC_PYTHON_FROZEN',kind,width,lanes,len(rows))
def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/vector_arithmetic');a=p.parse_args();a.output_root.mkdir(parents=True,exist_ok=True)
 target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
 for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
 for label,name,func in [('add','VectorAdderComboRTL','test_vector_adder_combo'),('mul','VectorMulComboRTL','test_vector_mul_combo')]:
  out=io.StringIO()
  with contextlib.redirect_stdout(out):getattr(importlib.import_module(f'VectorCGRA.fu.vector.test.{name}_test'),func)()
  (a.output_root/f'original_{label}_test.json').write_text(json.dumps(dict(result='passed unmodified with Source/Sink assertions',stdout=out.getvalue()),indent=2)+'\n')
 for kind,width,lanes in PROFILES:freeze(a.output_root,kind,width,lanes)
 print('VECTOR_ARITHMETIC_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
