"""Freeze the unmodified ac96 real dynamic-FIR system test as raw cycle replay.

This is one-time migration evidence, not an implementation or daily build input.
The original SourceRTL/SinkRTL and configuration lists are used without edits.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback

from reference_model import ROOT, BASELINE, type_schema
from pymtl3 import DefaultPassGroup
from VectorCGRA.multi_cgra.test.MultiCgraRTL_migration_test import initialize_test_harness


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
  path.write_text(json.dumps(value, indent=2)+'\n', newline='\n')


def bits(value):
  return int(value.to_bits() if hasattr(value, 'to_bits') else value)


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--label', default='dynamic_fir')
  ap.add_argument('--max-cycles', type=int, default=450)
  a=ap.parse_args()
  out=ROOT/'sv/reference/phase4/migration'/a.label
  if out.exists():ap.error('Frozen evidence directory exists; select a new label')
  out.mkdir(parents=True)
  (out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  git=lambda *args: subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  assert not changed, changed
  start=time.monotonic()
  info=dict(label=a.label, baseline_commit=BASELINE, oracle='unmodified Python full system and original test harness',
    reference_test='multi_cgra/test/MultiCgraRTL_migration_test.py::test_multi_CGRA_fir_scalar_dynamic_migration',
    exporter_sha256=sha(__file__), hdl_equivalence=False, status='recording')
  events=[];rows=[]
  try:
    th=initialize_test_harness({},num_tile_ports=8,per_cgra_topology='KingMesh',
      test_name='test_fir_scalar_dynamic_migration')
    args=th._dsl.args
    Host=args[3]
    info.update(parameters=dict(DATA_W=32,COLS=2,ROWS=2,MULTI_COLS=2,MULTI_ROWS=2,TILE_PORTS=8,
      CTRL_DEPTH=args[8],GLOBAL_ADDR_W=7,BANK_DEPTH=args[10],NUM_BANKS=args[11],REG_DEPTH=args[12],
      NUM_CTRL=args[15],TOTAL_STEPS=args[16],TILE_VARIANT=1),host=type_schema(Host),
      fu_list=[f.__name__ for f in args[2]],fu_kinds=[0,1,6,7,9,5,10,2,8,13,22,26,20,19],
      configuration_packets=[f'{bits(p):0{(Host.nbits+3)//4}x}' for p in args[13]],
      original_expected_packets=[f'{bits(p):0{(Host.nbits+3)//4}x}' for p in args[20]],
      independent_math=dict(expression='3 + sum((10+i)*(12+i) for i in range(2,10))',
        expected=3+sum((10+i)*(12+i) for i in range(2,10))))
    save(out/'manifest.json',info)
    print('ELABORATING dynamic FIR',flush=True)
    th.apply(DefaultPassGroup())
    d=th.dut
    inputs=[('reset',1,lambda: th.reset,'reset'),
      ('host_recv_msg',Host.nbits,lambda:d.recv_from_cpu_pkt.msg,'recv_from_cpu_pkt__msg'),
      ('host_recv_val',1,lambda:d.recv_from_cpu_pkt.val,'recv_from_cpu_pkt__val'),
      ('host_send_rdy',1,lambda:d.send_to_cpu_pkt.rdy,'send_to_cpu_pkt__rdy')]
    outputs=[('host_recv_rdy',1,lambda:d.recv_from_cpu_pkt.rdy,'recv_from_cpu_pkt__rdy'),
      ('host_send_msg',Host.nbits,lambda:d.send_to_cpu_pkt.msg,'send_to_cpu_pkt__msg'),
      ('host_send_val',1,lambda:d.send_to_cpu_pkt.val,'send_to_cpu_pkt__val')]
    for c in range(4):
      for direction in ['north','south','west','east']:
        for p in range(2):
          port=getattr(d.cgra[c],'send_data_on_boundary_'+direction)[p]
          for field,width in [('msg',35),('val',1),('rdy',1)]:
            outputs.append((f'cgra{c}_{direction}{p}_{field}',width,
              lambda port=port,field=field:getattr(port,field),f'dut.send_{direction}_{field}[{c}][{p}]'))
      for direction,member in [('recv','recv_from_inter_cgra_noc'),('send','send_to_inter_cgra_noc')]:
        port=getattr(d.cgra[c],member)
        for field,width in [('msg',port.msg.to_bits().nbits),('val',1),('rdy',1)]:
          # Network recv is CGRA send, and vice versa.
          native='send' if direction=='recv' else 'recv'
          outputs.append((f'cgra{c}_noc_{direction}_{field}',width,
            lambda port=port,field=field:getattr(port,field),f'dut.noc_{native}_{field}[{c}]'))
      for t in range(4):
        context=d.cgra[c].tile[t].context_switch
        prefix=f'dut.cgras[{c}].cgra.tiles[{t}].context_tile.tile.core.context_switch'
        for field,width in [('progress_reg',35),('status_reg',2),('phi_addr_reg',4)]:
          outputs.append((f'cgra{c}_tile{t}_{field}',width,
            lambda context=context,field=field:getattr(context,field),prefix+'.'+field))
    def pack(fields):
      value=0
      for _,width,get,_ in fields:value=(value<<width)|bits(get())
      return value
    def schema(fields):return [dict(name=n,width=w,sv=sv) for n,w,_,sv in fields]
    info.update(inputs=schema(inputs),outputs=schema(outputs))
    save(out/'manifest.json',info)
    sent=received=0;done=None;last_progress={};link_counts={};context_events=[]
    trace=(out/'cycles.txt').open('w',newline='\n')
    input_width=sum(w for _,w,_,_ in inputs);output_width=sum(w for _,w,_,_ in outputs)
    for local in range(-3,a.max_cycles):
      th.reset @= local<0
      th.sim_eval_combinational()
      row=len(rows)
      line=f'{pack(inputs):0{(input_width+3)//4}x} {pack(outputs):0{(output_width+3)//4}x}'
      trace.write(line+'\n');rows.append(line)
      if local>=0:
        if d.recv_from_cpu_pkt.val and d.recv_from_cpu_pkt.rdy:
          p=d.recv_from_cpu_pkt.msg;sent+=1
          events.append(dict(cycle=row,event='host-input',cmd=int(p.payload.cmd),cgra=int(p.dst_cgra_id),tile=int(p.dst)))
        if d.send_to_cpu_pkt.val and d.send_to_cpu_pkt.rdy:
          p=d.send_to_cpu_pkt.msg;received+=1
          assert int(p.payload.cmd)==14 and int(p.payload.data.payload)==2215 and int(p.payload.data.predicate)==1
          assert int(p.src_cgra_id)==2 and int(p.src)==1 and int(p.dst)==4
          events.append(dict(cycle=row,event='complete',result=int(p.payload.data.payload),src_cgra=int(p.src_cgra_id),src_tile=int(p.src)))
        for c in range(4):
          for direction in ['north','south','west','east']:
            for p in range(2):
              port=getattr(d.cgra[c],'send_data_on_boundary_'+direction)[p]
              if port.val and port.rdy:
                key=f'{c}.{direction}.{p}';link_counts[key]=link_counts.get(key,0)+1
                events.append(dict(cycle=row,event='boundary',link=key,data=bits(port.msg)))
          for t in range(4):
            context=d.cgra[c].tile[t].context_switch
            progress=bits(context.progress_reg);key=(c,t)
            if progress!=last_progress.get(key,0):
              context_events.append(dict(cycle=row,cgra=c,tile=t,progress=progress,
                status=bits(context.status_reg),overwrite=bits(context.overwrite_fu_outport.msg),overwrite_val=int(context.overwrite_fu_outport.val)))
            last_progress[key]=progress
            if context.is_resuming and context.overwrite_fu_outport.val:
              context_events.append(dict(cycle=row,cgra=c,tile=t,event='resume-overwrite',progress=progress,
                data=bits(context.overwrite_fu_outport.msg)))
        if th.done():
          if done is None:done=local
          if local>=done+8:
            th.sim_tick();break
      if local%25==0:
        trace.flush();print(f'FIR cycle={local} sent={sent} received={received} seconds={time.monotonic()-start:.1f}',flush=True)
      th.sim_tick()
    else:raise RuntimeError(f'Original kernel timeout sent={sent}, received={received}')
    trace.close()
    assert sent==len(args[13]) and received==1 and th.done()
    assert link_counts,'No inter-CGRA physical boundary communication'
    assert all(any(e['cgra']==0 and e['tile']==t and e.get('event')=='resume-overwrite' and e['progress']!=0 for e in context_events) for t in (0,3)),context_events
    info.update(status='recorded',cycles=len(rows),input_bits=input_width,output_bits=output_width,
      events=events,context_events=context_events,physical_link_counts=link_counts,host_inputs=sent,completions=received,
      seconds=time.monotonic()-start,trace_sha256=sha(out/'cycles.txt'))
    print(f'PYTHON_DYNAMIC_FIR_PASS cycles={len(rows)} result=2215 physical_links={link_counts}',flush=True)
  except Exception:
    info.update(status='failed',failure=traceback.format_exc(),cycles_recorded=len(rows),seconds=time.monotonic()-start)
    (out/'failure.txt').write_text(info['failure'],newline='\n')
    raise
  finally:
    info['source_sha256']={Path(m.__file__).resolve().relative_to(ROOT).as_posix():sha(m.__file__)
      for m in list(sys.modules.values()) if getattr(m,'__file__',None) and Path(m.__file__).suffix=='.py' and Path(m.__file__).resolve().is_relative_to(ROOT)}
    save(out/'manifest.json',info)


if __name__=='__main__':main()
