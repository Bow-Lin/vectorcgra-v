`include "cgra_ring_ctrl_defs.svh"
// Bit-preserving layout adapter. Execution state remains in the existing ctrl_mem.
// Unused FU/routing fields are zero-padded; visible fields are never truncated.
module cgra_ring_ctrl_node #(`CGRA_RING_CTRL_PARAMETERS)(
  input logic clk,reset,
  input logic [ID_W-1:0] tile_id,
  input logic [PACKET_BITS-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [PACKET_BITS-1:0] send_msg,
  output logic send_val,
  input logic send_rdy,
  output logic [CTRL_BITS-1:0] ctrl_msg,
  output logic ctrl_val,
  input logic ctrl_rdy
);
  `include "cgra_ring_ctrl_types.svh"
  localparam integer CORE_PORTS=(TILE_INPUTS>TILE_OUTPUTS)?
    ((TILE_INPUTS>4)?TILE_INPUTS:4):((TILE_OUTPUTS>4)?TILE_OUTPUTS:4);
  localparam integer CORE_ROUTES=CORE_PORTS+4, CORE_ROUTE_W=$clog2(CORE_ROUTES+1);
  typedef struct packed {
    logic [6:0] operation;
    logic [3:0][2:0] fu_in;
    logic [CORE_ROUTES-1:0][CORE_ROUTE_W-1:0] routing_xbar_outport;
    logic [CORE_ROUTES-1:0][1:0] fu_xbar_outport;
    logic [2:0] vector_factor_power;
    logic is_last_ctrl;
    logic [3:0][1:0] write_reg_from;
    logic [3:0][REG_W-1:0] write_reg_idx;
    logic [3:0][1:0] read_reg_towards;
    logic [3:0][REG_W-1:0] read_reg_idx;
  } core_ctrl_t;
  typedef struct packed {
    logic [5:0] cmd;
    ring_data_t data;
    logic [DATA_ADDR_W-1:0] data_addr;
    core_ctrl_t ctrl;
    logic [ADDR_W-1:0] ctrl_addr;
  } core_payload_t;
  typedef struct packed {
    logic [ID_W-1:0] src,dst;
    logic src_cgra_id,dst_cgra_id,src_cgra_x,src_cgra_y,dst_cgra_x,dst_cgra_y;
    logic [7:0] opaque;
    logic vc_id;
    core_payload_t payload;
  } core_packet_t;
  function automatic core_ctrl_t widen(input ring_ctrl_t source);
    core_ctrl_t result;
    result='0;
    result.operation=source.operation;
    result.vector_factor_power=source.vector_factor_power;
    result.is_last_ctrl=source.is_last_ctrl;
    for (integer i=0;i<FU_INPUTS;i++) begin
      result.fu_in[i]=3'(source.fu_in[i]);
      result.write_reg_from[i]=source.write_reg_from[i];
      result.write_reg_idx[i]=source.write_reg_idx[i];
      result.read_reg_towards[i]=source.read_reg_towards[i];
      result.read_reg_idx[i]=source.read_reg_idx[i];
    end
    for (integer i=0;i<ROUTES;i++) begin
      result.routing_xbar_outport[i]=CORE_ROUTE_W'(source.routing_xbar_outport[i]);
      result.fu_xbar_outport[i]=2'(source.fu_xbar_outport[i]);
    end
    return result;
  endfunction
  function automatic ring_ctrl_t narrow(input core_ctrl_t source);
    ring_ctrl_t result;
    result='0;
    result.operation=source.operation;
    result.vector_factor_power=source.vector_factor_power;
    result.is_last_ctrl=source.is_last_ctrl;
    for (integer i=0;i<FU_INPUTS;i++) begin
      result.fu_in[i]=FU_SEL_W'(source.fu_in[i]);
      result.write_reg_from[i]=source.write_reg_from[i];
      result.write_reg_idx[i]=source.write_reg_idx[i];
      result.read_reg_towards[i]=source.read_reg_towards[i];
      result.read_reg_idx[i]=source.read_reg_idx[i];
    end
    for (integer i=0;i<ROUTES;i++) begin
      result.routing_xbar_outport[i]=ROUTE_W'(source.routing_xbar_outport[i]);
      result.fu_xbar_outport[i]=FU_OUT_W'(source.fu_xbar_outport[i]);
    end
    return result;
  endfunction
  ring_packet_t incoming,outgoing;
  core_packet_t core_recv,core_send;
  core_ctrl_t core_ctrl;
  assign incoming=recv_msg;
  assign core_recv={incoming[PACKET_BITS-1:PAYLOAD_BITS],incoming.payload.cmd,
    incoming.payload.data,incoming.payload.data_addr,widen(incoming.payload.ctrl),incoming.payload.ctrl_addr};
  assign outgoing={core_send[$bits(core_packet_t)-1:$bits(core_payload_t)],core_send.payload.cmd,
    core_send.payload.data,core_send.payload.data_addr,narrow(core_send.payload.ctrl),core_send.payload.ctrl_addr};
  assign send_msg=outgoing;
  assign ctrl_msg=narrow(core_ctrl);
  ctrl_mem #(.COLS(COLS),.ROWS(ROWS),.DATA_W(DATA_W),.TILE_PORTS(CORE_PORTS),
    .CTRL_DEPTH(CTRL_DEPTH),.REG_DEPTH(REG_DEPTH),.GLOBAL_ADDR_W(DATA_ADDR_W),
    .NUM_CTRL(NUM_CTRL),.TOTAL_STEPS(TOTAL_STEPS)) memory (
    .clk,.reset,.cgra_id(1'b0),.tile_id,
    .recv_pkt_from_controller__msg(core_recv),.recv_pkt_from_controller__val(recv_val),
    .recv_pkt_from_controller__rdy(recv_rdy),
    .send_pkt_to_controller__msg(core_send),.send_pkt_to_controller__val(send_val),
    .send_pkt_to_controller__rdy(send_rdy),
    .send_ctrl__msg(core_ctrl),.send_ctrl__val(ctrl_val),.send_ctrl__rdy(ctrl_rdy),
    .recv_from_element__msg('0),.recv_from_element__val(LEGACY_PYTHON),.recv_from_element__rdy(),
    .send_to_element__msg(),.send_to_element__val(),.send_to_element__rdy(1'b0),
    .ctrl_addr_outport(),.prologue_count_outport_fu(),
    .prologue_count_outport_fu_crossbar(),.prologue_count_outport_routing_crossbar()
  );
endmodule
