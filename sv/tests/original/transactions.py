"""Replay original accepted system transactions with native handshakes.

No program or expected-message edits. Inputs retain earliest issue cycles and
causal output barriers, then remain stable until accepted. Output streams are
checked independently, with bounded completion and a duplicate-drain interval.
"""
import json


def render_transactions(meta, parameters, native_ports, trace):
  from run import render
  # Reuse exact port/type checking and initialization from cycle renderer.
  base=render(meta,parameters,native_ports)
  prefix=base.split('if(!$value$plusargs("VECTORS=')[0]
  ports=meta['ports'];by_path={p['path']:i for i,p in enumerate(ports)}
  channels=[]; covered=set()
  for i,p in enumerate(ports):
    if not p['path'].endswith('.msg'):continue
    stem=p['path'][:-4]
    if stem+'.val' not in by_path or stem+'.rdy' not in by_path:continue
    val,rdy=by_path[stem+'.val'],by_path[stem+'.rdy']
    channels.append(dict(name=stem,msg=i,val=val,rdy=rdy,input=p['direction']=='input',words=[],barriers=[],cycles=[]))
    covered.update([i,val,rdy])
  outputs=[c for c in channels if not c['input']]
  inputs=[c for c in channels if c['input']]
  reset=by_path['reset']; covered.add(reset)
  static={}; extra={};counts=[0]*len(outputs);pending={};cycle=0;reset_edges=0;started=False;active=False
  lines=(trace/'vectors.txt').read_text().splitlines()
  for line in lines:
    fields=line.split()
    if fields[0]!='1':continue
    values=[int(x,16) for x in fields[1:]]
    if values[reset]:
      assert not started,'Mid-test reset needs explicit epoch replay'
      reset_edges+=1;continue
    started=True
    active=active or any(values[c['val']] for c in inputs)
    for i,p in enumerate(ports):
      if i in covered:continue
      if p['direction']=='input':
        if active:
          assert i not in static or static[i]==values[i], 'Dynamic non-channel input '+p['path']
          static[i]=values[i]
      else:extra[i]=values[i]
    for c in inputs:
      key=c['name']
      if values[c['val']] and key not in pending:
        pending[key]=(list(counts),cycle,values[c['msg']])
      if values[c['val']] and values[c['rdy']]:
        deps,first,msg=pending.pop(key)
        assert msg==values[c['msg']],'Original input changed while stalled: '+key
        c['words'].append(msg);c['barriers'].append(deps);c['cycles'].append(first)
    for j,c in enumerate(outputs):
      if values[c['val']] and values[c['rdy']]:
        c['words'].append(values[c['msg']]);counts[j]+=1
      c['ready_seen']=c.get('ready_seen',False) or bool(values[c['rdy']])
      c['final_ready']=bool(values[c['rdy']])
    cycle+=1
  # Direct tests may assert a final settled output before clocking it (DMA_DONE
  # is one example). Preserve that final observation, not just clocked events.
  final=lines[-1].split()
  if final[0]=='0':
    values=[int(x,16) for x in final[1:]]
    for c in outputs:
      if values[c['val']] and values[c['rdy']]:c['words'].append(values[c['msg']])
    for i in extra:extra[i]=values[i]
  for c in outputs:
    if c['name'] in meta.get('required_output_words',{}):
      required=meta['required_output_words'][c['name']]
      assert c['words']==required[:len(c['words'])],'Observed completion differs from original sink expectation'
      c['words']=required
  assert not pending, 'Unaccepted original input transactions: '+str(list(pending))
  assert reset_edges and started
  def sig(i):return ports[i]['signal']
  declarations=['integer cycle=0,drain=0;bit complete;']
  init=[]; drive=[]; check=[];advance=[];conditions=[]
  for i,value in static.items():init.append(f"{sig(i)}={ports[i]['width']}'h{value:x};")
  evidence=dict(original_cycles=cycle,inputs={},outputs={},final_outputs={ports[i]['path']:v for i,v in extra.items()})
  for j,c in enumerate(outputs):
    n=len(c['words']);width=ports[c['msg']]['width'];index=f'o{j}'
    declarations += [f'integer {index}=0;',f'logic [{width-1}:0] expected_{j}[0:{max(1,n)-1}];']
    for k,w in enumerate(c['words']):init.append(f"expected_{j}[{k}]={width}'h{w:x};")
    if n:init.append(f'if($test$plusargs("NEGATIVE") && {j}=={next(k for k,x in enumerate(outputs) if x["words"])})expected_{j}[0]^=1;')
    drive.append(f'{sig(c["rdy"])}={int(c.get("ready_seen",False))} && ({index}<{n} || {int(c.get("final_ready",False))}) && (!$test$plusargs("STALL") || cycle%7>=2);')
    if c.get('ready_seen',False):
      check += [f'if({sig(c["val"])} && {sig(c["rdy"])})begin',
        f'if({index}>={n})$fatal(1,"ORIGINAL_TRANSACTION_EXTRA {c["name"]} actual=%h",{sig(c["msg"])});',
        f'if({sig(c["msg"])}!==expected_{j}[{index}])$fatal(1,"ORIGINAL_TRANSACTION_MISMATCH {c["name"]} index=%0d actual=%h expected=%h",{index},{sig(c["msg"])},expected_{j}[{index}]);',f'{index}++;end']
    conditions.append(f'{index}=={n}')
    evidence['outputs'][c['name']]=n
  for j,c in enumerate(inputs):
    n=len(c['words']);width=ports[c['msg']]['width'];index=f'i{j}'
    declarations += [f'integer {index}=0;', f'logic [{width-1}:0] input_{j}[0:{max(1,n)-1}];',f'integer first_{j}[0:{max(1,n)-1}];']
    for k,w in enumerate(c['words']):init += [f"input_{j}[{k}]={width}'h{w:x};",f'first_{j}[{k}]={c["cycles"][k]};']
    deps=[]
    for o in range(len(outputs)):
      if not any(row[o] for row in c['barriers']):continue
      declarations.append(f'integer dep_{j}_{o}[0:{max(1,n)-1}];')
      init += [f'dep_{j}_{o}[{k}]={row[o]};' for k,row in enumerate(c['barriers'])]
      deps.append(f'o{o}>=dep_{j}_{o}[{index}]')
    enable=' && '.join([f'{index}<{n}',f'cycle>=first_{j}[{index}]']+deps) if n else '0'
    drive += [f'{sig(c["val"])}={enable};',f"{sig(c['msg'])}={index}<{n} ? input_{j}[{index}] : '0;"]
    advance.append(f'if({sig(c["val"])} && {sig(c["rdy"])}){index}++;')
    conditions.append(f'{index}=={n}');evidence['inputs'][c['name']]=n
  conditions += [f"{sig(i)}=={ports[i]['width']}'h{v:x}" for i,v in extra.items()]
  limit=max(1000,cycle*10)
  memory_init=[];memory_check=[]
  for kind,target in [('memory_setup',memory_init),('memory_final',memory_check)]:
    for bank,words in enumerate(meta.get(kind,[])):
      for addr,value in enumerate(words):
        signal=f'dut.cgra.data_mem.banks[{bank}].memory.memory[{addr}]'
        literal=f"{meta['parameters']['DATA_W']+3}'h{value:x}"
        if kind=='memory_setup':target.append(f'{signal}={literal};')
        else:
          expected=f"({literal} ^ DATA_BITS'($test$plusargs(\"BAD_MEMORY\") && {bank}==0 && {addr}==0))"
          target.append(f'if({signal}!=={expected})$fatal(1,"ORIGINAL_MEMORY_MISMATCH bank={bank} addr={addr} actual=%h",{signal});')
  code=prefix+'\n'+'\n'.join(init)+f'\nreset=1;repeat({reset_edges})begin #5;clk=1;#5;clk=0;end reset=0;\n'+'\n'.join(memory_init)+'\n'
  code+=f'while(cycle<{limit})begin\n'+'\n'.join(drive)+'\n#5;\n'+'\n'.join(check+advance)
  code+='\ncomplete='+' && '.join(conditions)+';\nif(complete)drain++;else drain=0;\n'
  code+='if(drain>=16)begin\n'+'\n'.join(memory_check)+'\n$display("ORIGINAL_TRANSACTION_PASS cycles=%0d",cycle);$finish;end\nclk=1;#5;clk=0;cycle++;end\n'
  for j,c in enumerate(outputs):code+=f'$display("OUTPUT_COUNT {c["name"]} %0d/{len(c["words"])}",o{j});\n'
  for j,c in enumerate(inputs):
    if c['words']:code+=f'$display("INPUT_COUNT {c["name"]} %0d/{len(c["words"])}",i{j});\n'
  code+='$fatal(1,"ORIGINAL_TRANSACTION_TIMEOUT");end\nendmodule\n'
  pos=code.index('string vectors;')
  code=code[:pos]+'\n'.join(declarations)+'\n'+code[pos:]
  (trace/'transactions.json').write_text(json.dumps(evidence,indent=2)+'\n')
  return code
