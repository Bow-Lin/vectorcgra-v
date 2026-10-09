`include "cgra_profile_defs.svh"
// Native InclusiveDivRTL migration from ac96; original state/handshake semantics.
module scalar_inclusive_div #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int VECTOR_FACTOR_POWER = 0,
  parameter int LATENCY = 2
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
  localparam int CTRL_SLOTS = 1 << CTRL_ADDR_W;
  initial if (DATA_W != 32 || LATENCY < 1) $fatal(1, "ac96 pipeline divider requires DATA_W=32 and positive LATENCY");
  data_t from_mem_rdata__msg_typed ;
  assign from_mem_rdata__msg_typed = from_mem_rdata__msg;
  data_t recv_const__msg_typed ;
  assign recv_const__msg_typed = recv_const__msg;
  payload_t recv_from_ctrl_mem__msg_typed ;
  assign recv_from_ctrl_mem__msg_typed = recv_from_ctrl_mem__msg;
  data_t recv_in__msg_typed [0:3];
  assign recv_in__msg_typed = recv_in__msg;
  ctrl_t recv_opt__msg_typed ;
  assign recv_opt__msg_typed = recv_opt__msg;
  data_t send_out__msg_typed [0:1];
  assign send_out__msg = send_out__msg_typed;
  payload_t send_to_ctrl_mem__msg_typed ;
  assign send_to_ctrl_mem__msg = send_to_ctrl_mem__msg_typed;
  data_t to_mem_wdata__msg_typed ;
  assign to_mem_wdata__msg = to_mem_wdata__msg_typed;

  localparam data_t const_zero  = '0;
  localparam logic [6:0] OPT_START  = 7'd0;
  localparam int latency_at_proceed_latency = LATENCY;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_DIV_INCLUSIVE_START  = 7'd48;
  localparam logic [6:0] OPT_REM_INCLUSIVE_START  = 7'd59;
  localparam logic [6:0] OPT_DIV_INCLUSIVE_END  = 7'd49;
  localparam logic [6:0] OPT_REM_INCLUSIVE_END  = 7'd15;
  logic [2:0] in0;
  logic [1:0] in0_idx;
  logic [2:0] in1;
  logic [1:0] in1_idx;
  logic [$clog2(LATENCY+1)-1:0] latency;
  logic [0:0] reached_vector_factor;
  logic [0:0] recv_all_val;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;

  logic [0:0] div_clk;
  logic [DATA_W-1:0] div_dividend;
  logic [DATA_W-1:0] div_divisor;
  logic [DATA_W-1:0] div_quotient;
  logic [DATA_W-1:0] div_remainder;
  logic [0:0] div_reset;

  scalar_div_pipeline #(.WIDTH(32), .CYCLE(LATENCY)) div (
    .clk( div_clk ),
    .dividend( div_dividend ),
    .divisor( div_divisor ),
    .quotient( div_quotient ),
    .remainder( div_remainder ),
    .reset( div_reset )
  );

  always_comb begin : comb_logic
    recv_all_val = 1'd0;
    in0 = 3'd0;
    in1 = 3'd0;
    for ( int unsigned i = 1'd0; i < 3'( num_inports_at_comb_logic ); i += 1'd1 )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 1'd0; i < 2'( num_outports_at_comb_logic ); i += 1'd1 ) begin
      send_out__val[1'(i)] = 1'd0;
      send_out__msg_typed[1'(i)] = '0;
    end
    recv_const__rdy = 1'd0;
    recv_opt__rdy = 1'd0;
    send_to_ctrl_mem__val = 1'd0;
    send_to_ctrl_mem__msg_typed = '0;
    recv_from_ctrl_mem__rdy = 1'd0;
    if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.fu_in[2'd0] != 3'd0 ) begin
        in0 = recv_opt__msg_typed.fu_in[2'd0] - 3'd1;
      end
      if ( recv_opt__msg_typed.fu_in[2'd1] != 3'd0 ) begin
        in1 = recv_opt__msg_typed.fu_in[2'd1] - 3'd1;
      end
    end
    if ( recv_opt__val ) begin
      if ( ( recv_opt__msg_typed.operation == 7'( OPT_DIV_INCLUSIVE_START ) ) | ( recv_opt__msg_typed.operation == 7'( OPT_REM_INCLUSIVE_START ) ) ) begin
        div_dividend = recv_in__msg_typed[in0_idx].payload;
        div_divisor = recv_in__msg_typed[in1_idx].payload;
        send_out__msg_typed[1'd0].payload = DATA_W'(0);
        send_out__msg_typed[1'd0].predicate = ( recv_in__msg_typed[in0_idx].predicate & recv_in__msg_typed[in1_idx].predicate ) & reached_vector_factor;
        recv_all_val = recv_in__val[in0_idx] & recv_in__val[in1_idx];
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val;
        recv_opt__rdy = recv_all_val & send_out__rdy[1'd0];
      end
      else if ( ( recv_opt__msg_typed.operation == 7'( OPT_DIV_INCLUSIVE_END ) ) | ( recv_opt__msg_typed.operation == 7'( OPT_REM_INCLUSIVE_END ) ) ) begin
        if ( recv_opt__msg_typed.operation == 7'( OPT_DIV_INCLUSIVE_END ) ) begin
          send_out__msg_typed[1'd0].payload = div_quotient;
        end
        else
          send_out__msg_typed[1'd0].payload = div_remainder;
        send_out__msg_typed[1'd0].predicate = ( recv_in__msg_typed[in0_idx].predicate & recv_in__msg_typed[in1_idx].predicate ) & reached_vector_factor;
        recv_all_val = recv_in__val[in0_idx] & recv_in__val[in1_idx];
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val & send_out__rdy[1'd0];
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

  always_comb begin : update_mem
    to_mem_waddr__val = 1'd0;
    to_mem_wdata__val = 1'd0;
    to_mem_wdata__msg_typed = const_zero;
    to_mem_waddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__val = 1'd0;
    from_mem_rdata__rdy = 1'd0;
  end

  always_comb begin : update_reached_vector_factor
    reached_vector_factor = 1'd0;
    if ( recv_opt__val & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) >= ( 8'd1 << { { 5 { 1'b0 } }, recv_opt__msg_typed.vector_factor_power } ) ) ) begin
      reached_vector_factor = 1'd1;
    end
  end

  always_ff @(posedge clk) begin : proceed_latency
    if ( recv_opt__msg_typed.operation == 7'( OPT_START ) ) begin
      latency <= 2'd0;
    end
    else if ( latency == ( ($clog2(LATENCY)+1)'( latency_at_proceed_latency ) - 2'd1 ) ) begin
      latency <= 2'd0;
    end
    else
      latency <= latency + 2'd1;
  end

  always_ff @(posedge clk) begin : update_vector_factor_counter
    if ( reset ) begin
      vector_factor_counter <= 8'd0;
    end
    else if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.is_last_ctrl & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) < ( 8'd1 << { { 5 { 1'b0 } }, recv_opt__msg_typed.vector_factor_power } ) ) ) begin
        vector_factor_counter <= vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } );
      end
      else if ( recv_opt__msg_typed.is_last_ctrl & reached_vector_factor ) begin
        vector_factor_counter <= 8'd0;
      end
    end
  end

  assign vector_factor_power = 3'(VECTOR_FACTOR_POWER);
  assign div_clk = clk;
  assign div_reset = reset;
  assign in0_idx = in0[1:0];
  assign in1_idx = in1[1:0];

endmodule
