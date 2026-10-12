"""Freeze all outputs of unchanged current VectorAllReduceRTL, including defects."""
import argparse
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import random
import re
import sys
import types
ROOT=Path(__file__).resolve().parents[2]
p=types.ModuleType('VectorCGRA');p.__path__=[str(ROOT)];sys.modules['VectorCGRA']=p
from pymtl3 import DefaultPassGroup,mk_bits
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
from VectorCGRA.fu.vector.VectorAllReduceRTL import VectorAllReduceRTL

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def layout(db,cb,pb):
  ins=[('clear',1),('reset',1),('ctrl_addr_inport',3),('from_mem_rdata__msg',db),('from_mem_rdata__val',1),
    ('recv_const__msg',db),('recv_const__val',1),('recv_from_ctrl_mem__msg',pb),('recv_from_ctrl_mem__val',1)]
  ins.extend((f'recv_in__msg[{i}]',db) for i in range(4))
  ins.extend((f'recv_in__val[{i}]',1) for i in range(4))
  ins.extend([('recv_opt__msg',cb),('recv_opt__val',1),('send_out__rdy[0]',1),('send_out__rdy[1]',1)])
  ins.extend((n,1) for n in ['send_to_ctrl_mem__rdy','to_mem_raddr__rdy','to_mem_waddr__rdy','to_mem_wdata__rdy'])
  outs=[(n,1) for n in ['from_mem_rdata__rdy','recv_const__rdy','recv_from_ctrl_mem__rdy']]
  outs.extend((f'recv_in__rdy[{i}]',1) for i in range(4));outs.append(('recv_opt__rdy',1))
  outs.extend((f'send_out__msg[{i}]',db) for i in range(2));outs.extend((f'send_out__val[{i}]',1) for i in range(2))
  outs.extend([('send_to_ctrl_mem__msg',pb),('send_to_ctrl_mem__val',1),('to_mem_raddr__msg',7),('to_mem_raddr__val',1),
    ('to_mem_waddr__msg',7),('to_mem_waddr__val',1),('to_mem_wdata__msg',db),('to_mem_wdata__val',1)])
  return ins,outs

def port(m,name):
  r=re.fullmatch(r'(\w+)__(\w+)(?:\[(\d+)\])?',name)
  if not r:return getattr(m,name)
  obj=getattr(m,r[1]);return getattr(obj[int(r[3])] if r[3] is not None else obj,r[2])

def packed(m,fields):
  v=0
  for n,w in fields:
    x=port(m,n);v=(v<<w)|int(x.to_bits() if hasattr(x,'to_bits') else x)
  return v

def freeze(root,width,lanes):
  D=mk_data(width,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3))
  T=mk_intra_cgra_pkt(1,1,4,P);m=VectorAllReduceRTL(T,4,2,num_lanes=lanes)
  m.apply(DefaultPassGroup());ins,outs=layout(D.nbits,C.nbits,P.nbits);rows=[];labels=[]
  rng=random.Random(33000+width+lanes)
  def tick(label,op=0,cv=0,vals=0,ready=0,request_ready=0,response_valid=0,reset=0,clear=0):
    c=C.from_bits(mk_bits(C.nbits)(rng.getrandbits(C.nbits)));c.operation @= op
    values={n:rng.getrandbits(w) for n,w in ins}
    values.update(clear=clear,reset=reset,recv_opt__msg=c,recv_opt__val=cv,
      recv_from_ctrl_mem__val=response_valid,send_to_ctrl_mem__rdy=request_ready)
    for i in range(4):values[f'recv_in__val[{i}]']=(vals>>i)&1
    for i in range(2):values[f'send_out__rdy[{i}]']=ready
    for n,w in ins:
      value=values[n]
      if n=='recv_opt__msg':value=c
      elif '__msg' in n:
        typ=P if n=='recv_from_ctrl_mem__msg' else D
        value=typ.from_bits(mk_bits(typ.nbits)(value))
      signal=port(m,n);signal @= value
    m.sim_eval_combinational();rows.append((packed(m,ins),packed(m,outs)));labels.append(label);m.sim_tick()
  tick('initial_reset',reset=1)
  tick('invalid_control_base_request',op=78,cv=0,vals=3,request_ready=1)
  tick('reset_after_spurious_request',reset=1)
  tick('global_mul_uses_add_result',op=77,cv=1,vals=1,request_ready=1)
  tick('response_stall',op=77,cv=1,vals=1,response_valid=1)
  tick('control_retires_without_response',op=77,cv=1,vals=1,ready=1)
  tick('reset',reset=1)
  tick('base_request',op=78,cv=1,vals=3,request_ready=1)
  tick('duplicate_base_request',op=78,cv=1,vals=3,request_ready=1)
  tick('clear_ignored',op=78,cv=1,vals=3,response_valid=1,clear=1)
  for n in range(350):
    tick('mixed:'+str(n),op=[56,57,68,69,76,77,78,79,0,127][n%10],cv=rng.randrange(2),vals=rng.randrange(16),
      ready=rng.randrange(2),request_ready=rng.randrange(2),response_valid=rng.randrange(2),reset=int(n%59==0),clear=int(n%43==0))
  d=root/f'w{width}_l{lanes}';d.mkdir(parents=True,exist_ok=True)
  (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in rows))
  (d/'labels.json').write_text(json.dumps(labels,indent=2)+'\n')
  (d/'manifest.json').write_text(json.dumps(dict(parameters=dict(DATA_W=width,LANES=lanes),cycles=len(rows),
    inputs=ins,outputs=outs,input_bits=sum(w for _,w in ins),output_bits=sum(w for _,w in outs),
    reset_samples=sum(label in ['initial_reset','reset_after_spurious_request','reset'] or
      label.startswith('mixed:') and int(label.split(':')[1])%59==0 for label in labels),
    source_sha256={p:sha(ROOT/p) for p in ['fu/vector/VectorAllReduceRTL.py','fu/basic/SumUnit.py',
      'fu/basic/ReduceMulUnit.py','fu/vector/test/VectorAllReduceRTL_test.py','lib/messages.py']},
    generator_sha256=sha(Path(__file__)),vectors_sha256=sha(d/'vectors.txt'),
    python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
    notes=['Unmodified current model, all outputs including originally undriven zero fields and reset samples.',
      'Synthetic traffic exposes missing global guards, zero global product, missing base ready, premature retirement and ignored clear.']),indent=2)+'\n')
  print('VECTOR_REDUCE_PYTHON_FROZEN',width,lanes,len(rows),sum(w for _,w in outs))

def main():
  p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/vector_reduce')
  a=p.parse_args();a.output_root.mkdir(parents=True,exist_ok=True)
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
  out=io.StringIO()
  with contextlib.redirect_stdout(out):importlib.import_module('VectorCGRA.fu.vector.test.VectorAllReduceRTL_test').test_vector_all_reduce()
  (a.output_root/'original_test.json').write_text(json.dumps(dict(result='passed unmodified with Source/Sink assertions',
    note='Original test uses 16-bit data and a 2-input/1-output control type; public SV profile exposes 4 inputs and 2 outputs.',stdout=out.getvalue()),indent=2)+'\n')
  for w,l in [(16,4),(32,4),(32,8),(64,8)]:freeze(a.output_root,w,l)
  print('VECTOR_REDUCE_SOURCE_GUARD_PASS',len(target['source_sha256']))
if __name__=='__main__':main()
