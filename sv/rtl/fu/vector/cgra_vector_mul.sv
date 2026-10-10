`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// ac96 behavior preserved, including undriven fields and original handshake rules.
module cgra_vector_mul #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int LANE_W = 8
) (
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input logic [2*LANE_W-1:0] recv_const__msg  ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [2*LANE_W-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg  ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [2*LANE_W-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] 
);
  `include "cgra_profile.svh"
  ctrl_t p_recv_opt__msg ;
  assign p_recv_opt__msg = recv_opt__msg;

  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_MUL  = `CGRA_OPT_MUL;
  logic [2:0] in0;
  logic [1:0] in0_idx;
  logic [2:0] in1;
  logic [1:0] in1_idx;
  logic [0:0] recv_all_val;

  always_comb begin : comb_logic
    recv_all_val = 1'd0;
    in0 = 3'd0;
    in1 = 3'd0;
    for ( int unsigned i = 1'd0; i < 3'( num_inports_at_comb_logic ); i += 1'd1 )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 1'd0; i < 3'( num_inports_at_comb_logic ); i += 1'd1 )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 1'd0; i < 2'( num_outports_at_comb_logic ); i += 1'd1 ) begin
      send_out__val[1'(i)] = 1'd0;
      send_out__msg[1'(i)] = (2*LANE_W)'(0);
    end
    recv_const__rdy = 1'd0;
    recv_opt__rdy = 1'd0;
    if ( recv_opt__val ) begin
      if ( p_recv_opt__msg.fu_in[2'd0] != 3'd0 ) begin
        in0 = p_recv_opt__msg.fu_in[2'd0] - 3'd1;
      end
      if ( p_recv_opt__msg.fu_in[2'd1] != 3'd0 ) begin
        in1 = p_recv_opt__msg.fu_in[2'd1] - 3'd1;
      end
    end
    if ( recv_opt__val ) begin
      if ( p_recv_opt__msg.operation == 7'( OPT_MUL ) ) begin
        send_out__msg[1'd0] = recv_in__msg[in0_idx] * recv_in__msg[in1_idx];
        recv_all_val = recv_in__val[in0_idx] & recv_in__val[in1_idx];
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_in__rdy[in1_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_opt__rdy = recv_all_val & send_out__rdy[1'd0];
      end
      else begin
        for ( int unsigned j = 1'd0; j < 2'( num_outports_at_comb_logic ); j += 1'd1 )
          send_out__val[1'(j)] = 1'd0;
        recv_opt__rdy = 1'd0;
        recv_in__rdy[in0_idx] = 1'd0;
        recv_in__rdy[in1_idx] = 1'd0;
      end
    end
  end

  assign in0_idx = in0[1:0];
  assign in1_idx = in1[1:0];

endmodule
