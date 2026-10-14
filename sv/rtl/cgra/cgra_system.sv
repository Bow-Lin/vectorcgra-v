`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
// Native CGRA system: external NoC or baseline local bypass, optional DMA/im2col.
// All Tile, bank and control-ring instances are
// elaborated by SystemVerilog; no generated fixed fabric is instantiated.
module cgra_system #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS,
  parameter int TILE_VARIANT=0,
  parameter bit IS_MULTI = NUM_CGRAS > 1,
  parameter logic [NUM_TILES-1:0][31:0] TILE_FU_COUNTS = {NUM_TILES{32'(FU_COUNT)}},
  parameter logic [NUM_TILES-1:0][FU_COUNT*8-1:0] TILE_FU_KINDS = {NUM_TILES{FU_KINDS}},
  // Static architecture tables replace Python TileList/LinkList construction.
  // A disabled or missing internal directed link is grounded. One source and
  // one destination per physical port matches the original point-to-point graph.
  parameter bit CUSTOM_TOPOLOGY=0,
  parameter int LINK_COUNT=1,
  parameter logic [LINK_COUNT-1:0] LINK_ENABLED='0,
  parameter logic [LINK_COUNT-1:0][31:0] LINK_SRC_TILE='0, LINK_SRC_PORT='0,
  parameter logic [LINK_COUNT-1:0][31:0] LINK_DST_TILE='0, LINK_DST_PORT='0,
  parameter logic [MEM_PORTS-1:0][31:0] READ_PORT_TILE='1,
  parameter logic [MEM_WRITE_PORTS-1:0][31:0] WRITE_PORT_TILE='1,
  parameter logic [NUM_TILES-1:0][TILE_PORTS-1:0] BOUNDARY_IN_ENABLE='0, BOUNDARY_OUT_ENABLE='0,
  // Match CgraRTL(has_ctrl_ring=False): disconnected tile control ports.
  // This construction mode has no alternate configuration/launch transport.
  parameter bit HAS_CTRL_RING=1
) (
  input logic [GLOBAL_ADDR_W-1:0] address_lower, address_upper,
  input logic [CGRA_ID_W-1:0] cgra_id,
  input logic clk, reset,
  input logic [DATA_BITS-1:0] recv_data_on_boundary_east__msg [0:ROWS-1],
  output logic recv_data_on_boundary_east__rdy [0:ROWS-1],
  input logic recv_data_on_boundary_east__val [0:ROWS-1],
  input logic [DATA_BITS-1:0] recv_data_on_boundary_north__msg [0:COLS-1],
  output logic recv_data_on_boundary_north__rdy [0:COLS-1],
  input logic recv_data_on_boundary_north__val [0:COLS-1],
  input logic [DATA_BITS-1:0] recv_data_on_boundary_south__msg [0:COLS-1],
  output logic recv_data_on_boundary_south__rdy [0:COLS-1],
  input logic recv_data_on_boundary_south__val [0:COLS-1],
  input logic [DATA_BITS-1:0] recv_data_on_boundary_west__msg [0:ROWS-1],
  output logic recv_data_on_boundary_west__rdy [0:ROWS-1],
  input logic recv_data_on_boundary_west__val [0:ROWS-1],
  input logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg,
  output logic recv_from_cpu_pkt__rdy,
  input logic recv_from_cpu_pkt__val,
  input logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg,
  output logic recv_from_inter_cgra_noc__rdy,
  input logic recv_from_inter_cgra_noc__val,
  output logic [DATA_BITS-1:0] send_data_on_boundary_east__msg [0:ROWS-1],
  input logic send_data_on_boundary_east__rdy [0:ROWS-1],
  output logic send_data_on_boundary_east__val [0:ROWS-1],
  output logic [DATA_BITS-1:0] send_data_on_boundary_north__msg [0:COLS-1],
  input logic send_data_on_boundary_north__rdy [0:COLS-1],
  output logic send_data_on_boundary_north__val [0:COLS-1],
  output logic [DATA_BITS-1:0] send_data_on_boundary_south__msg [0:COLS-1],
  input logic send_data_on_boundary_south__rdy [0:COLS-1],
  output logic send_data_on_boundary_south__val [0:COLS-1],
  output logic [DATA_BITS-1:0] send_data_on_boundary_west__msg [0:ROWS-1],
  input logic send_data_on_boundary_west__rdy [0:ROWS-1],
  output logic send_data_on_boundary_west__val [0:ROWS-1],
  output logic [HOST_BITS-1:0] send_to_cpu_pkt__msg,
  input logic send_to_cpu_pkt__rdy,
  output logic send_to_cpu_pkt__val,
  output logic [NOC_BITS-1:0] send_to_inter_cgra_noc__msg,
  input logic send_to_inter_cgra_noc__rdy,
  output logic send_to_inter_cgra_noc__val,
  output logic [138:0] dma_cmd__msg,
  output logic dma_cmd__val,
  input logic dma_cmd__rdy,
  input logic [7:0] dma_done__msg,
  input logic dma_done__val,
  output logic dma_done__rdy,
  input logic [31:0] recv_from_dma_spm_rd_req__msg,
  input logic recv_from_dma_spm_rd_req__val,
  output logic recv_from_dma_spm_rd_req__rdy,
  input logic [67:0] recv_from_dma_spm_wr_req__msg,
  input logic recv_from_dma_spm_wr_req__val,
  output logic recv_from_dma_spm_wr_req__rdy,
  output logic [31:0] send_to_dma_spm_rd_resp__msg,
  output logic send_to_dma_spm_rd_resp__val,
  input logic send_to_dma_spm_rd_resp__rdy,
  input logic [HOST_BITS-1:0] recv_from_im2col_pkt__msg,
  input logic recv_from_im2col_pkt__val,
  output logic recv_from_im2col_pkt__rdy,
  output logic [HOST_BITS-1:0] send_to_im2col_engine_pkt__msg,
  output logic send_to_im2col_engine_pkt__val,
  input logic send_to_im2col_engine_pkt__rdy
);
  `include "cgra_profile.svh"
  localparam int NORTH=0, SOUTH=1, WEST=2, EAST=3;
  logic [DATA_BITS-1:0] tile_recv_msg [0:NUM_TILES-1][0:TILE_PORTS-1];
  logic tile_recv_val [0:NUM_TILES-1][0:TILE_PORTS-1], tile_recv_rdy [0:NUM_TILES-1][0:TILE_PORTS-1];
  logic [DATA_BITS-1:0] tile_send_msg [0:NUM_TILES-1][0:TILE_PORTS-1];
  logic tile_send_val [0:NUM_TILES-1][0:TILE_PORTS-1], tile_send_rdy [0:NUM_TILES-1][0:TILE_PORTS-1];
  logic [HOST_BITS-1:0] ring_recv_msg [0:MAX_TILES], ring_send_msg [0:MAX_TILES];
  logic ring_recv_val [0:MAX_TILES], ring_recv_rdy [0:MAX_TILES];
  logic ring_send_val [0:MAX_TILES], ring_send_rdy [0:MAX_TILES];
  logic [GLOBAL_ADDR_W-1:0] mem_raddr_msg [0:MEM_PORTS-1], mem_waddr_msg [0:MEM_WRITE_PORTS-1];
  logic mem_raddr_val [0:MEM_PORTS-1], mem_raddr_rdy [0:MEM_PORTS-1];
  logic mem_waddr_val [0:MEM_WRITE_PORTS-1], mem_waddr_rdy [0:MEM_WRITE_PORTS-1];
  logic [DATA_BITS-1:0] mem_wdata_msg [0:MEM_WRITE_PORTS-1], mem_rdata_msg [0:MEM_PORTS-1];
  logic mem_wdata_val [0:MEM_WRITE_PORTS-1], mem_wdata_rdy [0:MEM_WRITE_PORTS-1];
  logic mem_rdata_val [0:MEM_PORTS-1], mem_rdata_rdy [0:MEM_PORTS-1];
  logic [NOC_BITS-1:0] loop_in_msg, loop_out_msg;
  logic loop_in_val, loop_in_rdy, loop_out_val, loop_out_rdy;
  logic [NOC_BITS-1:0] noc_load_req_msg, noc_store_req_msg, noc_load_resp_msg;
  logic noc_load_req_val, noc_load_req_rdy, noc_store_req_val, noc_store_req_rdy;
  logic noc_load_resp_val, noc_load_resp_rdy;
  logic [NOC_BITS-1:0] tile_load_req_msg, tile_load_resp_msg, tile_store_msg;
  logic tile_load_req_val, tile_load_req_rdy, tile_load_resp_val, tile_load_resp_rdy;
  logic tile_store_val, tile_store_rdy;
  logic sram_resp_val, sram_resp_rdy;
  logic [31:0] sram_resp_msg;
  logic mem_dma_rd_val, mem_dma_wr_val, mem_dma_rd_rdy, mem_dma_wr_rdy;
  logic [31:0] mem_dma_rd_msg;
  logic [67:0] mem_dma_wr_msg;

  initial begin
    if(MAX_COLS<COLS || MAX_ROWS<ROWS || MAX_MEM_PORTS<MEM_PORTS || MEM_PORTS<1 || MEM_WRITE_PORTS<1)
      $fatal(1,"Shared packet geometry must contain the local CGRA");
    if(!CUSTOM_TOPOLOGY && (MEM_PORTS!=COLS+ROWS-1 || MEM_WRITE_PORTS!=COLS+ROWS-1))
      $fatal(1,"Nonstandard memory wiring requires CUSTOM_TOPOLOGY tables");
    if(HAS_DMA && DATA_W!=32) $fatal(1,"The integrated ac96 DMA profile requires 32-bit CGRA words");
    if(TILE_VARIANT<0 || TILE_VARIANT>2) $fatal(1,"Unknown Tile variant");
    if((TILE_VARIANT==2 && TILE_PORTS!=8) || (TILE_VARIANT!=2 && TILE_PORTS!=4 && TILE_PORTS!=8))
      $fatal(1,"Supported profiles: base/context four ports; original streaming KingMesh eight ports");
    if (!(COLS >= 2 && ROWS >= 2)) $fatal(1, "scalar mesh requires COLS,ROWS >= 2");
    if (!(DATA_W >= 11 && DATA_W >= GLOBAL_ADDR_W && GLOBAL_ADDR_W >= 1 && GLOBAL_ADDR_W <= 32))
      $fatal(1, "unsupported scalar payload/address width");
    if (!(CTRL_DEPTH >= 2 && NUM_CTRL >= 1 && NUM_CTRL <= CTRL_DEPTH))
      $fatal(1, "control storage must contain NUM_CTRL and at least two entries");
    if (!(REG_DEPTH >= 2)) $fatal(1, "register depth must contain at least two entries");
    if (!(TOTAL_STEPS >= 0 && TOTAL_STEPS <= 2047))
      $fatal(1, "TOTAL_STEPS exceeds the ac96 eleven-bit counter");
    if (!(BANK_DEPTH >= 2 && (BANK_DEPTH & (BANK_DEPTH-1)) == 0 && NUM_BANKS >= 1 &&
            (NUM_BANKS & (NUM_BANKS-1)) == 0 &&
            64'(NUM_BANKS)*64'(BANK_DEPTH) <= (64'd1 << GLOBAL_ADDR_W)))
      $fatal(1, "invalid local/global memory capacity");
  end

  if(IS_MULTI) begin : external_noc
    assign loop_out_msg=recv_from_inter_cgra_noc__msg;
    assign loop_out_val=recv_from_inter_cgra_noc__val;
    assign recv_from_inter_cgra_noc__rdy=loop_out_rdy;
    assign send_to_inter_cgra_noc__msg=loop_in_msg;
    assign send_to_inter_cgra_noc__val=loop_in_val;
    assign loop_in_rdy=send_to_inter_cgra_noc__rdy;
  end else begin : local_noc
    // Single-CGRA traffic uses the local loopback. The unused public NoC port
    // must still have defined outputs when this hierarchy is synthesized.
    assign recv_from_inter_cgra_noc__rdy=1'b0;
    assign send_to_inter_cgra_noc__msg='0;
    assign send_to_inter_cgra_noc__val=1'b0;
    cgra_queue #(.WIDTH(NOC_BITS), .DEPTH(1), .BYPASS(1)) loopback (
      .clk, .reset, .clear(1'b0), .recv_msg(loop_in_msg), .recv_val(loop_in_val), .recv_rdy(loop_in_rdy),
      .send_msg(loop_out_msg), .send_val(loop_out_val), .send_rdy(loop_out_rdy), .count()
    );
  end
  if (HAS_CTRL_RING) begin : enabled_ctrl_ring
    cgra_credit_ring #(.LEGACY_PYTHON(NOC_LEGACY_PYTHON),.WIDTH(HOST_BITS), .NODES(MAX_TILES+1), .DST_LSB(HOST_DST_LSB),
                     .DST_WIDTH(TILE_ID_W), .VC_LSB(PAYLOAD_BITS)) ctrl_ring (
    .clk, .reset, .recv_msg(ring_recv_msg), .recv_val(ring_recv_val), .recv_rdy(ring_recv_rdy),
    .send_msg(ring_send_msg), .send_val(ring_send_val), .send_rdy(ring_send_rdy)
    );
  end else begin : disabled_ctrl_ring
    for (genvar node=0;node<=MAX_TILES;node++) begin : disconnected
      assign ring_recv_rdy[node]=1'b0;
      assign ring_send_msg[node]='0;
      assign ring_send_val[node]=1'b0;
    end
  end
  cgra_controller #(`CGRA_PROFILE_BIND,.REDUCE_LEGACY_PYTHON(REDUCE_LEGACY_PYTHON)) controller (
    .clk, .reset, .cgra_id,
    .recv_from_cpu_pkt__msg, .recv_from_cpu_pkt__val, .recv_from_cpu_pkt__rdy,
    .send_to_cpu_pkt__msg, .send_to_cpu_pkt__val, .send_to_cpu_pkt__rdy,
    .recv_from_inter_cgra_noc__msg(loop_out_msg), .recv_from_inter_cgra_noc__val(loop_out_val), .recv_from_inter_cgra_noc__rdy(loop_out_rdy),
    .send_to_inter_cgra_noc__msg(loop_in_msg), .send_to_inter_cgra_noc__val(loop_in_val), .send_to_inter_cgra_noc__rdy(loop_in_rdy),
    .recv_from_ctrl_ring_pkt__msg(ring_send_msg[NUM_TILES]), .recv_from_ctrl_ring_pkt__val(ring_send_val[NUM_TILES]), .recv_from_ctrl_ring_pkt__rdy(ring_send_rdy[NUM_TILES]),
    .send_to_ctrl_ring_pkt__msg(ring_recv_msg[NUM_TILES]), .send_to_ctrl_ring_pkt__val(ring_recv_val[NUM_TILES]), .send_to_ctrl_ring_pkt__rdy(ring_recv_rdy[NUM_TILES]),
    .recv_from_tile_load_request_pkt__msg(tile_load_req_msg), .recv_from_tile_load_request_pkt__val(tile_load_req_val), .recv_from_tile_load_request_pkt__rdy(tile_load_req_rdy),
    .recv_from_tile_load_response_pkt__msg(tile_load_resp_msg), .recv_from_tile_load_response_pkt__val(tile_load_resp_val), .recv_from_tile_load_response_pkt__rdy(tile_load_resp_rdy),
    .recv_from_tile_store_request_pkt__msg(tile_store_msg), .recv_from_tile_store_request_pkt__val(tile_store_val), .recv_from_tile_store_request_pkt__rdy(tile_store_rdy),
    .send_to_sram_load_request_from_noc__msg(noc_load_req_msg), .send_to_sram_load_request_from_noc__val(noc_load_req_val), .send_to_sram_load_request_from_noc__rdy(noc_load_req_rdy),
    .send_to_sram_store_request_from_noc__msg(noc_store_req_msg), .send_to_sram_store_request_from_noc__val(noc_store_req_val), .send_to_sram_store_request_from_noc__rdy(noc_store_req_rdy),
    .send_to_tile_load_response__msg(noc_load_resp_msg), .send_to_tile_load_response__val(noc_load_resp_val), .send_to_tile_load_response__rdy(noc_load_resp_rdy),
    .recv_from_im2col_pkt__msg, .recv_from_im2col_pkt__val, .recv_from_im2col_pkt__rdy,
    .send_to_im2col_engine_pkt__msg, .send_to_im2col_engine_pkt__val, .send_to_im2col_engine_pkt__rdy,
    .dma_cmd__msg, .dma_cmd__val, .dma_cmd__rdy,
    .dma_done__msg, .dma_done__val, .dma_done__rdy,
    .recv_from_dma_spm_rd_req__msg, .recv_from_dma_spm_rd_req__val, .recv_from_dma_spm_rd_req__rdy,
    .recv_from_dma_spm_wr_req__msg, .recv_from_dma_spm_wr_req__val, .recv_from_dma_spm_wr_req__rdy,
    .recv_from_sram_load_response__msg(sram_resp_msg), .recv_from_sram_load_response__val(sram_resp_val), .recv_from_sram_load_response__rdy(sram_resp_rdy),
    .send_to_dma_spm_rd_resp__msg, .send_to_dma_spm_rd_resp__val, .send_to_dma_spm_rd_resp__rdy,
    .send_to_sram_load_request_from_dma__msg(mem_dma_rd_msg), .send_to_sram_load_request_from_dma__val(mem_dma_rd_val), .send_to_sram_load_request_from_dma__rdy(mem_dma_rd_rdy),
    .send_to_sram_store_request_from_dma__msg(mem_dma_wr_msg), .send_to_sram_store_request_from_dma__val(mem_dma_wr_val), .send_to_sram_store_request_from_dma__rdy(mem_dma_wr_rdy)
  );
  cgra_data_memory #(`CGRA_PROFILE_BIND) data_mem (
    .clk, .reset, .cgra_id, .address_lower, .address_upper,
    .recv_raddr__msg(mem_raddr_msg), .recv_raddr__val(mem_raddr_val), .recv_raddr__rdy(mem_raddr_rdy),
    .recv_waddr__msg(mem_waddr_msg), .recv_waddr__val(mem_waddr_val), .recv_waddr__rdy(mem_waddr_rdy),
    .recv_wdata__msg(mem_wdata_msg), .recv_wdata__val(mem_wdata_val), .recv_wdata__rdy(mem_wdata_rdy),
    .send_rdata__msg(mem_rdata_msg), .send_rdata__val(mem_rdata_val), .send_rdata__rdy(mem_rdata_rdy),
    .recv_from_noc_load_request__msg(noc_load_req_msg), .recv_from_noc_load_request__val(noc_load_req_val), .recv_from_noc_load_request__rdy(noc_load_req_rdy),
    .recv_from_noc_store_request__msg(noc_store_req_msg), .recv_from_noc_store_request__val(noc_store_req_val), .recv_from_noc_store_request__rdy(noc_store_req_rdy),
    .recv_from_noc_load_response_pkt__msg(noc_load_resp_msg), .recv_from_noc_load_response_pkt__val(noc_load_resp_val), .recv_from_noc_load_response_pkt__rdy(noc_load_resp_rdy),
    .send_to_noc_load_request_pkt__msg(tile_load_req_msg), .send_to_noc_load_request_pkt__val(tile_load_req_val), .send_to_noc_load_request_pkt__rdy(tile_load_req_rdy),
    .send_to_noc_load_response_pkt__msg(tile_load_resp_msg), .send_to_noc_load_response_pkt__val(tile_load_resp_val), .send_to_noc_load_response_pkt__rdy(tile_load_resp_rdy),
    .send_to_noc_store_pkt__msg(tile_store_msg), .send_to_noc_store_pkt__val(tile_store_val), .send_to_noc_store_pkt__rdy(tile_store_rdy),
    .recv_from_controller_spm_rd_req__msg(mem_dma_rd_msg), .recv_from_controller_spm_rd_req__val(mem_dma_rd_val), .recv_from_controller_spm_rd_req__rdy(mem_dma_rd_rdy),
    .recv_from_controller_spm_wr_req__msg(mem_dma_wr_msg), .recv_from_controller_spm_wr_req__val(mem_dma_wr_val), .recv_from_controller_spm_wr_req__rdy(mem_dma_wr_rdy),
    .send_to_controller_spm_rd_resp__msg(sram_resp_msg), .send_to_controller_spm_rd_resp__val(sram_resp_val), .send_to_controller_spm_rd_resp__rdy(sram_resp_rdy)
  );

  function automatic int find_link(input int tile,port,output_side);
    find_link=-1;
    for(int k=0;k<LINK_COUNT;k++)
      if(LINK_ENABLED[k] && (output_side ? LINK_SRC_TILE[k]==tile && LINK_SRC_PORT[k]==port : LINK_DST_TILE[k]==tile && LINK_DST_PORT[k]==port)) find_link=k;
  endfunction
  function automatic int memory_port(input int tile,write_port);
    memory_port=-1;
    if(CUSTOM_TOPOLOGY) begin
      if(write_port) begin
        for(int k=0;k<MEM_WRITE_PORTS;k++) if(WRITE_PORT_TILE[k]==32'(tile)) memory_port=k;
      end else begin
        for(int k=0;k<MEM_PORTS;k++) if(READ_PORT_TILE[k]==32'(tile)) memory_port=k;
      end
    end else if(tile%COLS==0 || tile/COLS==0)
      memory_port=tile%COLS==0 ? tile/COLS : ROWS+tile%COLS-1;
  endfunction
  for(genvar i=NUM_TILES+1;i<=MAX_TILES;i++) begin : unused_control_routers
    assign ring_recv_msg[i]='0; assign ring_recv_val[i]=0; assign ring_send_rdy[i]=0;
  end
  for(genvar p=0;p<MEM_PORTS;p++) begin : unused_memory_ports
    if(CUSTOM_TOPOLOGY && READ_PORT_TILE[p]==32'hffffffff) begin
      assign mem_raddr_msg[p]='0; assign mem_raddr_val[p]=0; assign mem_rdata_rdy[p]=0;
    end
  end
  for(genvar p=0;p<MEM_WRITE_PORTS;p++) begin : unused_memory_write_ports
    if(CUSTOM_TOPOLOGY && WRITE_PORT_TILE[p]==32'hffffffff) begin
      assign mem_waddr_msg[p]='0; assign mem_waddr_val[p]=0; assign mem_wdata_msg[p]='0; assign mem_wdata_val[p]=0;
    end
  end
  initial if(CUSTOM_TOPOLOGY) begin
    for(int k=0;k<LINK_COUNT;k++) if(LINK_ENABLED[k]) begin
      if(LINK_SRC_TILE[k]>=NUM_TILES || LINK_DST_TILE[k]>=NUM_TILES || LINK_SRC_PORT[k]>=TILE_PORTS || LINK_DST_PORT[k]>=TILE_PORTS) $fatal(1,"Link endpoint out of range");
      for(int j=k+1;j<LINK_COUNT;j++) if(LINK_ENABLED[j] &&
        ((LINK_SRC_TILE[k]==LINK_SRC_TILE[j] && LINK_SRC_PORT[k]==LINK_SRC_PORT[j]) ||
         (LINK_DST_TILE[k]==LINK_DST_TILE[j] && LINK_DST_PORT[k]==LINK_DST_PORT[j]))) $fatal(1,"Multiple links share a physical port");
      if(BOUNDARY_IN_ENABLE[LINK_DST_TILE[k]][LINK_DST_PORT[k]] || BOUNDARY_OUT_ENABLE[LINK_SRC_TILE[k]][LINK_SRC_PORT[k]]) $fatal(1,"Boundary and internal link share a port");
    end
    for(int t=0;t<NUM_TILES;t++) for(int d=0;d<TILE_PORTS;d++)
      if(BOUNDARY_IN_ENABLE[t][d] || BOUNDARY_OUT_ENABLE[t][d])
        if(!((d==NORTH && t/COLS==ROWS-1) || (d==SOUTH && t/COLS==0) ||
             (d==WEST && t%COLS==0) || (d==EAST && t%COLS==COLS-1))) $fatal(1,"Boundary mapping must name an exterior cardinal port");
    for(int k=0;k<MEM_PORTS;k++) begin
      if(READ_PORT_TILE[k]!=32'hffffffff && READ_PORT_TILE[k]>=NUM_TILES) $fatal(1,"Read tile out of range");
      for(int j=k+1;j<MEM_PORTS;j++) begin
        if(READ_PORT_TILE[k]!=32'hffffffff && READ_PORT_TILE[k]==READ_PORT_TILE[j]) $fatal(1,"Tile has multiple memory read ports");
      end
    end
    for(int k=0;k<MEM_WRITE_PORTS;k++) begin
      if(WRITE_PORT_TILE[k]!=32'hffffffff && WRITE_PORT_TILE[k]>=NUM_TILES) $fatal(1,"Write tile out of range");
      for(int j=k+1;j<MEM_WRITE_PORTS;j++)
        if(WRITE_PORT_TILE[k]!=32'hffffffff && WRITE_PORT_TILE[k]==WRITE_PORT_TILE[j]) $fatal(1,"Tile has multiple memory write ports");
    end
  end
  for (genvar t = 0; t < NUM_TILES; t++) begin : tiles
    localparam int X=t%COLS, Y=t/COLS;
    initial if(TILE_FU_COUNTS[t]<1 || TILE_FU_COUNTS[t]>FU_COUNT)
      $fatal(1,"Tile FU count must fit the architecture table");
    logic [GLOBAL_ADDR_W-1:0] raddr_msg, waddr_msg;
    logic raddr_val, raddr_rdy, waddr_val, waddr_rdy;
    logic [DATA_BITS-1:0] wdata_msg, rdata_msg;
    logic wdata_val, wdata_rdy, rdata_val, rdata_rdy;
      cgra_pe #(.VARIANT(TILE_VARIANT), `CGRA_PROFILE_BIND, .FU_COUNT(TILE_FU_COUNTS[t]),
        .FU_KINDS(TILE_FU_KINDS[t][TILE_FU_COUNTS[t]*8-1:0]),
        `CGRA_FU_BIND_OPTIONS) tile (
      .clk, .reset, .cgra_id, .tile_id(TILE_ID_W'(t)),
      .recv_data__msg(tile_recv_msg[t]), .recv_data__val(tile_recv_val[t]), .recv_data__rdy(tile_recv_rdy[t]),
      .send_data__msg(tile_send_msg[t]), .send_data__val(tile_send_val[t]), .send_data__rdy(tile_send_rdy[t]),
      .recv_from_controller_pkt__msg(ring_send_msg[t]), .recv_from_controller_pkt__val(ring_send_val[t]), .recv_from_controller_pkt__rdy(ring_send_rdy[t]),
      .send_to_controller_pkt__msg(ring_recv_msg[t]), .send_to_controller_pkt__val(ring_recv_val[t]), .send_to_controller_pkt__rdy(ring_recv_rdy[t]),
      .to_mem_raddr__msg(raddr_msg), .to_mem_raddr__val(raddr_val), .to_mem_raddr__rdy(raddr_rdy),
      .to_mem_waddr__msg(waddr_msg), .to_mem_waddr__val(waddr_val), .to_mem_waddr__rdy(waddr_rdy),
      .to_mem_wdata__msg(wdata_msg), .to_mem_wdata__val(wdata_val), .to_mem_wdata__rdy(wdata_rdy),
      .from_mem_rdata__msg(rdata_msg), .from_mem_rdata__val(rdata_val), .from_mem_rdata__rdy(rdata_rdy)
      );

    localparam int READ_PORT=memory_port(t,0), WRITE_PORT=memory_port(t,1);
    if(READ_PORT>=0) begin : memory_read
      assign mem_raddr_msg[READ_PORT]=raddr_msg; assign mem_raddr_val[READ_PORT]=raddr_val; assign raddr_rdy=mem_raddr_rdy[READ_PORT];
      assign rdata_msg=mem_rdata_msg[READ_PORT]; assign rdata_val=mem_rdata_val[READ_PORT]; assign mem_rdata_rdy[READ_PORT]=rdata_rdy;
    end else begin : no_read_port
      assign raddr_rdy=0; assign rdata_msg='0; assign rdata_val=0;
    end
    if(WRITE_PORT>=0) begin : memory_write
      assign mem_waddr_msg[WRITE_PORT]=waddr_msg; assign mem_waddr_val[WRITE_PORT]=waddr_val; assign waddr_rdy=mem_waddr_rdy[WRITE_PORT];
      assign mem_wdata_msg[WRITE_PORT]=wdata_msg; assign mem_wdata_val[WRITE_PORT]=wdata_val; assign wdata_rdy=mem_wdata_rdy[WRITE_PORT];
    end else begin : no_write_port
      assign waddr_rdy=0; assign wdata_rdy=0;
    end
    if(!CUSTOM_TOPOLOGY) begin : regular_topology
    for (genvar d=0; d<4; d++) begin : mesh
      localparam int OPP = d == NORTH ? SOUTH : d == SOUTH ? NORTH : d == WEST ? EAST : WEST;
      localparam int NEIGHBOR = d == NORTH ? t+COLS : d == SOUTH ? t-COLS : d == WEST ? t-1 : t+1;
      localparam bit BOUNDARY = d == NORTH ? Y==ROWS-1 : d == SOUTH ? Y==0 : d == WEST ? X==0 : X==COLS-1;
      if (!BOUNDARY) begin : internal_link
        assign tile_recv_msg[t][d] = tile_send_msg[NEIGHBOR][OPP];
        assign tile_recv_val[t][d] = tile_send_val[NEIGHBOR][OPP];
        assign tile_send_rdy[t][d] = tile_recv_rdy[NEIGHBOR][OPP];
      end else if (d == NORTH) begin : north_boundary
        assign tile_recv_msg[t][d]=recv_data_on_boundary_north__msg[X]; assign tile_recv_val[t][d]=recv_data_on_boundary_north__val[X];
        assign recv_data_on_boundary_north__rdy[X]=tile_recv_rdy[t][d];
        assign send_data_on_boundary_north__msg[X]=tile_send_msg[t][d]; assign send_data_on_boundary_north__val[X]=tile_send_val[t][d];
        assign tile_send_rdy[t][d]=send_data_on_boundary_north__rdy[X];
      end else if (d == SOUTH) begin : south_boundary
        assign tile_recv_msg[t][d]=recv_data_on_boundary_south__msg[X]; assign tile_recv_val[t][d]=recv_data_on_boundary_south__val[X];
        assign recv_data_on_boundary_south__rdy[X]=tile_recv_rdy[t][d];
        assign send_data_on_boundary_south__msg[X]=tile_send_msg[t][d]; assign send_data_on_boundary_south__val[X]=tile_send_val[t][d];
        assign tile_send_rdy[t][d]=send_data_on_boundary_south__rdy[X];
      end else if (d == WEST) begin : west_boundary
        assign tile_recv_msg[t][d]=recv_data_on_boundary_west__msg[Y]; assign tile_recv_val[t][d]=recv_data_on_boundary_west__val[Y];
        assign recv_data_on_boundary_west__rdy[Y]=tile_recv_rdy[t][d];
        assign send_data_on_boundary_west__msg[Y]=tile_send_msg[t][d]; assign send_data_on_boundary_west__val[Y]=tile_send_val[t][d];
        assign tile_send_rdy[t][d]=send_data_on_boundary_west__rdy[Y];
      end else begin : east_boundary
        assign tile_recv_msg[t][d]=recv_data_on_boundary_east__msg[Y]; assign tile_recv_val[t][d]=recv_data_on_boundary_east__val[Y];
        assign recv_data_on_boundary_east__rdy[Y]=tile_recv_rdy[t][d];
        assign send_data_on_boundary_east__msg[Y]=tile_send_msg[t][d]; assign send_data_on_boundary_east__val[Y]=tile_send_val[t][d];
        assign tile_send_rdy[t][d]=send_data_on_boundary_east__rdy[Y];
      end
    end
    if(TILE_PORTS==8) begin : king_mesh
      for(genvar d=4;d<8;d++) begin : diagonal
        localparam int DX=(d==4 || d==7) ? -1 : 1;
        localparam int DY=(d==4 || d==5) ? 1 : -1;
        localparam int OPP=d==4 ? 6 : d==5 ? 7 : d==6 ? 4 : 5;
        localparam int NEIGHBOR=t+DY*COLS+DX;
        localparam bit BOUNDARY=(X+DX<0 || X+DX>=COLS || Y+DY<0 || Y+DY>=ROWS);
        if(!BOUNDARY) begin : connected
          assign tile_recv_msg[t][d]=tile_send_msg[NEIGHBOR][OPP];
          assign tile_recv_val[t][d]=tile_send_val[NEIGHBOR][OPP];
          assign tile_send_rdy[t][d]=tile_recv_rdy[NEIGHBOR][OPP];
        end else begin : terminated
          // ac96 has no diagonal exterior interfaces; preserve its tie-offs.
          assign tile_recv_msg[t][d]='0;
          assign tile_recv_val[t][d]=0;
          assign tile_send_rdy[t][d]=0;
        end
      end
    end
    end else begin : architecture_links
      for(genvar d=0;d<TILE_PORTS;d++) begin : port_links
        localparam int IN_LINK=find_link(t,d,0), OUT_LINK=find_link(t,d,1);
        if(IN_LINK>=0) begin : incoming_link
          assign tile_recv_msg[t][d]=tile_send_msg[LINK_SRC_TILE[IN_LINK]][LINK_SRC_PORT[IN_LINK]];
          assign tile_recv_val[t][d]=tile_send_val[LINK_SRC_TILE[IN_LINK]][LINK_SRC_PORT[IN_LINK]];
        end else if(BOUNDARY_IN_ENABLE[t][d]) begin : incoming_boundary
          if(d==0) begin
            assign tile_recv_msg[t][d]=recv_data_on_boundary_north__msg[X];
            assign tile_recv_val[t][d]=recv_data_on_boundary_north__val[X];
            assign recv_data_on_boundary_north__rdy[X]=tile_recv_rdy[t][d];
          end
          else if(d==1) begin
            assign tile_recv_msg[t][d]=recv_data_on_boundary_south__msg[X];
            assign tile_recv_val[t][d]=recv_data_on_boundary_south__val[X];
            assign recv_data_on_boundary_south__rdy[X]=tile_recv_rdy[t][d];
          end
          else if(d==2) begin
            assign tile_recv_msg[t][d]=recv_data_on_boundary_west__msg[Y];
            assign tile_recv_val[t][d]=recv_data_on_boundary_west__val[Y];
            assign recv_data_on_boundary_west__rdy[Y]=tile_recv_rdy[t][d];
          end
          else if(d==3) begin
            assign tile_recv_msg[t][d]=recv_data_on_boundary_east__msg[Y];
            assign tile_recv_val[t][d]=recv_data_on_boundary_east__val[Y];
            assign recv_data_on_boundary_east__rdy[Y]=tile_recv_rdy[t][d];
          end
        end else begin : incoming_grounded
          assign tile_recv_msg[t][d]='0; assign tile_recv_val[t][d]=0;
        end
        if(OUT_LINK>=0) begin : outgoing_link
          assign tile_send_rdy[t][d]=tile_recv_rdy[LINK_DST_TILE[OUT_LINK]][LINK_DST_PORT[OUT_LINK]];
        end else if(BOUNDARY_OUT_ENABLE[t][d]) begin : outgoing_boundary
          if(d==0) begin
            assign send_data_on_boundary_north__msg[X]=tile_send_msg[t][d];
            assign send_data_on_boundary_north__val[X]=tile_send_val[t][d];
            assign tile_send_rdy[t][d]=send_data_on_boundary_north__rdy[X];
          end
          else if(d==1) begin
            assign send_data_on_boundary_south__msg[X]=tile_send_msg[t][d];
            assign send_data_on_boundary_south__val[X]=tile_send_val[t][d];
            assign tile_send_rdy[t][d]=send_data_on_boundary_south__rdy[X];
          end
          else if(d==2) begin
            assign send_data_on_boundary_west__msg[Y]=tile_send_msg[t][d];
            assign send_data_on_boundary_west__val[Y]=tile_send_val[t][d];
            assign tile_send_rdy[t][d]=send_data_on_boundary_west__rdy[Y];
          end
          else if(d==3) begin
            assign send_data_on_boundary_east__msg[Y]=tile_send_msg[t][d];
            assign send_data_on_boundary_east__val[Y]=tile_send_val[t][d];
            assign tile_send_rdy[t][d]=send_data_on_boundary_east__rdy[Y];
          end
        end else begin : outgoing_grounded
          assign tile_send_rdy[t][d]=0;
        end
      end
    end
  end
endmodule
