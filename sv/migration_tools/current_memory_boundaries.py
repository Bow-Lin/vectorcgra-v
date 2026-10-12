"""Capture pinned Python memory/peripheral behavior without editing source models."""
import argparse,contextlib,importlib,io,json,random,shutil
from pathlib import Path
from current_vector_reduce import ROOT,sha,port,packed
from pymtl3 import DefaultPassGroup,mk_bits
from pymtl3.passes.backends.verilog import VerilogPlaceholderPass,VerilogTranslationPass
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_intra_cgra_pkt,mk_inter_cgra_pkt
from VectorCGRA.mem.dma.DmaEngineRTL import DmaEngineRTL
from VectorCGRA.fu.others.Im2colEngineRTL import Im2colEngineRTL
from VectorCGRA.mem.data.DataMemControllerRTL import DataMemControllerRTL

def originals(root):
 result=[]
 modules=['fu.others.test.Im2colEngineRTL_test','mem.dma.test.DmaEngineRTL_test',
          'mem.data.test.DataMemControllerRTL_test','mem.data.test.DataMemControllerRTL_dma_test']
 for name in modules:
  module=importlib.import_module('VectorCGRA.'+name)
  for fn in sorted(n for n in vars(module) if n.startswith('test_')):
   cases=[(96,),(256,)] if 'configurable_partial_second_beat' in fn else [({},)] if name.endswith('Im2colEngineRTL_test') or fn=='test_mem_controller' else [()]
   for args in cases:
    log=io.StringIO()
    with contextlib.redirect_stdout(log):getattr(module,fn)(*args)
    result.append(dict(test=name+'::'+fn,args=args,status='passed unchanged assertions',stdout=log.getvalue()))
 (root/'original_tests.json').write_text(json.dumps(result,indent=2)+'\n')
 print('MEMORY_ORIGINAL_TESTS_PASS',len(result),flush=True)

