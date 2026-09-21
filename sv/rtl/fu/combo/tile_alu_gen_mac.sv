`include "cgra_profile_defs.svh"
// ac96 behavior preserved, including undriven fields and original handshake rules.
module tile_alu_gen_mac #(
  `CGRA_PROFILE_PARAMETERS
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
  initial if (DATA_W != 16) $fatal(1,"ALUgenMAC requires DATA_W=16");
  data_t p_from_mem_rdata__msg ;
  assign p_from_mem_rdata__msg = from_mem_rdata__msg;
  data_t p_recv_const__msg ;
  assign p_recv_const__msg = recv_const__msg;
  payload_t p_recv_from_ctrl_mem__msg ;
  assign p_recv_from_ctrl_mem__msg = recv_from_ctrl_mem__msg;
  data_t p_recv_in__msg [0:3];
  assign p_recv_in__msg = recv_in__msg;
  ctrl_t p_recv_opt__msg ;
  assign p_recv_opt__msg = recv_opt__msg;
  data_t p_send_out__msg [0:1];
  assign send_out__msg = p_send_out__msg;
  payload_t p_send_to_ctrl_mem__msg ;
  assign send_to_ctrl_mem__msg = p_send_to_ctrl_mem__msg;
  data_t p_to_mem_wdata__msg ;
  assign to_mem_wdata__msg = p_to_mem_wdata__msg;

  localparam data_t const_zero  = '0;
  localparam logic [6:0] OPT_START  = GLOBAL_ADDR_W'(0);
  localparam logic [0:0] latency_at_proceed_latency  = 1'd1;
  localparam logic [6:0] OPT_ADD  = 7'd2;
  localparam logic [6:0] OPT_SUB  = 7'd4;
  localparam logic [6:0] OPT_LT  = 7'd60;
  localparam logic [6:0] OPT_GTE  = 7'd61;
  localparam logic [6:0] OPT_GT  = 7'd62;
  localparam logic [6:0] OPT_LTE  = 7'd63;
  localparam logic [6:0] OPT_MUL  = 7'd7;
  localparam logic [6:0] OPT_MUL_ADD  = 7'd18;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  logic [2:0] in0;
  logic [1:0] in0_idx;
  logic [2:0] in1;
  logic [1:0] in1_idx;
  logic [2:0] in2;
  logic [1:0] in2_idx;
  logic [0:0] latency;
  logic [0:0] reached_vector_factor;
  logic [0:0] recv_all_val;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;

  logic [0:0] fALU_clk;
  logic [15:0] fALU_lhs_0;
  logic [0:0] fALU_reset;
  logic [15:0] fALU_rhs_0;
  logic [15:0] fALU_rhs_1;
  logic [15:0] fALU_rhs_1b;
  logic [5:0] fALU_rhs_2;

  cgra_alu_gen_mac fALU
  (
    .clk( fALU_clk ),
    .lhs_0( fALU_lhs_0 ),
    .reset( fALU_reset ),
    .rhs_0( fALU_rhs_0 ),
    .rhs_1( fALU_rhs_1 ),
    .rhs_1b( fALU_rhs_1b ),
    .rhs_2( fALU_rhs_2 )
  );

  always_comb begin : _lambda__s_fALU_rhs_2
    fALU_rhs_2 = ( p_recv_opt__msg.operation == 7'( OPT_ADD ) ) ? 6'd0 : ( p_recv_opt__msg.operation == 7'( OPT_SUB ) ) ? 6'd1 : ( p_recv_opt__msg.operation == 7'( OPT_LT ) ) ? 6'd3 : ( p_recv_opt__msg.operation == 7'( OPT_GTE ) ) ? 6'd7 : ( p_recv_opt__msg.operation == 7'( OPT_GT ) ) ? 6'd10 : ( p_recv_opt__msg.operation == 7'( OPT_LTE ) ) ? 6'd14 : ( p_recv_opt__msg.operation == 7'( OPT_MUL ) ) ? 6'd16 : ( p_recv_opt__msg.operation == 7'( OPT_MUL_ADD ) ) ? 6'd48 : 6'd0;
  end

  always_comb begin : comb_logic
    recv_all_val = 1'd0;
    in0 = 3'd0;
    in1 = 3'd0;
    in2 = 3'd0;
    for ( int unsigned i = 1'd0; i < 3'( num_inports_at_comb_logic ); i += 1'd1 )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 1'd0; i < 2'( num_outports_at_comb_logic ); i += 1'd1 ) begin
      send_out__val[1'(i)] = 1'd0;
      p_send_out__msg[1'(i)] = '0;
    end
    recv_const__rdy = 1'd0;
    recv_opt__rdy = 1'd0;
    send_to_ctrl_mem__val = 1'd0;
    p_send_to_ctrl_mem__msg = '0;
    recv_from_ctrl_mem__rdy = 1'd0;
    if ( recv_opt__val & send_out__rdy[1'd0] ) begin
      if ( p_recv_opt__msg.fu_in[2'd0] != 3'd0 ) begin
        in0 = p_recv_opt__msg.fu_in[2'd0] - 3'd1;
      end
      if ( p_recv_opt__msg.fu_in[2'd1] != 3'd0 ) begin
        in1 = p_recv_opt__msg.fu_in[2'd1] - 3'd1;
      end
      if ( p_recv_opt__msg.fu_in[2'd2] != 3'd0 ) begin
        in2 = p_recv_opt__msg.fu_in[2'd2] - 3'd1;
      end
    end
    if ( recv_opt__val ) begin
      if ( ( ( ( ( ( ( ( p_recv_opt__msg.operation == 7'( OPT_ADD ) ) | ( p_recv_opt__msg.operation == 7'( OPT_SUB ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_LT ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_GTE ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_GT ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_LTE ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_MUL ) ) ) | ( p_recv_opt__msg.operation == 7'( OPT_MUL_ADD ) ) ) begin
        fALU_rhs_0 = p_recv_in__msg[in0_idx].payload;
        fALU_rhs_1 = p_recv_in__msg[in1_idx].payload;
        fALU_rhs_1b = p_recv_in__msg[in2_idx].payload;
        p_send_out__msg[1'd0].predicate = ( p_recv_in__msg[in0_idx].predicate & p_recv_in__msg[in1_idx].predicate ) & p_recv_in__msg[in2_idx].predicate;
        recv_all_val = ( recv_in__val[in0_idx] & recv_in__val[in1_idx] ) & recv_in__val[in2_idx];
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_in__rdy[in1_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_in__rdy[in2_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_opt__rdy = recv_all_val & send_out__rdy[1'd0];
      end
      else begin
        for ( int unsigned j = 1'd0; j < 2'( num_outports_at_comb_logic ); j += 1'd1 )
          send_out__val[1'(j)] = 1'd0;
        recv_opt__rdy = 1'd0;
        recv_in__rdy[in0_idx] = 1'd0;
        recv_in__rdy[in1_idx] = 1'd0;
        recv_in__rdy[in2_idx] = 1'd0;
      end
      p_send_out__msg[1'd0].payload = fALU_lhs_0;
    end
  end

  always_comb begin : update_mem
    to_mem_waddr__val = 1'd0;
    to_mem_wdata__val = 1'd0;
    p_to_mem_wdata__msg = const_zero;
    to_mem_waddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__val = 1'd0;
    from_mem_rdata__rdy = 1'd0;
  end

  always_comb begin : update_reached_vector_factor
    reached_vector_factor = 1'd0;
    if ( recv_opt__val & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) >= ( 8'd1 << { { 5 { 1'b0 } }, p_recv_opt__msg.vector_factor_power } ) ) ) begin
      reached_vector_factor = 1'd1;
    end
  end

  always_ff @(posedge clk) begin : proceed_latency
    if ( p_recv_opt__msg.operation == 7'( OPT_START ) ) begin
      latency <= 1'd0;
    end
    else if ( latency == ( 1'( latency_at_proceed_latency ) - 1'd1 ) ) begin
      latency <= 1'd0;
    end
    else
      latency <= latency + 1'd1;
  end

  always_ff @(posedge clk) begin : update_vector_factor_counter
    if ( reset ) begin
      vector_factor_counter <= 8'd0;
    end
    else if ( recv_opt__val ) begin
      if ( p_recv_opt__msg.is_last_ctrl & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) < ( 8'd1 << { { 5 { 1'b0 } }, p_recv_opt__msg.vector_factor_power } ) ) ) begin
        vector_factor_counter <= vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } );
      end
      else if ( p_recv_opt__msg.is_last_ctrl & reached_vector_factor ) begin
        vector_factor_counter <= 8'd0;
      end
    end
  end

  assign vector_factor_power = 3'd0;
  assign fALU_clk = clk;
  assign fALU_reset = reset;
  assign in0_idx = in0[1:0];
  assign in1_idx = in1[1:0];
  assign in2_idx = in2[1:0];

endmodule
