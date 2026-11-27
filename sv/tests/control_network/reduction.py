#!/usr/bin/env python3
"""Host-configured global add/multiply: real PE requests and Controller replies."""
import argparse
import copy
import importlib.util
import json
import math
import time
import re
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('control_system',HERE/'system.py')
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


def workload(config,multiply,multicast,base=1):
  p=config['parameters'];ports=p['TILE_PORTS'];active=[0,1,2];capacity=p['BANK_DEPTH']*p['NUM_BANKS']
  initial=[0x12340000+i*19 for i in range(capacity)]
  vectors=[sum((t+lane+base)<<(8*lane) for lane in range(4)) for t in active]
  local=[math.prod(t+lane+base for lane in range(4)) if multiply else sum(t+lane+base for lane in range(4)) for t in active]
  answer=(math.prod(local) if multiply else sum(local))&0xffffffff
  steps=[dict(kind='preload',address=0,values=initial),
      dict(kind='command',cmd='GLOBAL_REDUCE_COUNT',data=len(active))]
  config_writes=[]
  for t,vector in zip(active,vectors):
    words=[dict(operation='CONST',fu_in=[1,2,3,4],write_reg_from={'0':2},write_reg_idx={'0':0},fu_xbar_outport={str(ports):1}),
      dict(operation='VEC_REDUCE_MUL_GLOBAL' if multiply else 'VEC_REDUCE_ADD_GLOBAL',fu_in=[1,2,3,4],
        read_reg_towards={'0':1},read_reg_idx={'0':0},write_reg_from={'0':2},write_reg_idx={'0':1},fu_xbar_outport={str(ports):1}),
      dict(operation='STR_CONST',fu_in=[1,2,3,4],read_reg_towards={'0':1},read_reg_idx={'0':1})]
    steps += [dict(kind='constants',tile=t,values=[vector,t]),
      dict(kind='command',tile=t,cmd='CONFIG_COUNT_PER_ITER',data=3),
      dict(kind='command',tile=t,cmd='CONFIG_TOTAL_CTRL_COUNT',data=3)]
    config_writes += [dict(tile=t,address=pc,ctrl=word) for pc,word in enumerate(words)]
  steps.append(dict(kind='config_batch',multicast=multicast,writes=config_writes))
  steps += [dict(kind='command',tile=t,cmd='LAUNCH') for t in reversed(active)]
  steps += [dict(kind='barrier',completions=len(active))]
  steps += [dict(kind='command',cmd='LOAD_REQUEST',data_addr=i) for i in range(capacity)]
  expected=list(initial)
  for t in active:expected[t]=answer
  return dict(schema=1,steps=steps),dict(active=active,expected_memory=expected,result=answer,multiply=multiply)


