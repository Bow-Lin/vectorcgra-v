// Deliberately no include guard: these types belong to the including module.
// Requires the parameters declared by CGRA_PROFILE_PARAMETERS.
typedef struct packed {
  logic [DATA_W-1:0] payload;
  logic predicate, bypass, delay;
} data_t;
typedef struct packed {
  logic [6:0] operation;
  logic [3:0][2:0] fu_in;
  logic [7:0][3:0] routing_xbar_outport;
  logic [7:0][1:0] fu_xbar_outport;
  logic [2:0] vector_factor_power;
  logic is_last_ctrl;
  logic [3:0][1:0] write_reg_from;
  logic [3:0][REG_ADDR_W-1:0] write_reg_idx;
  logic [3:0][1:0] read_reg_towards;
  logic [3:0][REG_ADDR_W-1:0] read_reg_idx;
} ctrl_t;
typedef struct packed {
  logic [5:0] cmd;
  data_t data;
  logic [GLOBAL_ADDR_W-1:0] data_addr;
  ctrl_t ctrl;
  logic [CTRL_ADDR_W-1:0] ctrl_addr;
} payload_t;
typedef struct packed {
  logic [TILE_ID_W-1:0] src, dst;
  logic src_cgra_id, dst_cgra_id, src_cgra_x, src_cgra_y, dst_cgra_x, dst_cgra_y;
  logic [7:0] opaque;
  logic vc_id;
  payload_t payload;
} host_packet_t;
typedef struct packed {
  logic src, dst, src_x, src_y, dst_x, dst_y;
  logic [TILE_ID_W-1:0] src_tile_id, dst_tile_id;
  logic [MEM_PORT_W-1:0] remote_src_port;
  logic [7:0] opaque;
  logic [1:0] vc_id;
  payload_t payload;
} noc_packet_t;
typedef struct packed {
  logic dst;
  noc_packet_t inter_cgra_pkt;
} controller_xbar_t;
typedef struct packed {
  logic [MEM_PORT_W-1:0] src;
  logic [BANK_PORT_W-1:0] dst;
  logic [GLOBAL_ADDR_W-1:0] addr;
  data_t data;
  logic src_cgra;
  logic [TILE_ID_W-1:0] src_tile;
  logic [MEM_PORT_W-1:0] remote_src_port;
} mem_request_t;
typedef struct packed {
  logic [BANK_PORT_W-1:0] src;
  logic [MEM_PORT_W-1:0] dst;
  logic [GLOBAL_ADDR_W-1:0] addr;
  data_t data;
  logic src_cgra;
  logic [TILE_ID_W-1:0] src_tile;
  logic [MEM_PORT_W-1:0] remote_src_port;
} mem_response_t;
// Disabled DMA ports remain declared to preserve the ac96 controller contract.
typedef struct packed {
  logic [2:0] opcode;
  logic [63:0] dram_addr;
  logic [31:0] spm_addr, nbytes;
  logic [7:0] dma_tag;
} dma_cmd_t;
typedef struct packed { logic [7:0] dma_tag; } dma_done_t;
typedef struct packed { logic [31:0] addr; } dma_read_req_t;
typedef struct packed { logic [31:0] addr, data; logic [3:0] mask; } dma_write_req_t;
typedef struct packed { logic [31:0] data; } dma_read_resp_t;