class Trace:
 def __init__(self,model,inputs,outputs):
  self.model=model;self.inputs=inputs;self.outputs=outputs;self.rows=[];self.labels=[]
 def tick(self,values,label):
  for name,width in self.inputs:
   signal=port(self.model,name);T=type(signal);value=int(values.get(name,0))
   signal @= T.from_bits(mk_bits(width)(value)) if hasattr(T,'from_bits') else T(value)
  self.model.sim_eval_combinational()
  self.rows.append((packed(self.model,self.inputs),packed(self.model,self.outputs)))
  self.labels.append(label);self.model.sim_tick()
 def save(self,root,name,parameters,sources,notes):
  d=root/name;d.mkdir(parents=True,exist_ok=True)
  (d/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i,o in self.rows))
  (d/'labels.json').write_text(json.dumps(self.labels,indent=2)+'\n')
  manifest=dict(parameters=parameters,cycles=len(self.rows),inputs=self.inputs,outputs=self.outputs,
   input_bits=sum(w for _,w in self.inputs),output_bits=sum(w for _,w in self.outputs),
   python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',source_sha256={p:sha(ROOT/p) for p in sources},
   generator_sha256=sha(Path(__file__)),helper_sha256=sha(ROOT/'sv/migration_tools/current_vector_reduce.py'),vectors_sha256=sha(d/'vectors.txt'),notes=notes)
  (d/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
  print('MEMORY_PYTHON_FROZEN',name,len(self.rows),flush=True)

def dma(root,width):
 m=DmaEngineRTL(dram_data_nbits=width);m.apply(DefaultPassGroup());m.sim_reset()
 ins=[('reset',1),('dma_cmd__msg',139),('dma_cmd__val',1),('dma_done__rdy',1),
  ('send_to_dram_rd_req__rdy',1),('recv_from_dram_rd_resp__msg',width),('recv_from_dram_rd_resp__val',1),
  ('send_to_dram_wr_req__rdy',1),('recv_from_dram_wr_resp__msg',1),('recv_from_dram_wr_resp__val',1),
  ('send_to_spm_wr_req__rdy',1),('send_to_spm_rd_req__rdy',1),('recv_from_spm_rd_resp__msg',32),('recv_from_spm_rd_resp__val',1)]
 outs=[('dma_cmd__rdy',1),('dma_done__msg',8),('dma_done__val',1),('send_to_dram_rd_req__msg',64),('send_to_dram_rd_req__val',1),
  ('recv_from_dram_rd_resp__rdy',1),('send_to_dram_wr_req__msg',64+width+width//8),('send_to_dram_wr_req__val',1),
  ('recv_from_dram_wr_resp__rdy',1),('send_to_spm_wr_req__msg',68),('send_to_spm_wr_req__val',1),
  ('send_to_spm_rd_req__msg',32),('send_to_spm_rd_req__val',1),('recv_from_spm_rd_resp__rdy',1)]
 t=Trace(m,ins,outs);rng=random.Random(10000+width)
 for n in range(600):
  values={name:rng.getrandbits(bits) for name,bits in ins}
  op=(n//37)%3;count=[0,1,3,4,12,32,36][(n//11)%7]
  cmd=(op<<136)|((4096+(n//7)*4)<<72)|((n%31)<<40)|(count<<8)|(n%256)
  values.update(reset=int(n%73==0),dma_cmd__msg=cmd,dma_cmd__val=int(n%4!=0))
  t.tick(values,f'raw:{n}:op{op}:bytes{count}')
 t.save(root,f'dma_w{width}',dict(DRAM_DATA_W=width,SPM_DATA_W=32),['mem/dma/DmaEngineRTL.py','mem/dma/test/DmaEngineRTL_test.py','lib/messages.py'],
  ['Both models receive a reset clock before comparison; power-on FSM encoding is not a hardware contract. All subsequent raw outputs including invalid/reset are compared. Diagnostic stimuli include source truncation/underflow and unknown-opcode behavior.',
   'Responses are synthetic raw-cycle stimuli, not a proof of a valid DMA memory transaction sequence. Independent native scoreboards check real transfers.'])

def im2col(root,width,depth):
 D=mk_data(width,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));T=mk_intra_cgra_pkt(1,1,4,P)
 image=[((i*17+3)^(0x80000000 if i%7==0 else 0))|((i<<40) if width==64 else 0) for i in range(25)]
 m=Im2colEngineRTL(D,T,P,depth,image);m.apply(DefaultPassGroup())
 t=Trace(m,[('reset',1),('recv_cmd_pkt__msg',T.nbits),('recv_cmd_pkt__val',1),('send_pkt__rdy',1)],
   [('recv_cmd_pkt__rdy',1),('send_pkt__msg',T.nbits),('send_pkt__val',1),('done',1)])
 def tick(label,cmd=0,data=0,addr=0,valid=0,ready=0,reset=0):
  p=T(payload=P(cmd=cmd,data=D(data,1),data_addr=addr))
  t.tick(dict(reset=reset,recv_cmd_pkt__msg=int(p.to_bits()),recv_cmd_pkt__val=valid,send_pkt__rdy=ready),label)
 def configure(h,w,kh,kw,lg,base):
  for cmd,value in [(53,h),(54,w),(55,kh),(56,kw),(57,lg)]:tick(f'config:{cmd}:{value}',cmd,value,valid=1)
  tick('config:base',58,addr=base,valid=1)
 def finish(label,abort=False):
  tick(label+':launch',52,valid=1)
  accepted=0
  for n in range(3000):
   ready=n%7<3
   # Monitor the pre-edge output; message/config presented while busy are ignored.
   m.send_pkt.rdy @= ready;m.sim_eval_combinational()
   accepted+=int(m.send_pkt.val)&ready
   tick(label+f':body:{n}',53,1,valid=1,ready=ready)
   if abort and accepted==3:return
   if int(m.done):return
  raise AssertionError('Original im2col failed to reach its expected bound')
 tick('reset:initial',reset=1);tick('reset:initial2',reset=1)
 configure(5,5,2,3,0,9);finish('first')
 for i in range(5):tick(f'terminal_relaunch_blocked:{i}',52,valid=1,ready=1)
 tick('reset:retain_configuration',reset=1);finish('warm')
 tick('reset:reconfigure',reset=1);configure(5,5,3,2,1,101);finish('stride')
 tick('reset:abort_setup',reset=1);configure(5,5,2,2,0,0);finish('abort',True)
 tick('reset:abort',reset=1);finish('after_abort')
 t.save(root,f'im2col_w{width}_d{depth}',dict(DATA_W=width,SCRATCH_DEPTH=depth,preload_image=image),
  ['fu/others/Im2colEngineRTL.py','fu/others/test/Im2colEngineRTL_test.py','mem/data/DataMemRTL.py','lib/messages.py'],
  ['Original DONE is terminal until reset; geometry and scratch preload state survive reset.',
   'Includes warm launch, stride, busy configuration, held outputs and reset during execution.'])

def asymmetric_probe(root):
 results=[]
 for reads,writes in [(3,1),(1,3)]:
  D=mk_data(32,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));N=mk_inter_cgra_pkt(2,2,4,reads,P)
  for stage in ['simulation','translation']:
   m=DataMemControllerRTL(N,128,16,2,reads,writes,2,2,4,True,{0:[0,0],1:[1,0],2:[0,1],3:[1,1]},False)
   result=dict(reads=reads,writes=writes,stage=stage)
   try:
    if stage=='simulation':m.apply(DefaultPassGroup());m.sim_reset();m.sim_eval_combinational()
    else:
     m.elaborate();m.apply(VerilogPlaceholderPass())
     m.set_metadata(VerilogTranslationPass.enable,True)
     m.set_metadata(VerilogTranslationPass.explicit_module_name,f'MemoryBoundaryReference_r{reads}w{writes}')
     m.apply(VerilogTranslationPass())
     dest=root/f'r{reads}w{writes}_reference.v'
     shutil.copyfile(m.get_metadata(VerilogTranslationPass.translated_filename),dest)
     result.update(rtl=dest.name,sha256=sha(dest))
    result['status']='passed'
   except Exception as error:
    result.update(status='original Python failure',exception=type(error).__name__,message=str(error).replace(str(ROOT),'<repository>'))
   results.append(result)
 (root/'asymmetric_python_probe.json').write_text(json.dumps(results,indent=2)+'\n')

def memory_trace(root):
 D=mk_data(32,1);C=mk_ctrl(4,2,4,4,16);P=mk_cgra_payload(D,mk_bits(7),C,mk_bits(3));N=mk_inter_cgra_pkt(2,2,4,3,P)
 m=DataMemControllerRTL(N,128,16,2,3,1,2,2,4,True,{0:[0,0],1:[1,0],2:[0,1],3:[1,1]},False)
 m.apply(DefaultPassGroup());m.sim_reset()
 ins=[('address_lower',7),('address_upper',7),('cgra_id',2),('reset',1)]
 outs=[]
 for name,bits in [('recv_from_controller_spm_rd_req',32),('recv_from_controller_spm_wr_req',68),('recv_from_noc_load_request',N.nbits),('recv_from_noc_load_response_pkt',N.nbits),('recv_from_noc_store_request',N.nbits)]:
  ins.extend([(name+'__msg',bits),(name+'__val',1)]);outs.append((name+'__rdy',1))
 for name,bits,count in [('recv_raddr',7,3),('recv_waddr',7,1),('recv_wdata',D.nbits,1)]:
  for i in range(count):ins.extend([(f'{name}__msg[{i}]',bits),(f'{name}__val[{i}]',1)]);outs.append((f'{name}__rdy[{i}]',1))
 for i in range(3):ins.append((f'send_rdata__rdy[{i}]',1));outs.extend([(f'send_rdata__msg[{i}]',D.nbits),(f'send_rdata__val[{i}]',1)])
 for name,bits in [('send_to_controller_spm_rd_resp',32),('send_to_noc_load_request_pkt',N.nbits),('send_to_noc_load_response_pkt',N.nbits),('send_to_noc_store_pkt',N.nbits)]:
  ins.append((name+'__rdy',1));outs.extend([(name+'__msg',bits),(name+'__val',1)])
 t=Trace(m,ins,outs);rng=random.Random(332010)
 for n in range(440):
  values={name:rng.getrandbits(bits) for name,bits in ins}
  values.update(address_lower=0,address_upper=31,cgra_id=0,reset=int(n%71==0),recv_from_controller_spm_rd_req__val=0,recv_from_controller_spm_wr_req__val=0)
  for name,cmd in [('recv_from_noc_load_request',10),('recv_from_noc_load_response_pkt',11),('recv_from_noc_store_request',12)]:
   pkt=N(src=n%4,src_tile_id=n%4,remote_src_port=n%3,payload=P(cmd=cmd,data_addr=n%32,data=D(rng.getrandbits(32),n%2)))
   values[name+'__msg']=int(pkt.to_bits())
  t.tick(values,f'raw:{n}')
 t.save(root,'controller_r3w1',dict(MEM_PORTS=3,MEM_WRITE_PORTS=1,MEM_COMBINATIONAL=1,DATA_W=32),
  ['mem/data/DataMemControllerRTL.py','mem/data/DataMemRTL.py','lib/messages.py'],
  ['Pure Python succeeds for this profile; original Verilog translation fails on widening trunc.',
   'Reset before comparison; every subsequent raw output bit is compared, including reset and invalid cycles. Synthetic raw traffic is separate from native transaction math.'])

def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,required=True);a=p.parse_args();root=a.output_root.resolve();root.mkdir(parents=True,exist_ok=True)
 target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
 for path,h in target['source_sha256'].items():assert sha(ROOT/path)==h,path
 originals(root)
 for width in [32,96,128,256]:dma(root,width)
 im2col(root,32,64);im2col(root,64,32);asymmetric_probe(root);memory_trace(root)
 print('MEMORY_PYTHON_SOURCE_GUARD_PASS',len(target['source_sha256']),flush=True)
if __name__=='__main__':main()
