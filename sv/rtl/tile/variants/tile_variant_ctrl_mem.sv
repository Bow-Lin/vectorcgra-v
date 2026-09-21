// Native parameterized scalar profile; migrated from ac96 CtrlMemDynamicRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_variant_ctrl_mem #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] cgra_id ,
  input  logic [0:0] clk ,
  output logic [CTRL_ADDR_W-1:0] ctrl_addr_outport ,
  output logic [2:0] prologue_count_outport_fu ,
  output logic [2:0] prologue_count_outport_fu_crossbar [0:CTRL_DEPTH-1][0:1],
  output logic [2:0] prologue_count_outport_routing_crossbar [0:CTRL_DEPTH-1][0:ROUTING_OUTPUTS-1],
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [PAYLOAD_BITS-1:0] recv_from_element__msg ,
  output logic [0:0] recv_from_element__rdy  ,
  input logic [0:0] recv_from_element__val  ,
  input logic [HOST_BITS-1:0] recv_pkt_from_controller__msg ,
  output logic [0:0] recv_pkt_from_controller__rdy  ,
  input logic [0:0] recv_pkt_from_controller__val  ,
  output logic [CTRL_BITS-1:0] send_ctrl__msg ,
  input logic [0:0] send_ctrl__rdy  ,
  output logic [0:0] send_ctrl__val  ,
  output logic [HOST_BITS-1:0] send_pkt_to_controller__msg ,
  input logic [0:0] send_pkt_to_controller__rdy  ,
  output logic [0:0] send_pkt_to_controller__val  ,
  output logic [PAYLOAD_BITS-1:0] send_to_element__msg ,
  input logic [0:0] send_to_element__rdy  ,
  output logic [0:0] send_to_element__val  
);
  `include "cgra_profile.svh"
  localparam int PC_W=$clog2(NUM_CTRL+1);
  localparam int BOUND_W=$clog2(CTRL_DEPTH+1);
  ctrl_t send_ctrl__msg_typed ;
  assign send_ctrl__msg = send_ctrl__msg_typed;
  payload_t recv_from_element__msg_typed ;
  assign recv_from_element__msg_typed = recv_from_element__msg;
  payload_t send_to_element__msg_typed ;
  assign send_to_element__msg = send_to_element__msg_typed;
  host_packet_t recv_pkt_from_controller__msg_typed ;
  assign recv_pkt_from_controller__msg_typed = recv_pkt_from_controller__msg;
  host_packet_t send_pkt_to_controller__msg_typed ;
  assign send_pkt_to_controller__msg = send_pkt_to_controller__msg_typed;
  localparam logic [2:0] num_fu_inports_at_update_msg  = 3'd4;
  localparam int num_routing_outports_at_update_msg = ROUTING_OUTPUTS;
  localparam logic [1:0] CMD_CONFIG  = 2'd3;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD_RESPONSE  = 5'd20;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_MUL_RESPONSE  = 5'd21;
  localparam logic [4:0] CMD_CONFIG_LOOP_LOWER  = 5'd28;
  localparam logic [4:0] CMD_CONFIG_LOOP_UPPER  = 5'd29;
  localparam logic [4:0] CMD_CONFIG_LOOP_STEP  = 5'd30;
  localparam logic [4:0] CMD_UPDATE_COUNTER_SHADOW_VALUE  = 5'd26;
  localparam logic [4:0] CMD_RESET_LEAF_COUNTER  = 5'd27;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU  = 3'd4;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU_CROSSBAR  = 3'd5;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR  = 3'd6;
  localparam logic [0:0] CMD_LAUNCH  = 1'd0;
  localparam logic [1:0] CMD_TERMINATE  = 2'd2;
  localparam logic [0:0] CMD_PAUSE  = 1'd1;
  localparam logic [4:0] CMD_PRESERVE  = 5'd22;
  localparam logic [3:0] CMD_RESUME  = 4'd15;
  localparam logic [2:0] CMD_CONFIG_TOTAL_CTRL_COUNT  = 3'd7;
  localparam logic [3:0] CMD_CONFIG_COUNT_PER_ITER  = 4'd8;
  localparam logic [3:0] CMD_CONFIG_CTRL_LOWER_BOUND  = 4'd9;
  localparam logic [4:0] CMD_RECORD_PHI_ADDR  = 5'd16;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_START_ADDR  = 5'd23;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_STRIDE  = 5'd24;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_END_ADDR  = 5'd25;
  localparam logic [3:0] CMD_COMPLETE  = 4'd14;
  localparam logic [6:0] OPT_START  = 7'd0;
  localparam logic [2:0] num_fu_inports_at_update_send_ctrl_msg  = 3'd4;
  localparam int num_routing_outports_at_update_send_ctrl_msg = ROUTING_OUTPUTS;
  localparam logic [6:0] OPT_NAH  = 7'd1;
  localparam int num_routing_xbar_inports_at_update_prologue_outport = ROUTING_OUTPUTS;
  localparam logic [1:0] num_fu_outports_at_update_prologue_outport  = 2'd2;
  localparam int num_routing_xbar_inports_at_update_prologue_reg = ROUTING_OUTPUTS;
  localparam logic [1:0] num_fu_outports_at_update_prologue_reg  = 2'd2;
  logic [CTRL_ADDR_W-1:0] ctrl_count_lower_bound;
  logic [PC_W-1:0] ctrl_count_per_iter_val;
  logic [BOUND_W-1:0] ctrl_count_upper_bound;
  logic [2:0] prologue_count_reg_fu [0:CTRL_DEPTH-1];
  logic [2:0] prologue_count_reg_fu_crossbar [0:CTRL_DEPTH-1][0:1];
  logic [2:0] prologue_count_reg_routing_crossbar [0:CTRL_DEPTH-1][0:ROUTING_OUTPUTS-1];
  logic [0:0] sent_complete;
  logic [0:0] start_iterate_ctrl;
  logic [10:0] times;
  logic [10:0] total_ctrl_steps_val;
  logic [0:0] recv_from_element_queue__clk;
  logic [1:0] recv_from_element_queue__count;
  logic [0:0] recv_from_element_queue__reset;
  payload_t recv_from_element_queue__recv__msg;
  logic [0:0] recv_from_element_queue__recv__rdy;
  logic [0:0] recv_from_element_queue__recv__val;
  payload_t recv_from_element_queue__send__msg;
  logic [0:0] recv_from_element_queue__send__rdy;
  logic [0:0] recv_from_element_queue__send__val;
  cgra_queue #(.WIDTH(PAYLOAD_BITS), .DEPTH(2)) recv_from_element_queue (
    .clear(1'b0),
    .clk( recv_from_element_queue__clk ),
    .count( recv_from_element_queue__count ),
    .reset( recv_from_element_queue__reset ),
    .recv_msg( recv_from_element_queue__recv__msg ),
    .recv_rdy( recv_from_element_queue__recv__rdy ),
    .recv_val( recv_from_element_queue__recv__val ),
    .send_msg( recv_from_element_queue__send__msg ),
    .send_rdy( recv_from_element_queue__send__rdy ),
    .send_val( recv_from_element_queue__send__val )
  );
  logic [0:0] recv_pkt_from_controller_queue__clk;
  logic [1:0] recv_pkt_from_controller_queue__count;
  logic [0:0] recv_pkt_from_controller_queue__reset;
  host_packet_t recv_pkt_from_controller_queue__recv__msg;
  logic [0:0] recv_pkt_from_controller_queue__recv__rdy;
  logic [0:0] recv_pkt_from_controller_queue__recv__val;
  host_packet_t recv_pkt_from_controller_queue__send__msg;
  logic [0:0] recv_pkt_from_controller_queue__send__rdy;
  logic [0:0] recv_pkt_from_controller_queue__send__val;
  cgra_queue #(.WIDTH(HOST_BITS), .DEPTH(2)) recv_pkt_from_controller_queue (
    .clear(1'b0),
    .clk( recv_pkt_from_controller_queue__clk ),
    .count( recv_pkt_from_controller_queue__count ),
    .reset( recv_pkt_from_controller_queue__reset ),
    .recv_msg( recv_pkt_from_controller_queue__recv__msg ),
    .recv_rdy( recv_pkt_from_controller_queue__recv__rdy ),
    .recv_val( recv_pkt_from_controller_queue__recv__val ),
    .send_msg( recv_pkt_from_controller_queue__send__msg ),
    .send_rdy( recv_pkt_from_controller_queue__send__rdy ),
    .send_val( recv_pkt_from_controller_queue__send__val )
  );
  logic [0:0] reg_file__clk;
  logic [CTRL_ADDR_W-1:0] reg_file__raddr [0:0];
  ctrl_t reg_file__rdata [0:0];
  logic [0:0] reg_file__reset;
  logic [CTRL_ADDR_W-1:0] reg_file__waddr [0:0];
  ctrl_t reg_file__wdata [0:0];
  logic [0:0] reg_file__wen [0:0];
  cgra_register_file #(.WIDTH(CTRL_BITS), .DEPTH(CTRL_DEPTH), .RD_PORTS(1), .WR_PORTS(1)) reg_file
  (
    .clk( reg_file__clk ),
    .raddr( reg_file__raddr ),
    .rdata( reg_file__rdata ),
    .reset( reg_file__reset ),
    .waddr( reg_file__waddr ),
    .wdata( reg_file__wdata ),
    .wen( reg_file__wen )
  );
  logic [3:0] tmp_update_prologue_reg_temp_routing_crossbar_in;
  logic [1:0] tmp_update_prologue_reg_temp_fu_crossbar_in;
  always_comb begin : update_ctrl_addr_outport
    ctrl_addr_outport = reg_file__raddr[1'd0];
  end
  always_comb begin : update_msg
    recv_pkt_from_controller_queue__send__rdy = 1'd0;
    send_to_element__msg_typed = '0;
    send_to_element__val = 1'd0;
    reg_file__wen[1'd0] = 1'd0;
    reg_file__waddr[1'd0] = recv_pkt_from_controller_queue__send__msg.payload.ctrl_addr;
    reg_file__wdata[1'd0].operation = 7'd0;
    for ( int unsigned i = 0; i < 3'( num_fu_inports_at_update_msg ); i++ ) begin
      reg_file__wdata[1'd0].fu_in[2'(i)] = 3'd0;
      reg_file__wdata[1'd0].write_reg_from[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.write_reg_from[2'(i)];
      reg_file__wdata[1'd0].write_reg_idx[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.write_reg_idx[2'(i)];
      reg_file__wdata[1'd0].read_reg_towards[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.read_reg_towards[2'(i)];
      reg_file__wdata[1'd0].read_reg_idx[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.read_reg_idx[2'(i)];
    end
    for ( int unsigned i = 0; i < num_routing_outports_at_update_msg; i++ ) begin
      reg_file__wdata[1'd0].routing_xbar_outport[i] = 4'd0;
      reg_file__wdata[1'd0].fu_xbar_outport[i] = 2'd0;
    end
    reg_file__wdata[1'd0].vector_factor_power = recv_pkt_from_controller_queue__send__msg.payload.ctrl.vector_factor_power;
    reg_file__wdata[1'd0].is_last_ctrl = 1'd0;
    if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG ) ) ) begin
      reg_file__wen[1'd0] = 1'd1;
      reg_file__waddr[1'd0] = recv_pkt_from_controller_queue__send__msg.payload.ctrl_addr;
      reg_file__wdata[1'd0].operation = recv_pkt_from_controller_queue__send__msg.payload.ctrl.operation;
      for ( int unsigned i = 0; i < 3'( num_fu_inports_at_update_msg ); i++ ) begin
        reg_file__wdata[1'd0].fu_in[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.fu_in[2'(i)];
        reg_file__wdata[1'd0].write_reg_from[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.write_reg_from[2'(i)];
        reg_file__wdata[1'd0].write_reg_idx[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.write_reg_idx[2'(i)];
        reg_file__wdata[1'd0].read_reg_towards[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.read_reg_towards[2'(i)];
        reg_file__wdata[1'd0].read_reg_idx[2'(i)] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.read_reg_idx[2'(i)];
      end
      for ( int unsigned i = 0; i < num_routing_outports_at_update_msg; i++ ) begin
        reg_file__wdata[1'd0].routing_xbar_outport[i] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.routing_xbar_outport[i];
        reg_file__wdata[1'd0].fu_xbar_outport[i] = recv_pkt_from_controller_queue__send__msg.payload.ctrl.fu_xbar_outport[i];
      end
      reg_file__wdata[1'd0].vector_factor_power = recv_pkt_from_controller_queue__send__msg.payload.ctrl.vector_factor_power;
      reg_file__wdata[1'd0].is_last_ctrl = recv_pkt_from_controller_queue__send__msg.payload.ctrl.is_last_ctrl;
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( ( ( ( ( ( ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD_RESPONSE ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL_RESPONSE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_LOWER ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_UPPER ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_STEP ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_UPDATE_COUNTER_SHADOW_VALUE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RESET_LEAF_COUNTER ) ) ) ) begin
      send_to_element__msg_typed = recv_pkt_from_controller_queue__send__msg.payload;
      send_to_element__val = 1'd1;
    end
    if ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU_CROSSBAR ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_LAUNCH ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_TERMINATE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_PAUSE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_PRESERVE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RESUME ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_TOTAL_CTRL_COUNT ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_COUNT_PER_ITER ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_CTRL_LOWER_BOUND ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RECORD_PHI_ADDR ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD_RESPONSE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_START_ADDR ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_STRIDE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_END_ADDR ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL_RESPONSE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_LOWER ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_UPPER ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_STEP ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_UPDATE_COUNTER_SHADOW_VALUE ) ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RESET_LEAF_COUNTER ) ) ) begin
      recv_pkt_from_controller_queue__send__rdy = 1'd1;
    end
  end
  always_comb begin : update_prologue_outport
    prologue_count_outport_fu = prologue_count_reg_fu[reg_file__raddr[1'd0]];
    for ( int unsigned addr = 0; addr < CTRL_DEPTH; addr++ ) begin
      for ( int unsigned i = 0; i < num_routing_xbar_inports_at_update_prologue_outport; i++ )
        prologue_count_outport_routing_crossbar[CTRL_ADDR_W'(addr)][i] = prologue_count_reg_routing_crossbar[CTRL_ADDR_W'(addr)][i];
      for ( int unsigned i = 0; i < 2'( num_fu_outports_at_update_prologue_outport ); i++ )
        prologue_count_outport_fu_crossbar[CTRL_ADDR_W'(addr)][1'(i)] = prologue_count_reg_fu_crossbar[CTRL_ADDR_W'(addr)][1'(i)];
    end
  end
  always_comb begin : update_send_ctrl_msg
    for ( int unsigned i = 0; i < 3'( num_fu_inports_at_update_send_ctrl_msg ); i++ ) begin
      send_ctrl__msg_typed.fu_in[2'(i)] = reg_file__rdata[1'd0].fu_in[2'(i)];
      send_ctrl__msg_typed.write_reg_from[2'(i)] = reg_file__rdata[1'd0].write_reg_from[2'(i)];
      send_ctrl__msg_typed.write_reg_idx[2'(i)] = reg_file__rdata[1'd0].write_reg_idx[2'(i)];
      send_ctrl__msg_typed.read_reg_towards[2'(i)] = reg_file__rdata[1'd0].read_reg_towards[2'(i)];
      send_ctrl__msg_typed.read_reg_idx[2'(i)] = reg_file__rdata[1'd0].read_reg_idx[2'(i)];
    end
    for ( int unsigned i = 0; i < num_routing_outports_at_update_send_ctrl_msg; i++ ) begin
      send_ctrl__msg_typed.routing_xbar_outport[i] = reg_file__rdata[1'd0].routing_xbar_outport[i];
      send_ctrl__msg_typed.fu_xbar_outport[i] = reg_file__rdata[1'd0].fu_xbar_outport[i];
    end
    send_ctrl__msg_typed.vector_factor_power = reg_file__rdata[1'd0].vector_factor_power;
    send_ctrl__msg_typed.is_last_ctrl = reg_file__rdata[1'd0].is_last_ctrl;
    if ( prologue_count_outport_fu != 3'd0 ) begin
      send_ctrl__msg_typed.operation = 7'( OPT_NAH );
    end
    else
      send_ctrl__msg_typed.operation = reg_file__rdata[1'd0].operation;
  end
  always_comb begin : update_send_ctrl_val
    send_ctrl__val = 1'd0;
    if ( start_iterate_ctrl == 1'd1 ) begin
      if ( sent_complete ) begin
        send_ctrl__val = 1'd0;
      end
      else if ( ( ( total_ctrl_steps_val > 11'd0 ) & ( times == total_ctrl_steps_val ) ) | ( reg_file__rdata[1'd0].operation == 7'( OPT_START ) ) ) begin
        send_ctrl__val = 1'd0;
      end
      else
        send_ctrl__val = 1'd1;
    end
    if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_TERMINATE ) ) ) begin
      send_ctrl__val = 1'd0;
    end
  end
  always_comb begin : update_send_pkt_to_controller
    send_pkt_to_controller__val = 1'd0;
    send_pkt_to_controller__msg_typed = { TILE_ID_W'(0), TILE_ID_W'(NUM_TILES), 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 8'd0, 1'd0, { 6'( CMD_COMPLETE ), DATA_BITS'(0), GLOBAL_ADDR_W'(0), CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
    recv_from_element_queue__send__rdy = 1'd0;
    if ( start_iterate_ctrl == 1'd1 ) begin
      if ( recv_from_element_queue__send__val & ( ~sent_complete ) ) begin
        send_pkt_to_controller__msg_typed = { tile_id, TILE_ID_W'(NUM_TILES), 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 8'd0, 1'd0, recv_from_element_queue__send__msg };
        send_pkt_to_controller__val = 1'd1;
        recv_from_element_queue__send__rdy = send_pkt_to_controller__rdy;
      end
      else if ( ( ( total_ctrl_steps_val > 11'd0 ) & ( times == total_ctrl_steps_val ) ) | ( reg_file__rdata[1'd0].operation == 7'( OPT_START ) ) ) begin
        if ( ( ( ( ~sent_complete ) & ( total_ctrl_steps_val > 11'd0 ) ) & ( times == total_ctrl_steps_val ) ) & start_iterate_ctrl ) begin
          send_pkt_to_controller__msg_typed = { tile_id, TILE_ID_W'(NUM_TILES), 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 8'd0, 1'd0, { 6'( CMD_COMPLETE ), DATA_BITS'(0), GLOBAL_ADDR_W'(0), CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
          send_pkt_to_controller__val = 1'd1;
        end
      end
    end
  end
  always_comb begin : update_upper_bound
    ctrl_count_upper_bound = BOUND_W'(ctrl_count_lower_bound) + ctrl_count_per_iter_val;
  end
  always_ff @(posedge clk) begin : issue_complete
    if ( reset ) begin
      sent_complete <= 1'd0;
    end
    else if ( ( send_pkt_to_controller__val & send_pkt_to_controller__rdy ) & ( send_pkt_to_controller__msg_typed.payload.cmd == 6'( CMD_COMPLETE ) ) ) begin
      sent_complete <= 1'd1;
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_LAUNCH ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RESUME ) ) ) ) begin
      sent_complete <= 1'd0;
    end
  end
  always_ff @(posedge clk) begin : update_ctrl_count_per_iter
    if ( reset ) begin
      ctrl_count_per_iter_val <= PC_W'(NUM_CTRL);
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_COUNT_PER_ITER ) ) ) begin
      ctrl_count_per_iter_val <= PC_W'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
    end
  end
  always_ff @(posedge clk) begin : update_lower_bound
    if ( reset ) begin
      ctrl_count_lower_bound <= 3'd0;
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_CTRL_LOWER_BOUND ) ) ) begin
      ctrl_count_lower_bound <= CTRL_ADDR_W'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
    end
  end
  always_ff @(posedge clk) begin : update_prologue_reg
    if ( reset ) begin
      for ( int unsigned addr = 0; addr < CTRL_DEPTH; addr++ ) begin
        for ( int unsigned i = 0; i < num_routing_xbar_inports_at_update_prologue_reg; i++ )
          prologue_count_reg_routing_crossbar[CTRL_ADDR_W'(addr)][i] <= 3'd0;
        for ( int unsigned i = 0; i < 2'( num_fu_outports_at_update_prologue_reg ); i++ )
          prologue_count_reg_fu_crossbar[CTRL_ADDR_W'(addr)][1'(i)] <= 3'd0;
      end
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR ) ) ) begin
      tmp_update_prologue_reg_temp_routing_crossbar_in = recv_pkt_from_controller_queue__send__msg.payload.ctrl.routing_xbar_outport[3'd0];
      if ( tmp_update_prologue_reg_temp_routing_crossbar_in > 4'd0 ) begin
        prologue_count_reg_routing_crossbar[recv_pkt_from_controller_queue__send__msg.payload.ctrl_addr][$clog2(ROUTING_OUTPUTS)'(tmp_update_prologue_reg_temp_routing_crossbar_in - 4'd1)] <= 3'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
      end
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU_CROSSBAR ) ) ) begin
      tmp_update_prologue_reg_temp_fu_crossbar_in = recv_pkt_from_controller_queue__send__msg.payload.ctrl.fu_xbar_outport[3'd0];
      prologue_count_reg_fu_crossbar[recv_pkt_from_controller_queue__send__msg.payload.ctrl_addr][1'(tmp_update_prologue_reg_temp_fu_crossbar_in)] <= 3'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
    end
  end
  always_ff @(posedge clk) begin : update_raddr_and_fu_prologue
    if ( reset ) begin
      times <= 11'd0;
      reg_file__raddr[1'd0] <= 3'd0;
      for ( int unsigned i = 0; i < CTRL_DEPTH; i++ )
        prologue_count_reg_fu[CTRL_ADDR_W'(i)] <= 3'd0;
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_CTRL_LOWER_BOUND ) ) ) begin
      reg_file__raddr[1'd0] <= CTRL_ADDR_W'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_TERMINATE ) ) ) begin
      times <= 11'd0;
    end
    else begin
      if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU ) ) ) begin
        prologue_count_reg_fu[recv_pkt_from_controller_queue__send__msg.payload.ctrl_addr] <= 3'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
      end
      if ( start_iterate_ctrl == 1'd1 ) begin
        if ( ( ( ( total_ctrl_steps_val == 11'd0 ) | ( times < total_ctrl_steps_val ) ) & send_ctrl__rdy ) & send_ctrl__val ) begin
          times <= times + 11'd1;
        end
        if ( send_ctrl__rdy & send_ctrl__val ) begin
          if ( BOUND_W'(reg_file__raddr[1'd0]) == ( ctrl_count_upper_bound - BOUND_W'(1) ) ) begin
            reg_file__raddr[1'd0] <= ctrl_count_lower_bound;
          end
          else
            reg_file__raddr[1'd0] <= reg_file__raddr[1'd0] + 3'd1;
          if ( prologue_count_reg_fu[reg_file__raddr[1'd0]] > 3'd0 ) begin
            prologue_count_reg_fu[reg_file__raddr[1'd0]] <= prologue_count_reg_fu[reg_file__raddr[1'd0]] - 3'd1;
          end
        end
      end
    end
  end
  always_ff @(posedge clk) begin : update_total_ctrl_steps
    if ( reset ) begin
      total_ctrl_steps_val <= 11'(TOTAL_STEPS);
    end
    else if ( recv_pkt_from_controller_queue__send__val & ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_CONFIG_TOTAL_CTRL_COUNT ) ) ) begin
      total_ctrl_steps_val <= 11'(recv_pkt_from_controller_queue__send__msg.payload.data.payload);
    end
  end
  always_ff @(posedge clk) begin : update_whether_we_can_iterate_ctrl
    if ( reset ) begin
      start_iterate_ctrl <= 1'd0;
    end
    else if ( recv_pkt_from_controller_queue__send__val ) begin
      if ( ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_LAUNCH ) ) | ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_RESUME ) ) ) begin
        start_iterate_ctrl <= 1'd1;
      end
      else if ( recv_pkt_from_controller_queue__send__msg.payload.cmd == 6'( CMD_TERMINATE ) ) begin
        start_iterate_ctrl <= 1'd0;
      end
    end
  end
  assign reg_file__clk = clk;
  assign reg_file__reset = reset;
  assign recv_pkt_from_controller_queue__clk = clk;
  assign recv_pkt_from_controller_queue__reset = reset;
  assign recv_from_element_queue__clk = clk;
  assign recv_from_element_queue__reset = reset;
  assign recv_pkt_from_controller_queue__recv__msg = recv_pkt_from_controller__msg_typed;
  assign recv_pkt_from_controller__rdy = recv_pkt_from_controller_queue__recv__rdy;
  assign recv_pkt_from_controller_queue__recv__val = recv_pkt_from_controller__val;
  assign recv_from_element_queue__recv__msg = recv_from_element__msg_typed;
  assign recv_from_element__rdy = recv_from_element_queue__recv__rdy;
  assign recv_from_element_queue__recv__val = recv_from_element__val;
endmodule
