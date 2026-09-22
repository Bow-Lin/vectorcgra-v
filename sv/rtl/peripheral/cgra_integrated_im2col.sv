// Native parameterized composition; baseline engines are separate reusable RTL.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module cgra_integrated_im2col #(
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
  parameter int SCRATCH_DEPTH=64,
  parameter logic[SCRATCH_DEPTH*DATA_W-1:0] PRELOAD_IMAGE='0
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
  output logic send_to_inter_cgra_noc__val
);
  `include "cgra_profile.svh"
  initial if(!HAS_IM2COL || HAS_DMA || IS_MULTI) $fatal(1,"cgra_integrated_im2col requires HAS_IM2COL=1, HAS_DMA=0 and IS_MULTI=0");
  logic [HOST_BITS-1:0] engine_recv_msg,engine_send_msg;
  logic engine_recv_val,engine_recv_rdy,engine_send_val,engine_send_rdy,engine_done,engine_active;
  logic cpu_val,cpu_rdy;
  host_packet_t launch_packet;
  assign launch_packet=engine_recv_msg;
  always_ff @(posedge clk) begin
    if(reset)engine_active<=0;
    else if(engine_recv_val && engine_recv_rdy && launch_packet.payload.cmd==6'd52)engine_active<=1;
    else if(engine_done)engine_active<=0;
  end
  assign cpu_val=engine_active ? 1'b0 : recv_from_cpu_pkt__val;
  assign recv_from_cpu_pkt__rdy=engine_active ? 1'b0 : cpu_rdy;
  cgra_im2col_engine #(`CGRA_PROFILE_BIND,.SCRATCH_DEPTH(SCRATCH_DEPTH),.PRELOAD_IMAGE(PRELOAD_IMAGE)) engine (
    .clk,.reset,.recv_cmd_pkt__msg(engine_recv_msg),.recv_cmd_pkt__val(engine_recv_val),.recv_cmd_pkt__rdy(engine_recv_rdy),
    .send_pkt__msg(engine_send_msg),.send_pkt__val(engine_send_val),.send_pkt__rdy(engine_send_rdy),.done(engine_done)
  );
  cgra_system #(`CGRA_PROFILE_BIND,`CGRA_FU_BIND,
    .TILE_VARIANT(TILE_VARIANT),
    .IS_MULTI(IS_MULTI),
    .TILE_FU_COUNTS(TILE_FU_COUNTS),
    .TILE_FU_KINDS(TILE_FU_KINDS),
    .CUSTOM_TOPOLOGY(CUSTOM_TOPOLOGY),
    .LINK_COUNT(LINK_COUNT),
    .LINK_ENABLED(LINK_ENABLED),
    .LINK_SRC_TILE(LINK_SRC_TILE),
    .LINK_SRC_PORT(LINK_SRC_PORT),
    .LINK_DST_TILE(LINK_DST_TILE),
    .LINK_DST_PORT(LINK_DST_PORT),
    .READ_PORT_TILE(READ_PORT_TILE),
    .WRITE_PORT_TILE(WRITE_PORT_TILE),
    .BOUNDARY_IN_ENABLE(BOUNDARY_IN_ENABLE),
    .BOUNDARY_OUT_ENABLE(BOUNDARY_OUT_ENABLE)) cgra (
    .address_lower(address_lower),
    .address_upper(address_upper),
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .recv_data_on_boundary_east__msg(recv_data_on_boundary_east__msg),
    .recv_data_on_boundary_east__rdy(recv_data_on_boundary_east__rdy),
    .recv_data_on_boundary_east__val(recv_data_on_boundary_east__val),
    .recv_data_on_boundary_north__msg(recv_data_on_boundary_north__msg),
    .recv_data_on_boundary_north__rdy(recv_data_on_boundary_north__rdy),
    .recv_data_on_boundary_north__val(recv_data_on_boundary_north__val),
    .recv_data_on_boundary_south__msg(recv_data_on_boundary_south__msg),
    .recv_data_on_boundary_south__rdy(recv_data_on_boundary_south__rdy),
    .recv_data_on_boundary_south__val(recv_data_on_boundary_south__val),
    .recv_data_on_boundary_west__msg(recv_data_on_boundary_west__msg),
    .recv_data_on_boundary_west__rdy(recv_data_on_boundary_west__rdy),
    .recv_data_on_boundary_west__val(recv_data_on_boundary_west__val),
    .recv_from_cpu_pkt__msg(recv_from_cpu_pkt__msg),
    .recv_from_cpu_pkt__rdy(cpu_rdy),
    .recv_from_cpu_pkt__val(cpu_val),
    .recv_from_inter_cgra_noc__msg(recv_from_inter_cgra_noc__msg),
    .recv_from_inter_cgra_noc__rdy(recv_from_inter_cgra_noc__rdy),
    .recv_from_inter_cgra_noc__val(recv_from_inter_cgra_noc__val),
    .send_data_on_boundary_east__msg(send_data_on_boundary_east__msg),
    .send_data_on_boundary_east__rdy(send_data_on_boundary_east__rdy),
    .send_data_on_boundary_east__val(send_data_on_boundary_east__val),
    .send_data_on_boundary_north__msg(send_data_on_boundary_north__msg),
    .send_data_on_boundary_north__rdy(send_data_on_boundary_north__rdy),
    .send_data_on_boundary_north__val(send_data_on_boundary_north__val),
    .send_data_on_boundary_south__msg(send_data_on_boundary_south__msg),
    .send_data_on_boundary_south__rdy(send_data_on_boundary_south__rdy),
    .send_data_on_boundary_south__val(send_data_on_boundary_south__val),
    .send_data_on_boundary_west__msg(send_data_on_boundary_west__msg),
    .send_data_on_boundary_west__rdy(send_data_on_boundary_west__rdy),
    .send_data_on_boundary_west__val(send_data_on_boundary_west__val),
    .send_to_cpu_pkt__msg(send_to_cpu_pkt__msg),
    .send_to_cpu_pkt__rdy(send_to_cpu_pkt__rdy),
    .send_to_cpu_pkt__val(send_to_cpu_pkt__val),
    .send_to_inter_cgra_noc__msg(send_to_inter_cgra_noc__msg),
    .send_to_inter_cgra_noc__rdy(send_to_inter_cgra_noc__rdy),
    .send_to_inter_cgra_noc__val(send_to_inter_cgra_noc__val),
    .dma_cmd__msg(),
    .dma_cmd__val(),
    .dma_cmd__rdy(1'b0),
    .dma_done__msg('0),
    .dma_done__val(1'b0),
    .dma_done__rdy(),
    .recv_from_dma_spm_rd_req__msg('0),
    .recv_from_dma_spm_rd_req__val(1'b0),
    .recv_from_dma_spm_rd_req__rdy(),
    .recv_from_dma_spm_wr_req__msg('0),
    .recv_from_dma_spm_wr_req__val(1'b0),
    .recv_from_dma_spm_wr_req__rdy(),
    .send_to_dma_spm_rd_resp__msg(),
    .send_to_dma_spm_rd_resp__val(),
    .send_to_dma_spm_rd_resp__rdy(1'b0),
    .recv_from_im2col_pkt__msg(engine_send_msg),
    .recv_from_im2col_pkt__val(engine_send_val),
    .recv_from_im2col_pkt__rdy(engine_send_rdy),
    .send_to_im2col_engine_pkt__msg(engine_recv_msg),
    .send_to_im2col_engine_pkt__val(engine_recv_val),
    .send_to_im2col_engine_pkt__rdy(engine_recv_rdy)
  );
endmodule
