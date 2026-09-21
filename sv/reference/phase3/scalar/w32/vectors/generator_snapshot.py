"""Freeze original ac96 Python FU cycle oracles; not part of SV daily builds."""
import argparse
import importlib
import importlib.util
import json
import random
import re
from collections import Counter
from pathlib import Path
from phase3_scalar_export import ROOT, BASELINE, MODULES, sha, write


def fields(db, cb, pb, ca):
  ins = [('clear',1),('reset',1),('ctrl_addr_inport',ca),
         ('from_mem_rdata__msg',db),('from_mem_rdata__val',1),
         ('recv_const__msg',db),('recv_const__val',1),
         ('recv_from_ctrl_mem__msg',pb),('recv_from_ctrl_mem__val',1)]
  ins += [(f'recv_in__msg[{i}]',db) for i in range(4)]
  ins += [(f'recv_in__val[{i}]',1) for i in range(4)]
  ins += [('recv_opt__msg',cb),('recv_opt__val',1)]
  ins += [(f'send_out__rdy[{i}]',1) for i in range(2)]
  ins += [(n,1) for n in ('send_to_ctrl_mem__rdy','to_mem_raddr__rdy','to_mem_waddr__rdy','to_mem_wdata__rdy')]
  outs = [(n,1) for n in ('from_mem_rdata__rdy','recv_const__rdy','recv_from_ctrl_mem__rdy')]
  outs += [(f'recv_in__rdy[{i}]',1) for i in range(4)]
  outs += [('recv_opt__rdy',1)]
  outs += [(f'send_out__msg[{i}]',db) for i in range(2)]
  outs += [(f'send_out__val[{i}]',1) for i in range(2)]
  outs += [('send_to_ctrl_mem__msg',pb),('send_to_ctrl_mem__val',1),
           ('to_mem_raddr__msg',7),('to_mem_raddr__val',1),
           ('to_mem_waddr__msg',7),('to_mem_waddr__val',1),
           ('to_mem_wdata__msg',db),('to_mem_wdata__val',1)]
  return ins, outs


def port(model, name):
  m = re.fullmatch(r'(\w+)__(\w+)(?:\[(\d+)\])?',name)
  if not m:
    return getattr(model,name)
  base, member, index = m.groups()
  obj = getattr(model,base)
  return getattr(obj[int(index)] if index is not None else obj,member)


def pack(values, layout):
  result = 0
  for name,width in layout:
    v = values[name]
    result = (result << width) | int(v.to_bits() if hasattr(v,'to_bits') else v)
  return result


def outputs(model,layout):
  return pack({n:port(model,n) for n,w in layout},layout)