def verify(config,specification,trace):
  host=s.program.layouts(config)['host'];packets=[]
  for line in trace.read_text().splitlines():
    row=line.split();assert row[0]=='H','Unexpected boundary traffic'
    packets.append(s.program.unpack(host,int(row[2],16)))
  completed=[x for x in packets if x['payload']['cmd']==14]
  reads=[x for x in packets if x['payload']['cmd']==11]
  assert len(completed)+len(reads)==len(packets),'Unexpected host command'
  assert sorted(x['src'] for x in completed)==specification['active'],'Missing or duplicate PE completion'
  for x in completed:
    assert x['dst']==config['widths']['NUM_TILES'] and x['dst_cgra_id']==0
    assert x['payload']['data']['payload']==0 and s.program.pack(s.program.layouts(config)['ctrl'],x['payload']['ctrl'])==0
  actual=[]
  for x in reads:
    data=x['payload']['data']
    assert data['predicate']==1 and data['bypass']==0 and data['delay']==0
    assert x['dst']==config['widths']['MAX_TILES'] and x['src_cgra_id']==0 and x['dst_cgra_id']==0
    assert x['payload']['data_addr']==len(actual),'Readback address/order'
    actual.append(data['payload'])
  assert actual==specification['expected_memory'],'Global reduction result or guard memory mismatch'
  return dict(result=specification['result'],checked_words=len(actual),completed_PE_ids=sorted(x['src'] for x in completed))


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--backends',default='0,1,2')
  ap.add_argument('--jobs',type=int,default=1)
  args=ap.parse_args();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
  if (output/'results.json').exists():
    (output/'results.json').rename(output/f'previous-results-{time.time_ns()}.json')
  report=dict(baseline=s.runner.BASELINE,evidence='RTL full-system global reductions via public host with complete memory readback',cases=[])
  for backend in map(int,args.backends.split(',')):
    multicast=int(backend!=0)
    d=s.architecture(2,2,backend,multicast)
    d['parameters'].update(CTRL_DEPTH=4,REG_DEPTH=2,NUM_CTRL=3,TOTAL_STEPS=3)
    d['default_fus']=['CONST','VECTOR_REDUCE','MEM','NAH']
    c=s.cfg.normalize(d);entry=dict(config=d,normalized=c,paths=[[0,1,2]],python_model='regular')
    folder=output/f'backend{backend}';folder.mkdir(exist_ok=True)
    row=dict(backend=backend,runs=[]);report['cases'].append(row)
    row['build'],binary=s.build(folder,entry,args.jobs)
    if row['build']['exit_code']!=0:row['status']='build_failed'
    else:
      for multiply in [False,True]:
        plain,expectation=workload(c,multiply,False)
        _,reference_words,_=s.program.compile_program(c,plain)
        reference=[s.program.unpack(s.program.layouts(c)['host'],x) for x in reference_words]
        # Replies are expected after launch, with independently calculated data.
        for t in expectation['active']:
          reference.append(s.program.host_command(c,'GLOBAL_REDUCE_MUL_RESPONSE' if multiply else 'GLOBAL_REDUCE_ADD_RESPONSE',
              tile=t,data=s.program.data_value(expectation['result'],1)))
        for stream in (['unicast','multicast'] if multicast else ['unicast']):
          doc,_=workload(c,multiply,stream=='multicast')
          files,metadata=s.program.encode_outputs(c,doc)
          case=folder/('mul' if multiply else 'add')/stream;case.mkdir(parents=True,exist_ok=True)
          for name,text in files.items():(case/name).write_text(text)
          (case/'boundary.txt').write_text('')
          (case/'program.json').write_text(json.dumps(doc,indent=2)+'\n')
          for schedule in [0,37]:
            trace=case/f'outputs-{schedule}.txt';control=case/f'control-{schedule}.txt'
            result=s.runner.command([binary,f'+VECTORS={case}',f'+TRACE={trace}',f'+CONTROL_TRACE={control}',
                f'+SCHEDULE={schedule}','+COMPLETIONS=3',f'+READS={len(expectation["expected_memory"])}',
                '+BOUNDARY_OUTPUTS=0'],case/f'run-{schedule}.log',600)
            result.update(multiply=multiply,stream=stream,schedule=schedule,status='failed',packet_count=metadata['packet_count'],
                binary_sha256=s.sha(binary),program_sha256=s.sha(case/'program.hex'))
            if result['exit_code']==0:
              try:
                result['math']=verify(c,expectation,trace)
                wrong=copy.deepcopy(expectation);wrong['expected_memory'][0]^=1
                try:verify(c,wrong,trace)
                except AssertionError:result['wrong_expected_rejected']=True
                else:raise AssertionError('Incorrect reduction oracle accepted')
                result['control']=s.observations(c,control,reference)
                up=result['control']['commands_by_boundary']['U'];down=result['control']['commands_by_boundary']['D']
                assert up.get('19' if multiply else '18')==3 and down.get('21' if multiply else '20')==3,'Reduction request/reply count'
                result['cycles']=int(re.search(r'PARAM_TRANSPORT_PASS cycles=(\d+)',Path(result['log']).read_text())[1])
                result['status']='passed'
              except Exception as error:result['error']=repr(error)
            row['runs'].append(result)
            print(f'CONTROL_REDUCE backend={backend} mul={multiply} {stream}/{schedule}: {result["status"]}',flush=True)
      # Two tasks, one reset: overwrite the program, change reduction operation
      # and constants, and read the entire memory after each task.
      docs=[];expectations=[];references=[];counts=[]
      for epoch in range(2):
        doc,expectation=workload(c,bool(epoch),bool(multicast),base=epoch+1)
        plain,_=workload(c,bool(epoch),False,base=epoch+1)
        # Base has an append-only cyclic constant table and cumulative retired
        # step count; LAUNCH does not clear either. Stage both constant sets
        # before task 1, then extend the step budget for task 2. This uses only
        # the baseline's supported public commands, with no new reset semantics.
        for document in [doc,plain]:
          if epoch==0:
            later,_=workload(c,True,False,base=2)
            values={step['tile']:step['values'] for step in later['steps'] if step['kind']=='constants'}
            for step in document['steps']:
              if step['kind']=='constants':step['values']+=values[step['tile']]
          else:
            document['steps']=[step for step in document['steps'] if step['kind']!='constants']
            for step in document['steps']:
              if step.get('cmd')=='CONFIG_TOTAL_CTRL_COUNT':step['data']=6
        _,words,_=s.program.compile_program(c,plain)
        reference=[s.program.unpack(s.program.layouts(c)['host'],x) for x in words]
        for t in expectation['active']:
          reference.append(s.program.host_command(c,'GLOBAL_REDUCE_MUL_RESPONSE' if epoch else 'GLOBAL_REDUCE_ADD_RESPONSE',
              tile=t,data=s.program.data_value(expectation['result'],1)))
        if epoch:
          for step in doc['steps']:
            if step['kind']=='barrier':step['completions']+=3
        docs+=doc['steps'];expectations.append(expectation);references.append(reference)
        counts.append(s.program.encode_outputs(c,dict(schema=1,steps=doc['steps']))[1]['packet_count'])
      files,metadata=s.program.encode_outputs(c,dict(schema=1,steps=docs))
      case=folder/'repeat';case.mkdir(exist_ok=True)
      for name,text in files.items():(case/name).write_text(text)
      (case/'boundary.txt').write_text('')
      (case/'program.json').write_text(json.dumps(dict(schema=1,steps=docs),indent=2)+'\n')
      for schedule in [0,37]:
        trace=case/f'outputs-{schedule}.txt';control=case/f'control-{schedule}.txt'
        result=s.runner.command([binary,f'+VECTORS={case}',f'+TRACE={trace}',f'+CONTROL_TRACE={control}',
            f'+SCHEDULE={schedule}','+COMPLETIONS=6','+READS=64','+BOUNDARY_OUTPUTS=0'],case/f'run-{schedule}.log',600)
        result.update(repeated_tasks=2,schedule=schedule,status='failed',packet_count=metadata['packet_count'],
            binary_sha256=s.sha(binary),program_sha256=s.sha(case/'program.hex'))
        if result['exit_code']==0:
          try:
            lines=trace.read_text().splitlines();assert len(lines)==70
            controls=control.read_text().splitlines();seen=0;cut=None
            for line in controls:
              if line.startswith('H '):
                if seen==counts[0]:cut=int(line.split()[1]);break
                seen+=1
            assert cut is not None,'Second task was not sent'
            result['epochs']=[]
            for epoch in range(2):
              part=case/f'outputs-{schedule}-epoch{epoch}.txt'
              part.write_text('\n'.join(lines[epoch*35:(epoch+1)*35])+'\n')
              ct=case/f'control-{schedule}-epoch{epoch}.txt'
              ct.write_text('\n'.join(line for line in controls if (int(line.split()[1])<cut)==(epoch==0))+'\n')
              result['epochs'].append(dict(math=verify(c,expectations[epoch],part),
                  control=s.observations(c,ct,references[epoch])))
            result['cycles']=int(re.search(r'PARAM_TRANSPORT_PASS cycles=(\d+)',Path(result['log']).read_text())[1])
            result['status']='passed'
          except Exception as error:result['error']=repr(error)
        row['runs'].append(result)
        print(f'CONTROL_REPEAT backend={backend} schedule={schedule}: {result["status"]}',flush=True)
      row['status']='passed' if all(x['status']=='passed' for x in row['runs']) else 'failed'
    (output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  report['all_passed']=all(x['status']=='passed' for x in report['cases'])
  (output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  return int(not report['all_passed'])


if __name__=='__main__':raise SystemExit(main())
