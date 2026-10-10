`include "cgra_profile_defs.svh"
// Native parameterized cgra_data_memory; control flow derived from ac96 cgra_data_memory.
// Native writes pair address/data; explicit compatibility retains source handshakes.
module cgra_data_memory #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [GLOBAL_ADDR_W-1:0] address_lower ,
  input  logic [GLOBAL_ADDR_W-1:0] address_upper ,
  input  logic [CGRA_ID_W-1:0] cgra_id ,
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input logic [32-1:0] recv_from_controller_spm_rd_req__msg  ,
  output logic [0:0] recv_from_controller_spm_rd_req__rdy  ,
  input logic [0:0] recv_from_controller_spm_rd_req__val  ,
  input logic [68-1:0] recv_from_controller_spm_wr_req__msg  ,
  output logic [0:0] recv_from_controller_spm_wr_req__rdy  ,
  input logic [0:0] recv_from_controller_spm_wr_req__val  ,
  input logic [NOC_BITS-1:0] recv_from_noc_load_request__msg  ,
  output logic [0:0] recv_from_noc_load_request__rdy  ,
  input logic [0:0] recv_from_noc_load_request__val  ,
  input logic [NOC_BITS-1:0] recv_from_noc_load_response_pkt__msg  ,
  output logic [0:0] recv_from_noc_load_response_pkt__rdy  ,
  input logic [0:0] recv_from_noc_load_response_pkt__val  ,
  input logic [NOC_BITS-1:0] recv_from_noc_store_request__msg  ,
  output logic [0:0] recv_from_noc_store_request__rdy  ,
  input logic [0:0] recv_from_noc_store_request__val  ,
  input logic [GLOBAL_ADDR_W-1:0] recv_raddr__msg [0:MEM_PORTS-1] ,
  output logic [0:0] recv_raddr__rdy [0:MEM_PORTS-1] ,
  input logic [0:0] recv_raddr__val [0:MEM_PORTS-1] ,
  input logic [GLOBAL_ADDR_W-1:0] recv_waddr__msg [0:MEM_WRITE_PORTS-1] ,
  output logic [0:0] recv_waddr__rdy [0:MEM_WRITE_PORTS-1] ,
  input logic [0:0] recv_waddr__val [0:MEM_WRITE_PORTS-1] ,
  input logic [DATA_BITS-1:0] recv_wdata__msg [0:MEM_WRITE_PORTS-1] ,
  output logic [0:0] recv_wdata__rdy [0:MEM_WRITE_PORTS-1] ,
  input logic [0:0] recv_wdata__val [0:MEM_WRITE_PORTS-1] ,
  output logic [DATA_BITS-1:0] send_rdata__msg [0:MEM_PORTS-1] ,
  input logic [0:0] send_rdata__rdy [0:MEM_PORTS-1] ,
  output logic [0:0] send_rdata__val [0:MEM_PORTS-1] ,
  output logic [32-1:0] send_to_controller_spm_rd_resp__msg  ,
  input logic [0:0] send_to_controller_spm_rd_resp__rdy  ,
  output logic [0:0] send_to_controller_spm_rd_resp__val  ,
  output logic [NOC_BITS-1:0] send_to_noc_load_request_pkt__msg  ,
  input logic [0:0] send_to_noc_load_request_pkt__rdy  ,
  output logic [0:0] send_to_noc_load_request_pkt__val  ,
  output logic [NOC_BITS-1:0] send_to_noc_load_response_pkt__msg  ,
  input logic [0:0] send_to_noc_load_response_pkt__rdy  ,
  output logic [0:0] send_to_noc_load_response_pkt__val  ,
  output logic [NOC_BITS-1:0] send_to_noc_store_pkt__msg  ,
  input logic [0:0] send_to_noc_store_pkt__rdy  ,
  output logic [0:0] send_to_noc_store_pkt__val  
);
  `include "cgra_profile.svh"
  dma_read_req_t p_recv_from_controller_spm_rd_req__msg ;
  assign p_recv_from_controller_spm_rd_req__msg = recv_from_controller_spm_rd_req__msg;
  dma_write_req_t p_recv_from_controller_spm_wr_req__msg ;
  assign p_recv_from_controller_spm_wr_req__msg = recv_from_controller_spm_wr_req__msg;
  wire dma_write_legal = MEMORY_LEGACY_PYTHON || p_recv_from_controller_spm_wr_req__msg.mask==4'hf;