def main():
  from pymtl3 import DefaultPassGroup, mk_bits, clog2
  from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt
  import VectorCGRA.lib.opt_type as opt
  import VectorCGRA.lib.cmd_type as cmd
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--profile',choices=['w32','w64'],required=True)
  ap.add_argument('--seed',type=int,default=93481)
  args=ap.parse_args()
  directory=ROOT/'sv/reference/phase3/scalar'/args.profile
  manifest=json.loads((directory/'manifest.json').read_text())
  p=manifest['parameters']; dw=p['DATA_W']; cd=p['CTRL_DEPTH']; rd=p['REG_DEPTH']
  Data=mk_data(dw,1); Ctrl=mk_ctrl(4,2,4,4,rd)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(clog2(cd)))
  Packet=mk_intra_cgra_pkt(1,1,4,Payload)
  ins,outs=fields(Data.nbits,Ctrl.nbits,Payload.nbits,clog2(cd))
  models={}; adapted={}; source_hashes={}
  for name in MODULES[:-2]:
    cls=getattr(importlib.import_module(f'VectorCGRA.fu.single.{name}RTL'),name+'RTL')
    models[name]=cls(Packet,4,2); models[name].apply(DefaultPassGroup())
    source_hashes[f'fu/single/{name}RTL.py']=sha(ROOT/f'fu/single/{name}RTL.py')
    adapter=directory/name/'translation_adapter.py'
    if adapter.exists():
      spec=importlib.util.spec_from_file_location(f'VectorCGRA.fu.single._oracle_{name}_{args.profile}',adapter)
      module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
      adapted[name]=getattr(module,name+'RTL')(Packet,4,2)
      adapted[name].apply(DefaultPassGroup())
      source_hashes[adapter.relative_to(ROOT).as_posix()]=sha(adapter)
  rng=random.Random(args.seed); mask=(1<<dw)-1
  codes=sorted({int(v) for r in manifest['modules'] for v in r['operations'].values()} | {0,127})
  cmds=[0,cmd.CMD_CONFIG_GEP_STRIDE,cmd.CMD_CONFIG_LOOP_LOWER,cmd.CMD_CONFIG_LOOP_UPPER,
        cmd.CMD_CONFIG_LOOP_STEP,cmd.CMD_UPDATE_COUNTER_SHADOW_VALUE,cmd.CMD_RESET_LEAF_COUNTER]
  cases=[]
  # Begin with reset, then execute every operation under ready/predicate combinations.
  for code in codes:
    for variation in range(32):
      cases.append(dict(code=code,variation=variation,phase='operations'))
  # Consecutive operations cover vector replay and stateful per-address contexts.
  for addr in range(cd):
    for code in [int(opt.OPT_PHI_CONST),int(opt.OPT_GRT_ONCE),int(opt.OPT_RET),int(opt.OPT_RET_VOID)]:
      for k in range(12): cases.append(dict(code=code,addr=addr,variation=k,phase='stateful'))
  # Pipeline-specific known operands; inclusive input stage then output stage.
  for code in [int(opt.OPT_DIV_INCLUSIVE_START),int(opt.OPT_DIV_INCLUSIVE_END),int(opt.OPT_REM_INCLUSIVE_START),int(opt.OPT_REM_INCLUSIVE_END),int(opt.OPT_DIV),int(opt.OPT_REM)]:
    for k in range(16): cases.append(dict(code=code,variation=k,phase='division'))
  # Independent counter programme: bounds 2..8 step2, shadow and reset.
  for addr in [0,cd-1]:
    for c,v in [(cmd.CMD_CONFIG_LOOP_LOWER,2),(cmd.CMD_CONFIG_LOOP_UPPER,8),(cmd.CMD_CONFIG_LOOP_STEP,2)]:
      cases.append(dict(code=0,addr=addr,command=c,command_data=v,variation=0,phase='counter_config'))
    for k in range(8): cases.append(dict(code=int(opt.OPT_LOOP_COUNT),addr=addr,variation=k,phase='counter_count'))
    cases.append(dict(code=0,addr=addr,command=cmd.CMD_UPDATE_COUNTER_SHADOW_VALUE,command_data=91,variation=0,phase='counter_config'))
    cases.append(dict(code=int(opt.OPT_LOOP_DELIVERY),addr=addr,variation=0,phase='counter_shadow'))
    cases.append(dict(code=0,addr=addr,command=cmd.CMD_RESET_LEAF_COUNTER,command_data=0,variation=0,phase='counter_config'))
    cases.append(dict(code=int(opt.OPT_LOOP_COUNT),addr=addr,variation=0,phase='counter_reset'))
  for k in range(1024): cases.append(dict(code=rng.choice(codes),variation=k,phase='random'))
  cases=[dict(code=0,variation=0,phase='initial_reset') for _ in range(3)]+cases
  inputs=[]; traces={n:[] for n in models}; coverage=Counter(); checks=Counter(); details=[]
  boundaries=[0,1,2,3,7,31,32,63,64,mask,(1<<(dw-1)),(1<<(dw-1))-1]
  for cycle,case in enumerate(cases):
    k=case['variation']; phase=case['phase']; code=case['code']
    rand=phase=='random'; directed=phase in ('division','counter_config','counter_count','counter_shadow','counter_reset')
    ctrl=Ctrl(); ctrl.operation=code
    ctrl.fu_in=[1,2,3,4] if directed or not rand else [rng.randrange(8) for _ in range(4)]
    ctrl.vector_factor_power=0 if directed else ((k//4)%8)
    ctrl.is_last_ctrl=0 if directed else (k%2)
    # Random non-FU control bits are retained in sideband return messages.
    if rand:
      ctrl.routing_xbar_outport=[rng.randrange(16) for _ in range(8)]
      ctrl.fu_xbar_outport=[rng.randrange(4) for _ in range(8)]
    ctrl=Ctrl(ctrl.operation,[mk_bits(3)(v) for v in ctrl.fu_in],
              [mk_bits(4)(v) for v in ctrl.routing_xbar_outport],
              [mk_bits(2)(v) for v in ctrl.fu_xbar_outport],
              ctrl.vector_factor_power,ctrl.is_last_ctrl)
    vals={n:0 for n,w in ins}
    vals.update(clear=int((rand and k%131==0) or (phase=='stateful' and k==0)),
                reset=int(phase=='initial_reset' or (rand and k%257==0)),
                ctrl_addr_inport=case.get('addr',cycle%cd),
                recv_opt__msg=ctrl,recv_opt__val=int(directed or k%8!=7),
                recv_const__msg=Data(7 if directed else boundaries[(k+2)%len(boundaries)],1 if directed else k%2,k%2,(k//2)%2),
                recv_const__val=int(directed or k%5!=4),from_mem_rdata__msg=Data(29,1,1,1),from_mem_rdata__val=k%2)
    command=case.get('command',cmds[(k//3)%len(cmds)])
    command_data=case.get('command_data',(k*3+5)&mask)
    vals['recv_from_ctrl_mem__msg']=Payload(command,Data(command_data,1,k%2,(k//2)%2),cycle%128,ctrl,case.get('addr',cycle%cd))
    vals['recv_from_ctrl_mem__val']=int('command' in case or (not directed and k%3==0))
    for i in range(4):
      value=[50,7,3,1][i] if directed else boundaries[(k+i)%len(boundaries)]
      # Any selector may alias any input. Div Python reads payload even when val=0.
      if code==int(opt.OPT_DIV) and value==0: value=1
      vals[f'recv_in__msg[{i}]']=Data(value,1 if directed else (k//(i+1))%2,(k+i)%2,(k//2+i)%2)
      vals[f'recv_in__val[{i}]']=int(directed or (k+i)%7!=6)
    for i in range(2): vals[f'send_out__rdy[{i}]']=int(directed or (k+i)%4!=3)
    for n in ('send_to_ctrl_mem__rdy','to_mem_raddr__rdy','to_mem_waddr__rdy','to_mem_wdata__rdy'):
      vals[n]=int(directed or k%4!=2)
    if code==int(opt.OPT_DIV_CONST) and int(vals['recv_const__msg'].payload)==0:
      vals['recv_const__msg'].payload=mk_bits(dw)(1)
    for name,model in list(models.items())+[(n+'_adapted',m) for n,m in adapted.items()]:
      for signal,value in vals.items():
        target=port(model,signal); target @= value
      model.sim_eval_combinational()
    for name,model in models.items():
      got=outputs(model,outs); traces[name].append(got)
      if name in adapted:
        assert got==outputs(adapted[name],outs),(name,cycle,'adapter changed original Python outputs')
        checks[name+'_adapter_cycles']+=1
    # Arithmetic oracle uses Python integers independently of native/translated HDL.
    if vals['recv_opt__val']:
      a=int(vals['recv_in__msg[0]'].payload); b=int(vals['recv_in__msg[1]'].payload)
      if ctrl.fu_in==[1,2,3,4] and code==int(opt.OPT_DIV):
        assert int(models['Div'].send_out[0].msg.payload)==a//b
        checks['division_unsigned_math']+=1
    if phase=='counter_shadow':
      assert int(models['LoopCounter'].send_out[0].msg.payload)==91
      assert int(models['LoopCounter'].send_out[0].val)==1
      checks['counter_shadow_math']+=1
    if phase=='counter_reset':
      assert int(models['LoopCounter'].send_out[0].msg.payload)==2
      checks['counter_reset_math']+=1
    if phase=='counter_count':
      assert int(models['LoopCounter'].send_out[0].msg.payload)==min(2+2*k,8)
      assert int(models['LoopCounter'].send_out[0].msg.predicate)==int(k<3)
      checks['counter_sequence_math']+=1
    inputs.append(pack(vals,ins)); coverage[f'op_{code}']+=1; coverage[phase]+=1
    for label,v in [('reset',vals['reset']),('clear',vals['clear']),('invalid_ctrl',not vals['recv_opt__val']),('backpressure',not vals['send_out__rdy[0]'])]:
      coverage[label]+=int(v)
    details.append(dict(cycle=cycle,phase=phase,code=code,variation=k))
    for model in list(models.values())+list(adapted.values()): model.sim_tick()
  out=directory/'vectors'; out.mkdir(exist_ok=True)
  def hexfile(path,values,width): write(path,''.join(f'{v:0{(width+3)//4}x}\n' for v in values))
  ib=sum(w for n,w in ins); ob=sum(w for n,w in outs)
  hexfile(out/'inputs.hex',inputs,ib)
  for name,values in traces.items(): hexfile(out/(name+'.hex'),values,ob)
  write(out/'cases.json',json.dumps(details,indent=2)+'\n')
  write(out/'generator_snapshot.py',Path(__file__).read_text())
  source_hashes['sv/migration_tools/phase3_scalar_vectors.py']=sha(Path(__file__))
  result=dict(baseline_commit=BASELINE,profile=args.profile,seed=args.seed,cycles=len(cases),input_bits=ib,output_bits=ob,
              input_layout=ins,output_layout=outs,coverage=dict(coverage),independent_checks=dict(checks),
              source_sha256=source_hashes,files_sha256={p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'},
              compare='All raw output bits before each rising edge, including invalid messages; original Python vs isolated adapter Python checked in same run.',
              undefined_domains=['Combinational Div division by zero excluded: original Python raises ZeroDivisionError.',
                'Pipeline dividers require external Verilog placeholder and are checked HDL-vs-HDL with separate mathematical tests, not claimed Python simulated.',
                'Two-state simulation only; original incompletely assigned/latch signals retained.'])
  write(out/'manifest.json',json.dumps(result,indent=2)+'\n')
  print(f'SCALAR_PYTHON_PASS profile={args.profile} modules={len(models)} cycles={len(cases)} output_bits={ob} adapters={len(adapted)} checks={dict(checks)}',flush=True)


if __name__=='__main__': main()
