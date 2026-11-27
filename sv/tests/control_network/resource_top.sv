`include "cgra_profile_defs.svh"
// Out-of-context control fabric only. The same full payloads, programmable
// destinations and independent backpressure drive every compared backend.
module control_resource_top #(`CGRA_PROFILE_PARAMETERS) (
  input logic clk,reset,
  input logic [PAYLOAD_BITS-1:0] command,
  input logic [TILE_ID_W-1:0] destination,
  input logic command_valid,
  output logic command_ready,
  output logic [HOST_BITS-1:0] pe_command [0:NUM_TILES-1],
  output logic pe_command_valid [0:NUM_TILES-1],
  input logic pe_command_ready [0:NUM_TILES-1],
  input logic [PAYLOAD_BITS-1:0] pe_return [0:NUM_TILES-1],
  input logic pe_return_valid [0:NUM_TILES-1],
  output logic pe_return_ready [0:NUM_TILES-1],
  output logic [HOST_BITS-1:0] controller_return,
  output logic controller_return_valid,
  input logic controller_return_ready
);
  `include "cgra_profile.svh"
  logic [HOST_BITS-1:0] recv_msg[0:MAX_TILES],send_msg[0:MAX_TILES];
  logic recv_val[0:MAX_TILES],recv_rdy[0:MAX_TILES];
  logic send_val[0:MAX_TILES],send_rdy[0:MAX_TILES];
  host_packet_t down;
  always_comb begin
    down='0;down.src=TILE_ID_W'(NUM_TILES);down.dst=destination;down.payload=command;
  end
  assign recv_msg[NUM_TILES]=down;
  assign recv_val[NUM_TILES]=command_valid && int'(destination)<NUM_TILES;
  assign command_ready=recv_rdy[NUM_TILES] && int'(destination)<NUM_TILES;
  assign controller_return=send_msg[NUM_TILES];
  assign controller_return_valid=send_val[NUM_TILES];
  assign send_rdy[NUM_TILES]=controller_return_ready;
  for(genvar t=0;t<NUM_TILES;t++)begin : endpoints
    host_packet_t up;
    always_comb begin up='0;up.src=TILE_ID_W'(t);up.dst=TILE_ID_W'(NUM_TILES);up.payload=pe_return[t];end
    assign recv_msg[t]=up;assign recv_val[t]=pe_return_valid[t];assign pe_return_ready[t]=recv_rdy[t];
    assign pe_command[t]=send_msg[t];assign pe_command_valid[t]=send_val[t];assign send_rdy[t]=pe_command_ready[t];
  end
  for(genvar t=NUM_TILES+1;t<=MAX_TILES;t++)begin : padding
    assign recv_msg[t]='0;assign recv_val[t]=0;assign send_rdy[t]=0;
  end
  if(CTRL_NETWORK==0)begin : ring
    cgra_credit_ring #(.WIDTH(HOST_BITS),.NODES(MAX_TILES+1),.DST_LSB(HOST_DST_LSB),
      .DST_WIDTH(TILE_ID_W),.VC_LSB(PAYLOAD_BITS),.LEGACY_PYTHON(0)) network(.*);
  end else begin : dedicated
    cgra_ctrl_network #(.WIDTH(HOST_BITS),.TILES(NUM_TILES),.MAX_TILES(MAX_TILES),
      .COLS(COLS),.LAYOUT(CTRL_NETWORK),.DST_LSB(HOST_DST_LSB),.DST_WIDTH(TILE_ID_W),.VC_LSB(PAYLOAD_BITS),
      .MULTICAST(CTRL_MULTICAST),.CMD_LSB(PAYLOAD_BITS-6),.DATA_LSB(CTRL_ADDR_W+CTRL_BITS+GLOBAL_ADDR_W+3),
      .DATA_WIDTH(DATA_W),.MASK_ADDR_LSB(CTRL_ADDR_W+CTRL_BITS),.MASK_ADDR_WIDTH(GLOBAL_ADDR_W),
      .CTRL_ADDR_WIDTH(CTRL_ADDR_W),.CTRL_DEPTH(CTRL_DEPTH)) network(.*);
  end
endmodule