`ifndef SYNTHESIS
  always @(posedge clk) if(HAS_DMA && !reset && recv_from_controller_spm_wr_req__val && !dma_write_legal)
    $fatal(1,"MEM_DMA_MASK: the banked SPM interface accepts full 32-bit words");
`endif
  noc_packet_t p_recv_from_noc_load_request__msg ;
  assign p_recv_from_noc_load_request__msg = recv_from_noc_load_request__msg;
  noc_packet_t p_recv_from_noc_load_response_pkt__msg ;
  assign p_recv_from_noc_load_response_pkt__msg = recv_from_noc_load_response_pkt__msg;
  noc_packet_t p_recv_from_noc_store_request__msg ;
  assign p_recv_from_noc_store_request__msg = recv_from_noc_store_request__msg;
  data_t p_recv_wdata__msg [0:MEM_WRITE_PORTS-1];
  assign p_recv_wdata__msg = recv_wdata__msg;
  data_t p_send_rdata__msg [0:MEM_PORTS-1];
  assign send_rdata__msg = p_send_rdata__msg;
  dma_read_resp_t p_send_to_controller_spm_rd_resp__msg ;
  assign send_to_controller_spm_rd_resp__msg = p_send_to_controller_spm_rd_resp__msg;
  noc_packet_t p_send_to_noc_load_request_pkt__msg ;
  assign send_to_noc_load_request_pkt__msg = p_send_to_noc_load_request_pkt__msg;
  noc_packet_t p_send_to_noc_load_response_pkt__msg ;
  assign send_to_noc_load_response_pkt__msg = p_send_to_noc_load_response_pkt__msg;
  noc_packet_t p_send_to_noc_store_pkt__msg ;
  assign send_to_noc_store_pkt__msg = p_send_to_noc_store_pkt__msg;

  localparam int num_xbar_in_rd_ports_at_assemble_xbar_pkt = XBAR_MEM_PORTS;
  localparam int num_xbar_in_wr_ports_at_assemble_xbar_pkt = XBAR_WR_MEM_PORTS;
  localparam int num_rd_tiles_at_assemble_xbar_pkt = MEM_PORTS;
  localparam int per_bank_addr_nbits_at_assemble_xbar_pkt = BANK_ADDR_W;
  localparam int num_banks_per_cgra_at_assemble_xbar_pkt = NUM_BANKS;
  localparam int num_wr_tiles_at_assemble_xbar_pkt = MEM_WRITE_PORTS;
  localparam logic [0:0] has_dma_ports_at_assemble_xbar_pkt  = HAS_DMA;
  localparam int num_rd_tiles_at_update_all = MEM_PORTS;
  localparam int num_wr_tiles_at_update_all = MEM_WRITE_PORTS;
  localparam int num_xbar_in_rd_ports_at_update_all = XBAR_MEM_PORTS;
  localparam int num_xbar_in_wr_ports_at_update_all = XBAR_WR_MEM_PORTS;
  localparam logic [0:0] has_dma_ports_at_update_all  = HAS_DMA;
  localparam logic [3:0] CMD_LOAD_RESPONSE  = 4'd11;
  localparam int num_banks_per_cgra_at_update_all = NUM_BANKS;
  localparam logic [3:0] CMD_LOAD_REQUEST  = 4'd10;
  localparam logic [3:0] CMD_STORE_REQUEST  = 4'd12;
  logic [CGRA_X_W-1:0] idTo2d_x_lut [0:NUM_CGRAS-1];
  logic [CGRA_Y_W-1:0] idTo2d_y_lut [0:NUM_CGRAS-1];
  mem_request_t rd_pkt [0:XBAR_MEM_PORTS-1];
  mem_write_request_t wr_pkt [0:XBAR_WR_MEM_PORTS-1];

  logic [0:0] read_crossbar__clk;
  logic [0:0] read_crossbar__reset;
  mem_request_t read_crossbar__recv__msg [0:XBAR_MEM_PORTS-1];
  logic [0:0] read_crossbar__recv__rdy [0:XBAR_MEM_PORTS-1];
  logic [0:0] read_crossbar__recv__val [0:XBAR_MEM_PORTS-1];
  mem_request_t read_crossbar__send__msg [0:NUM_BANKS];
  logic [0:0] read_crossbar__send__rdy [0:NUM_BANKS];
  logic [0:0] read_crossbar__send__val [0:NUM_BANKS];

  cgra_xbar #(.WIDTH(MEM_BITS), .INPUTS(XBAR_MEM_PORTS), .OUTPUTS(NUM_BANKS+1), .DST_LSB(MEM_BITS-XBAR_MEM_PORT_W-BANK_PORT_W), .DST_WIDTH(BANK_PORT_W), .INPUT_BYPASS(1)) read_crossbar (
    .clk(read_crossbar__clk),
    .reset(read_crossbar__reset),
    .recv_msg(read_crossbar__recv__msg),
    .recv_rdy(read_crossbar__recv__rdy),
    .recv_val(read_crossbar__recv__val),
    .send_msg(read_crossbar__send__msg),
    .send_rdy(read_crossbar__send__rdy),
    .send_val(read_crossbar__send__val)
  );

  logic [0:0] response_crossbar__clk;
  logic [0:0] response_crossbar__reset;
  mem_response_t response_crossbar__recv__msg [0:NUM_BANKS];
  logic [0:0] response_crossbar__recv__rdy [0:NUM_BANKS];
  logic [0:0] response_crossbar__recv__val [0:NUM_BANKS];
  mem_response_t response_crossbar__send__msg [0:XBAR_MEM_PORTS-1];
  logic [0:0] response_crossbar__send__rdy [0:XBAR_MEM_PORTS-1];
  logic [0:0] response_crossbar__send__val [0:XBAR_MEM_PORTS-1];

  cgra_xbar #(.WIDTH(MEM_BITS), .INPUTS(NUM_BANKS+1), .OUTPUTS(XBAR_MEM_PORTS), .DST_LSB(MEM_BITS-BANK_PORT_W-XBAR_MEM_PORT_W), .DST_WIDTH(XBAR_MEM_PORT_W), .INPUT_BYPASS(1)) response_crossbar (
    .clk(response_crossbar__clk),
    .reset(response_crossbar__reset),
    .recv_msg(response_crossbar__recv__msg),
    .recv_rdy(response_crossbar__recv__rdy),
    .recv_val(response_crossbar__recv__val),
    .send_msg(response_crossbar__send__msg),
    .send_rdy(response_crossbar__send__rdy),
    .send_val(response_crossbar__send__val)
  );

  logic [0:0] write_crossbar__clk;
  logic [0:0] write_crossbar__reset;
  mem_write_request_t write_crossbar__recv__msg [0:XBAR_WR_MEM_PORTS-1];
  logic [0:0] write_crossbar__recv__rdy [0:XBAR_WR_MEM_PORTS-1];
  logic [0:0] write_crossbar__recv__val [0:XBAR_WR_MEM_PORTS-1];
  mem_write_request_t write_crossbar__send__msg [0:NUM_BANKS];
  logic [0:0] write_crossbar__send__rdy [0:NUM_BANKS];
  logic [0:0] write_crossbar__send__val [0:NUM_BANKS];

  cgra_xbar #(.WIDTH(WR_MEM_BITS), .INPUTS(XBAR_WR_MEM_PORTS), .OUTPUTS(NUM_BANKS+1), .DST_LSB(WR_MEM_BITS-XBAR_WR_MEM_PORT_W-BANK_PORT_W), .DST_WIDTH(BANK_PORT_W), .INPUT_BYPASS(1)) write_crossbar (
    .clk(write_crossbar__clk),
    .reset(write_crossbar__reset),
    .recv_msg(write_crossbar__recv__msg),
    .recv_rdy(write_crossbar__recv__rdy),
    .recv_val(write_crossbar__recv__val),
    .send_msg(write_crossbar__send__msg),
    .send_rdy(write_crossbar__send__rdy),
    .send_val(write_crossbar__send__val)
  );

  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_raddr;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_load_local;
  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_raddr_from_noc;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_load_from_noc;
  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_waddr;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_store_local;
  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_waddr_from_noc;
  data_t assemble_xbar_pkt_recv_wdata_from_noc;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_store_from_noc;
  logic [XBAR_MEM_PORT_W-1:0] assemble_xbar_pkt_dma_rd_idx;
  logic [XBAR_WR_MEM_PORT_W-1:0] assemble_xbar_pkt_dma_wr_idx;
  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_raddr_from_dma;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_load_from_dma;
  logic [GLOBAL_ADDR_W-1:0] assemble_xbar_pkt_recv_waddr_from_dma;
  logic [BANK_PORT_W-1:0] assemble_xbar_pkt_bank_index_store_from_dma;
  logic [XBAR_MEM_PORT_W-1:0] update_all_dma_rd_idx;
  logic [XBAR_WR_MEM_PORT_W-1:0] update_all_dma_wr_idx;
  logic [CGRA_ID_W-1:0] update_all_from_cgra_id;
  logic [TILE_ID_W-1:0] update_all_from_tile_id;

  always_comb begin : assemble_xbar_pkt
    for ( int unsigned i = 1'd0; i < num_xbar_in_rd_ports_at_assemble_xbar_pkt; i += 1'd1 )
      rd_pkt[i] = { XBAR_MEM_PORT_W'(i), BANK_PORT_W'(0), GLOBAL_ADDR_W'(0), { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, CGRA_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(0) };
    for ( int unsigned i = 1'd0; i < num_xbar_in_wr_ports_at_assemble_xbar_pkt; i += 1'd1 )
      wr_pkt[i] = { XBAR_WR_MEM_PORT_W'(i), BANK_PORT_W'(0), GLOBAL_ADDR_W'(0), { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, CGRA_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(0) };
    for ( int unsigned i = 1'd0; i < num_rd_tiles_at_assemble_xbar_pkt; i += 1'd1 ) begin
      assemble_xbar_pkt_recv_raddr = recv_raddr__msg[i];
      if ( ( assemble_xbar_pkt_recv_raddr >= address_lower ) & ( assemble_xbar_pkt_recv_raddr <= address_upper ) ) begin
        assemble_xbar_pkt_bank_index_load_local = BANK_PORT_W'(( assemble_xbar_pkt_recv_raddr - address_lower ) >> BANK_ADDR_W);
      end
      else
        assemble_xbar_pkt_bank_index_load_local = BANK_PORT_W'(NUM_BANKS);
      rd_pkt[i] = { XBAR_MEM_PORT_W'(i), assemble_xbar_pkt_bank_index_load_local, assemble_xbar_pkt_recv_raddr, { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, cgra_id, TILE_ID_W'(0), MEM_PORT_W'(i) };
    end
    assemble_xbar_pkt_recv_raddr_from_noc = p_recv_from_noc_load_request__msg.payload.data_addr;
    if ( ( assemble_xbar_pkt_recv_raddr_from_noc >= address_lower ) & ( assemble_xbar_pkt_recv_raddr_from_noc <= address_upper ) ) begin
      assemble_xbar_pkt_bank_index_load_from_noc = BANK_PORT_W'(( assemble_xbar_pkt_recv_raddr_from_noc - address_lower ) >> BANK_ADDR_W);
    end
    else
      assemble_xbar_pkt_bank_index_load_from_noc = BANK_PORT_W'(NUM_BANKS);
    rd_pkt[num_rd_tiles_at_assemble_xbar_pkt] = { XBAR_MEM_PORT_W'(num_rd_tiles_at_assemble_xbar_pkt), assemble_xbar_pkt_bank_index_load_from_noc, assemble_xbar_pkt_recv_raddr_from_noc, { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, p_recv_from_noc_load_request__msg.src, p_recv_from_noc_load_request__msg.src_tile_id, p_recv_from_noc_load_request__msg.remote_src_port };
    for ( int unsigned i = 1'd0; i < num_wr_tiles_at_assemble_xbar_pkt; i += 1'd1 ) begin
      assemble_xbar_pkt_recv_waddr = recv_waddr__msg[i];
      if ( ( assemble_xbar_pkt_recv_waddr >= address_lower ) & ( assemble_xbar_pkt_recv_waddr <= address_upper ) ) begin
        assemble_xbar_pkt_bank_index_store_local = BANK_PORT_W'(( assemble_xbar_pkt_recv_waddr - address_lower ) >> BANK_ADDR_W);
      end
      else
        assemble_xbar_pkt_bank_index_store_local = BANK_PORT_W'(NUM_BANKS);
      wr_pkt[i] = { XBAR_WR_MEM_PORT_W'(i), assemble_xbar_pkt_bank_index_store_local, assemble_xbar_pkt_recv_waddr, p_recv_wdata__msg[i], CGRA_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(i) };
    end
    assemble_xbar_pkt_recv_waddr_from_noc = p_recv_from_noc_store_request__msg.payload.data_addr;
    assemble_xbar_pkt_recv_wdata_from_noc = p_recv_from_noc_store_request__msg.payload.data;
    if ( ( assemble_xbar_pkt_recv_waddr_from_noc >= address_lower ) & ( assemble_xbar_pkt_recv_waddr_from_noc <= address_upper ) ) begin
      assemble_xbar_pkt_bank_index_store_from_noc = BANK_PORT_W'(( assemble_xbar_pkt_recv_waddr_from_noc - address_lower ) >> BANK_ADDR_W);
    end
    else
      assemble_xbar_pkt_bank_index_store_from_noc = BANK_PORT_W'(NUM_BANKS);
    wr_pkt[num_wr_tiles_at_assemble_xbar_pkt] = { XBAR_WR_MEM_PORT_W'(num_wr_tiles_at_assemble_xbar_pkt), assemble_xbar_pkt_bank_index_store_from_noc, assemble_xbar_pkt_recv_waddr_from_noc, assemble_xbar_pkt_recv_wdata_from_noc, CGRA_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(num_wr_tiles_at_assemble_xbar_pkt) };
    if ( 1'( has_dma_ports_at_assemble_xbar_pkt ) ) begin
      assemble_xbar_pkt_dma_rd_idx = XBAR_MEM_PORT_W'(XBAR_MEM_PORTS-1);
      assemble_xbar_pkt_dma_wr_idx = XBAR_WR_MEM_PORT_W'(XBAR_WR_MEM_PORTS-1);
      assemble_xbar_pkt_recv_raddr_from_dma = GLOBAL_ADDR_W'(p_recv_from_controller_spm_rd_req__msg.addr);
      if ( ( assemble_xbar_pkt_recv_raddr_from_dma >= address_lower ) & ( assemble_xbar_pkt_recv_raddr_from_dma <= address_upper ) ) begin
        assemble_xbar_pkt_bank_index_load_from_dma = BANK_PORT_W'(( assemble_xbar_pkt_recv_raddr_from_dma - address_lower ) >> BANK_ADDR_W);
      end
      else
        assemble_xbar_pkt_bank_index_load_from_dma = BANK_PORT_W'(NUM_BANKS);
      rd_pkt[assemble_xbar_pkt_dma_rd_idx] = { assemble_xbar_pkt_dma_rd_idx, assemble_xbar_pkt_bank_index_load_from_dma, assemble_xbar_pkt_recv_raddr_from_dma, { DATA_W'(0), 1'd0, 1'd0, 1'd0 }, cgra_id, TILE_ID_W'(0), MEM_PORT_W'(0) };
      assemble_xbar_pkt_recv_waddr_from_dma = GLOBAL_ADDR_W'(p_recv_from_controller_spm_wr_req__msg.addr);
      if ( ( assemble_xbar_pkt_recv_waddr_from_dma >= address_lower ) & ( assemble_xbar_pkt_recv_waddr_from_dma <= address_upper ) ) begin
        assemble_xbar_pkt_bank_index_store_from_dma = BANK_PORT_W'(( assemble_xbar_pkt_recv_waddr_from_dma - address_lower ) >> BANK_ADDR_W);
      end
      else
        assemble_xbar_pkt_bank_index_store_from_dma = BANK_PORT_W'(NUM_BANKS);
      wr_pkt[assemble_xbar_pkt_dma_wr_idx] = { assemble_xbar_pkt_dma_wr_idx, assemble_xbar_pkt_bank_index_store_from_dma, assemble_xbar_pkt_recv_waddr_from_dma, { DATA_W'(p_recv_from_controller_spm_wr_req__msg.data), 1'd1, 1'd0, 1'd0 }, CGRA_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(0) };
    end
  end

  always_comb begin : update_all
    for ( int unsigned i = 1'd0; i < num_rd_tiles_at_update_all; i += 1'd1 )
      recv_raddr__rdy[i] = 1'd0;
    recv_from_noc_load_request__rdy = 1'd0;
    for ( int unsigned i = 1'd0; i < num_wr_tiles_at_update_all; i += 1'd1 )
      recv_waddr__rdy[i] = 1'd0;
    recv_from_noc_store_request__rdy = 1'd0;
    for ( int unsigned i = 1'd0; i < num_rd_tiles_at_update_all; i += 1'd1 ) begin
      send_rdata__val[i] = 1'd0;
      p_send_rdata__msg[i] = '0;
    end
    send_to_noc_load_response_pkt__val = 1'd0;
    p_send_to_noc_load_response_pkt__msg = '0;
    for ( int unsigned i = 1'd0; i < num_wr_tiles_at_update_all; i += 1'd1 )
      recv_wdata__rdy[i] = 1'd0;
    p_send_to_noc_store_pkt__msg = '0;
    send_to_noc_store_pkt__val = 1'd0;
    for ( int unsigned i = 1'd0; i < num_xbar_in_rd_ports_at_update_all; i += 1'd1 ) begin
      read_crossbar__recv__val[i] = 1'd0;
      read_crossbar__recv__msg[i] = '0;
    end
    recv_from_noc_load_response_pkt__rdy = 1'd0;
    for ( int unsigned i = 1'd0; i < num_xbar_in_wr_ports_at_update_all; i += 1'd1 ) begin
      write_crossbar__recv__val[i] = 1'd0;
      write_crossbar__recv__msg[i] = '0;
    end
    recv_from_controller_spm_wr_req__rdy = 1'd0;
    recv_from_controller_spm_rd_req__rdy = 1'd0;
    send_to_controller_spm_rd_resp__val = 1'd0;
    p_send_to_controller_spm_rd_resp__msg = DATA_W'(0);
    p_send_to_noc_load_request_pkt__msg = '0;
    send_to_noc_load_request_pkt__val = 1'd0;
    for ( int unsigned i = 1'd0; i < num_rd_tiles_at_update_all; i += 1'd1 ) begin
      read_crossbar__recv__val[i] = recv_raddr__val[i];
      read_crossbar__recv__msg[i] = rd_pkt[i];
      recv_raddr__rdy[i] = read_crossbar__recv__rdy[i];
    end
    read_crossbar__recv__val[num_rd_tiles_at_update_all] = recv_from_noc_load_request__val;
    read_crossbar__recv__msg[num_rd_tiles_at_update_all] = rd_pkt[num_rd_tiles_at_update_all];
    recv_from_noc_load_request__rdy = read_crossbar__recv__rdy[num_rd_tiles_at_update_all];
    if ( 1'( has_dma_ports_at_update_all ) ) begin
      update_all_dma_rd_idx = XBAR_MEM_PORT_W'(XBAR_MEM_PORTS-1);
      read_crossbar__recv__val[update_all_dma_rd_idx] = recv_from_controller_spm_rd_req__val;
      read_crossbar__recv__msg[update_all_dma_rd_idx] = rd_pkt[update_all_dma_rd_idx];
      recv_from_controller_spm_rd_req__rdy = read_crossbar__recv__rdy[update_all_dma_rd_idx];
    end
    for ( int unsigned i = 1'd0; i < num_wr_tiles_at_update_all; i += 1'd1 ) begin
      write_crossbar__recv__val[i] = recv_waddr__val[i] && (MEMORY_LEGACY_PYTHON || recv_wdata__val[i]);
      write_crossbar__recv__msg[i] = wr_pkt[i];
      recv_waddr__rdy[i] = write_crossbar__recv__rdy[i] && (MEMORY_LEGACY_PYTHON || recv_wdata__val[i]);
      recv_wdata__rdy[i] = write_crossbar__recv__rdy[i] && (MEMORY_LEGACY_PYTHON || recv_waddr__val[i]);
    end
    write_crossbar__recv__val[num_wr_tiles_at_update_all] = recv_from_noc_store_request__val;
    write_crossbar__recv__msg[num_wr_tiles_at_update_all] = wr_pkt[num_wr_tiles_at_update_all];
    recv_from_noc_store_request__rdy = write_crossbar__recv__rdy[num_wr_tiles_at_update_all];
    if ( 1'( has_dma_ports_at_update_all ) ) begin
      update_all_dma_wr_idx = XBAR_WR_MEM_PORT_W'(XBAR_WR_MEM_PORTS-1);
      write_crossbar__recv__val[update_all_dma_wr_idx] = recv_from_controller_spm_wr_req__val && dma_write_legal;
      write_crossbar__recv__msg[update_all_dma_wr_idx] = wr_pkt[update_all_dma_wr_idx];
      recv_from_controller_spm_wr_req__rdy = write_crossbar__recv__rdy[update_all_dma_wr_idx] && dma_write_legal;
    end
    for ( int unsigned i = 1'd0; i < num_xbar_in_rd_ports_at_update_all; i += 1'd1 )
      if ( XBAR_MEM_PORT_W'(i) < XBAR_MEM_PORT_W'(num_rd_tiles_at_update_all) ) begin
        p_send_rdata__msg[i] = response_crossbar__send__msg[i].data;
        send_rdata__val[i] = response_crossbar__send__val[i];
        response_crossbar__send__rdy[i] = send_rdata__rdy[i];
      end
      else if ( XBAR_MEM_PORT_W'(i) == XBAR_MEM_PORT_W'(num_rd_tiles_at_update_all) ) begin
        update_all_from_cgra_id = response_crossbar__send__msg[i].src_cgra;
        update_all_from_tile_id = response_crossbar__send__msg[i].src_tile;
        p_send_to_noc_load_response_pkt__msg = { cgra_id, update_all_from_cgra_id, idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], idTo2d_x_lut[update_all_from_cgra_id], idTo2d_y_lut[update_all_from_cgra_id], TILE_ID_W'(0), update_all_from_tile_id, response_crossbar__send__msg[i].remote_src_port, 8'd0, 2'd0, { 6'( CMD_LOAD_RESPONSE ), response_crossbar__send__msg[i].data, response_crossbar__send__msg[i].addr, CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
        send_to_noc_load_response_pkt__val = response_crossbar__send__val[i];
        response_crossbar__send__rdy[i] = send_to_noc_load_response_pkt__rdy;
      end
      else if ( 1'( has_dma_ports_at_update_all ) ) begin
        p_send_to_controller_spm_rd_resp__msg = response_crossbar__send__msg[i].data.payload;
        send_to_controller_spm_rd_resp__val = response_crossbar__send__val[i];
        response_crossbar__send__rdy[i] = send_to_controller_spm_rd_resp__rdy;
      end
    p_send_to_noc_load_request_pkt__msg = { cgra_id, CGRA_ID_W'(0), idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], CGRA_X_W'(0), CGRA_Y_W'(0), TILE_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(read_crossbar__send__msg[num_banks_per_cgra_at_update_all].src), 8'd0, 2'd0, { 6'( CMD_LOAD_REQUEST ), DATA_BITS'(0), read_crossbar__send__msg[num_banks_per_cgra_at_update_all].addr, CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
    send_to_noc_load_request_pkt__val = read_crossbar__send__val[num_banks_per_cgra_at_update_all];
    recv_from_noc_load_response_pkt__rdy = response_crossbar__recv__rdy[num_banks_per_cgra_at_update_all];
    response_crossbar__recv__val[num_banks_per_cgra_at_update_all] = recv_from_noc_load_response_pkt__val;
    response_crossbar__recv__msg[num_banks_per_cgra_at_update_all] = { BANK_PORT_W'(num_banks_per_cgra_at_update_all), XBAR_MEM_PORT_W'(p_recv_from_noc_load_response_pkt__msg.remote_src_port), p_recv_from_noc_load_response_pkt__msg.payload.data_addr, p_recv_from_noc_load_response_pkt__msg.payload.data, p_recv_from_noc_load_response_pkt__msg.src, p_recv_from_noc_load_response_pkt__msg.src_tile_id, MEM_PORT_W'(0) };
    read_crossbar__send__rdy[num_banks_per_cgra_at_update_all] = send_to_noc_load_request_pkt__rdy;
    p_send_to_noc_store_pkt__msg = { cgra_id, CGRA_ID_W'(0), idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], CGRA_X_W'(0), CGRA_Y_W'(0), TILE_ID_W'(0), TILE_ID_W'(0), MEM_PORT_W'(write_crossbar__send__msg[num_banks_per_cgra_at_update_all].src), 8'd0, 2'd0, { 6'( CMD_STORE_REQUEST ), write_crossbar__send__msg[num_banks_per_cgra_at_update_all].data, write_crossbar__send__msg[num_banks_per_cgra_at_update_all].addr, CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
    send_to_noc_store_pkt__val = write_crossbar__send__val[num_banks_per_cgra_at_update_all];
    write_crossbar__send__rdy[num_banks_per_cgra_at_update_all] = send_to_noc_store_pkt__rdy;
    if (!MEMORY_LEGACY_PYTHON && reset) begin
      for(integer i=0;i<MEM_PORTS;i++) begin
        recv_raddr__rdy[i]=0;send_rdata__val[i]=0;p_send_rdata__msg[i]='0;
      end
      for(integer i=0;i<MEM_WRITE_PORTS;i++) begin recv_waddr__rdy[i]=0;recv_wdata__rdy[i]=0;end
      for(integer i=0;i<XBAR_MEM_PORTS;i++) begin read_crossbar__recv__val[i]=0;response_crossbar__send__rdy[i]=0;end
      for(integer i=0;i<XBAR_WR_MEM_PORTS;i++) write_crossbar__recv__val[i]=0;
      response_crossbar__recv__val[NUM_BANKS]=0;
      read_crossbar__send__rdy[NUM_BANKS]=0;write_crossbar__send__rdy[NUM_BANKS]=0;
      recv_from_noc_load_request__rdy=0;recv_from_noc_load_response_pkt__rdy=0;recv_from_noc_store_request__rdy=0;
      send_to_noc_load_request_pkt__val=0;p_send_to_noc_load_request_pkt__msg='0;
      send_to_noc_load_response_pkt__val=0;p_send_to_noc_load_response_pkt__msg='0;
      send_to_noc_store_pkt__val=0;p_send_to_noc_store_pkt__msg='0;
      recv_from_controller_spm_rd_req__rdy=0;recv_from_controller_spm_wr_req__rdy=0;
      send_to_controller_spm_rd_resp__val=0;p_send_to_controller_spm_rd_resp__msg='0;
    end
  end

  assign read_crossbar__clk = clk;
  assign read_crossbar__reset = reset;
  assign write_crossbar__clk = clk;
  assign write_crossbar__reset = reset;
  assign response_crossbar__clk = clk;
  assign response_crossbar__reset = reset;
  for (genvar id=0; id<NUM_CGRAS; id++) begin : coordinates
    assign idTo2d_x_lut[id] = CUSTOM_COORD_MAP ? COORD_X_MAP[id*CGRA_X_W+:CGRA_X_W] : CGRA_X_W'(id%MULTI_COLS);
    assign idTo2d_y_lut[id] = CUSTOM_COORD_MAP ? COORD_Y_MAP[id*CGRA_Y_W+:CGRA_Y_W] : CGRA_Y_W'(id/MULTI_COLS);
  end


  for (genvar bank = 0; bank < NUM_BANKS; bank++) begin : banks
    cgra_data_bank #(`CGRA_PROFILE_BIND) memory (
      .clk(clk), .reset(reset),
      .recv_rd__msg(read_crossbar__send__msg[bank]),
      .recv_rd__val(read_crossbar__send__val[bank]),
      .recv_rd__rdy(read_crossbar__send__rdy[bank]),
      .recv_wr__msg(write_crossbar__send__msg[bank]),
      .recv_wr__val(write_crossbar__send__val[bank]),
      .recv_wr__rdy(write_crossbar__send__rdy[bank]),
      .send__msg(response_crossbar__recv__msg[bank]),
      .send__val(response_crossbar__recv__val[bank]),
      .send__rdy(response_crossbar__recv__rdy[bank])
    );
  end
endmodule
