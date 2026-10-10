"""Freeze current YAML programs and unmodified Python system traces.

Migration-only: normal SV regressions read the resulting text files directly.
The original test harness and SinkRTL assertions remain active.
"""
import argparse
import contextlib
import hashlib
import importlib
import json
from pathlib import Path
import signal
import sys
import traceback
import types

ROOT = Path(__file__).resolve().parents[2]
pkg = types.ModuleType('VectorCGRA')
pkg.__path__ = [str(ROOT)]
sys.modules['VectorCGRA'] = pkg
from pymtl3 import DefaultPassGroup

KINDS = dict(AdderRTL=0, MulRTL=1, MemUnitRTL=2, NahRTL=3, ConstRTL=4,
             CompRTL=5, LogicRTL=6, ShifterRTL=7, SelRTL=8, PhiRTL=9,
             GrantRTL=10, GepRTL=11, ExtractPredicateRTL=12, RetRTL=13,
             VectorAllReduceRTL=21, VectorAdderComboRTL=19, VectorMulComboRTL=20,
             DivRTL=16, InclusiveDivRTL=17, ExclusiveDivRTL=18,
             SeqMulAdderRTL=22, SeqMulShifterRTL=23, PrlMulAdderRTL=24,
             ThreeMulAdderShifterRTL=25, FourIncCmpNotGrantRTL=26,
             FpAddRTL=28, FpMulRTL=29)

def bits(v):
  return int(v.to_bits() if hasattr(v, 'to_bits') else v)

def main():
  ap = argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--kernel', required=True, choices=['axpy','fir4x4','gemm','gemv','histogram','relu4x4','sad','spmv'])
  ap.add_argument('--max-cycles', type=int, default=3000)
  ap.add_argument('--wall-seconds', type=int, default=1800,
                  help='Bound expensive reference elaboration/simulation; incomplete traces never pass')
  ap.add_argument('--output-dir', type=Path,
                  help='Record a diagnostic run elsewhere without replacing frozen fixtures')
  a = ap.parse_args()
  target = json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for name, expected in target['source_sha256'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected, name
  out = a.output_dir.resolve() if a.output_dir else ROOT/'sv/reference/current/kernels'/a.kernel
  out.mkdir(parents=True, exist_ok=True)
  mod = importlib.import_module(f'VectorCGRA.cgra.test.CgraRTL_{a.kernel}_test_from_yaml')
  info = dict(kernel=a.kernel, python_commit=target['python_target_commit'], status='recording', events=[])
  (out/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
  rows = []

  def run(th, **driver_options):
    args = th._dsl.args
    params = dict(COLS=args[5], ROWS=args[6], CTRL_DEPTH=args[7], GLOBAL_ADDR_W=(args[8]-1).bit_length(),
                  BANK_DEPTH=args[9], NUM_BANKS=args[10], REG_DEPTH=args[11], NUM_CTRL=args[13],
                  TOTAL_STEPS=args[14], MEM_COMBINATIONAL=int(args[15]), MULTI_ROWS=args[19], MULTI_COLS=args[20])
    info.update(parameters=params, fu_kinds=[KINDS[f.__name__] for f in args[2]],
                configuration_packets=[f'{bits(p):x}' for p in args[12]],
                expected_packets=[f'{bits(p):x}' for p in args[18]],
                query_packets=[f'{bits(p):x}' for p in args[21]])
    (out/'program.hex').write_text(''.join(f'{bits(p):x}\n' for p in args[12]))
    (out/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    print(f'CURRENT_KERNEL_ELABORATING kernel={a.kernel}',file=sys.__stdout__,flush=True)
    th.apply(DefaultPassGroup())
    d = th.dut
    ins=[]; outs=[]
    def scalar(layout, name, getter):
      value=getter(); width=(value.to_bits() if hasattr(value,'to_bits') else value).nbits
      layout.append((name,width,getter))
    scalar(ins,'reset',lambda:th.reset)
    for name in ['cgra_id','address_lower','address_upper']:
      scalar(ins,name,lambda name=name:getattr(d,name))
    for direction in ['north','south','west','east']:
      for base in ['recv_data_on_boundary_','send_data_on_boundary_']:
        for i,p in enumerate(getattr(d,base+direction)):
          for field in ['msg','val','rdy']:
            incoming=(base.startswith('recv') and field!='rdy') or (base.startswith('send') and field=='rdy')
            scalar(ins if incoming else outs,base+direction+'__'+field+f'[{i}]',lambda p=p,field=field:getattr(p,field))
    for name in ['recv_from_cpu_pkt','send_to_cpu_pkt','recv_from_inter_cgra_noc','send_to_inter_cgra_noc']:
      p=getattr(d,name)
      for field in ['msg','val','rdy']:
        incoming=(name.startswith('recv') and field!='rdy') or (name.startswith('send') and field=='rdy')
        scalar(ins if incoming else outs,name+'__'+field,lambda p=p,field=field:getattr(p,field))
    info.update(inputs=[(n,w) for n,w,g in ins], outputs=[(n,w) for n,w,g in outs])
    def pack(layout):
      v=0
      for n,w,g in layout: v=(v<<w)|bits(g())
      return f'{v:0{(sum(w for n,w,g in layout)+3)//4}x}'
    events=info['events']
    for cycle in range(a.max_cycles):
      if cycle%100==0:
        print(f'CURRENT_KERNEL_RECORDING kernel={a.kernel} cycle={cycle}',file=sys.__stdout__,flush=True)
      th.reset @= int(cycle<3)
      th.sim_eval_combinational()
      rows.append(pack(ins)+' '+pack(outs))
      if d.send_to_cpu_pkt.val and d.send_to_cpu_pkt.rdy:
        events.append(dict(cycle=cycle,packet=f'{bits(d.send_to_cpu_pkt.msg):x}'))
      th.sim_tick()
      if cycle>=3 and th.done():
        info.update(status='passed', cycles=len(rows), events=events)
        break
    else:
      raise RuntimeError(f'Python kernel {a.kernel} did not complete in {a.max_cycles} cycles')

  # Replace only the simulation driver/logging, never RTL, configuration or sinks.
  mod.run_sim=run
  mod.config_model_with_cmdline_opts=lambda th,*args,**kwargs:th
  mod.init_trace_logger=lambda *args,**kwargs:None
  mod.close_trace_logger=lambda:None
  def wall_timeout(signum, frame):
    raise TimeoutError(f'Python reference exceeded {a.wall_seconds} wall seconds')
  signal.signal(signal.SIGALRM, wall_timeout)
  signal.alarm(a.wall_seconds)
  try:
    test=next(f for n,f in vars(mod).items() if n.startswith('test_homogeneous_'))
    with (out/'generation.log').open('w') as log, contextlib.redirect_stdout(log): test({})
  except BaseException as exc:
    info.update(status='incomplete' if isinstance(exc,(TimeoutError,KeyboardInterrupt)) else 'failed',
                error=traceback.format_exc())
    raise
  finally:
    signal.alarm(0)
    info['cycles']=len(rows)
    (out/'cycles.txt').write_text('\n'.join(rows)+'\n')
    info['trace_sha256']=hashlib.sha256((out/'cycles.txt').read_bytes()).hexdigest()
    (out/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
  print(f'CURRENT_KERNEL_PYTHON_PASS kernel={a.kernel} cycles={len(rows)}',flush=True)

if __name__=='__main__':
  main()
