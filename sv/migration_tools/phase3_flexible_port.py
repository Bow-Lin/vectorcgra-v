"""One-time scaffold for the ordered native FU catalog; not a runtime generator."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'rtl/fu/tile_flexible_fu.sv').read_text()
header=source[source.index('`include'):source.index('\n);')+4]
header=header.replace('`include "cgra_profile_defs.svh"','`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"')
header=header.replace('module tile_flexible_fu #(', 'module tile_flexible_fu_configurable #(')
header=header.replace('`CGRA_PROFILE_PARAMETERS','`CGRA_PROFILE_PARAMETERS,\n  `CGRA_FU_PARAMETERS')
lines=[]
for line in header.splitlines():
    if re.search(r'\b(?:clear|from_mem_\w+|to_mem_\w+)\b',line):
        line=line.replace('[0:3]','[0:FU_COUNT-1]')
    lines.append(line.rstrip())
header='\n'.join(lines)
standard=(ROOT/'rtl/fu/tile_adder.sv').read_text().split('\n);',1)[0]
ports=re.findall(r'\b(?:input|output)\s+logic\s+(?:\[[^\]]+\]\s+)?(\w+)',standard)
signals={p:p for p in ports}
for p in ports:
    if p=='clear' or p.startswith(('to_mem_','from_mem_')): signals[p]=p+'[slot]'
    if p.startswith('send_out__') and not p.endswith('rdy'): signals[p]='fu_'+p+'[slot]'
    if p=='recv_in__rdy': signals[p]='fu_input_ready[slot]'
    if p in ['recv_const__rdy','recv_opt__rdy','recv_from_ctrl_mem__rdy','send_to_ctrl_mem__msg','send_to_ctrl_mem__val']:
        signals[p]='fu_'+p+'[slot]'
signals['recv_opt__msg']='effective_control'
mapping=[
('ADDER','tile_adder'),('MUL','tile_multiplier'),('MEM','tile_memory_fu'),('NAH','tile_nah'),
('CONST','scalar_const'),('COMP','scalar_comp'),('LOGIC','scalar_logic'),('SHIFTER','scalar_shifter'),
('SEL','scalar_sel'),('PHI','scalar_phi'),('GRANT','scalar_grant'),('GEP','scalar_gep'),
('EXTRACT_PREDICATE','scalar_extract_predicate'),('RET','scalar_ret'),('LOOP_COUNTER','scalar_loop_counter'),
('LOOP_CONTROL','scalar_loop_control'),('DIV','scalar_div'),('INCLUSIVE_DIV','scalar_inclusive_div'),('EXCLUSIVE_DIV','scalar_exclusive_div'),
('VECTOR_ADDER','tile_vector_adder_combo'),('VECTOR_MUL','tile_vector_mul_combo'),('VECTOR_REDUCE','tile_vector_all_reduce'),
('SEQ_MUL_ADDER','tile_seq_mul_adder'),('SEQ_MUL_SHIFTER','tile_seq_mul_shifter'),('PRL_MUL_ADDER','tile_prl_mul_adder'),
('THREE_MUL_ADDER_SHIFTER','tile_three_mul_adder_shifter'),('FOUR_INC_CMP_NOT_GRANT','tile_four_inc_cmp_not_grant'),
('ALU_GEN_MAC','tile_alu_gen_mac'),('FP_ADD','tile_fp_add'),('FP_MUL','tile_fp_mul'),('STREAMING_MEM','tile_streaming_memory_fu')]
text=header+r'''
  `include "cgra_profile.svh"
  ctrl_t effective_control;
  logic [DATA_BITS-1:0] fu_send_out__msg [0:FU_COUNT-1][0:1];
  logic fu_send_out__val [0:FU_COUNT-1][0:1];
  logic fu_input_ready [0:FU_COUNT-1][0:3];
  logic fu_recv_const__rdy [0:FU_COUNT-1], fu_recv_opt__rdy [0:FU_COUNT-1];
  logic fu_recv_from_ctrl_mem__rdy [0:FU_COUNT-1];
  logic [PAYLOAD_BITS-1:0] fu_send_to_ctrl_mem__msg [0:FU_COUNT-1];
  logic fu_send_to_ctrl_mem__val [0:FU_COUNT-1];
  function automatic int count_kind(input logic [7:0] kind);
    int count;
    count=0;
    for(int i=0;i<FU_COUNT;i++) if(FU_KINDS[8*i+:8]==kind) count++;
    return count;
  endfunction
  initial begin
    if(FU_COUNT<1) $fatal(1,"FU_COUNT must be positive");
    if(count_kind(`CGRA_FU_NAH)!=1) $fatal(1,"FU_KINDS must contain the ac96 Nah unit exactly once");
    if(count_kind(`CGRA_FU_STREAMING_MEM)>1) $fatal(1,"Only one streaming controller consumer is supported");
  end
  always_comb begin
    effective_control=recv_opt__msg;
    if(prologue_count_inport!=0) effective_control.operation=7'd1;
    recv_const__rdy=0;
    recv_opt__rdy=(prologue_count_inport!=0);
    recv_from_ctrl_mem__rdy=0;
    send_to_ctrl_mem__msg='0;
    send_to_ctrl_mem__val=0;
    for(int p=0;p<4;p++) recv_in__rdy[p]=0;
    for(int p=0;p<2;p++) begin send_out__msg[p]='0; send_out__val[p]=0; end
    for(int i=0;i<FU_COUNT;i++) begin
      recv_const__rdy |= fu_recv_const__rdy[i];
      recv_opt__rdy |= fu_recv_opt__rdy[i];
      recv_from_ctrl_mem__rdy |= fu_recv_from_ctrl_mem__rdy[i];
      if(fu_send_to_ctrl_mem__val[i]) begin
        send_to_ctrl_mem__msg=fu_send_to_ctrl_mem__msg[i];
        send_to_ctrl_mem__val=fu_send_to_ctrl_mem__val[i];
      end
      for(int p=0;p<4;p++) recv_in__rdy[p] |= fu_input_ready[i][p];
      // ac96 uses ordered last-valid selection, not a new arbiter or OR of payloads.
      for(int p=0;p<2;p++) if(fu_send_out__val[i][p]) begin
        send_out__msg[p]=fu_send_out__msg[i][p];
        send_out__val[p]=fu_send_out__val[i][p];
      end
    end
  end
  for(genvar slot=0;slot<FU_COUNT;slot++) begin : units
    localparam logic [7:0] KIND=FU_KINDS[8*slot+:8];
'''
connections=[f'.{p}({signals[p]})' for p in ports]
text+='`define CGRA_FU_SLOT_PORTS \\\n        '+', \\\n        '.join(connections)+'\n'
for i,(kind,module) in enumerate(mapping):
    prefix='if' if i==0 else 'else if'
    extra=''
    if module.startswith('scalar_'): extra=', .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)'
    if kind in ['VECTOR_ADDER','VECTOR_MUL','VECTOR_REDUCE']: extra=', .LANES(VECTOR_LANES), .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)'
    if kind in ['FP_ADD','FP_MUL']: extra=', .FP_EXP_W(FP_EXP_W), .FP_SIG_W(FP_SIG_W)'
    text+=f'    {prefix}(KIND==`CGRA_FU_{kind}) begin : kind_{kind.lower()}\n'
    connections=['`CGRA_FU_SLOT_PORTS']
    if kind=='STREAMING_MEM':
        connections += [f'.recv_from_controller_pkt__{p}(recv_pkt_from_controller__{p})' for p in ['msg','val','rdy']]
    text+=f'      {module} #(`CGRA_PROFILE_BIND{extra}) fu (\n        '+',\n        '.join(connections)+'\n      );\n    end\n'
text+='''    else begin : invalid_kind
      initial $fatal(1,"Unknown elaboration-time FU kind %0d",KIND);
    end
  end
  // With no streaming FU, recv_pkt_from_controller.rdy is undriven in ac96.
endmodule
`undef CGRA_FU_SLOT_PORTS
'''
(ROOT/'rtl/fu/tile_flexible_fu_configurable.sv').write_text(text,newline='\n')
print('CONFIGURABLE_FU_SCAFFOLD_PASS')
