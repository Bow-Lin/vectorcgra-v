"""Migration-only: freeze ac96 ContextSwitch traces and emit standalone SV tests."""
import hashlib, json, random, re, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT.parent))
from pymtl3 import DefaultPassGroup
from VectorCGRA.mem.ctrl.ContextSwitchRTL import ContextSwitchRTL
from VectorCGRA.lib.messages import mk_data

def write(path,text):
  path.parent.mkdir(parents=True,exist_ok=True)
  path.write_text(text,newline='\n')

def context():
  out=ROOT/'sv/reference/phase3/tile_variants/context-pyreplay'
  if out.exists(): raise RuntimeError(f'Frozen output exists: {out}')
  d=ContextSwitchRTL(32,3); d.apply(DefaultPassGroup()); Data=mk_data(32)
  rng=random.Random(31415926); traces=[]; states=[]
  for cycle in range(360):
    reset=cycle in (0,1,2,170,171)
    cmd,valid,phi,opt,addr,payload,pred,pval,rdy=0,0,2,32,2,cycle+100,1,1,1
    schedule={4:16,8:1,22:22,35:15,50:1,70:22,90:15,150:22,175:15}
    if cycle in schedule: cmd,valid=schedule[cycle],1
    if cycle in range(11,17): pval,pred,rdy=0,0,0
    if 36<=cycle<=38: rdy=0
    if cycle>=200:
      cmd=rng.choice([1,15,16,22,0,2]); valid=rng.randrange(2); phi=rng.randrange(8)
      opt=rng.choice([32,84,2]); addr=rng.randrange(8);payload=rng.getrandbits(32)
      pred,pval,rdy=[rng.randrange(2) for _ in range(3)]
    data=Data(payload,pred,cycle%2,(cycle//2)%2)
    d.reset @= reset; d.recv_cmd @= cmd; d.recv_cmd_vld @= valid; d.phi_addr @= phi
    d.recv_opt @= opt; d.ctrl_mem_rd_addr @= addr; d.progress_in @= data
    d.progress_in_val @= pval; d.overwrite_fu_outport.rdy @= rdy
    d.sim_eval_combinational()
    values=[(reset,1),(cmd,6),(valid,1),(phi,3),(opt,7),(int(data.to_bits()),35),(pval,1),(addr,3),(rdy,1)]
    packed=0
    for val,width in values: packed=(packed<<width)|val
    result=(int(d.overwrite_fu_outport.val)<<35)|int(d.overwrite_fu_outport.msg.to_bits())
    traces.append(f'{packed:015x} {result:09x}')
    states.append(dict(cycle=cycle,status=int(d.status_reg),progress=int(d.progress_reg.to_bits()),phi=int(d.phi_addr_reg),overwrite=int(d.overwrite_fu_outport.val),message=int(d.overwrite_fu_outport.msg.to_bits())))
    d.sim_tick()
  write(out/'cycles.txt','\n'.join(traces)+'\n')
  write(out/'states.json',json.dumps(states,indent=2)+'\n')
  manifest=dict(baseline='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b',kind='unmodified Python simulation',cycles=len(traces),input_bits=58,output_bits=36,seed=31415926,
    source_sha256=hashlib.sha256((ROOT/'mem/ctrl/ContextSwitchRTL.py').read_bytes()).hexdigest(),
    trace_sha256=hashlib.sha256((out/'cycles.txt').read_bytes()).hexdigest(),
    note='No translation workaround. PyMTL zero initialization and Verilator default two-state initialization are the compared startup contract.')
  write(out/'manifest.json',json.dumps(manifest,indent=2)+'\n')
  bench='''`timescale 1ns/1ps
module tb_context_switch;
  logic clk=0, reset, recv_cmd_vld, progress_in_val, overwrite_fu_outport__rdy;
  logic [5:0] recv_cmd;
  logic [2:0] phi_addr, ctrl_mem_rd_addr;
  logic [6:0] recv_opt;
  logic [34:0] progress_in, overwrite_fu_outport__msg;
  logic overwrite_fu_outport__val;
  logic [57:0] stimulus;
  logic [35:0] expected;
  integer fd, count=0, rc, suppressed=0, restored=0;
  tile_context_switch dut(.*);
  initial begin
    fd=$fopen("reference/phase3/tile_variants/context-pyreplay/cycles.txt","r");
    if (!fd) $fatal(1,"missing context reference");
    while (!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\\n",stimulus,expected);
      if(rc!=2) $fatal(1,"malformed context trace");
      {reset,recv_cmd,recv_cmd_vld,phi_addr,recv_opt,progress_in,progress_in_val,ctrl_mem_rd_addr,overwrite_fu_outport__rdy}=stimulus;
      #4;
      if($test$plusargs("EXPECT_FAILURE") && count==20) expected[0]=~expected[0];
      if ({overwrite_fu_outport__val,overwrite_fu_outport__msg} !== expected)
        $fatal(1,"context mismatch cycle=%0d actual=%h expected=%h",count,{overwrite_fu_outport__val,overwrite_fu_outport__msg},expected);
      if(count==11 && (overwrite_fu_outport__val!==1 || overwrite_fu_outport__msg!==0))
        $fatal(1,"PAUSE must suppress even invalid progress");
      if(count==38 && (overwrite_fu_outport__val!==0))
        $fatal(1,"RESUME must consume saved progress despite output backpressure");
      if(overwrite_fu_outport__val && overwrite_fu_outport__msg==0) suppressed++;
      if(overwrite_fu_outport__val && overwrite_fu_outport__msg!=0) restored++;
      clk=1; #1; clk=0; #1; count++;
    end
    if(count!=360 || suppressed==0 || restored==0) $fatal(1,"incomplete context coverage");
    $display("CONTEXT_SWITCH_PASS cycles=%0d suppressed=%0d restored=%0d",count,suppressed,restored);
    $finish;
  end
endmodule
'''
  write(ROOT/'sv/tests/phase3/tile_variants/tb_context_switch.sv',bench)

if __name__=='__main__': context()
