"""Freeze original Python divider and LoopControl behavior without changing project sources."""
import argparse,contextlib,importlib,io,json,os,random
from pathlib import Path
from current_vector_reduce import ROOT,sha,layout,port,packed
from pymtl3 import DefaultPassGroup,mk_bits
from pymtl3.stdlib.test_utils import config_model_with_cmdline_opts
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
PROFILES=[('div',16,1),('div',32,1),('div',64,1),('inclusive',32,1),('inclusive',32,2),('inclusive',32,3),('inclusive',32,4),('exclusive',32,1),('exclusive',32,3),('exclusive',32,4),('loop',32,1),('loop',64,1)]
CLASSES={'div':'DivRTL','inclusive':'InclusiveDivRTL','exclusive':'ExclusiveDivRTL','loop':'LoopControlRTL'}
def zero_probe(root):
 from VectorCGRA.fu.single.DivRTL import DivRTL
 D=mk_data(32,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));T=mk_intra_cgra_pkt(1,1,4,P)
 results=[]
 for opcode in [26,65]:
  m=DivRTL(T,4,2);m.apply(DefaultPassGroup());m.sim_reset()
  c=C();c.operation @= opcode;c.fu_in[0] @= 1;c.fu_in[1] @= 2
  m.recv_opt.msg @= c;m.recv_opt.val @= 1
  m.recv_in[0].msg @= D(13,1);m.recv_in[1].msg @= D(0,1)
  m.recv_in[0].val @= 1;m.recv_in[1].val @= 1
  m.recv_const.msg @= D(0,1);m.recv_const.val @= 1;m.send_out[0].rdy @= 1
  try:m.sim_eval_combinational()
  except ZeroDivisionError:results.append(dict(opcode=opcode,result='ZeroDivisionError'))
  else:raise AssertionError(f'Original division-by-zero behavior changed: {opcode}')
 (root/'original_divide_zero.json').write_text(json.dumps(dict(cases=results,source_sha256=sha(ROOT/'fu/single/DivRTL.py')),indent=2)+'\n')
def original_tests(root):
 for name in CLASSES.values():
  m=importlib.import_module(f'VectorCGRA.fu.single.test.{name}_test');out=io.StringIO()
  with contextlib.redirect_stdout(out):
   if name=='DivRTL':
    for a in range(5,8):
     for b in range(2,4):m.test_div0(a,b)
   elif name=='LoopControlRTL':
    m.test_loop_control_basic();m.test_loop_control_step();m.test_loop_control_nested()
   else:m.test_mul()
  (root/f'original_{name}_test.json').write_text(json.dumps(dict(result='passed unmodified Source/Sink assertions',cases=6 if name=='DivRTL' else 3 if name=='LoopControlRTL' else 1,stdout=out.getvalue()),indent=2)+'\n')
def freeze(root,kind,width,latency):
 name=CLASSES[kind];cls=getattr(importlib.import_module(f'VectorCGRA.fu.single.{name}'),name)
 D=mk_data(width,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));T=mk_intra_cgra_pkt(1,1,4,P)
 m=cls(T,4,2,latency=latency) if kind in ['inclusive','exclusive'] else cls(T,4,2)
 m=config_model_with_cmdline_opts(m,{},[]);m.apply(DefaultPassGroup());ins,outs=layout(D.nbits,C.nbits,P.nbits)
 rng=random.Random(91000+width+latency+len(kind));rows=[];labels=[]
 ops={'div':[26,65,0,127],'inclusive':[48,59,49,15,0,127],'exclusive':[26,44,0,127],'loop':[83,0,127]}[kind]
 for n in range(360):
  c=C.from_bits(mk_bits(C.nbits)(rng.getrandbits(C.nbits)));c.operation @= ops[(n//7)%len(ops)]
  for i in range(4):c.fu_in[i] @= 1+((n//11+i)%4)
  values={s:rng.getrandbits(w) for s,w in ins}
  values.update(reset=int(n%61==0),clear=int(n%47==0),recv_opt__msg=c,recv_opt__val=int(n%13!=5))
  for i in range(4):
   v=D(rng.getrandbits(width) or 1,rng.randrange(2));values[f'recv_in__msg[{i}]']=v.to_bits();values[f'recv_in__val[{i}]']=int(n%17 not in [6,7])
  values['recv_const__msg']=D(rng.getrandbits(width) or 1,rng.randrange(2)).to_bits()
  values['send_out__rdy[0]']=int(n%19 not in [6,7,8,9,10]);values['recv_const__val']=int(n%23!=5)
  for s,w in ins:
   value=values[s]
   if s=='recv_opt__msg':value=c
   elif '__msg' in s:
    typ=P if s=='recv_from_ctrl_mem__msg' else D;value=typ.from_bits(mk_bits(typ.nbits)(value))
   signal=port(m,s);signal @= value
  m.sim_eval_combinational();rows.append((packed(m,ins),packed(m,outs)));labels.append(f'op{int(c.operation)}:sample{n}');m.sim_tick()
 d=root/f'{kind}_w{width}_l{latency}';d.mkdir(parents=True,exist_ok=True)
 (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows));(d/'labels.json').write_text(json.dumps(labels,indent=2)+'\n')
 paths=[f'fu/single/{name}.py',f'fu/single/test/{name}_test.py','fu/basic/Fu.py','lib/messages.py']
 if kind in ['inclusive','exclusive']:paths.append('fu/single/division.v')
 (d/'manifest.json').write_text(json.dumps(dict(kind=kind,parameters=dict(DATA_W=width,LATENCY=latency),cycles=len(rows),reset_samples=6,
  inputs=ins,outputs=outs,input_bits=sum(w for _,w in ins),output_bits=sum(w for _,w in outs),source_sha256={p:sha(ROOT/p) for p in paths},
  generator_sha256=sha(Path(__file__)),helper_sha256=sha(ROOT/'sv/migration_tools/current_vector_reduce.py'),vectors_sha256=sha(d/'vectors.txt'),
  python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',notes=['Original Python behavior; InclusiveDiv/ExclusiveDiv import original division.v with Verilator 4.036.',
   'All outputs including invalid data/reset compared. Divisors are nonzero; zero is separately a native contract.',
   'Legacy latency-three pipeline deliberately retains missing restoring iterations.']),indent=2)+'\n')
 print('ARITHMETIC_PYTHON_FROZEN',kind,width,latency,len(rows))
def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,required=True);a=p.parse_args();root=a.output_root.resolve();root.mkdir(parents=True,exist_ok=True)
 target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
 for p,h in target['source_sha256'].items():assert sha(ROOT/p)==h,p
 original_tests(root);zero_probe(root)
 for kind,width,latency in PROFILES:freeze(root,kind,width,latency)
 print('ARITHMETIC_PYTHON_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
