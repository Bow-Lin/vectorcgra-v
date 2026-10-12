`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// Native LoopCounterRTL migration from ac96; original state/handshake semantics.
module scalar_loop_counter #(
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
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_LOOP_COUNT  = `CGRA_OPT_LOOP_COUNT;
  localparam logic [4:0] CMD_LEAF_COUNTER_COMPLETE  = 5'd31;
  localparam logic [6:0] OPT_LOOP_DELIVERY  = `CGRA_OPT_LOOP_DELIVERY;
  localparam logic [4:0] CMD_RESET_LEAF_COUNTER  = 5'd27;
  localparam logic [4:0] CMD_UPDATE_COUNTER_SHADOW_VALUE  = 5'd26;
  localparam logic [4:0] CMD_CONFIG_LOOP_LOWER  = 5'd28;
  localparam logic [4:0] CMD_CONFIG_LOOP_UPPER  = 5'd29;
  localparam logic [4:0] CMD_CONFIG_LOOP_STEP  = 5'd30;
  localparam int ctrl_mem_size_at_update_leaf_counters = CTRL_SLOTS;
  localparam int ctrl_mem_size_at_update_shadow_registers = CTRL_SLOTS;
  localparam int ctrl_mem_size_at_update_already_done = CTRL_SLOTS;
  logic [0:0] already_done [0:CTRL_SLOTS-1];
  logic [0:0] cmd_config_lower;
  logic [0:0] cmd_config_step;
  logic [0:0] cmd_config_upper;
  logic [0:0] cmd_reset_counter;
  logic [0:0] cmd_update_shadow;
  logic [CTRL_ADDR_W-1:0] current_ctrl_addr;
  logic [0:0] latency;
  data_t leaf_current_value [0:CTRL_SLOTS-1];
  data_t leaf_lower_bound [0:CTRL_SLOTS-1];
  data_t leaf_step [0:CTRL_SLOTS-1];
  data_t leaf_upper_bound [0:CTRL_SLOTS-1];
  logic [0:0] loop_terminated;
  logic [0:0] reached_vector_factor;
  data_t shadow_regs [0:CTRL_SLOTS-1];
  logic [0:0] shadow_valid [0:CTRL_SLOTS-1];
  logic [CTRL_ADDR_W-1:0] target_ctrl_addr;
  data_t target_ctrl_data;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;
  logic [CTRL_ADDR_W-1:0] comb_logic_addr;
  logic [CTRL_ADDR_W-1:0] update_leaf_counters_addr;
  logic [CTRL_ADDR_W-1:0] update_shadow_registers_addr;
  logic [CTRL_ADDR_W-1:0] update_already_done_addr;

  always_comb begin : comb_logic
    comb_logic_addr='0;
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
    current_ctrl_addr = ctrl_addr_inport;
    loop_terminated = leaf_current_value[current_ctrl_addr].payload >= leaf_upper_bound[current_ctrl_addr].payload;
    cmd_reset_counter = 1'd0;
    cmd_update_shadow = 1'd0;
    cmd_config_lower = 1'd0;
    cmd_config_upper = 1'd0;
    cmd_config_step = 1'd0;
    target_ctrl_addr = CTRL_ADDR_W'(0);
    target_ctrl_data = '0;
    if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_COUNT ) ) begin
        comb_logic_addr = current_ctrl_addr;
        recv_const__rdy = 1'd0;
        send_out__msg_typed[1'd0].payload = leaf_current_value[comb_logic_addr].payload;
        if ( loop_terminated ) begin
          send_out__msg_typed[1'd0].predicate = 1'd0;
          if ( ~already_done[comb_logic_addr] ) begin
            send_to_ctrl_mem__val = 1'd1;
            send_to_ctrl_mem__msg_typed = { 6'( CMD_LEAF_COUNTER_COMPLETE ), { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, GLOBAL_ADDR_W'(0), recv_opt__msg_typed, comb_logic_addr };
            send_out__val[1'd0] = 1'd1;
            recv_opt__rdy = send_to_ctrl_mem__rdy & send_out__rdy[1'd0];
          end
          else begin
            send_out__val[1'd0] = 1'd1;
            recv_opt__rdy = send_out__rdy[1'd0];
          end
        end
        else begin
          send_out__msg_typed[1'd0].predicate = 1'd1;
          send_out__val[1'd0] = 1'd1;
          recv_opt__rdy = send_out__rdy[1'd0];
        end
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_DELIVERY ) ) begin
        comb_logic_addr = current_ctrl_addr;
        if ( shadow_valid[comb_logic_addr] ) begin
          send_out__val[1'd0] = 1'd1;
          send_out__msg_typed[1'd0] = shadow_regs[comb_logic_addr];
          recv_opt__rdy = send_out__rdy[1'd0];
        end
        else begin
          send_out__val[1'd0] = 1'd0;
          recv_opt__rdy = 1'd0;
        end
      end
    end
    if ( recv_from_ctrl_mem__val ) begin
      recv_from_ctrl_mem__rdy = 1'd1;
      target_ctrl_addr = recv_from_ctrl_mem__msg_typed.ctrl_addr;
      target_ctrl_data = recv_from_ctrl_mem__msg_typed.data;
      if ( recv_from_ctrl_mem__msg_typed.cmd == 6'( CMD_RESET_LEAF_COUNTER ) ) begin
        cmd_reset_counter = 1'd1;
      end
      else if ( recv_from_ctrl_mem__msg_typed.cmd == 6'( CMD_UPDATE_COUNTER_SHADOW_VALUE ) ) begin
        cmd_update_shadow = 1'd1;
      end
      else if ( recv_from_ctrl_mem__msg_typed.cmd == 6'( CMD_CONFIG_LOOP_LOWER ) ) begin
        cmd_config_lower = 1'd1;
      end
      else if ( recv_from_ctrl_mem__msg_typed.cmd == 6'( CMD_CONFIG_LOOP_UPPER ) ) begin
        cmd_config_upper = 1'd1;
      end
      else if ( recv_from_ctrl_mem__msg_typed.cmd == 6'( CMD_CONFIG_LOOP_STEP ) ) begin
        cmd_config_step = 1'd1;
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
      latency <= 1'd0;
    end
    else if ( latency == ( 1'( latency_at_proceed_latency ) - 1'd1 ) ) begin
      latency <= 1'd0;
    end
    else
      latency <= latency + 1'd1;
  end

  always_ff @(posedge clk) begin : update_already_done
    if ( reset | clear ) begin
      for ( int unsigned i = 1'd0; i < ctrl_mem_size_at_update_already_done; i += 1'd1 )
        already_done[CTRL_ADDR_W'(i)] <= 1'd0;
    end
    else begin
      if ( ( ( ( ( recv_opt__val & ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_COUNT ) ) ) & ( ~already_done[current_ctrl_addr] ) ) & loop_terminated ) & send_to_ctrl_mem__val ) & send_to_ctrl_mem__rdy ) begin
        update_already_done_addr = current_ctrl_addr;
        already_done[update_already_done_addr] <= 1'd1;
      end
      if ( cmd_reset_counter ) begin
        update_already_done_addr = target_ctrl_addr;
        already_done[update_already_done_addr] <= 1'd0;
      end
    end
  end

  always_ff @(posedge clk) begin : update_leaf_counters
    if ( reset | clear ) begin
      for ( int unsigned i = 1'd0; i < ctrl_mem_size_at_update_leaf_counters; i += 1'd1 ) begin
        leaf_lower_bound[CTRL_ADDR_W'(i)] <= '0;
        leaf_upper_bound[CTRL_ADDR_W'(i)] <= '0;
        leaf_step[CTRL_ADDR_W'(i)] <= '0;
        leaf_current_value[CTRL_ADDR_W'(i)] <= '0;
      end
    end
    else begin
      if ( cmd_config_lower ) begin
        leaf_lower_bound[target_ctrl_addr] <= target_ctrl_data;
        leaf_current_value[target_ctrl_addr] <= target_ctrl_data;
      end
      if ( cmd_config_upper ) begin
        leaf_upper_bound[target_ctrl_addr] <= target_ctrl_data;
      end
      if ( cmd_config_step ) begin
        leaf_step[target_ctrl_addr] <= target_ctrl_data;
      end
      if ( recv_opt__val & ( recv_opt__msg_typed.operation == 7'( OPT_LOOP_COUNT ) ) ) begin
        update_leaf_counters_addr = current_ctrl_addr;
        if ( ( send_out__val[1'd0] & send_out__rdy[1'd0] ) & ( ~loop_terminated ) ) begin
          leaf_current_value[update_leaf_counters_addr] <= { leaf_current_value[update_leaf_counters_addr].payload + leaf_step[update_leaf_counters_addr].payload, 1'd1, 1'd0, 1'd0 };
        end
      end
      if ( cmd_reset_counter ) begin
        update_leaf_counters_addr = target_ctrl_addr;
        leaf_current_value[update_leaf_counters_addr] <= leaf_lower_bound[update_leaf_counters_addr];
      end
    end
  end

  always_ff @(posedge clk) begin : update_shadow_registers
    if ( reset | clear ) begin
      for ( int unsigned i = 1'd0; i < ctrl_mem_size_at_update_shadow_registers; i += 1'd1 ) begin
        shadow_regs[CTRL_ADDR_W'(i)] <= '0;
        shadow_valid[CTRL_ADDR_W'(i)] <= 1'd0;
      end
    end
    else if ( cmd_update_shadow ) begin
      update_shadow_registers_addr = target_ctrl_addr;
      shadow_regs[update_shadow_registers_addr] <= target_ctrl_data;
      shadow_valid[update_shadow_registers_addr] <= 1'd1;
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
