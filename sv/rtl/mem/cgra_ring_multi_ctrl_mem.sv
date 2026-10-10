`include "cgra_ring_ctrl_defs.svh"
// Standalone RingMultiCtrlMemDynamicRTL. See RING_CTRL_MEMORY_API.md.
module cgra_ring_multi_ctrl_mem #(`CGRA_RING_CTRL_PARAMETERS)(
  input logic clk,reset,
  input logic [PACKET_BITS-1:0] recv_pkt_from_controller__msg,
  input logic recv_pkt_from_controller__val,
  output logic recv_pkt_from_controller__rdy,
  output logic [PACKET_BITS-1:0] send_to_controller_pkt__msg,
  output logic send_to_controller_pkt__val,
  input logic send_to_controller_pkt__rdy,
  output logic [CTRL_BITS-1:0] send_ctrl__msg [0:NUM_TILES-1],
  output logic send_ctrl__val [0:NUM_TILES-1],
  input logic send_ctrl__rdy [0:NUM_TILES-1]
);
  `include "cgra_ring_ctrl_types.svh"
  logic [PACKET_BITS-1:0] ring_recv_msg [0:NUM_TILES],ring_send_msg [0:NUM_TILES];
  logic ring_recv_val [0:NUM_TILES],ring_recv_rdy [0:NUM_TILES];
  logic ring_send_val [0:NUM_TILES],ring_send_rdy [0:NUM_TILES];
  assign ring_recv_msg[NUM_TILES]=recv_pkt_from_controller__msg;
  assign ring_recv_val[NUM_TILES]=recv_pkt_from_controller__val;
  assign recv_pkt_from_controller__rdy=ring_recv_rdy[NUM_TILES];
  if (LEGACY_PYTHON) begin : legacy
    assign send_to_controller_pkt__msg=ring_send_msg[NUM_TILES];
    assign send_to_controller_pkt__val=ring_send_val[NUM_TILES];
    assign ring_send_rdy[NUM_TILES]=send_to_controller_pkt__rdy;
  end else begin : native_output
    // The inherited VC arbiter may change selection while stalled. Register
    // the chosen packet so the public val/rdy output remains stable.
    cgra_queue #(.WIDTH(PACKET_BITS),.DEPTH(1)) hold_packet (
      .clk,.reset,.clear(1'b0),.recv_msg(ring_send_msg[NUM_TILES]),
      .recv_val(ring_send_val[NUM_TILES]),.recv_rdy(ring_send_rdy[NUM_TILES]),
      .send_msg(send_to_controller_pkt__msg),.send_val(send_to_controller_pkt__val),
      .send_rdy(send_to_controller_pkt__rdy),.count()
    );
  end
  cgra_credit_ring #(.WIDTH(PACKET_BITS),.NODES(NUM_TILES+1),
    .DST_LSB(PAYLOAD_BITS+15),.DST_WIDTH(ID_W),.VC_LSB(PAYLOAD_BITS)) ring_network (
    .clk,.reset,.recv_msg(ring_recv_msg),.recv_val(ring_recv_val),.recv_rdy(ring_recv_rdy),
    .send_msg(ring_send_msg),.send_val(ring_send_val),.send_rdy(ring_send_rdy)
  );
  for (genvar n=0;n<NUM_TILES;n++) begin : nodes
    cgra_ring_ctrl_node #(`CGRA_RING_CTRL_BIND) node_memory (
      .clk,.reset,.tile_id(ID_W'(n)),.recv_msg(ring_send_msg[n]),.recv_val(ring_send_val[n]),
      .recv_rdy(ring_send_rdy[n]),.send_msg(ring_recv_msg[n]),.send_val(ring_recv_val[n]),
      .send_rdy(ring_recv_rdy[n]),.ctrl_msg(send_ctrl__msg[n]),
      .ctrl_val(send_ctrl__val[n]),.ctrl_rdy(send_ctrl__rdy[n])
    );
  end
`ifndef SYNTHESIS
  initial begin
    if (COLS<1 || ROWS<1 || CTRL_DEPTH<2 || REG_DEPTH<2 || DATA_W<11 || DATA_ADDR_W<1 ||
        NUM_CTRL<1 || NUM_CTRL>CTRL_DEPTH || TOTAL_STEPS<0 || TOTAL_STEPS>2047 ||
        FU_INPUTS<1 || FU_INPUTS>4 || FU_OUTPUTS!=2 ||
        TILE_INPUTS<1 || TILE_INPUTS>8 || TILE_OUTPUTS<1 || TILE_OUTPUTS>8)
      $fatal(1,"RING_CTRL_PARAMETER");
  end
  ring_packet_t check_packet;
  assign check_packet=recv_pkt_from_controller__msg;
  always @(posedge clk) if (!reset && recv_pkt_from_controller__val) begin
    if (check_packet.dst > NUM_TILES) $fatal(1,"RING_CTRL_DESTINATION");
    if (check_packet.dst < NUM_TILES && check_packet.payload.cmd>=3 && check_packet.payload.cmd<=6 &&
        check_packet.payload.ctrl_addr >= CTRL_DEPTH) $fatal(1,"RING_CTRL_ADDRESS");
  end
`endif
endmodule
