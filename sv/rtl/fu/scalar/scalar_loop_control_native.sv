`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// Native LoopControlRTL migration from ac96; original state/handshake semantics.
module scalar_loop_control_native #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int VECTOR_FACTOR_POWER = 0
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg  ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_const__msg  ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg  ,
  output logic [0:0] recv_from_ctrl_mem__rdy  ,
  input logic [0:0] recv_from_ctrl_mem__val  ,
  input logic [DATA_BITS-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg  ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg  ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg  ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val
);
  `include "cgra_profile.svh"
  ctrl_t control;
  data_t inputs[0:3],outputs[0:1];
  logic [1:0] selected[4],delivered;
  logic initialized,active,legal,valid_inputs,flush,retire,reached,loop_valid;
  logic [DATA_W-1:0] current_index,index_value;
  logic [7:0] vector_count;
  logic [8:0] vector_next;
  assign control=recv_opt__msg;
  assign inputs=recv_in__msg;
  assign send_out__msg=outputs;
  assign flush=reset || clear;
  assign vector_next={1'b0,vector_count}+(9'd1<<VECTOR_FACTOR_POWER);
  assign reached=vector_next>=(9'd1<<control.vector_factor_power);
  initial if (VECTOR_FACTOR_POWER<0 || VECTOR_FACTOR_POWER>7) $fatal(1,"LOOP_CONTROL_VECTOR_FACTOR");
  always_comb begin
    legal=1;valid_inputs=1;
    for(integer i=0;i<4;i++) begin
      selected[i]=control.fu_in[i]==0 ? 2'd0 : 2'(control.fu_in[i]-1);
      legal &= control.fu_in[i]<=4;
      valid_inputs &= recv_in__val[selected[i]];
      recv_in__rdy[i]=0;
    end
    active=!flush && recv_opt__val && control.operation==`CGRA_OPT_LOOP_CONTROL && legal && valid_inputs;
    index_value=initialized ? current_index : inputs[selected[1]].payload;
    loop_valid=inputs[selected[0]].predicate && index_value<inputs[selected[2]].payload;
    outputs[0]='0;outputs[1]='0;
    send_out__val[0]=0;send_out__val[1]=0;recv_opt__rdy=0;retire=0;
    if (active) begin
      outputs[0].payload=index_value;outputs[0].predicate=loop_valid && reached;
      outputs[1].payload=DATA_W'(loop_valid);outputs[1].predicate=reached;
      send_out__val[0]=!delivered[0];send_out__val[1]=!delivered[1];
      retire=(delivered[0] || send_out__rdy[0]) && (delivered[1] || send_out__rdy[1]);
      recv_opt__rdy=retire;
      for(integer i=0;i<4;i++) recv_in__rdy[selected[i]]=retire;
    end
  end
  always_ff @(posedge clk) begin
    if (flush) begin current_index<=0;initialized<=0;delivered<=0;vector_count<=0;end
    else if (retire) begin
      current_index<=index_value+inputs[selected[3]].payload;initialized<=1;delivered<=0;
      if (control.is_last_ctrl) vector_count<=reached ? 8'd0 : vector_next[7:0];
    end else begin
      for(integer i=0;i<2;i++) if (send_out__val[i] && send_out__rdy[i]) delivered[i]<=1;
    end
  end
  assign recv_const__rdy=0;
  assign recv_from_ctrl_mem__rdy=0;
  assign send_to_ctrl_mem__msg='0;
  assign send_to_ctrl_mem__val=0;
  assign from_mem_rdata__rdy=0;
  assign to_mem_raddr__msg='0;
  assign to_mem_raddr__val=0;
  assign to_mem_waddr__msg='0;
  assign to_mem_waddr__val=0;
  assign to_mem_wdata__msg='0;
  assign to_mem_wdata__val=0;
endmodule
