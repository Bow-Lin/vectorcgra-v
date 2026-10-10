// No include guard: module-local packed types match lib/messages.py.
typedef struct packed {
  logic [DATA_W-1:0] payload;
  logic predicate,bypass,delay;
} ring_data_t;
typedef struct packed {
  logic [6:0] operation;
  logic [FU_INPUTS-1:0][FU_SEL_W-1:0] fu_in;
  logic [ROUTES-1:0][ROUTE_W-1:0] routing_xbar_outport;
  logic [ROUTES-1:0][FU_OUT_W-1:0] fu_xbar_outport;
  logic [2:0] vector_factor_power;
  logic is_last_ctrl;
  logic [FU_INPUTS-1:0][1:0] write_reg_from;
  logic [FU_INPUTS-1:0][REG_W-1:0] write_reg_idx;
  logic [FU_INPUTS-1:0][1:0] read_reg_towards;
  logic [FU_INPUTS-1:0][REG_W-1:0] read_reg_idx;
} ring_ctrl_t;
typedef struct packed {
  logic [5:0] cmd;
  ring_data_t data;
  logic [DATA_ADDR_W-1:0] data_addr;
  ring_ctrl_t ctrl;
  logic [ADDR_W-1:0] ctrl_addr;
} ring_payload_t;
typedef struct packed {
  logic [ID_W-1:0] src,dst;
  logic src_cgra_id,dst_cgra_id,src_cgra_x,src_cgra_y,dst_cgra_x,dst_cgra_y;
  logic [7:0] opaque;
  logic vc_id;
  ring_payload_t payload;
} ring_packet_t;
