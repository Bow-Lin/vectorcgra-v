"""Migration-only fixture generation from pinned, unmodified Python. Never used by native regressions."""
import sys, importlib, json, random, hashlib, types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'sv/reference/current'
sys.path.insert(0, str(ROOT/'sv/migration_tools'))
package = types.ModuleType('VectorCGRA')
package.__path__ = [str(ROOT)]
sys.modules['VectorCGRA'] = package
target = json.loads((OUT/'target.json').read_text())
for path, expected in target['source_sha256'].items():
  if hashlib.sha256((ROOT/path).read_bytes()).hexdigest() != expected:
    raise RuntimeError('Frozen Python target changed: '+path)
from pymtl3 import DefaultPassGroup, mk_bits
from phase3_scalar_vectors import fields, port, pack, outputs

catalog = {
 'Adder': ('fu.single.AdderRTL','AdderRTL','tile_adder'),
 'Mul': ('fu.single.MulRTL','MulRTL','tile_multiplier'),
 'Mem': ('fu.single.MemUnitRTL','MemUnitRTL','tile_memory_fu'),
 'Grant': ('fu.single.GrantRTL','GrantRTL','scalar_grant'),
 'Shifter': ('fu.single.ShifterRTL','ShifterRTL','scalar_shifter'),
 'Gep': ('fu.single.GepRTL','GepRTL','scalar_gep'),
 'Comp': ('fu.single.CompRTL','CompRTL','scalar_comp'),
 'VectorMul': ('fu.vector.VectorMulComboRTL','VectorMulComboRTL','tile_vector_mul_combo'),
}
def types(package):
 m = importlib.import_module(package+'.lib.messages')
 D=m.mk_data(32,1); C=m.mk_ctrl(4,2,4,4,16)
 P=m.mk_cgra_payload(D,mk_bits(7),C,mk_bits(3))
 return D,C,P,m.mk_intra_cgra_pkt(1,1,4,P)

D,C,P,T=types('VectorCGRA')
ins,outs=fields(D.nbits,C.nbits,P.nbits,3)
cases=[]
def case(label, code=0, addr=0, a=9,b=3,c=2, p0=1,p1=1, reset=0,clear=0, rdy=1,vals=15):
 ctrl=C(); ctrl.operation=mk_bits(7)(code)
 for i in range(4): ctrl.fu_in[i]=mk_bits(3)(i+1)
 v={'clear':clear,'reset':reset,'ctrl_addr_inport':addr,
    'from_mem_rdata__msg':D(23,1),'from_mem_rdata__val':1,
    'recv_const__msg':D(c,1),'recv_const__val':1,
    'recv_from_ctrl_mem__msg':P(),'recv_from_ctrl_mem__val':0,
    'recv_opt__msg':ctrl,'recv_opt__val':1,
    'send_out__rdy[0]':rdy,'send_out__rdy[1]':rdy,
    'send_to_ctrl_mem__rdy':1,'to_mem_raddr__rdy':1,'to_mem_waddr__rdy':1,'to_mem_wdata__rdy':1}
 for i,value in enumerate([a,b,7,11]):
  v[f'recv_in__msg[{i}]']=D(value, p0 if i==0 else p1 if i==1 else 1)
  v[f'recv_in__val[{i}]']=(vals>>i)&1
 cases.append((label,v))
case('initial_reset',reset=1)
case('grant_slot0_first',47,addr=0)
case('grant_slot1_first',47,addr=1)
case('reset_after_grant',reset=1)
case('grant_once_const_current',88,c=17)
case('left_shift_const_current',96,a=3,c=2)
case('store_pred00',13,p0=0,p1=0,a=4,b=99)
case('store_pred01',13,p0=0,p1=1,a=4,b=99)
case('store_pred10',13,p0=1,p1=0,a=4,b=99)
case('store_pred11',13,p0=1,p1=1,a=4,b=40)
case('GEP_current_code',92,a=9,b=3)
case('GTE_CONST_current_code',90,a=9,c=2)
case('GT_CONST_current_code',97,a=9,c=2)
case('LT_CONST_current_code',98,a=1,c=2)
case('vector_mul_known_python_hdl_split',75,a=256,b=256)
case('sub_const_ready_shared_defect',36,a=9,b=3,c=2)
case('grant_clear',reset=1)
case('grant_const_blocked',88,addr=2,c=53,rdy=0)
case('grant_const_accept',88,addr=2,c=53)
case('grant_const_repeat',88,addr=2,c=71)
case('grant_const_other_slot',88,addr=3,c=97)
case('grant_const_clear',88,addr=3,clear=1)
case('grant_const_after_clear',88,addr=3,c=101)
case('gep_stride_config',reset=1)
cases[-1][1]['recv_from_ctrl_mem__msg'] = P(cmd=mk_bits(6)(43),data=D(13,1))
cases[-1][1]['recv_from_ctrl_mem__val'] = 1
case('gep_stride_write')
cases[-1][1]['recv_from_ctrl_mem__msg'] = P(cmd=mk_bits(6)(43),data=D(13,1))
cases[-1][1]['recv_from_ctrl_mem__val'] = 1
case('gep_2d_after_config',94,a=9,b=3)
case('gep_2d_const_after_config',95,a=9,b=3,c=7)
rng=random.Random(413072)
for n in range(512):
 code=rng.choice([0,1,2,3,4,5,6,7,13,25,29,36,47,55,75,*range(88,102)])
 case(f'random{n}',code,addr=rng.randrange(8),a=rng.getrandbits(32),b=rng.getrandbits(32),c=rng.randrange(33),p0=rng.randrange(2),p1=rng.randrange(2),rdy=rng.randrange(2),vals=rng.randrange(16),reset=int(n%97==0),clear=int(n%59==0))

python_results={}
for package in ['VectorCGRA']:
 d,c,p,t=types(package)
 results={}
 for name,(path,cls,sv) in catalog.items():
  model=getattr(importlib.import_module(package+'.'+path),cls)(t,4,2)
  model.apply(DefaultPassGroup())
  records=[]; packed=[]
  for label,values in cases:
   for field,width in ins:
    signal=port(model,field); value=values[field]
    if hasattr(value,'to_bits'):
     value=type(signal).from_bits(value.to_bits()) if hasattr(signal,'from_bits') else value.to_bits()
    signal @= value
   model.sim_eval_combinational()
   records.append({n:int(port(model,n).to_bits() if hasattr(port(model,n),'to_bits') else port(model,n)) for n,w in outs})
   packed.append(outputs(model,outs))
   model.sim_tick()
  results[name]=records
  (OUT/f'{package}_{name}.hex').write_text(''.join(f'{v:076x}\n' for v in packed))
 python_results[package]=results
 print('PYTHON_PROBE',package,len(cases),'cycles',flush=True)
(OUT/'inputs.hex').write_text(''.join(f'{pack(v,ins):0130x}\n' for _,v in cases))
(OUT/'python.json').write_text(json.dumps({'labels':[l for l,_ in cases], 'results':python_results},indent=2))


(OUT/'cases.json').write_text(json.dumps({'cycles':len(cases),'input_bits':sum(w for _,w in ins),'output_bits':sum(w for _,w in outs),'labels':[l for l,_ in cases]},indent=2)+'\n')
