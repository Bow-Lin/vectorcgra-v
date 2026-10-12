// Native ac96 TileRTL with an elaboration-time ordered FU catalog.
// Cycle contract synchronized with frozen Python cd7aad878915; see CURRENT_MIGRATION.md.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tile_programmable #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS
) (

  `include "cgra_pe_ports.svh"
);
  `include "cgra_profile.svh"
  data_t recv_data__msg_typed [0:TILE_PORTS-1];
  for (genvar p=0; p<TILE_PORTS; p++) begin : port_recv_data__msg
    assign recv_data__msg_typed[p] = recv_data__msg[p];
  end
  data_t send_data__msg_typed [0:TILE_PORTS-1];
  for (genvar p=0; p<TILE_PORTS; p++) begin : port_send_data__msg
    assign send_data__msg[p] = send_data__msg_typed[p];
  end
  host_packet_t recv_from_controller_pkt__msg_typed ;
  assign recv_from_controller_pkt__msg_typed = recv_from_controller_pkt__msg;
  host_packet_t send_to_controller_pkt__msg_typed ;
  assign send_to_controller_pkt__msg = send_to_controller_pkt__msg_typed;
  localparam logic [1:0] CMD_CONFIG  = 2'd3;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU  = 3'd4;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU_CROSSBAR  = 3'd5;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR  = 3'd6;
  localparam logic [2:0] CMD_CONFIG_TOTAL_CTRL_COUNT  = 3'd7;
  localparam logic [3:0] CMD_CONFIG_COUNT_PER_ITER  = 4'd8;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD_RESPONSE  = 5'd20;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_MUL_RESPONSE  = 5'd21;
  localparam logic [0:0] CMD_LAUNCH  = 1'd0;
  localparam logic [4:0] CMD_CONFIG_LOOP_LOWER  = 5'd28;
  localparam logic [4:0] CMD_CONFIG_LOOP_UPPER  = 5'd29;
  localparam logic [4:0] CMD_CONFIG_LOOP_STEP  = 5'd30;
  localparam logic [3:0] CMD_CONST  = 4'd13;
  logic [0:0] element_done;
  logic [0:0] fu_crossbar_done;
  logic [0:0] routing_crossbar_done;
  // Base Tile has no task-switch clear; make the inactive input explicit.
  wire [0:0] const_mem__clear = 1'b0;
  logic [0:0] const_mem__clk;
  logic [0:0] const_mem__ctrl_proceed;
  logic [0:0] const_mem__reset;
  data_t const_mem__recv_const__msg;
  logic [0:0] const_mem__recv_const__rdy;
  logic [0:0] const_mem__recv_const__val;
  data_t const_mem__send_const__msg;
  logic [0:0] const_mem__send_const__rdy;
  logic [0:0] const_mem__send_const__val;
  const_queue #(`CGRA_PROFILE_BIND) const_mem
  (
    .clear( const_mem__clear ),
    .clk( const_mem__clk ),
    .ctrl_proceed( const_mem__ctrl_proceed ),
    .reset( const_mem__reset ),
    .recv_const__msg( const_mem__recv_const__msg ),
    .recv_const__rdy( const_mem__recv_const__rdy ),
    .recv_const__val( const_mem__recv_const__val ),
    .send_const__msg( const_mem__send_const__msg ),
    .send_const__rdy( const_mem__send_const__rdy ),
    .send_const__val( const_mem__send_const__val )
  );
  logic [CGRA_ID_W-1:0] ctrl_mem__cgra_id;
  logic [0:0] ctrl_mem__clk;
  logic [CTRL_ADDR_W-1:0] ctrl_mem__ctrl_addr_outport;
  logic [2:0] ctrl_mem__prologue_count_outport_fu;
  logic [2:0] ctrl_mem__prologue_count_outport_fu_crossbar [0:CTRL_DEPTH-1][0:1];
  logic [2:0] ctrl_mem__prologue_count_outport_routing_crossbar [0:CTRL_DEPTH-1][0:ROUTING_OUTPUTS-1];
  logic [0:0] ctrl_mem__reset;
  logic [TILE_ID_W-1:0] ctrl_mem__tile_id;
  payload_t ctrl_mem__recv_from_element__msg;
  logic [0:0] ctrl_mem__recv_from_element__rdy;
  logic [0:0] ctrl_mem__recv_from_element__val;
  host_packet_t ctrl_mem__recv_pkt_from_controller__msg;
  logic [0:0] ctrl_mem__recv_pkt_from_controller__rdy;
  logic [0:0] ctrl_mem__recv_pkt_from_controller__val;
  ctrl_t ctrl_mem__send_ctrl__msg;
  logic [0:0] ctrl_mem__send_ctrl__rdy;
  logic [0:0] ctrl_mem__send_ctrl__val;
  host_packet_t ctrl_mem__send_pkt_to_controller__msg;
  logic [0:0] ctrl_mem__send_pkt_to_controller__rdy;
  logic [0:0] ctrl_mem__send_pkt_to_controller__val;
  payload_t ctrl_mem__send_to_element__msg;
  logic [0:0] ctrl_mem__send_to_element__rdy;
  logic [0:0] ctrl_mem__send_to_element__val;
  ctrl_mem #(`CGRA_PROFILE_BIND) ctrl_mem
  (
    .cgra_id( ctrl_mem__cgra_id ),
    .clk( ctrl_mem__clk ),
    .ctrl_addr_outport( ctrl_mem__ctrl_addr_outport ),
    .prologue_count_outport_fu( ctrl_mem__prologue_count_outport_fu ),
    .prologue_count_outport_fu_crossbar( ctrl_mem__prologue_count_outport_fu_crossbar ),
    .prologue_count_outport_routing_crossbar( ctrl_mem__prologue_count_outport_routing_crossbar ),
    .reset( ctrl_mem__reset ),
    .tile_id( ctrl_mem__tile_id ),
    .recv_from_element__msg( ctrl_mem__recv_from_element__msg ),
    .recv_from_element__rdy( ctrl_mem__recv_from_element__rdy ),
    .recv_from_element__val( ctrl_mem__recv_from_element__val ),
    .recv_pkt_from_controller__msg( ctrl_mem__recv_pkt_from_controller__msg ),
    .recv_pkt_from_controller__rdy( ctrl_mem__recv_pkt_from_controller__rdy ),
    .recv_pkt_from_controller__val( ctrl_mem__recv_pkt_from_controller__val ),
    .send_ctrl__msg( ctrl_mem__send_ctrl__msg ),
    .send_ctrl__rdy( ctrl_mem__send_ctrl__rdy ),
    .send_ctrl__val( ctrl_mem__send_ctrl__val ),
    .send_pkt_to_controller__msg( ctrl_mem__send_pkt_to_controller__msg ),
    .send_pkt_to_controller__rdy( ctrl_mem__send_pkt_to_controller__rdy ),
    .send_pkt_to_controller__val( ctrl_mem__send_pkt_to_controller__val ),
    .send_to_element__msg( ctrl_mem__send_to_element__msg ),
    .send_to_element__rdy( ctrl_mem__send_to_element__rdy ),
    .send_to_element__val( ctrl_mem__send_to_element__val )
  );
  logic [0:0] element__clear [0:FU_COUNT-1];
  logic [0:0] element__clk;
  logic [CTRL_ADDR_W-1:0] element__ctrl_addr_inport;
  logic [2:0] element__prologue_count_inport;
  logic [0:0] element__reset;
  logic [TILE_ID_W-1:0] element__tile_id;
  data_t element__from_mem_rdata__msg [0:FU_COUNT-1];
  logic [0:0] element__from_mem_rdata__rdy [0:FU_COUNT-1];
  logic [0:0] element__from_mem_rdata__val [0:FU_COUNT-1];
  data_t element__recv_const__msg;
  logic [0:0] element__recv_const__rdy;
  logic [0:0] element__recv_const__val;
  payload_t element__recv_from_ctrl_mem__msg;
  logic [0:0] element__recv_from_ctrl_mem__rdy;
  logic [0:0] element__recv_from_ctrl_mem__val;
  data_t element__recv_in__msg [0:3];
  logic [0:0] element__recv_in__rdy [0:3];
  logic [0:0] element__recv_in__val [0:3];
  ctrl_t element__recv_opt__msg;
  logic [0:0] element__recv_opt__rdy;
  logic [0:0] element__recv_opt__val;
  host_packet_t element__recv_pkt_from_controller__msg;
  logic [0:0] element__recv_pkt_from_controller__rdy;
  logic [0:0] element__recv_pkt_from_controller__val;
  // Base PE has no streaming raw-packet consumer.
  assign element__recv_pkt_from_controller__msg = '0;
  assign element__recv_pkt_from_controller__val = 1'b0;
  data_t element__send_out__msg [0:1];
  logic [0:0] element__send_out__rdy [0:1];
  logic [0:0] element__send_out__val [0:1];
  payload_t element__send_to_ctrl_mem__msg;
  logic [0:0] element__send_to_ctrl_mem__rdy;
  logic [0:0] element__send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] element__to_mem_raddr__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_raddr__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_raddr__val [0:FU_COUNT-1];
  logic [GLOBAL_ADDR_W-1:0] element__to_mem_waddr__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_waddr__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_waddr__val [0:FU_COUNT-1];
  data_t element__to_mem_wdata__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_wdata__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_wdata__val [0:FU_COUNT-1];
  tile_flexible_fu_configurable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) element
  (
    .clear( element__clear ),
    .clk( element__clk ),
    .ctrl_addr_inport( element__ctrl_addr_inport ),
    .prologue_count_inport( element__prologue_count_inport ),
    .reset( element__reset ),
    .tile_id( element__tile_id ),
    .from_mem_rdata__msg( element__from_mem_rdata__msg ),
    .from_mem_rdata__rdy( element__from_mem_rdata__rdy ),
    .from_mem_rdata__val( element__from_mem_rdata__val ),
    .recv_const__msg( element__recv_const__msg ),
    .recv_const__rdy( element__recv_const__rdy ),
    .recv_const__val( element__recv_const__val ),
    .recv_from_ctrl_mem__msg( element__recv_from_ctrl_mem__msg ),
    .recv_from_ctrl_mem__rdy( element__recv_from_ctrl_mem__rdy ),
    .recv_from_ctrl_mem__val( element__recv_from_ctrl_mem__val ),
    .recv_in__msg( element__recv_in__msg ),
    .recv_in__rdy( element__recv_in__rdy ),
    .recv_in__val( element__recv_in__val ),
    .recv_opt__msg( element__recv_opt__msg ),
    .recv_opt__rdy( element__recv_opt__rdy ),
    .recv_opt__val( element__recv_opt__val ),
    .recv_pkt_from_controller__msg( element__recv_pkt_from_controller__msg ),
    .recv_pkt_from_controller__rdy( element__recv_pkt_from_controller__rdy ),
    .recv_pkt_from_controller__val( element__recv_pkt_from_controller__val ),
    .send_out__msg( element__send_out__msg ),
    .send_out__rdy( element__send_out__rdy ),
    .send_out__val( element__send_out__val ),
    .send_to_ctrl_mem__msg( element__send_to_ctrl_mem__msg ),
    .send_to_ctrl_mem__rdy( element__send_to_ctrl_mem__rdy ),
    .send_to_ctrl_mem__val( element__send_to_ctrl_mem__val ),
    .to_mem_raddr__msg( element__to_mem_raddr__msg ),
    .to_mem_raddr__rdy( element__to_mem_raddr__rdy ),
    .to_mem_raddr__val( element__to_mem_raddr__val ),
    .to_mem_waddr__msg( element__to_mem_waddr__msg ),
    .to_mem_waddr__rdy( element__to_mem_waddr__rdy ),
    .to_mem_waddr__val( element__to_mem_waddr__val ),
    .to_mem_wdata__msg( element__to_mem_wdata__msg ),
    .to_mem_wdata__rdy( element__to_mem_wdata__rdy ),
    .to_mem_wdata__val( element__to_mem_wdata__val )
  );
  logic [CGRA_ID_W-1:0] fu_crossbar__cgra_id;
  logic [0:0] fu_crossbar__clear;
  logic [0:0] fu_crossbar__clk;
  logic [0:0] fu_crossbar__compute_done;
  logic [0:0] fu_crossbar__crossbar_id;
  logic [1:0] fu_crossbar__crossbar_outport [0:ROUTING_OUTPUTS-1];
  logic [CTRL_ADDR_W-1:0] fu_crossbar__ctrl_addr_inport;
  logic [2:0] fu_crossbar__prologue_count_inport [0:CTRL_DEPTH-1][0:1];
  logic [0:0] fu_crossbar__reset;
  logic [TILE_ID_W-1:0] fu_crossbar__tile_id;
  data_t fu_crossbar__recv_data__msg [0:1];
  logic [0:0] fu_crossbar__recv_data__rdy [0:1];
  logic [0:0] fu_crossbar__recv_data__val [0:1];
  ctrl_t fu_crossbar__recv_opt__msg;
  logic [0:0] fu_crossbar__recv_opt__rdy;
  logic [0:0] fu_crossbar__recv_opt__val;
  data_t fu_crossbar__send_data__msg [0:ROUTING_OUTPUTS-1];
  logic [0:0] fu_crossbar__send_data__rdy [0:ROUTING_OUTPUTS-1];
  logic [0:0] fu_crossbar__send_data__val [0:ROUTING_OUTPUTS-1];
  tile_static_crossbar #(`CGRA_PROFILE_BIND, .INPUTS(2)) fu_crossbar
  (
    .cgra_id( fu_crossbar__cgra_id ),
    .clear( fu_crossbar__clear ),
    .clk( fu_crossbar__clk ),
    .compute_done( fu_crossbar__compute_done ),
    .crossbar_id( fu_crossbar__crossbar_id ),
    .crossbar_outport( fu_crossbar__crossbar_outport ),
    .ctrl_addr_inport( fu_crossbar__ctrl_addr_inport ),
    .prologue_count_inport( fu_crossbar__prologue_count_inport ),
    .reset( fu_crossbar__reset ),
    .tile_id( fu_crossbar__tile_id ),
    .recv_data__msg( fu_crossbar__recv_data__msg ),
    .recv_data__rdy( fu_crossbar__recv_data__rdy ),
    .recv_data__val( fu_crossbar__recv_data__val ),
    .recv_opt__msg( fu_crossbar__recv_opt__msg ),
    .recv_opt__rdy( fu_crossbar__recv_opt__rdy ),
    .recv_opt__val( fu_crossbar__recv_opt__val ),
    .send_data__msg( fu_crossbar__send_data__msg ),
    .send_data__rdy( fu_crossbar__send_data__rdy ),
    .send_data__val( fu_crossbar__send_data__val )
  );
  logic [0:0] register_cluster__clear;
  logic [0:0] register_cluster__clk;
  logic [0:0] register_cluster__inport_ctrl_proceed;
  ctrl_t register_cluster__inport_opt;
  logic [0:0] register_cluster__reset;
  data_t register_cluster__recv_data_from_const__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_const__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_const__val [0:3];
  data_t register_cluster__recv_data_from_fu_crossbar__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_fu_crossbar__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_fu_crossbar__val [0:3];
  data_t register_cluster__recv_data_from_routing_crossbar__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_routing_crossbar__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_routing_crossbar__val [0:3];
  data_t register_cluster__send_data_to_fu__msg [0:3];
  logic [0:0] register_cluster__send_data_to_fu__rdy [0:3];
  logic [0:0] register_cluster__send_data_to_fu__val [0:3];
  data_t register_cluster__send_data_to_routing_crossbar__msg [0:3];
  logic [0:0] register_cluster__send_data_to_routing_crossbar__rdy [0:3];
  logic [0:0] register_cluster__send_data_to_routing_crossbar__val [0:3];
  register_cluster #(`CGRA_PROFILE_BIND) register_cluster
  (
    .clear( register_cluster__clear ),
    .clk( register_cluster__clk ),
    .inport_ctrl_proceed( register_cluster__inport_ctrl_proceed ),
    .inport_opt( register_cluster__inport_opt ),
    .reset( register_cluster__reset ),
    .recv_data_from_const__msg( register_cluster__recv_data_from_const__msg ),
    .recv_data_from_const__rdy( register_cluster__recv_data_from_const__rdy ),
    .recv_data_from_const__val( register_cluster__recv_data_from_const__val ),
    .recv_data_from_fu_crossbar__msg( register_cluster__recv_data_from_fu_crossbar__msg ),
    .recv_data_from_fu_crossbar__rdy( register_cluster__recv_data_from_fu_crossbar__rdy ),
    .recv_data_from_fu_crossbar__val( register_cluster__recv_data_from_fu_crossbar__val ),
    .recv_data_from_routing_crossbar__msg( register_cluster__recv_data_from_routing_crossbar__msg ),
    .recv_data_from_routing_crossbar__rdy( register_cluster__recv_data_from_routing_crossbar__rdy ),
    .recv_data_from_routing_crossbar__val( register_cluster__recv_data_from_routing_crossbar__val ),
    .send_data_to_fu__msg( register_cluster__send_data_to_fu__msg ),
    .send_data_to_fu__rdy( register_cluster__send_data_to_fu__rdy ),
    .send_data_to_fu__val( register_cluster__send_data_to_fu__val ),
    .send_data_to_routing_crossbar__msg( register_cluster__send_data_to_routing_crossbar__msg ),
    .send_data_to_routing_crossbar__rdy( register_cluster__send_data_to_routing_crossbar__rdy ),
    .send_data_to_routing_crossbar__val( register_cluster__send_data_to_routing_crossbar__val )
  );
  logic [CGRA_ID_W-1:0] routing_crossbar__cgra_id;
  logic [0:0] routing_crossbar__clear;
  logic [0:0] routing_crossbar__clk;
  logic [0:0] routing_crossbar__compute_done;
  logic [0:0] routing_crossbar__crossbar_id;
  logic [ROUTING_SEL_W-1:0] routing_crossbar__crossbar_outport [0:ROUTING_OUTPUTS-1];
  logic [CTRL_ADDR_W-1:0] routing_crossbar__ctrl_addr_inport;
  logic [2:0] routing_crossbar__prologue_count_inport [0:CTRL_DEPTH-1][0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__reset;
  logic [TILE_ID_W-1:0] routing_crossbar__tile_id;
  data_t routing_crossbar__recv_data__msg [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__recv_data__rdy [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__recv_data__val [0:ROUTING_OUTPUTS-1];
  ctrl_t routing_crossbar__recv_opt__msg;
  logic [0:0] routing_crossbar__recv_opt__rdy;
  logic [0:0] routing_crossbar__recv_opt__val;
  data_t routing_crossbar__send_data__msg [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__send_data__rdy [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__send_data__val [0:ROUTING_OUTPUTS-1];
  tile_static_crossbar #(`CGRA_PROFILE_BIND) routing_crossbar
  (
    .cgra_id( routing_crossbar__cgra_id ),
    .clear( routing_crossbar__clear ),
    .clk( routing_crossbar__clk ),
    .compute_done( routing_crossbar__compute_done ),
    .crossbar_id( routing_crossbar__crossbar_id ),
    .crossbar_outport( routing_crossbar__crossbar_outport ),
    .ctrl_addr_inport( routing_crossbar__ctrl_addr_inport ),
    .prologue_count_inport( routing_crossbar__prologue_count_inport ),
    .reset( routing_crossbar__reset ),
    .tile_id( routing_crossbar__tile_id ),
    .recv_data__msg( routing_crossbar__recv_data__msg ),
    .recv_data__rdy( routing_crossbar__recv_data__rdy ),
    .recv_data__val( routing_crossbar__recv_data__val ),
    .recv_opt__msg( routing_crossbar__recv_opt__msg ),
    .recv_opt__rdy( routing_crossbar__recv_opt__rdy ),
    .recv_opt__val( routing_crossbar__recv_opt__val ),
    .send_data__msg( routing_crossbar__send_data__msg ),
    .send_data__rdy( routing_crossbar__send_data__rdy ),
    .send_data__val( routing_crossbar__send_data__val )
  );
  always_comb begin : feed_pkt
    ctrl_mem__recv_pkt_from_controller__msg = '0;
    const_mem__recv_const__msg = '0;
    ctrl_mem__recv_pkt_from_controller__val = 1'd0;
    const_mem__recv_const__val = 1'd0;
    recv_from_controller_pkt__rdy = 1'd0;
    if ( recv_from_controller_pkt__val & ( ( ( ( ( ( ( ( ( ( ( ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU_CROSSBAR ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_TOTAL_CTRL_COUNT ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_COUNT_PER_ITER ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD_RESPONSE ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL_RESPONSE ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_LAUNCH ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_LOOP_LOWER ) ) ) | ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_LOOP_UPPER ) ) ) | ( ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONFIG_LOOP_STEP ) ) | (recv_from_controller_pkt__msg_typed.payload.cmd == 6'd43) ) ) ) begin
      ctrl_mem__recv_pkt_from_controller__val = 1'd1;
      ctrl_mem__recv_pkt_from_controller__msg = recv_from_controller_pkt__msg_typed;
      recv_from_controller_pkt__rdy = ctrl_mem__recv_pkt_from_controller__rdy;
    end
    else if ( recv_from_controller_pkt__val & ( recv_from_controller_pkt__msg_typed.payload.cmd == 6'( CMD_CONST ) ) ) begin
      const_mem__recv_const__val = 1'd1;
      const_mem__recv_const__msg = recv_from_controller_pkt__msg_typed.payload.data;
      recv_from_controller_pkt__rdy = const_mem__recv_const__rdy;
    end
  end
  always_comb begin : notify_const_mem
    const_mem__ctrl_proceed = ctrl_mem__send_ctrl__rdy & ctrl_mem__send_ctrl__val;
    register_cluster__inport_ctrl_proceed = ctrl_mem__send_ctrl__rdy & ctrl_mem__send_ctrl__val;
  end
  always_comb begin : notify_crossbars_compute_status
    routing_crossbar__compute_done = element_done;
    fu_crossbar__compute_done = element_done;
  end
  always_comb begin : update_opt
    element__recv_opt__msg = ctrl_mem__send_ctrl__msg;
    routing_crossbar__recv_opt__msg = ctrl_mem__send_ctrl__msg;
    fu_crossbar__recv_opt__msg = ctrl_mem__send_ctrl__msg;
    element__recv_opt__val = ctrl_mem__send_ctrl__val & ( ~element_done );
    routing_crossbar__recv_opt__val = ctrl_mem__send_ctrl__val & ( ~routing_crossbar_done );
    fu_crossbar__recv_opt__val = ctrl_mem__send_ctrl__val & ( ~fu_crossbar_done );
    ctrl_mem__send_ctrl__rdy = ( ( element__recv_opt__rdy | element_done ) & ( routing_crossbar__recv_opt__rdy | routing_crossbar_done ) ) & ( fu_crossbar__recv_opt__rdy | fu_crossbar_done );
  end
  always_comb begin : update_send_out_signal
    send_to_controller_pkt__val = 1'd0;
    send_to_controller_pkt__msg_typed = '0;
    if ( ctrl_mem__send_pkt_to_controller__val ) begin
      send_to_controller_pkt__val = 1'd1;
      send_to_controller_pkt__msg_typed = ctrl_mem__send_pkt_to_controller__msg;
    end
    ctrl_mem__send_pkt_to_controller__rdy = send_to_controller_pkt__rdy;
  end
  always_ff @(posedge clk) begin : already_done
    if ( reset | ctrl_mem__send_ctrl__rdy ) begin
      element_done <= 1'd0;
      fu_crossbar_done <= 1'd0;
      routing_crossbar_done <= 1'd0;
    end
    else begin
      if ( element__recv_opt__rdy ) begin
        element_done <= 1'd1;
      end
      if ( fu_crossbar__recv_opt__rdy ) begin
        fu_crossbar_done <= 1'd1;
      end
      if ( routing_crossbar__recv_opt__rdy ) begin
        routing_crossbar_done <= 1'd1;
      end
    end
  end
  assign element__clk = clk;
  assign element__reset = reset;
  assign const_mem__clk = clk;
  assign const_mem__reset = reset;
  assign routing_crossbar__clk = clk;
  assign routing_crossbar__reset = reset;
  assign fu_crossbar__clk = clk;
  assign fu_crossbar__reset = reset;
  assign register_cluster__clk = clk;
  assign register_cluster__reset = reset;
  assign ctrl_mem__clk = clk;
  assign ctrl_mem__reset = reset;
  assign element__tile_id = tile_id;
  assign ctrl_mem__cgra_id = cgra_id;
  assign ctrl_mem__tile_id = tile_id;
  assign fu_crossbar__cgra_id = cgra_id;
  assign fu_crossbar__tile_id = tile_id;
  assign routing_crossbar__cgra_id = cgra_id;
  assign routing_crossbar__tile_id = tile_id;
  assign routing_crossbar__crossbar_id = 1'd0;
  assign fu_crossbar__crossbar_id = 1'd1;
  assign element__recv_const__msg = const_mem__send_const__msg;
  assign const_mem__send_const__rdy = element__recv_const__rdy;
  assign element__recv_const__val = const_mem__send_const__val;
  assign ctrl_mem__recv_from_element__msg = element__send_to_ctrl_mem__msg;
  assign element__send_to_ctrl_mem__rdy = ctrl_mem__recv_from_element__rdy;
  assign ctrl_mem__recv_from_element__val = element__send_to_ctrl_mem__val;
  assign element__recv_from_ctrl_mem__msg = ctrl_mem__send_to_element__msg;
  assign ctrl_mem__send_to_element__rdy = element__recv_from_ctrl_mem__rdy;
  assign element__recv_from_ctrl_mem__val = ctrl_mem__send_to_element__val;
  assign routing_crossbar__ctrl_addr_inport = ctrl_mem__ctrl_addr_outport;
  assign fu_crossbar__ctrl_addr_inport = ctrl_mem__ctrl_addr_outport;
  assign element__ctrl_addr_inport = ctrl_mem__ctrl_addr_outport;
  assign element__prologue_count_inport = ctrl_mem__prologue_count_outport_fu;
  localparam logic [7:0] PE_MEMORY_KIND=`CGRA_FU_MEM;
  `include "cgra_pe_memory.svh"
  initial begin
    if(TILE_PORTS!=4 && TILE_PORTS!=8) $fatal(1,"Base programmable Tile requires four or eight mesh ports");
    for(int i=0;i<FU_COUNT;i++) if(FU_KINDS[8*i+:8]==`CGRA_FU_STREAMING_MEM)
      $fatal(1,"StreamingMem requires the streaming Tile variant");
  end
  for(genvar slot=0;slot<FU_COUNT;slot++) begin : clear_slots
    assign element__clear[slot]=1'b0;
  end

  assign routing_crossbar__recv_data__msg[TILE_PORTS+0] = register_cluster__send_data_to_routing_crossbar__msg[0];
  assign register_cluster__send_data_to_routing_crossbar__rdy[0] = routing_crossbar__recv_data__rdy[TILE_PORTS+0];
  assign routing_crossbar__recv_data__val[TILE_PORTS+0] = register_cluster__send_data_to_routing_crossbar__val[0];
  assign routing_crossbar__recv_data__msg[TILE_PORTS+1] = register_cluster__send_data_to_routing_crossbar__msg[1];
  assign register_cluster__send_data_to_routing_crossbar__rdy[1] = routing_crossbar__recv_data__rdy[TILE_PORTS+1];
  assign routing_crossbar__recv_data__val[TILE_PORTS+1] = register_cluster__send_data_to_routing_crossbar__val[1];
  assign routing_crossbar__recv_data__msg[TILE_PORTS+2] = register_cluster__send_data_to_routing_crossbar__msg[2];
  assign register_cluster__send_data_to_routing_crossbar__rdy[2] = routing_crossbar__recv_data__rdy[TILE_PORTS+2];
  assign routing_crossbar__recv_data__val[TILE_PORTS+2] = register_cluster__send_data_to_routing_crossbar__val[2];
  assign routing_crossbar__recv_data__msg[TILE_PORTS+3] = register_cluster__send_data_to_routing_crossbar__msg[3];
  assign register_cluster__send_data_to_routing_crossbar__rdy[3] = routing_crossbar__recv_data__rdy[TILE_PORTS+3];
  assign routing_crossbar__recv_data__val[TILE_PORTS+3] = register_cluster__send_data_to_routing_crossbar__val[3];
  assign fu_crossbar__recv_data__msg[0] = element__send_out__msg[0];
  assign element__send_out__rdy[0] = fu_crossbar__recv_data__rdy[0];
  assign fu_crossbar__recv_data__val[0] = element__send_out__val[0];
  assign fu_crossbar__recv_data__msg[1] = element__send_out__msg[1];
  assign element__send_out__rdy[1] = fu_crossbar__recv_data__rdy[1];
  assign fu_crossbar__recv_data__val[1] = element__send_out__val[1];
  assign register_cluster__recv_data_from_routing_crossbar__msg[0] = routing_crossbar__send_data__msg[TILE_PORTS+0];
  assign routing_crossbar__send_data__rdy[TILE_PORTS+0] = register_cluster__recv_data_from_routing_crossbar__rdy[0];
  assign register_cluster__recv_data_from_routing_crossbar__val[0] = routing_crossbar__send_data__val[TILE_PORTS+0];
  assign register_cluster__recv_data_from_fu_crossbar__msg[0] = fu_crossbar__send_data__msg[TILE_PORTS+0];
  assign fu_crossbar__send_data__rdy[TILE_PORTS+0] = register_cluster__recv_data_from_fu_crossbar__rdy[0];
  assign register_cluster__recv_data_from_fu_crossbar__val[0] = fu_crossbar__send_data__val[TILE_PORTS+0];
  assign register_cluster__recv_data_from_const__msg[0] = '0;
  assign register_cluster__recv_data_from_const__val[0] = 1'd0;
  assign element__recv_in__msg[0] = register_cluster__send_data_to_fu__msg[0];
  assign register_cluster__send_data_to_fu__rdy[0] = element__recv_in__rdy[0];
  assign element__recv_in__val[0] = register_cluster__send_data_to_fu__val[0];
  assign register_cluster__inport_opt = ctrl_mem__send_ctrl__msg;
  assign register_cluster__recv_data_from_routing_crossbar__msg[1] = routing_crossbar__send_data__msg[TILE_PORTS+1];
  assign routing_crossbar__send_data__rdy[TILE_PORTS+1] = register_cluster__recv_data_from_routing_crossbar__rdy[1];
  assign register_cluster__recv_data_from_routing_crossbar__val[1] = routing_crossbar__send_data__val[TILE_PORTS+1];
  assign register_cluster__recv_data_from_fu_crossbar__msg[1] = fu_crossbar__send_data__msg[TILE_PORTS+1];
  assign fu_crossbar__send_data__rdy[TILE_PORTS+1] = register_cluster__recv_data_from_fu_crossbar__rdy[1];
  assign register_cluster__recv_data_from_fu_crossbar__val[1] = fu_crossbar__send_data__val[TILE_PORTS+1];
  assign register_cluster__recv_data_from_const__msg[1] = '0;
  assign register_cluster__recv_data_from_const__val[1] = 1'd0;
  assign element__recv_in__msg[1] = register_cluster__send_data_to_fu__msg[1];
  assign register_cluster__send_data_to_fu__rdy[1] = element__recv_in__rdy[1];
  assign element__recv_in__val[1] = register_cluster__send_data_to_fu__val[1];
  assign register_cluster__recv_data_from_routing_crossbar__msg[2] = routing_crossbar__send_data__msg[TILE_PORTS+2];
  assign routing_crossbar__send_data__rdy[TILE_PORTS+2] = register_cluster__recv_data_from_routing_crossbar__rdy[2];
  assign register_cluster__recv_data_from_routing_crossbar__val[2] = routing_crossbar__send_data__val[TILE_PORTS+2];
  assign register_cluster__recv_data_from_fu_crossbar__msg[2] = fu_crossbar__send_data__msg[TILE_PORTS+2];
  assign fu_crossbar__send_data__rdy[TILE_PORTS+2] = register_cluster__recv_data_from_fu_crossbar__rdy[2];
  assign register_cluster__recv_data_from_fu_crossbar__val[2] = fu_crossbar__send_data__val[TILE_PORTS+2];
  assign register_cluster__recv_data_from_const__msg[2] = '0;
  assign register_cluster__recv_data_from_const__val[2] = 1'd0;
  assign element__recv_in__msg[2] = register_cluster__send_data_to_fu__msg[2];
  assign register_cluster__send_data_to_fu__rdy[2] = element__recv_in__rdy[2];
  assign element__recv_in__val[2] = register_cluster__send_data_to_fu__val[2];
  assign register_cluster__recv_data_from_routing_crossbar__msg[3] = routing_crossbar__send_data__msg[TILE_PORTS+3];
  assign routing_crossbar__send_data__rdy[TILE_PORTS+3] = register_cluster__recv_data_from_routing_crossbar__rdy[3];
  assign register_cluster__recv_data_from_routing_crossbar__val[3] = routing_crossbar__send_data__val[TILE_PORTS+3];
  assign register_cluster__recv_data_from_fu_crossbar__msg[3] = fu_crossbar__send_data__msg[TILE_PORTS+3];
  assign fu_crossbar__send_data__rdy[TILE_PORTS+3] = register_cluster__recv_data_from_fu_crossbar__rdy[3];
  assign register_cluster__recv_data_from_fu_crossbar__val[3] = fu_crossbar__send_data__val[TILE_PORTS+3];
  assign register_cluster__recv_data_from_const__msg[3] = '0;
  assign register_cluster__recv_data_from_const__val[3] = 1'd0;
  assign element__recv_in__msg[3] = register_cluster__send_data_to_fu__msg[3];
  assign register_cluster__send_data_to_fu__rdy[3] = element__recv_in__rdy[3];
  assign element__recv_in__val[3] = register_cluster__send_data_to_fu__val[3];
  assign fu_crossbar__clear = 1'd0;
  assign register_cluster__clear = 1'd0;
  assign routing_crossbar__clear = 1'd0;
  for (genvar a=0;a<CTRL_DEPTH;a++) begin : prologue_links
    for (genvar i=0;i<ROUTING_OUTPUTS;i++) begin : routing_inputs
      assign routing_crossbar__prologue_count_inport[a][i]=ctrl_mem__prologue_count_outport_routing_crossbar[a][i];
    end
    for (genvar i=0;i<2;i++) begin : fu_inputs
      assign fu_crossbar__prologue_count_inport[a][i]=ctrl_mem__prologue_count_outport_fu_crossbar[a][i];
    end
  end
  for(genvar d=0;d<TILE_PORTS;d++) begin : physical_ports
    cgra_channel #(.WIDTH(DATA_BITS),.LATENCY(1)) input_channel (
      .clk,.reset,.clear(1'b0),
      .recv_msg(recv_data__msg[d]),.recv_val(recv_data__val[d]),.recv_rdy(recv_data__rdy[d]),
      .send_msg(routing_crossbar__recv_data__msg[d]),.send_val(routing_crossbar__recv_data__val[d]),.send_rdy(routing_crossbar__recv_data__rdy[d])
    );
    tile_link_or #(`CGRA_PROFILE_BIND) output_link (
      .clk,.reset,
      .recv_fu__msg(fu_crossbar__send_data__msg[d]),.recv_fu__val(fu_crossbar__send_data__val[d]),.recv_fu__rdy(fu_crossbar__send_data__rdy[d]),
      .recv_xbar__msg(routing_crossbar__send_data__msg[d]),.recv_xbar__val(routing_crossbar__send_data__val[d]),.recv_xbar__rdy(routing_crossbar__send_data__rdy[d]),
      .send__msg(send_data__msg_typed[d]),.send__val(send_data__val[d]),.send__rdy(send_data__rdy[d])
    );
  end
  for(genvar d=0;d<ROUTING_OUTPUTS;d++) begin : routing_selections
    assign routing_crossbar__crossbar_outport[d]=ctrl_mem__send_ctrl__msg.routing_xbar_outport[d];
    assign fu_crossbar__crossbar_outport[d]=ctrl_mem__send_ctrl__msg.fu_xbar_outport[d];
  end
endmodule
