// Native ac96 TileWithContextSwitchRTL / TileWithStreamingLoadRTL wiring.
// STREAMING selects the original structural/state differences, not a behavior model.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`include "cgra_opcodes.svh"
module tile_variant_core #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS, parameter bit STREAMING=0) (
  input  logic [CGRA_ID_W-1:0] cgra_id ,
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_data__msg [0:TILE_PORTS-1] ,
  output logic [0:0] recv_data__rdy [0:TILE_PORTS-1] ,
  input logic [0:0] recv_data__val [0:TILE_PORTS-1] ,
  input logic [HOST_BITS-1:0] recv_from_controller_pkt__msg ,
  output logic [0:0] recv_from_controller_pkt__rdy  ,
  input logic [0:0] recv_from_controller_pkt__val  ,
  output logic [DATA_BITS-1:0] send_data__msg [0:TILE_PORTS-1] ,
  input logic [0:0] send_data__rdy [0:TILE_PORTS-1] ,
  output logic [0:0] send_data__val [0:TILE_PORTS-1] ,
  output logic [HOST_BITS-1:0] send_to_controller_pkt__msg ,
  input logic [0:0] send_to_controller_pkt__rdy  ,
  output logic [0:0] send_to_controller_pkt__val  ,
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
  localparam int ROUTE_INPUTS = STREAMING ? TILE_PORTS : TILE_PORTS+4;
  host_packet_t packet; ctrl_t control;
  logic clear, element_done, routing_crossbar_done, fu_crossbar_done;
  assign packet=recv_from_controller_pkt__msg;
  initial begin
    if ((!STREAMING && TILE_PORTS!=4 && TILE_PORTS!=8) || (STREAMING && TILE_PORTS!=8))
      $fatal(1,"ac96 Tile variants require context4/context8 or streaming8 physical ports");
  end
  logic [0:0] const_mem__clear ;
  logic [0:0] const_mem__ctrl_proceed ;
  logic [DATA_BITS-1:0] const_mem__recv_const__msg ;
  logic [0:0] const_mem__recv_const__rdy ;
  logic [0:0] const_mem__recv_const__val ;
  logic [DATA_BITS-1:0] const_mem__send_const__msg ;
  logic [0:0] const_mem__send_const__rdy ;
  logic [0:0] const_mem__send_const__val ;
  tile_variant_const_queue #(`CGRA_PROFILE_BIND, .CONST_DEPTH(CTRL_DEPTH+(STREAMING?0:10))) const_mem (
    .clear(const_mem__clear),
    .clk(clk),
    .ctrl_proceed(const_mem__ctrl_proceed),
    .reset(reset),
    .recv_const__msg(const_mem__recv_const__msg),
    .recv_const__rdy(const_mem__recv_const__rdy),
    .recv_const__val(const_mem__recv_const__val),
    .send_const__msg(const_mem__send_const__msg),
    .send_const__rdy(const_mem__send_const__rdy),
    .send_const__val(const_mem__send_const__val)
  );
  logic [CGRA_ID_W-1:0] ctrl_mem__cgra_id ;
  logic [CTRL_ADDR_W-1:0] ctrl_mem__ctrl_addr_outport ;
  logic [2:0] ctrl_mem__prologue_count_outport_fu ;
  logic [2:0] ctrl_mem__prologue_count_outport_fu_crossbar [0:CTRL_DEPTH-1][0:1];
  logic [2:0] ctrl_mem__prologue_count_outport_routing_crossbar [0:CTRL_DEPTH-1][0:ROUTING_OUTPUTS-1];
  logic [TILE_ID_W-1:0] ctrl_mem__tile_id ;
  logic [PAYLOAD_BITS-1:0] ctrl_mem__recv_from_element__msg ;
  logic [0:0] ctrl_mem__recv_from_element__rdy ;
  logic [0:0] ctrl_mem__recv_from_element__val ;
  logic [HOST_BITS-1:0] ctrl_mem__recv_pkt_from_controller__msg ;
  logic [0:0] ctrl_mem__recv_pkt_from_controller__rdy ;
  logic [0:0] ctrl_mem__recv_pkt_from_controller__val ;
  logic [CTRL_BITS-1:0] ctrl_mem__send_ctrl__msg ;
  logic [0:0] ctrl_mem__send_ctrl__rdy ;
  logic [0:0] ctrl_mem__send_ctrl__val ;
  logic [HOST_BITS-1:0] ctrl_mem__send_pkt_to_controller__msg ;
  logic [0:0] ctrl_mem__send_pkt_to_controller__rdy ;
  logic [0:0] ctrl_mem__send_pkt_to_controller__val ;
  logic [PAYLOAD_BITS-1:0] ctrl_mem__send_to_element__msg ;
  logic [0:0] ctrl_mem__send_to_element__rdy ;
  logic [0:0] ctrl_mem__send_to_element__val ;
  tile_variant_ctrl_mem #(`CGRA_PROFILE_BIND) ctrl_mem (
    .cgra_id(ctrl_mem__cgra_id),
    .clk(clk),
    .ctrl_addr_outport(ctrl_mem__ctrl_addr_outport),
    .prologue_count_outport_fu(ctrl_mem__prologue_count_outport_fu),
    .prologue_count_outport_fu_crossbar(ctrl_mem__prologue_count_outport_fu_crossbar),
    .prologue_count_outport_routing_crossbar(ctrl_mem__prologue_count_outport_routing_crossbar),
    .reset(reset),
    .tile_id(ctrl_mem__tile_id),
    .recv_from_element__msg(ctrl_mem__recv_from_element__msg),
    .recv_from_element__rdy(ctrl_mem__recv_from_element__rdy),
    .recv_from_element__val(ctrl_mem__recv_from_element__val),
    .recv_pkt_from_controller__msg(ctrl_mem__recv_pkt_from_controller__msg),
    .recv_pkt_from_controller__rdy(ctrl_mem__recv_pkt_from_controller__rdy),
    .recv_pkt_from_controller__val(ctrl_mem__recv_pkt_from_controller__val),
    .send_ctrl__msg(ctrl_mem__send_ctrl__msg),
    .send_ctrl__rdy(ctrl_mem__send_ctrl__rdy),
    .send_ctrl__val(ctrl_mem__send_ctrl__val),
    .send_pkt_to_controller__msg(ctrl_mem__send_pkt_to_controller__msg),
    .send_pkt_to_controller__rdy(ctrl_mem__send_pkt_to_controller__rdy),
    .send_pkt_to_controller__val(ctrl_mem__send_pkt_to_controller__val),
    .send_to_element__msg(ctrl_mem__send_to_element__msg),
    .send_to_element__rdy(ctrl_mem__send_to_element__rdy),
    .send_to_element__val(ctrl_mem__send_to_element__val)
  );
  logic [0:0] element__clear [0:FU_COUNT-1];
  logic [CTRL_ADDR_W-1:0] element__ctrl_addr_inport ;
  logic [2:0] element__prologue_count_inport ;
  logic [TILE_ID_W-1:0] element__tile_id ;
  logic [DATA_BITS-1:0] element__from_mem_rdata__msg [0:FU_COUNT-1];
  logic [0:0] element__from_mem_rdata__rdy [0:FU_COUNT-1];
  logic [0:0] element__from_mem_rdata__val [0:FU_COUNT-1];
  logic [DATA_BITS-1:0] element__recv_const__msg ;
  logic [0:0] element__recv_const__rdy ;
  logic [0:0] element__recv_const__val ;
  logic [PAYLOAD_BITS-1:0] element__recv_from_ctrl_mem__msg ;
  logic [0:0] element__recv_from_ctrl_mem__rdy ;
  logic [0:0] element__recv_from_ctrl_mem__val ;
  logic [DATA_BITS-1:0] element__recv_in__msg [0:3];
  logic [0:0] element__recv_in__rdy [0:3];
  logic [0:0] element__recv_in__val [0:3];
  logic [CTRL_BITS-1:0] element__recv_opt__msg ;
  logic [0:0] element__recv_opt__rdy ;
  logic [0:0] element__recv_opt__val ;
  logic [HOST_BITS-1:0] element__recv_pkt_from_controller__msg ;
  logic [0:0] element__recv_pkt_from_controller__rdy ;
  logic [0:0] element__recv_pkt_from_controller__val ;
  logic [DATA_BITS-1:0] element__send_out__msg [0:1];
  logic [0:0] element__send_out__rdy [0:1];
  logic [0:0] element__send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] element__send_to_ctrl_mem__msg ;
  logic [0:0] element__send_to_ctrl_mem__rdy ;
  logic [0:0] element__send_to_ctrl_mem__val ;
  logic [GLOBAL_ADDR_W-1:0] element__to_mem_raddr__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_raddr__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_raddr__val [0:FU_COUNT-1];
  logic [GLOBAL_ADDR_W-1:0] element__to_mem_waddr__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_waddr__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_waddr__val [0:FU_COUNT-1];
  logic [DATA_BITS-1:0] element__to_mem_wdata__msg [0:FU_COUNT-1];
  logic [0:0] element__to_mem_wdata__rdy [0:FU_COUNT-1];
  logic [0:0] element__to_mem_wdata__val [0:FU_COUNT-1];
  tile_flexible_fu_configurable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) element (
    .clear(element__clear),
    .clk(clk),
    .ctrl_addr_inport(element__ctrl_addr_inport),
    .prologue_count_inport(element__prologue_count_inport),
    .reset(reset),
    .tile_id(element__tile_id),
    .from_mem_rdata__msg(element__from_mem_rdata__msg),
    .from_mem_rdata__rdy(element__from_mem_rdata__rdy),
    .from_mem_rdata__val(element__from_mem_rdata__val),
    .recv_const__msg(element__recv_const__msg),
    .recv_const__rdy(element__recv_const__rdy),
    .recv_const__val(element__recv_const__val),
    .recv_from_ctrl_mem__msg(element__recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(element__recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(element__recv_from_ctrl_mem__val),
    .recv_in__msg(element__recv_in__msg),
    .recv_in__rdy(element__recv_in__rdy),
    .recv_in__val(element__recv_in__val),
    .recv_opt__msg(element__recv_opt__msg),
    .recv_opt__rdy(element__recv_opt__rdy),
    .recv_opt__val(element__recv_opt__val),
    .recv_pkt_from_controller__msg(element__recv_pkt_from_controller__msg),
    .recv_pkt_from_controller__rdy(element__recv_pkt_from_controller__rdy),
    .recv_pkt_from_controller__val(element__recv_pkt_from_controller__val),
    .send_out__msg(element__send_out__msg),
    .send_out__rdy(element__send_out__rdy),
    .send_out__val(element__send_out__val),
    .send_to_ctrl_mem__msg(element__send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(element__send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(element__send_to_ctrl_mem__val),
    .to_mem_raddr__msg(element__to_mem_raddr__msg),
    .to_mem_raddr__rdy(element__to_mem_raddr__rdy),
    .to_mem_raddr__val(element__to_mem_raddr__val),
    .to_mem_waddr__msg(element__to_mem_waddr__msg),
    .to_mem_waddr__rdy(element__to_mem_waddr__rdy),
    .to_mem_waddr__val(element__to_mem_waddr__val),
    .to_mem_wdata__msg(element__to_mem_wdata__msg),
    .to_mem_wdata__rdy(element__to_mem_wdata__rdy),
    .to_mem_wdata__val(element__to_mem_wdata__val)
  );
  logic [0:0] register_cluster__clear ;
  logic [0:0] register_cluster__inport_ctrl_proceed ;
  logic [CTRL_BITS-1:0] register_cluster__inport_opt ;
  logic [DATA_BITS-1:0] register_cluster__recv_data_from_const__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_const__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_const__val [0:3];
  logic [DATA_BITS-1:0] register_cluster__recv_data_from_fu_crossbar__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_fu_crossbar__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_fu_crossbar__val [0:3];
  logic [DATA_BITS-1:0] register_cluster__recv_data_from_routing_crossbar__msg [0:3];
  logic [0:0] register_cluster__recv_data_from_routing_crossbar__rdy [0:3];
  logic [0:0] register_cluster__recv_data_from_routing_crossbar__val [0:3];
  logic [DATA_BITS-1:0] register_cluster__send_data_to_fu__msg [0:3];
  logic [0:0] register_cluster__send_data_to_fu__rdy [0:3];
  logic [0:0] register_cluster__send_data_to_fu__val [0:3];
  logic [DATA_BITS-1:0] register_cluster__send_data_to_routing_crossbar__msg [0:3];
  logic [0:0] register_cluster__send_data_to_routing_crossbar__rdy [0:3];
  logic [0:0] register_cluster__send_data_to_routing_crossbar__val [0:3];
  register_cluster #(`CGRA_PROFILE_BIND) register_cluster (
    .clear(register_cluster__clear),
    .clk(clk),
    .inport_ctrl_proceed(register_cluster__inport_ctrl_proceed),
    .inport_opt(register_cluster__inport_opt),
    .reset(reset),
    .recv_data_from_const__msg(register_cluster__recv_data_from_const__msg),
    .recv_data_from_const__rdy(register_cluster__recv_data_from_const__rdy),
    .recv_data_from_const__val(register_cluster__recv_data_from_const__val),
    .recv_data_from_fu_crossbar__msg(register_cluster__recv_data_from_fu_crossbar__msg),
    .recv_data_from_fu_crossbar__rdy(register_cluster__recv_data_from_fu_crossbar__rdy),
    .recv_data_from_fu_crossbar__val(register_cluster__recv_data_from_fu_crossbar__val),
    .recv_data_from_routing_crossbar__msg(register_cluster__recv_data_from_routing_crossbar__msg),
    .recv_data_from_routing_crossbar__rdy(register_cluster__recv_data_from_routing_crossbar__rdy),
    .recv_data_from_routing_crossbar__val(register_cluster__recv_data_from_routing_crossbar__val),
    .send_data_to_fu__msg(register_cluster__send_data_to_fu__msg),
    .send_data_to_fu__rdy(register_cluster__send_data_to_fu__rdy),
    .send_data_to_fu__val(register_cluster__send_data_to_fu__val),
    .send_data_to_routing_crossbar__msg(register_cluster__send_data_to_routing_crossbar__msg),
    .send_data_to_routing_crossbar__rdy(register_cluster__send_data_to_routing_crossbar__rdy),
    .send_data_to_routing_crossbar__val(register_cluster__send_data_to_routing_crossbar__val)
  );
  logic [CGRA_ID_W-1:0] routing_crossbar__cgra_id ;
  logic [0:0] routing_crossbar__clear ;
  logic [0:0] routing_crossbar__compute_done ;
  logic [0:0] routing_crossbar__crossbar_id ;
  logic [ROUTING_SEL_W-1:0] routing_crossbar__crossbar_outport [0:ROUTING_OUTPUTS-1];
  logic [CTRL_ADDR_W-1:0] routing_crossbar__ctrl_addr_inport ;
  logic [2:0] routing_crossbar__prologue_count_inport [0:CTRL_DEPTH-1][0:ROUTE_INPUTS-1];
  logic [TILE_ID_W-1:0] routing_crossbar__tile_id ;
  logic [DATA_BITS-1:0] routing_crossbar__recv_data__msg [0:ROUTE_INPUTS-1];
  logic [0:0] routing_crossbar__recv_data__rdy [0:ROUTE_INPUTS-1];
  logic [0:0] routing_crossbar__recv_data__val [0:ROUTE_INPUTS-1];
  logic [CTRL_BITS-1:0] routing_crossbar__recv_opt__msg ;
  logic [0:0] routing_crossbar__recv_opt__rdy ;
  logic [0:0] routing_crossbar__recv_opt__val ;
  logic [DATA_BITS-1:0] routing_crossbar__send_data__msg [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__send_data__rdy [0:ROUTING_OUTPUTS-1];
  logic [0:0] routing_crossbar__send_data__val [0:ROUTING_OUTPUTS-1];
  tile_variant_crossbar #(`CGRA_PROFILE_BIND, .INPUTS(ROUTE_INPUTS)) routing_crossbar (
    .cgra_id(routing_crossbar__cgra_id),
    .clear(routing_crossbar__clear),
    .clk(clk),
    .compute_done(routing_crossbar__compute_done),
    .crossbar_id(routing_crossbar__crossbar_id),
    .crossbar_outport(routing_crossbar__crossbar_outport),
    .ctrl_addr_inport(routing_crossbar__ctrl_addr_inport),
    .prologue_count_inport(routing_crossbar__prologue_count_inport),
    .reset(reset),
    .tile_id(routing_crossbar__tile_id),
    .recv_data__msg(routing_crossbar__recv_data__msg),
    .recv_data__rdy(routing_crossbar__recv_data__rdy),
    .recv_data__val(routing_crossbar__recv_data__val),
    .recv_opt__msg(routing_crossbar__recv_opt__msg),
    .recv_opt__rdy(routing_crossbar__recv_opt__rdy),
    .recv_opt__val(routing_crossbar__recv_opt__val),
    .send_data__msg(routing_crossbar__send_data__msg),
    .send_data__rdy(routing_crossbar__send_data__rdy),
    .send_data__val(routing_crossbar__send_data__val)
  );
  logic [CGRA_ID_W-1:0] fu_crossbar__cgra_id ;
  logic [0:0] fu_crossbar__clear ;
  logic [0:0] fu_crossbar__compute_done ;
  logic [0:0] fu_crossbar__crossbar_id ;
  logic [2-1:0] fu_crossbar__crossbar_outport [0:ROUTING_OUTPUTS-1];
  logic [CTRL_ADDR_W-1:0] fu_crossbar__ctrl_addr_inport ;
  logic [2:0] fu_crossbar__prologue_count_inport [0:CTRL_DEPTH-1][0:2-1];
  logic [TILE_ID_W-1:0] fu_crossbar__tile_id ;
  logic [DATA_BITS-1:0] fu_crossbar__recv_data__msg [0:2-1];
  logic [0:0] fu_crossbar__recv_data__rdy [0:2-1];
  logic [0:0] fu_crossbar__recv_data__val [0:2-1];
  logic [CTRL_BITS-1:0] fu_crossbar__recv_opt__msg ;
  logic [0:0] fu_crossbar__recv_opt__rdy ;
  logic [0:0] fu_crossbar__recv_opt__val ;
  logic [DATA_BITS-1:0] fu_crossbar__send_data__msg [0:ROUTING_OUTPUTS-1];
  logic [0:0] fu_crossbar__send_data__rdy [0:ROUTING_OUTPUTS-1];
  logic [0:0] fu_crossbar__send_data__val [0:ROUTING_OUTPUTS-1];
  tile_variant_crossbar #(`CGRA_PROFILE_BIND, .INPUTS(2)) fu_crossbar (
    .cgra_id(fu_crossbar__cgra_id),
    .clear(fu_crossbar__clear),
    .clk(clk),
    .compute_done(fu_crossbar__compute_done),
    .crossbar_id(fu_crossbar__crossbar_id),
    .crossbar_outport(fu_crossbar__crossbar_outport),
    .ctrl_addr_inport(fu_crossbar__ctrl_addr_inport),
    .prologue_count_inport(fu_crossbar__prologue_count_inport),
    .reset(reset),
    .tile_id(fu_crossbar__tile_id),
    .recv_data__msg(fu_crossbar__recv_data__msg),
    .recv_data__rdy(fu_crossbar__recv_data__rdy),
    .recv_data__val(fu_crossbar__recv_data__val),
    .recv_opt__msg(fu_crossbar__recv_opt__msg),
    .recv_opt__rdy(fu_crossbar__recv_opt__rdy),
    .recv_opt__val(fu_crossbar__recv_opt__val),
    .send_data__msg(fu_crossbar__send_data__msg),
    .send_data__rdy(fu_crossbar__send_data__rdy),
    .send_data__val(fu_crossbar__send_data__val)
  );
  assign ctrl_mem__tile_id=tile_id;
  assign element__tile_id=tile_id;
  assign routing_crossbar__tile_id=tile_id;
  assign fu_crossbar__tile_id=tile_id;
  assign ctrl_mem__cgra_id=cgra_id;
  assign routing_crossbar__cgra_id=cgra_id;
  assign fu_crossbar__cgra_id=cgra_id;
  assign routing_crossbar__crossbar_id=1'b0;
  assign fu_crossbar__crossbar_id=1'b1;
  assign control=ctrl_mem__send_ctrl__msg;
  assign element__recv_const__msg=const_mem__send_const__msg;
  assign element__recv_const__val=const_mem__send_const__val;
  assign const_mem__send_const__rdy=element__recv_const__rdy;
  assign ctrl_mem__recv_from_element__msg=element__send_to_ctrl_mem__msg;
  assign ctrl_mem__recv_from_element__val=element__send_to_ctrl_mem__val;
  assign element__send_to_ctrl_mem__rdy=ctrl_mem__recv_from_element__rdy;
  assign element__recv_from_ctrl_mem__msg=ctrl_mem__send_to_element__msg;
  assign element__recv_from_ctrl_mem__val=ctrl_mem__send_to_element__val;
  assign ctrl_mem__send_to_element__rdy=element__recv_from_ctrl_mem__rdy;
  assign routing_crossbar__ctrl_addr_inport=ctrl_mem__ctrl_addr_outport;
  assign routing_crossbar__compute_done=element_done;
  assign routing_crossbar__clear=clear;
  assign routing_crossbar__recv_opt__msg=control;
  assign routing_crossbar__recv_opt__val=ctrl_mem__send_ctrl__val & ~routing_crossbar_done;
  assign fu_crossbar__ctrl_addr_inport=ctrl_mem__ctrl_addr_outport;
  assign fu_crossbar__compute_done=element_done;
  assign fu_crossbar__clear=clear;
  assign fu_crossbar__recv_opt__msg=control;
  assign fu_crossbar__recv_opt__val=ctrl_mem__send_ctrl__val & ~fu_crossbar_done;
  assign element__recv_opt__msg=control;
  assign element__recv_opt__val=ctrl_mem__send_ctrl__val & ~element_done;
  assign element__prologue_count_inport=ctrl_mem__prologue_count_outport_fu;
  assign fu_crossbar__prologue_count_inport=ctrl_mem__prologue_count_outport_fu_crossbar;
  assign ctrl_mem__send_ctrl__rdy=(element__recv_opt__rdy | element_done) & (routing_crossbar__recv_opt__rdy | routing_crossbar_done) & (fu_crossbar__recv_opt__rdy | fu_crossbar_done);
  assign const_mem__ctrl_proceed=ctrl_mem__send_ctrl__rdy & ctrl_mem__send_ctrl__val;
  assign register_cluster__inport_ctrl_proceed=const_mem__ctrl_proceed;
  assign register_cluster__inport_opt=control;
  assign register_cluster__clear=clear;
  assign clear=!STREAMING && recv_from_controller_pkt__val && packet.payload.cmd==6'd2;
  for(genvar a=0;a<CTRL_DEPTH;a++) begin : prologue_rows
    for(genvar i=0;i<ROUTE_INPUTS;i++) begin : columns
      assign routing_crossbar__prologue_count_inport[a][i]=ctrl_mem__prologue_count_outport_routing_crossbar[a][i];
    end
  end
  for(genvar i=0;i<ROUTING_OUTPUTS;i++) begin : selection
    assign routing_crossbar__crossbar_outport[i]=control.routing_xbar_outport[i];
    assign fu_crossbar__crossbar_outport[i]=control.fu_xbar_outport[i];
  end
  for(genvar i=0;i<TILE_PORTS;i++) begin : physical_ports
    cgra_channel #(.WIDTH(DATA_BITS),.LATENCY(1)) input_channel (
      .clk(clk),.reset(reset),.clear(clear),
      .recv_msg(recv_data__msg[i]),.recv_val(recv_data__val[i]),.recv_rdy(recv_data__rdy[i]),
      .send_msg(routing_crossbar__recv_data__msg[i]),.send_val(routing_crossbar__recv_data__val[i]),.send_rdy(routing_crossbar__recv_data__rdy[i]));
    tile_link_or #(`CGRA_PROFILE_BIND) output_link (
      .clk(clk),.reset(reset),
      .recv_fu__msg(fu_crossbar__send_data__msg[i]),.recv_fu__val(fu_crossbar__send_data__val[i]),.recv_fu__rdy(fu_crossbar__send_data__rdy[i]),
      .recv_xbar__msg(routing_crossbar__send_data__msg[i]),.recv_xbar__val(routing_crossbar__send_data__val[i]),.recv_xbar__rdy(routing_crossbar__send_data__rdy[i]),
      .send__msg(send_data__msg[i]),.send__val(send_data__val[i]),.send__rdy(send_data__rdy[i]));
  end
  for(genvar i=0;i<4;i++) begin : operands
  assign register_cluster__recv_data_from_routing_crossbar__msg[i]=routing_crossbar__send_data__msg[TILE_PORTS+i];
  assign register_cluster__recv_data_from_routing_crossbar__val[i]=routing_crossbar__send_data__val[TILE_PORTS+i];
  assign routing_crossbar__send_data__rdy[TILE_PORTS+i]=register_cluster__recv_data_from_routing_crossbar__rdy[i];
  assign register_cluster__recv_data_from_fu_crossbar__msg[i]=fu_crossbar__send_data__msg[TILE_PORTS+i];
  assign register_cluster__recv_data_from_fu_crossbar__val[i]=fu_crossbar__send_data__val[TILE_PORTS+i];
  assign fu_crossbar__send_data__rdy[TILE_PORTS+i]=register_cluster__recv_data_from_fu_crossbar__rdy[i];
  assign element__recv_in__msg[i]=register_cluster__send_data_to_fu__msg[i];
  assign element__recv_in__val[i]=register_cluster__send_data_to_fu__val[i];
  assign register_cluster__send_data_to_fu__rdy[i]=element__recv_in__rdy[i];
  assign register_cluster__recv_data_from_const__msg[i]='0;
  assign register_cluster__recv_data_from_const__val[i]=1'b0;
    if(STREAMING) begin : no_register_routing
  assign register_cluster__send_data_to_routing_crossbar__rdy[i]=1'b0;
    end else begin : register_routing
  assign routing_crossbar__recv_data__msg[TILE_PORTS+i]=register_cluster__send_data_to_routing_crossbar__msg[i];
  assign routing_crossbar__recv_data__val[TILE_PORTS+i]=register_cluster__send_data_to_routing_crossbar__val[i];
  assign register_cluster__send_data_to_routing_crossbar__rdy[i]=routing_crossbar__recv_data__rdy[TILE_PORTS+i];
    end
  end
  assign fu_crossbar__recv_data__msg[1]=element__send_out__msg[1];
  assign fu_crossbar__recv_data__val[1]=element__send_out__val[1];
  assign element__send_out__rdy[1]=fu_crossbar__recv_data__rdy[1];
  assign element__send_out__rdy[0]=fu_crossbar__recv_data__rdy[0];
  if(STREAMING) begin : streaming_wiring
    assign element__ctrl_addr_inport=ctrl_mem__ctrl_addr_outport;
    assign fu_crossbar__recv_data__msg[0]=element__send_out__msg[0];
    assign fu_crossbar__recv_data__val[0]=element__send_out__val[0];
    // Streaming has no task-switch clear.
    assign const_mem__clear=1'b0;
  end else begin : context_wiring
    logic [DATA_BITS-1:0] overwrite_msg; logic overwrite_val;
    tile_context_switch #(`CGRA_PROFILE_BIND) context_switch (
      .clk(clk),.reset(reset),.recv_cmd(packet.payload.cmd),.recv_cmd_vld(recv_from_controller_pkt__val),
      .phi_addr(packet.payload.ctrl_addr),.recv_opt(control.operation),
      .progress_in(element__send_out__msg[0]),.progress_in_val(element__send_out__val[0]),
      .ctrl_mem_rd_addr(ctrl_mem__ctrl_addr_outport),
      .overwrite_fu_outport__msg(overwrite_msg),.overwrite_fu_outport__val(overwrite_val),.overwrite_fu_outport__rdy());
    assign fu_crossbar__recv_data__msg[0]=overwrite_val ? overwrite_msg : element__send_out__msg[0];
    assign fu_crossbar__recv_data__val[0]=overwrite_val | element__send_out__val[0];
    assign const_mem__clear=clear;
    // Per-slot grant state requires the actual control address in every variant.
    assign element__ctrl_addr_inport=ctrl_mem__ctrl_addr_outport;
    assign element__recv_pkt_from_controller__msg='0;
    assign element__recv_pkt_from_controller__val=1'b0;
  end
  function automatic int memory_count();
    int count;
    count=0;
    for(int i=0;i<FU_COUNT;i++)
      if(FU_KINDS[8*i+:8]==(STREAMING ? `CGRA_FU_STREAMING_MEM : `CGRA_FU_MEM)) count++;
    return count;
  endfunction
  initial if(memory_count()>1) $fatal(1,"Only one attached memory FU is supported");
  if(memory_count()==0) begin : no_memory_fu
    assign to_mem_raddr__msg='0;
    assign to_mem_raddr__val=1'b0;
    assign to_mem_waddr__msg='0;
    assign to_mem_waddr__val=1'b0;
    assign to_mem_wdata__msg='0;
    assign to_mem_wdata__val=1'b0;
    assign from_mem_rdata__rdy=1'b0;
  end
  for(genvar i=0;i<FU_COUNT;i++) begin : memory_slots
    localparam logic [7:0] KIND=FU_KINDS[8*i+:8];
    assign element__clear[i]=(!STREAMING && (KIND==`CGRA_FU_PHI || KIND==`CGRA_FU_RET || KIND==`CGRA_FU_GRANT)) ? clear : 1'b0;
    if((STREAMING && KIND==`CGRA_FU_STREAMING_MEM) || (!STREAMING && KIND==`CGRA_FU_MEM)) begin : attached
  assign to_mem_raddr__msg=element__to_mem_raddr__msg[i];
  assign to_mem_raddr__val=element__to_mem_raddr__val[i];
  assign element__to_mem_raddr__rdy[i]=to_mem_raddr__rdy;
  assign to_mem_waddr__msg=element__to_mem_waddr__msg[i];
  assign to_mem_waddr__val=element__to_mem_waddr__val[i];
  assign element__to_mem_waddr__rdy[i]=to_mem_waddr__rdy;
  assign to_mem_wdata__msg=element__to_mem_wdata__msg[i];
  assign to_mem_wdata__val=element__to_mem_wdata__val[i];
  assign element__to_mem_wdata__rdy[i]=to_mem_wdata__rdy;
  assign element__from_mem_rdata__msg[i]=from_mem_rdata__msg;
  assign element__from_mem_rdata__val[i]=from_mem_rdata__val;
  assign from_mem_rdata__rdy=element__from_mem_rdata__rdy[i];
    end else begin : detached
  assign element__to_mem_raddr__rdy[i]=1'b0;
  assign element__to_mem_waddr__rdy[i]=1'b0;
  assign element__to_mem_wdata__rdy[i]=1'b0;
  assign element__from_mem_rdata__msg[i]='0;
  assign element__from_mem_rdata__val[i]='0;
    end
  end
  logic accepted_command;
  always_comb begin
    case(packet.payload.cmd)
      6'd0,6'd3,6'd4,6'd5,6'd6,6'd7,6'd8,6'd20,6'd21,6'd23,6'd24,6'd25,6'd43: accepted_command=1;
      6'd1,6'd2,6'd9,6'd15,6'd16,6'd22: accepted_command=!STREAMING;
      default: accepted_command=0;
    endcase
    ctrl_mem__recv_pkt_from_controller__msg='0;
    ctrl_mem__recv_pkt_from_controller__val=0;
    const_mem__recv_const__msg='0; const_mem__recv_const__val=0;
    recv_from_controller_pkt__rdy=0;
    if(recv_from_controller_pkt__val && accepted_command) begin
      ctrl_mem__recv_pkt_from_controller__msg=packet; ctrl_mem__recv_pkt_from_controller__val=1;
      recv_from_controller_pkt__rdy=ctrl_mem__recv_pkt_from_controller__rdy | (STREAMING && element__recv_pkt_from_controller__rdy);
    end else if(recv_from_controller_pkt__val && packet.payload.cmd==6'd13) begin
      const_mem__recv_const__msg=packet.payload.data; const_mem__recv_const__val=1;
      recv_from_controller_pkt__rdy=const_mem__recv_const__rdy;
    end
  end
  if(STREAMING) begin : retained_packet
    // ac96 feed_pkt has no default assignment to these two signals.
    // Preserve its transparent retention; adding defaults would change behavior.
    always_latch if(recv_from_controller_pkt__val && accepted_command) begin
      element__recv_pkt_from_controller__msg=packet; element__recv_pkt_from_controller__val=1;
    end
  end
  assign send_to_controller_pkt__val=ctrl_mem__send_pkt_to_controller__val;
  assign send_to_controller_pkt__msg=ctrl_mem__send_pkt_to_controller__val ? ctrl_mem__send_pkt_to_controller__msg : '0;
  assign ctrl_mem__send_pkt_to_controller__rdy=send_to_controller_pkt__rdy;
  always_ff @(posedge clk) begin
    if(reset || ctrl_mem__send_ctrl__rdy || clear) begin
      element_done<=0; routing_crossbar_done<=0; fu_crossbar_done<=0;
    end else begin
      if(element__recv_opt__rdy) element_done<=1;
      // STREAM_LD can emit multiple results within one control step. Other
      // operations retire each crossbar once, even if the FU just completed
      // in this cycle (element_done still contains the previous cycle).
      if(routing_crossbar__recv_opt__rdy)
        routing_crossbar_done<=!STREAMING || control.operation!=`CGRA_OPT_STREAM_LD || element_done || element__recv_opt__rdy;
      if(fu_crossbar__recv_opt__rdy)
        fu_crossbar_done<=!STREAMING || control.operation!=`CGRA_OPT_STREAM_LD || element_done || element__recv_opt__rdy;
    end
  end
endmodule
