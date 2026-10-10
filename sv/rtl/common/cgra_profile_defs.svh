// CGRA profile. Default packet layouts remain the single-CGRA stage-1 contract.
// Include before module declarations; use cgra_profile.svh inside each module.
`ifndef CGRA_PROFILE_DEFS_SVH
`define CGRA_PROFILE_DEFS_SVH
`define CGRA_PROFILE_PARAMETERS \
  parameter int COLS = 2, ROWS = 2, DATA_W = 32, TILE_PORTS = 4, \
  parameter int CTRL_DEPTH = 8, REG_DEPTH = 16, BANK_DEPTH = 16, \
  parameter int NUM_BANKS = 2, GLOBAL_ADDR_W = 7, \
  parameter int NUM_CTRL = 8, TOTAL_STEPS = 8, \
  parameter int MULTI_COLS = 1, MULTI_ROWS = 1, \
  parameter int MAX_COLS = COLS, MAX_ROWS = ROWS, \
  parameter int MEM_PORTS = COLS + ROWS - 1, MAX_MEM_PORTS = MEM_PORTS, \
  parameter int MEM_WRITE_PORTS = MEM_PORTS, \
  parameter bit HAS_DMA = 0, HAS_IM2COL = 0, \
  parameter bit MEM_COMBINATIONAL = 1, MEMORY_LEGACY_PYTHON = 0, \
  localparam int NUM_TILES = COLS * ROWS, \
  localparam int MAX_TILES = MAX_COLS * MAX_ROWS, \
  localparam int NUM_CGRAS = MULTI_COLS * MULTI_ROWS, \
  localparam int CGRA_ID_W = NUM_CGRAS > 1 ? $clog2(NUM_CGRAS) : 1, \
  localparam int CGRA_X_W = MULTI_COLS > 1 ? $clog2(MULTI_COLS) : 1, \
  localparam int CGRA_Y_W = MULTI_ROWS > 1 ? $clog2(MULTI_ROWS) : 1, \
  parameter bit CUSTOM_ADDR_MAP = 0, CUSTOM_COORD_MAP = 0, \
  parameter logic [NUM_CGRAS*CGRA_ID_W-1:0] ADDR_MAP = '0, \
  parameter logic [NUM_CGRAS*CGRA_X_W-1:0] COORD_X_MAP = '0, \
  parameter logic [NUM_CGRAS*CGRA_Y_W-1:0] COORD_Y_MAP = '0, \
  localparam int TILE_ID_W = $clog2(MAX_TILES + 1), \
  localparam int CTRL_ADDR_W = $clog2(CTRL_DEPTH), \
  localparam int REG_ADDR_W = $clog2(REG_DEPTH), \
  localparam int BANK_ADDR_W = $clog2(BANK_DEPTH), \
  localparam int MEM_PORT_W = $clog2(MAX_MEM_PORTS + 1), \
  localparam int XBAR_MEM_PORTS = MEM_PORTS + 1 + HAS_DMA, \
  localparam int XBAR_MEM_PORT_W = $clog2(XBAR_MEM_PORTS), \
  localparam int XBAR_WR_MEM_PORTS = MEM_WRITE_PORTS + 1 + HAS_DMA, \
  localparam int XBAR_WR_MEM_PORT_W = $clog2(XBAR_WR_MEM_PORTS), \
  localparam int BANK_PORT_W = $clog2(NUM_BANKS + 1), \
  localparam int DATA_BITS = DATA_W + 3, \
  localparam int ROUTING_OUTPUTS = TILE_PORTS + 4, \
  localparam int ROUTING_SEL_W = $clog2(TILE_PORTS + 4 + 1), \
  localparam int CTRL_BITS = 39 + ROUTING_OUTPUTS * (ROUTING_SEL_W + 2) + 8 * REG_ADDR_W, \
  localparam int PAYLOAD_BITS = 6 + DATA_BITS + GLOBAL_ADDR_W + CTRL_BITS + CTRL_ADDR_W, \
  localparam int HOST_DST_LSB = PAYLOAD_BITS + 9 + 2 * (CGRA_ID_W + CGRA_X_W + CGRA_Y_W), \
  localparam int HOST_BITS = 2 * TILE_ID_W + HOST_DST_LSB, \
  localparam int NOC_BITS = 2 * TILE_ID_W + MEM_PORT_W + 10 + 2 * (CGRA_ID_W + CGRA_X_W + CGRA_Y_W) + PAYLOAD_BITS, \
  localparam int MEM_BITS = XBAR_MEM_PORT_W + MEM_PORT_W + BANK_PORT_W + GLOBAL_ADDR_W + DATA_BITS + CGRA_ID_W + TILE_ID_W, \
  localparam int WR_MEM_BITS = MEM_BITS - XBAR_MEM_PORT_W + XBAR_WR_MEM_PORT_W

`define CGRA_PROFILE_BIND_STORAGE \
  .DATA_W(DATA_W), .TILE_PORTS(TILE_PORTS), \
  .REG_DEPTH(REG_DEPTH), .BANK_DEPTH(BANK_DEPTH), .NUM_BANKS(NUM_BANKS), \
  .GLOBAL_ADDR_W(GLOBAL_ADDR_W), .NUM_CTRL(NUM_CTRL), .TOTAL_STEPS(TOTAL_STEPS), \
  .MULTI_COLS(MULTI_COLS), .MULTI_ROWS(MULTI_ROWS), .MAX_COLS(MAX_COLS), .MAX_ROWS(MAX_ROWS), \
  .MEM_PORTS(MEM_PORTS), .MEM_WRITE_PORTS(MEM_WRITE_PORTS), .MAX_MEM_PORTS(MAX_MEM_PORTS), .HAS_DMA(HAS_DMA), .HAS_IM2COL(HAS_IM2COL), \
  .MEM_COMBINATIONAL(MEM_COMBINATIONAL), .MEMORY_LEGACY_PYTHON(MEMORY_LEGACY_PYTHON), \
  .CUSTOM_ADDR_MAP(CUSTOM_ADDR_MAP), .CUSTOM_COORD_MAP(CUSTOM_COORD_MAP), \
  .ADDR_MAP(ADDR_MAP), .COORD_X_MAP(COORD_X_MAP), .COORD_Y_MAP(COORD_Y_MAP)
`define CGRA_PROFILE_BIND \
  .COLS(COLS), .ROWS(ROWS), .CTRL_DEPTH(CTRL_DEPTH), `CGRA_PROFILE_BIND_STORAGE
`endif
