// Single-CGRA scalar profile. Geometry and storage sizes are elaboration parameters.
// Include before module declarations; use cgra_profile.svh inside each module.
`ifndef CGRA_PROFILE_DEFS_SVH
`define CGRA_PROFILE_DEFS_SVH
`define CGRA_PROFILE_PARAMETERS \
  parameter int COLS = 2, ROWS = 2, DATA_W = 32, TILE_PORTS = 4, \
  parameter int CTRL_DEPTH = 8, REG_DEPTH = 16, BANK_DEPTH = 16, \
  parameter int NUM_BANKS = 2, GLOBAL_ADDR_W = 7, \
  parameter int NUM_CTRL = 8, TOTAL_STEPS = 8, \
  localparam int NUM_TILES = COLS * ROWS, \
  localparam int TILE_ID_W = $clog2(NUM_TILES + 1), \
  localparam int CTRL_ADDR_W = $clog2(CTRL_DEPTH), \
  localparam int REG_ADDR_W = $clog2(REG_DEPTH), \
  localparam int BANK_ADDR_W = $clog2(BANK_DEPTH), \
  localparam int MEM_PORTS = COLS + ROWS - 1, \
  localparam int MEM_PORT_W = $clog2(MEM_PORTS + 1), \
  localparam int BANK_PORT_W = $clog2(NUM_BANKS + 1), \
  localparam int DATA_BITS = DATA_W + 3, \
  localparam int ROUTING_OUTPUTS = TILE_PORTS + 4, \
  localparam int ROUTING_SEL_W = $clog2(TILE_PORTS + 4 + 1), \
  localparam int CTRL_BITS = 39 + ROUTING_OUTPUTS * (ROUTING_SEL_W + 2) + 8 * REG_ADDR_W, \
  localparam int PAYLOAD_BITS = 6 + DATA_BITS + GLOBAL_ADDR_W + CTRL_BITS + CTRL_ADDR_W, \
  localparam int HOST_BITS = 2 * TILE_ID_W + 15 + PAYLOAD_BITS, \
  localparam int NOC_BITS = 2 * TILE_ID_W + MEM_PORT_W + 16 + PAYLOAD_BITS, \
  localparam int MEM_BITS = 2 * MEM_PORT_W + BANK_PORT_W + GLOBAL_ADDR_W + DATA_BITS + 1 + TILE_ID_W

`define CGRA_PROFILE_BIND \
  .COLS(COLS), .ROWS(ROWS), .DATA_W(DATA_W), .TILE_PORTS(TILE_PORTS), .CTRL_DEPTH(CTRL_DEPTH), \
  .REG_DEPTH(REG_DEPTH), .BANK_DEPTH(BANK_DEPTH), .NUM_BANKS(NUM_BANKS), \
  .GLOBAL_ADDR_W(GLOBAL_ADDR_W), .NUM_CTRL(NUM_CTRL), .TOTAL_STEPS(TOTAL_STEPS)
`endif
