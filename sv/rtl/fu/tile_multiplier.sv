`include "cgra_opcodes.svh"
// Native parameterized scalar profile; migrated from ac96 MulRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_multiplier #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
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
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val  
);
  `include "cgra_profile.svh"
  data_t from_mem_rdata__msg_typed ;
  assign from_mem_rdata__msg_typed = from_mem_rdata__msg;
  data_t recv_const__msg_typed ;
  assign recv_const__msg_typed = recv_const__msg;
  data_t recv_in__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_recv_in__msg
    assign recv_in__msg_typed[p] = recv_in__msg[p];
  end
  data_t send_out__msg_typed [0:1];
  for (genvar p=0; p<=1; p++) begin : port_send_out__msg
    assign send_out__msg[p] = send_out__msg_typed[p];
  end
  data_t to_mem_wdata__msg_typed ;
  assign to_mem_wdata__msg = to_mem_wdata__msg_typed;
  ctrl_t recv_opt__msg_typed ;
  assign recv_opt__msg_typed = recv_opt__msg;
  payload_t recv_from_ctrl_mem__msg_typed ;
  assign recv_from_ctrl_mem__msg_typed = recv_from_ctrl_mem__msg;
  payload_t send_to_ctrl_mem__msg_typed ;
  assign send_to_ctrl_mem__msg = send_to_ctrl_mem__msg_typed;
  localparam data_t const_zero  = '0;
  localparam logic [6:0] OPT_START  = `CGRA_OPT_START;
  localparam logic [0:0] latency_at_proceed_latency  = 1'd1;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_MUL  = `CGRA_OPT_MUL;
  localparam logic [6:0] OPT_MUL_CONST  = `CGRA_OPT_MUL_CONST;
  logic [2:0] in0;
  logic [1:0] in0_idx;
  logic [2:0] in1;
  logic [1:0] in1_idx;
  logic [0:0] latency;
  logic [0:0] reached_vector_factor;
  logic [0:0] recv_all_val;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;
  always_comb begin : comb_logic
    recv_all_val = 1'd0;
    in0 = 3'd0;
    in1 = 3'd0;
    for ( int unsigned i = 0; i < 3'( num_inports_at_comb_logic ); i++ )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 0; i < 2'( num_outports_at_comb_logic ); i++ ) begin
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
      if ( recv_opt__msg_typed.operation == 7'( OPT_MUL ) ) begin
        send_out__msg_typed[1'd0].payload = recv_in__msg_typed[in0_idx].payload * recv_in__msg_typed[in1_idx].payload;
        send_out__msg_typed[1'd0].predicate = ( recv_in__msg_typed[in0_idx].predicate & recv_in__msg_typed[in1_idx].predicate ) & reached_vector_factor;
        recv_all_val = recv_in__val[in0_idx] & recv_in__val[in1_idx];
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_in__rdy[in1_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_opt__rdy = recv_all_val & send_out__rdy[1'd0];
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_MUL_CONST ) ) begin
        send_out__msg_typed[1'd0].payload = recv_in__msg_typed[in0_idx].payload * recv_const__msg_typed.payload;
        send_out__msg_typed[1'd0].predicate = recv_in__msg_typed[in0_idx].predicate & reached_vector_factor;
        recv_all_val = recv_in__val[in0_idx] & recv_const__val;
        send_out__val[1'd0] = recv_all_val;
        recv_in__rdy[in0_idx] = recv_all_val & send_out__rdy[1'd0];
        recv_const__rdy = recv_all_val & send_out__rdy[1'd0];
        recv_opt__rdy = recv_all_val & send_out__rdy[1'd0];
      end
      else begin
        for ( int unsigned j = 0; j < 2'( num_outports_at_comb_logic ); j++ )
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
    to_mem_waddr__msg = 7'd0;
    to_mem_raddr__msg = 7'd0;
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
      if ( recv_opt__msg_typed.is_last_ctrl & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) < ( 8'd1 << { { 5 { 1'b0 } }, recv_opt__msg_typed.vector_factor_power } ) ) ) begin
        vector_factor_counter <= vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } );
      end
      else if ( recv_opt__msg_typed.is_last_ctrl & reached_vector_factor ) begin
        vector_factor_counter <= 8'd0;
      end
    end
  end
  assign vector_factor_power = 3'd0;
  assign in0_idx = in0[1:0];
  assign in1_idx = in1[1:0];
endmodule
