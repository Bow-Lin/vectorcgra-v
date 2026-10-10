`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// Native LoopControlRTL migration from ac96; original state/handshake semantics.
module scalar_loop_control #(
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
  localparam int CTRL_SLOTS = 1 << CTRL_ADDR_W;
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
  localparam logic [6:0] OPT_START  = `CGRA_OPT_START;
  localparam logic [0:0] latency_at_proceed_latency  = 1'd1;
  localparam logic [6:0] OPT_LOOP_CONTROL  = `CGRA_OPT_LOOP_CONTROL;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  logic [DATA_W-1:0] current_index;
  logic [DATA_W-1:0] end_value;
  logic [2:0] in0;
  logic [2:0] in0_idx;
  logic [2:0] in1;
  logic [2:0] in1_idx;
  logic [2:0] in2;
  logic [2:0] in2_idx;
  logic [2:0] in3;
  logic [2:0] in3_idx;
  logic [0:0] is_first_iter;
  logic [0:0] latency;
  logic [0:0] loop_active;
  logic [0:0] loop_initialized_reg;
  logic [0:0] loop_valid;
  logic [DATA_W-1:0] next_index;
  logic [0:0] reached_vector_factor;
  logic [DATA_W-1:0] start_value;
  logic [DATA_W-1:0] step_value;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;
  logic [1:0] update_index_in0_idx_ff;
  logic [1:0] update_index_in1_idx_ff;
  logic [1:0] update_index_in2_idx_ff;
  logic [1:0] update_index_in3_idx_ff;
  logic [1:0] comb_logic_in0_idx_local;
  logic [1:0] comb_logic_in1_idx_local;
  logic [1:0] comb_logic_in2_idx_local;
  logic [1:0] comb_logic_in3_idx_local;
  logic [0:0] comb_logic_all_inputs_valid;
  logic [0:0] comb_logic_all_outputs_ready;
  logic [0:0] comb_logic_parent_valid;
  logic [DATA_W-1:0] comb_logic_current_idx;
  logic [DATA_W-1:0] comb_logic_output_idx;

  always_comb begin : comb_logic
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
    loop_valid = 1'd0;
    loop_active = 1'd0;
    is_first_iter = 1'd0;
    next_index = DATA_W'(0);
    start_value = DATA_W'(0);
    end_value = DATA_W'(0);
    step_value = DATA_W'(1);
    comb_logic_in0_idx_local = 2'(in0_idx);
    comb_logic_in1_idx_local = 2'(in1_idx);
    comb_logic_in2_idx_local = 2'(in2_idx);
    comb_logic_in3_idx_local = 2'(in3_idx);
    if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.fu_in[2'd0] != 3'd0 ) begin
        in0 = recv_opt__msg_typed.fu_in[2'd0] - 3'd1;
        comb_logic_in0_idx_local = 2'(recv_opt__msg_typed.fu_in[2'd0] - 3'd1);
      end
      if ( recv_opt__msg_typed.fu_in[2'd1] != 3'd0 ) begin
        in1 = recv_opt__msg_typed.fu_in[2'd1] - 3'd1;
        comb_logic_in1_idx_local = 2'(recv_opt__msg_typed.fu_in[2'd1] - 3'd1);
      end
      if ( recv_opt__msg_typed.fu_in[2'd2] != 3'd0 ) begin
        in2 = recv_opt__msg_typed.fu_in[2'd2] - 3'd1;
        comb_logic_in2_idx_local = 2'(recv_opt__msg_typed.fu_in[2'd2] - 3'd1);
      end
      if ( recv_opt__msg_typed.fu_in[2'd3] != 3'd0 ) begin
        in3 = recv_opt__msg_typed.fu_in[2'd3] - 3'd1;
        comb_logic_in3_idx_local = 2'(recv_opt__msg_typed.fu_in[2'd3] - 3'd1);
      end
    end
    comb_logic_all_inputs_valid = ( ( ( ( ( recv_opt__val & ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_CONTROL ) ) ) & recv_in__val[comb_logic_in0_idx_local] ) & recv_in__val[comb_logic_in1_idx_local] ) & recv_in__val[comb_logic_in2_idx_local] ) & recv_in__val[comb_logic_in3_idx_local] ) & send_out__rdy[1'd0];
    comb_logic_all_outputs_ready = send_out__rdy[1'd0] & send_out__rdy[1'd1];
    if ( comb_logic_all_inputs_valid ) begin
      comb_logic_parent_valid = recv_in__msg_typed[comb_logic_in0_idx_local].predicate;
      start_value = recv_in__msg_typed[comb_logic_in1_idx_local].payload;
      end_value = recv_in__msg_typed[comb_logic_in2_idx_local].payload;
      step_value = recv_in__msg_typed[comb_logic_in3_idx_local].payload;
      is_first_iter = ~loop_initialized_reg;
      comb_logic_current_idx = current_index;
      if ( is_first_iter ) begin
        comb_logic_output_idx = start_value;
        next_index = start_value + step_value;
        if ( start_value < end_value ) begin
          loop_active = 1'd1;
          loop_valid = comb_logic_parent_valid;
        end
        else begin
          loop_active = 1'd0;
          loop_valid = 1'd0;
        end
      end
      else begin
        comb_logic_output_idx = comb_logic_current_idx;
        next_index = comb_logic_current_idx + step_value;
        if ( comb_logic_current_idx < end_value ) begin
          loop_active = 1'd1;
          loop_valid = comb_logic_parent_valid;
        end
        else begin
          loop_active = 1'd0;
          loop_valid = 1'd0;
        end
      end
      send_out__msg_typed[1'd0].payload = comb_logic_output_idx;
      send_out__msg_typed[1'd0].predicate = loop_valid & reached_vector_factor;
      send_out__val[1'd0] = 1'd1;
      send_out__msg_typed[1'd1].payload = { { (DATA_W-1) { 1'b0 } }, loop_valid };
      send_out__msg_typed[1'd1].predicate = reached_vector_factor;
      send_out__val[1'd1] = 1'd1;
      recv_in__rdy[comb_logic_in0_idx_local] = 1'd1;
      recv_in__rdy[comb_logic_in1_idx_local] = 1'd1;
      recv_in__rdy[comb_logic_in2_idx_local] = 1'd1;
      recv_in__rdy[comb_logic_in3_idx_local] = 1'd1;
      recv_opt__rdy = comb_logic_all_outputs_ready;
    end
  end

  always_comb begin : update_indices
    in0_idx = in0;
    in1_idx = in1;
    in2_idx = in2;
    in3_idx = in3;
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
      latency <= 1'd0;
    end
    else if ( latency == ( 1'( latency_at_proceed_latency ) - 1'd1 ) ) begin
      latency <= 1'd0;
    end
    else
      latency <= latency + 1'd1;
  end

  always_ff @(posedge clk) begin : update_index
    if ( reset ) begin
      current_index <= DATA_W'(0);
      loop_initialized_reg <= 1'd0;
    end
    else begin
      update_index_in0_idx_ff = 2'(in0);
      update_index_in1_idx_ff = 2'(in1);
      update_index_in2_idx_ff = 2'(in2);
      update_index_in3_idx_ff = 2'(in3);
      if ( recv_opt__val & ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_CONTROL ) ) ) begin
        if ( recv_opt__msg_typed.fu_in[2'd0] != 3'd0 ) begin
          update_index_in0_idx_ff = 2'(recv_opt__msg_typed.fu_in[2'd0] - 3'd1);
        end
        if ( recv_opt__msg_typed.fu_in[2'd1] != 3'd0 ) begin
          update_index_in1_idx_ff = 2'(recv_opt__msg_typed.fu_in[2'd1] - 3'd1);
        end
        if ( recv_opt__msg_typed.fu_in[2'd2] != 3'd0 ) begin
          update_index_in2_idx_ff = 2'(recv_opt__msg_typed.fu_in[2'd2] - 3'd1);
        end
        if ( recv_opt__msg_typed.fu_in[2'd3] != 3'd0 ) begin
          update_index_in3_idx_ff = 2'(recv_opt__msg_typed.fu_in[2'd3] - 3'd1);
        end
      end
      if ( ( ( ( ( ( recv_opt__val & ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_CONTROL ) ) ) & recv_in__val[update_index_in0_idx_ff] ) & recv_in__val[update_index_in1_idx_ff] ) & recv_in__val[update_index_in2_idx_ff] ) & recv_in__val[update_index_in3_idx_ff] ) & send_out__rdy[1'd0] ) begin
        current_index <= next_index;
        if ( ~loop_initialized_reg ) begin
          loop_initialized_reg <= 1'd1;
        end
      end
    end
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

endmodule
