`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tile_flexible_fu_configurable #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS
) (
  input  logic [0:0] clear [0:FU_COUNT-1],
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [2:0] prologue_count_inport ,
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg [0:FU_COUNT-1] ,
  output logic [0:0] from_mem_rdata__rdy [0:FU_COUNT-1] ,
  input logic [0:0] from_mem_rdata__val [0:FU_COUNT-1] ,
  input logic [DATA_BITS-1:0] recv_const__msg ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ,
  output logic [0:0] recv_from_ctrl_mem__rdy  ,
  input logic [0:0] recv_from_ctrl_mem__val  ,
  input logic [DATA_BITS-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  input logic [HOST_BITS-1:0] recv_pkt_from_controller__msg ,
  output logic [0:0] recv_pkt_from_controller__rdy  ,
  input logic [0:0] recv_pkt_from_controller__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg [0:FU_COUNT-1] ,
  input logic [0:0] to_mem_raddr__rdy [0:FU_COUNT-1] ,
  output logic [0:0] to_mem_raddr__val [0:FU_COUNT-1] ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg [0:FU_COUNT-1] ,
  input logic [0:0] to_mem_waddr__rdy [0:FU_COUNT-1] ,
  output logic [0:0] to_mem_waddr__val [0:FU_COUNT-1] ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg [0:FU_COUNT-1] ,
  input logic [0:0] to_mem_wdata__rdy [0:FU_COUNT-1] ,
  output logic [0:0] to_mem_wdata__val [0:FU_COUNT-1]
);
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
    // Original FlexibleFuRTL constructs every child with its default factor.
    // Standalone FUs expose this parameter; the original composed Tile does not.
    if(VECTOR_FACTOR_POWER!=0) $fatal(1,"ac96 composed FU clusters require VECTOR_FACTOR_POWER=0");
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
`define CGRA_FU_SLOT_PORTS \
        .clear(clear[slot]), \
        .clk(clk), \
        .ctrl_addr_inport(ctrl_addr_inport), \
        .reset(reset), \
        .from_mem_rdata__msg(from_mem_rdata__msg[slot]), \
        .from_mem_rdata__rdy(from_mem_rdata__rdy[slot]), \
        .from_mem_rdata__val(from_mem_rdata__val[slot]), \
        .recv_const__msg(recv_const__msg), \
        .recv_const__rdy(fu_recv_const__rdy[slot]), \
        .recv_const__val(recv_const__val), \
        .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg), \
        .recv_from_ctrl_mem__rdy(fu_recv_from_ctrl_mem__rdy[slot]), \
        .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val), \
        .recv_in__msg(recv_in__msg), \
        .recv_in__rdy(fu_input_ready[slot]), \
        .recv_in__val(recv_in__val), \
        .recv_opt__msg(effective_control), \
        .recv_opt__rdy(fu_recv_opt__rdy[slot]), \
        .recv_opt__val(recv_opt__val), \
        .send_out__msg(fu_send_out__msg[slot]), \
        .send_out__rdy(send_out__rdy), \
        .send_out__val(fu_send_out__val[slot]), \
        .send_to_ctrl_mem__msg(fu_send_to_ctrl_mem__msg[slot]), \
        .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy), \
        .send_to_ctrl_mem__val(fu_send_to_ctrl_mem__val[slot]), \
        .to_mem_raddr__msg(to_mem_raddr__msg[slot]), \
        .to_mem_raddr__rdy(to_mem_raddr__rdy[slot]), \
        .to_mem_raddr__val(to_mem_raddr__val[slot]), \
        .to_mem_waddr__msg(to_mem_waddr__msg[slot]), \
        .to_mem_waddr__rdy(to_mem_waddr__rdy[slot]), \
        .to_mem_waddr__val(to_mem_waddr__val[slot]), \
        .to_mem_wdata__msg(to_mem_wdata__msg[slot]), \
        .to_mem_wdata__rdy(to_mem_wdata__rdy[slot]), \
        .to_mem_wdata__val(to_mem_wdata__val[slot])
    if(KIND==`CGRA_FU_ADDER) begin : kind_adder
      tile_adder #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_MUL) begin : kind_mul
      tile_multiplier #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_MEM) begin : kind_mem
      tile_memory_fu #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_NAH) begin : kind_nah
      tile_nah #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_CONST) begin : kind_const
      scalar_const #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_COMP) begin : kind_comp
      scalar_comp #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_LOGIC) begin : kind_logic
      scalar_logic #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_SHIFTER) begin : kind_shifter
      scalar_shifter #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_SEL) begin : kind_sel
      scalar_sel #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_PHI) begin : kind_phi
      scalar_phi #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_GRANT) begin : kind_grant
      scalar_grant #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_GEP) begin : kind_gep
      scalar_gep #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_EXTRACT_PREDICATE) begin : kind_extract_predicate
      scalar_extract_predicate #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_RET) begin : kind_ret
      scalar_ret #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_LOOP_COUNTER) begin : kind_loop_counter
      scalar_loop_counter #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_LOOP_CONTROL) begin : kind_loop_control
      scalar_loop_control #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_DIV) begin : kind_div
      scalar_div #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_INCLUSIVE_DIV) begin : kind_inclusive_div
      scalar_inclusive_div #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_EXCLUSIVE_DIV) begin : kind_exclusive_div
      scalar_exclusive_div #(`CGRA_PROFILE_BIND, .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_VECTOR_ADDER) begin : kind_vector_adder
      tile_vector_adder_combo #(`CGRA_PROFILE_BIND, .LANES(VECTOR_LANES), .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_VECTOR_MUL) begin : kind_vector_mul
      tile_vector_mul_combo #(`CGRA_PROFILE_BIND, .LANES(VECTOR_LANES), .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_VECTOR_REDUCE) begin : kind_vector_reduce
      tile_vector_all_reduce #(`CGRA_PROFILE_BIND, .LANES(VECTOR_LANES), .VECTOR_FACTOR_POWER(VECTOR_FACTOR_POWER)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_SEQ_MUL_ADDER) begin : kind_seq_mul_adder
      tile_seq_mul_adder #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_SEQ_MUL_SHIFTER) begin : kind_seq_mul_shifter
      tile_seq_mul_shifter #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_PRL_MUL_ADDER) begin : kind_prl_mul_adder
      tile_prl_mul_adder #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_THREE_MUL_ADDER_SHIFTER) begin : kind_three_mul_adder_shifter
      tile_three_mul_adder_shifter #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_FOUR_INC_CMP_NOT_GRANT) begin : kind_four_inc_cmp_not_grant
      tile_four_inc_cmp_not_grant #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_ALU_GEN_MAC) begin : kind_alu_gen_mac
      tile_alu_gen_mac #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_FP_ADD) begin : kind_fp_add
      tile_fp_add #(`CGRA_PROFILE_BIND, .FP_EXP_W(FP_EXP_W), .FP_SIG_W(FP_SIG_W)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_FP_MUL) begin : kind_fp_mul
      tile_fp_mul #(`CGRA_PROFILE_BIND, .FP_EXP_W(FP_EXP_W), .FP_SIG_W(FP_SIG_W)) fu (
        `CGRA_FU_SLOT_PORTS
      );
    end
    else if(KIND==`CGRA_FU_STREAMING_MEM) begin : kind_streaming_mem
      tile_streaming_memory_fu #(`CGRA_PROFILE_BIND) fu (
        `CGRA_FU_SLOT_PORTS,
        .recv_from_controller_pkt__msg(recv_pkt_from_controller__msg),
        .recv_from_controller_pkt__val(recv_pkt_from_controller__val),
        .recv_from_controller_pkt__rdy(recv_pkt_from_controller__rdy)
      );
    end
    else begin : invalid_kind
      initial $fatal(1,"Unknown elaboration-time FU kind %0d",KIND);
    end
  end
  // With no streaming FU, recv_pkt_from_controller.rdy is undriven in ac96.
endmodule
`undef CGRA_FU_SLOT_PORTS
