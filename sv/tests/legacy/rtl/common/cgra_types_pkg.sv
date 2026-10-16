`include "cgra_opcodes.svh"
// Public field and configuration contract for the fixed scalar 2x2 profile.
// Packing matches ac96a7 lib/messages.py and reference/manifest.json.
// Packed array element 0 occupies the low bits of that array field.
package cgra_types_pkg;
  localparam int TILE_COLUMNS = 2;
  localparam int TILE_ROWS = 2;
  localparam int NUM_TILES = 4;
  localparam int CONTROLLER_ID = 4;
  localparam int DATA_BITS = 35;
  localparam int CTRL_BITS = 119;
  localparam int PAYLOAD_BITS = 170;
  localparam int HOST_PACKET_BITS = 191;
  localparam int NOC_PACKET_BITS = 194;

  typedef struct packed {
    logic [31:0] payload;
    logic predicate;
    logic bypass;
    logic delay;
  } data_t;

  typedef struct packed {
    logic [6:0] operation;
    logic [3:0][2:0] fu_in;
    logic [7:0][3:0] routing_xbar_outport;
    logic [7:0][1:0] fu_xbar_outport;
    logic [2:0] vector_factor_power;
    logic is_last_ctrl;
    logic [3:0][1:0] write_reg_from;
    logic [3:0][3:0] write_reg_idx;
    logic [3:0][1:0] read_reg_towards;
    logic [3:0][3:0] read_reg_idx;
  } ctrl_t;

  typedef struct packed {
    logic [5:0] cmd;
    data_t data;
    logic [6:0] data_addr;
    ctrl_t ctrl;
    logic [2:0] ctrl_addr;
  } payload_t;

  typedef struct packed {
    logic [2:0] src;
    logic [2:0] dst;
    logic src_cgra_id;
    logic dst_cgra_id;
    logic src_cgra_x;
    logic src_cgra_y;
    logic dst_cgra_x;
    logic dst_cgra_y;
    logic [7:0] opaque;
    logic vc_id;
    payload_t payload;
  } host_packet_t;

  typedef struct packed {
    logic src;
    logic dst;
    logic src_x;
    logic src_y;
    logic dst_x;
    logic dst_y;
    logic [2:0] src_tile_id;
    logic [2:0] dst_tile_id;
    logic [1:0] remote_src_port;
    logic [7:0] opaque;
    logic [1:0] vc_id;
    payload_t payload;
  } noc_packet_t;

  // Baseline encodings; declaration does not imply every command is tested.
  localparam logic [5:0] CMD_LAUNCH = 0;
  localparam logic [5:0] CMD_PAUSE = 1;
  localparam logic [5:0] CMD_TERMINATE = 2;
  localparam logic [5:0] CMD_CONFIG = 3;
  localparam logic [5:0] CMD_CONFIG_PROLOGUE_FU = 4;
  localparam logic [5:0] CMD_CONFIG_PROLOGUE_FU_CROSSBAR = 5;
  localparam logic [5:0] CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR = 6;
  localparam logic [5:0] CMD_CONFIG_TOTAL_CTRL_COUNT = 7;
  localparam logic [5:0] CMD_CONFIG_COUNT_PER_ITER = 8;
  localparam logic [5:0] CMD_CONFIG_CTRL_LOWER_BOUND = 9;
  localparam logic [5:0] CMD_LOAD_REQUEST = 10;
  localparam logic [5:0] CMD_LOAD_RESPONSE = 11;
  localparam logic [5:0] CMD_STORE_REQUEST = 12;
  localparam logic [5:0] CMD_CONST = 13;
  localparam logic [5:0] CMD_COMPLETE = 14;
  localparam logic [5:0] CMD_RESUME = 15;

  // Operations implemented by the scalar Adder/Mul/Mem/Nah profile.
  localparam logic [6:0] OPT_NAH = `CGRA_OPT_NAH;
  localparam logic [6:0] OPT_ADD = `CGRA_OPT_ADD;
  localparam logic [6:0] OPT_INC = `CGRA_OPT_INC;
  localparam logic [6:0] OPT_SUB = `CGRA_OPT_SUB;
  localparam logic [6:0] OPT_MUL = `CGRA_OPT_MUL;
  localparam logic [6:0] OPT_LD = `CGRA_OPT_LD;
  localparam logic [6:0] OPT_STR = `CGRA_OPT_STR;
  localparam logic [6:0] OPT_ADD_CONST = `CGRA_OPT_ADD_CONST;
  localparam logic [6:0] OPT_LD_CONST = `CGRA_OPT_LD_CONST;
  localparam logic [6:0] OPT_MUL_CONST = `CGRA_OPT_MUL_CONST;
  localparam logic [6:0] OPT_PAS = `CGRA_OPT_PAS;
  // ac96 leaves constant-ready low for SUB_CONST; preserved, not repaired.
  localparam logic [6:0] OPT_SUB_CONST = `CGRA_OPT_SUB_CONST;
  localparam logic [6:0] OPT_STR_CONST = `CGRA_OPT_STR_CONST;
  localparam logic [6:0] OPT_ADD_CONST_LD = `CGRA_OPT_ADD_CONST_LD;

  localparam int NORTH = 0;
  localparam int SOUTH = 1;
  localparam int WEST = 2;
  localparam int EAST = 3;
endpackage
