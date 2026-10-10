`include "cgra_profile_defs.svh"
// Native parameterized cgra_controller; control flow derived from ac96 cgra_controller.
// Disabled DMA/im2col declarations and undriven inputs retain baseline semantics.
module cgra_controller #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [CGRA_ID_W-1:0] cgra_id ,
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  output logic [139-1:0] dma_cmd__msg  ,
  input logic [0:0] dma_cmd__rdy  ,
  output logic [0:0] dma_cmd__val  ,
  input logic [8-1:0] dma_done__msg  ,
  output logic [0:0] dma_done__rdy  ,
  input logic [0:0] dma_done__val  ,
  input logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg  ,
  output logic [0:0] recv_from_cpu_pkt__rdy  ,
  input logic [0:0] recv_from_cpu_pkt__val  ,
  input logic [HOST_BITS-1:0] recv_from_ctrl_ring_pkt__msg  ,
  output logic [0:0] recv_from_ctrl_ring_pkt__rdy  ,
  input logic [0:0] recv_from_ctrl_ring_pkt__val  ,
  input logic [32-1:0] recv_from_dma_spm_rd_req__msg  ,
  output logic [0:0] recv_from_dma_spm_rd_req__rdy  ,
  input logic [0:0] recv_from_dma_spm_rd_req__val  ,
  input logic [68-1:0] recv_from_dma_spm_wr_req__msg  ,
  output logic [0:0] recv_from_dma_spm_wr_req__rdy  ,
  input logic [0:0] recv_from_dma_spm_wr_req__val  ,
  input logic [HOST_BITS-1:0] recv_from_im2col_pkt__msg  ,
  output logic [0:0] recv_from_im2col_pkt__rdy  ,
  input logic [0:0] recv_from_im2col_pkt__val  ,
  input logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg  ,
  output logic [0:0] recv_from_inter_cgra_noc__rdy  ,
  input logic [0:0] recv_from_inter_cgra_noc__val  ,
  input logic [32-1:0] recv_from_sram_load_response__msg  ,
  output logic [0:0] recv_from_sram_load_response__rdy  ,
  input logic [0:0] recv_from_sram_load_response__val  ,
  input logic [NOC_BITS-1:0] recv_from_tile_load_request_pkt__msg  ,
  output logic [0:0] recv_from_tile_load_request_pkt__rdy  ,
  input logic [0:0] recv_from_tile_load_request_pkt__val  ,
  input logic [NOC_BITS-1:0] recv_from_tile_load_response_pkt__msg  ,
  output logic [0:0] recv_from_tile_load_response_pkt__rdy  ,
  input logic [0:0] recv_from_tile_load_response_pkt__val  ,
  input logic [NOC_BITS-1:0] recv_from_tile_store_request_pkt__msg  ,
  output logic [0:0] recv_from_tile_store_request_pkt__rdy  ,
  input logic [0:0] recv_from_tile_store_request_pkt__val  ,
  output logic [HOST_BITS-1:0] send_to_cpu_pkt__msg  ,
  input logic [0:0] send_to_cpu_pkt__rdy  ,
  output logic [0:0] send_to_cpu_pkt__val  ,
  output logic [HOST_BITS-1:0] send_to_ctrl_ring_pkt__msg  ,
  input logic [0:0] send_to_ctrl_ring_pkt__rdy  ,
  output logic [0:0] send_to_ctrl_ring_pkt__val  ,
  output logic [32-1:0] send_to_dma_spm_rd_resp__msg  ,
  input logic [0:0] send_to_dma_spm_rd_resp__rdy  ,
  output logic [0:0] send_to_dma_spm_rd_resp__val  ,
  output logic [HOST_BITS-1:0] send_to_im2col_engine_pkt__msg  ,
  input logic [0:0] send_to_im2col_engine_pkt__rdy  ,
  output logic [0:0] send_to_im2col_engine_pkt__val  ,
  output logic [NOC_BITS-1:0] send_to_inter_cgra_noc__msg  ,
  input logic [0:0] send_to_inter_cgra_noc__rdy  ,
  output logic [0:0] send_to_inter_cgra_noc__val  ,
  output logic [32-1:0] send_to_sram_load_request_from_dma__msg  ,
  input logic [0:0] send_to_sram_load_request_from_dma__rdy  ,
  output logic [0:0] send_to_sram_load_request_from_dma__val  ,
  output logic [NOC_BITS-1:0] send_to_sram_load_request_from_noc__msg  ,
  input logic [0:0] send_to_sram_load_request_from_noc__rdy  ,
  output logic [0:0] send_to_sram_load_request_from_noc__val  ,
  output logic [68-1:0] send_to_sram_store_request_from_dma__msg  ,
  input logic [0:0] send_to_sram_store_request_from_dma__rdy  ,
  output logic [0:0] send_to_sram_store_request_from_dma__val  ,
  output logic [NOC_BITS-1:0] send_to_sram_store_request_from_noc__msg  ,
  input logic [0:0] send_to_sram_store_request_from_noc__rdy  ,
  output logic [0:0] send_to_sram_store_request_from_noc__val  ,
  output logic [NOC_BITS-1:0] send_to_tile_load_response__msg  ,
  input logic [0:0] send_to_tile_load_response__rdy  ,
  output logic [0:0] send_to_tile_load_response__val  
);
  `include "cgra_profile.svh"
  dma_cmd_t p_dma_cmd__msg ;
  assign dma_cmd__msg = p_dma_cmd__msg;
  dma_done_t p_dma_done__msg ;
  assign p_dma_done__msg = dma_done__msg;
  host_packet_t p_recv_from_cpu_pkt__msg ;
  assign p_recv_from_cpu_pkt__msg = recv_from_cpu_pkt__msg;
  host_packet_t p_recv_from_ctrl_ring_pkt__msg ;
  assign p_recv_from_ctrl_ring_pkt__msg = recv_from_ctrl_ring_pkt__msg;
  dma_read_req_t p_recv_from_dma_spm_rd_req__msg ;
  assign p_recv_from_dma_spm_rd_req__msg = recv_from_dma_spm_rd_req__msg;
  dma_write_req_t p_recv_from_dma_spm_wr_req__msg ;
  assign p_recv_from_dma_spm_wr_req__msg = recv_from_dma_spm_wr_req__msg;
  host_packet_t p_recv_from_im2col_pkt__msg ;
  assign p_recv_from_im2col_pkt__msg = recv_from_im2col_pkt__msg;
  noc_packet_t p_recv_from_inter_cgra_noc__msg ;
  assign p_recv_from_inter_cgra_noc__msg = recv_from_inter_cgra_noc__msg;
  dma_read_resp_t p_recv_from_sram_load_response__msg ;
  assign p_recv_from_sram_load_response__msg = recv_from_sram_load_response__msg;
  noc_packet_t p_recv_from_tile_load_request_pkt__msg ;
  assign p_recv_from_tile_load_request_pkt__msg = recv_from_tile_load_request_pkt__msg;
  noc_packet_t p_recv_from_tile_load_response_pkt__msg ;
  assign p_recv_from_tile_load_response_pkt__msg = recv_from_tile_load_response_pkt__msg;
  noc_packet_t p_recv_from_tile_store_request_pkt__msg ;
  assign p_recv_from_tile_store_request_pkt__msg = recv_from_tile_store_request_pkt__msg;
  host_packet_t p_send_to_cpu_pkt__msg ;
  assign send_to_cpu_pkt__msg = p_send_to_cpu_pkt__msg;
  host_packet_t p_send_to_ctrl_ring_pkt__msg ;
  assign send_to_ctrl_ring_pkt__msg = p_send_to_ctrl_ring_pkt__msg;
  dma_read_resp_t p_send_to_dma_spm_rd_resp__msg ;
  assign send_to_dma_spm_rd_resp__msg = p_send_to_dma_spm_rd_resp__msg;
  host_packet_t p_send_to_im2col_engine_pkt__msg ;
  assign send_to_im2col_engine_pkt__msg = p_send_to_im2col_engine_pkt__msg;
  noc_packet_t p_send_to_inter_cgra_noc__msg ;
  assign send_to_inter_cgra_noc__msg = p_send_to_inter_cgra_noc__msg;
  dma_read_req_t p_send_to_sram_load_request_from_dma__msg ;
  assign send_to_sram_load_request_from_dma__msg = p_send_to_sram_load_request_from_dma__msg;
  noc_packet_t p_send_to_sram_load_request_from_noc__msg ;
  assign send_to_sram_load_request_from_noc__msg = p_send_to_sram_load_request_from_noc__msg;
  dma_write_req_t p_send_to_sram_store_request_from_dma__msg ;
  assign send_to_sram_store_request_from_dma__msg = p_send_to_sram_store_request_from_dma__msg;
  noc_packet_t p_send_to_sram_store_request_from_noc__msg ;
  assign send_to_sram_store_request_from_noc__msg = p_send_to_sram_store_request_from_noc__msg;
  noc_packet_t p_send_to_tile_load_response__msg ;
  assign send_to_tile_load_response__msg = p_send_to_tile_load_response__msg;

  localparam logic [0:0] has_dma_ports_at_update_dma_cmd_regs  = HAS_DMA;
  localparam logic [5:0] CMD_DMA_CONFIG_DRAM_ADDR_LO  = 6'd44;
  localparam logic [5:0] CMD_DMA_CONFIG_DRAM_ADDR_HI  = 6'd45;
  localparam logic [5:0] CMD_DMA_CONFIG_SPM_ADDR  = 6'd46;
  localparam logic [5:0] CMD_DMA_CONFIG_BYTES  = 6'd47;
  localparam logic [5:0] CMD_DMA_CONFIG_TAG  = 6'd48;
  localparam logic [0:0] has_dma_ports_at_update_dma_spm_forwarding  = HAS_DMA;
  localparam logic [0:0] DMA_MVIN  = 1'd0;
  localparam logic [2:0] CONTROLLER_CROSSBAR_INPORTS  = 3'd7;
  localparam logic [2:0] kFromInterTileRingIdx  = 3'd4;
  localparam logic [0:0] kLoadRequestInportIdx  = 1'd0;
  localparam logic [1:0] kStoreRequestInportIdx  = 2'd2;
  localparam logic [0:0] kLoadResponseInportIdx  = 1'd1;
  localparam logic [2:0] kFromReduceUnitIdx  = 3'd5;
  localparam logic [2:0] kFromIm2colIdx  = 3'd6;
  localparam int num_tiles_at_update_received_msg = MAX_TILES;
  localparam logic [0:0] has_dma_ports_at_update_received_msg  = HAS_DMA;
  localparam logic [5:0] CMD_DMA_MVIN  = 6'd49;
  localparam logic [5:0] CMD_DMA_MVOUT  = 6'd50;
  localparam logic [0:0] DMA_MVOUT  = 1'd1;
  localparam logic [0:0] has_im2col_engine_at_update_received_msg  = HAS_IM2COL;
  localparam logic [5:0] CMD_IM2COL_LAUNCH  = 6'd52;
  localparam logic [5:0] CMD_IM2COL_H  = 6'd53;
  localparam logic [5:0] CMD_IM2COL_W  = 6'd54;
  localparam logic [5:0] CMD_IM2COL_KH  = 6'd55;
  localparam logic [5:0] CMD_IM2COL_KW  = 6'd56;
  localparam logic [5:0] CMD_IM2COL_LOG2_STRIDE  = 6'd57;
  localparam logic [5:0] CMD_IM2COL_DST_SRAM_BASE  = 6'd58;
  localparam logic [1:0] kFromCpuCtrlAndDataIdx  = 2'd3;
  localparam logic [3:0] CMD_LOAD_REQUEST  = 4'd10;
  localparam logic [3:0] CMD_STORE_REQUEST  = 4'd12;
  localparam logic [3:0] CMD_LOAD_RESPONSE  = 4'd11;
  localparam logic [3:0] CMD_COMPLETE  = 4'd14;
  localparam logic [4:0] CMD_LEAF_COUNTER_COMPLETE  = 5'd31;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD  = 5'd18;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_COUNT  = 5'd17;
  localparam logic [1:0] CMD_CONFIG  = 2'd3;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU  = 3'd4;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_FU_CROSSBAR  = 3'd5;
  localparam logic [2:0] CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR  = 3'd6;
  localparam logic [2:0] CMD_CONFIG_TOTAL_CTRL_COUNT  = 3'd7;
  localparam logic [3:0] CMD_CONFIG_COUNT_PER_ITER  = 4'd8;
  localparam logic [3:0] CMD_CONFIG_CTRL_LOWER_BOUND  = 4'd9;
  localparam logic [3:0] CMD_CONST  = 4'd13;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD_RESPONSE  = 5'd20;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_MUL_RESPONSE  = 5'd21;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_START_ADDR  = 5'd23;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_STRIDE  = 5'd24;
  localparam logic [4:0] CMD_CONFIG_STREAMING_LD_END_ADDR  = 5'd25;
  localparam logic [0:0] CMD_PAUSE  = 1'd1;
  localparam logic [4:0] CMD_PRESERVE  = 5'd22;
  localparam logic [3:0] CMD_RESUME  = 4'd15;
  localparam logic [4:0] CMD_RECORD_PHI_ADDR  = 5'd16;
  localparam logic [1:0] CMD_TERMINATE  = 2'd2;
  localparam logic [0:0] CMD_LAUNCH  = 1'd0;
  localparam logic [4:0] CMD_CONFIG_LOOP_LOWER  = 5'd28;
  localparam logic [4:0] CMD_CONFIG_LOOP_UPPER  = 5'd29;
  localparam logic [4:0] CMD_CONFIG_LOOP_STEP  = 5'd30;
  localparam logic [5:0] CMD_DMA_DONE  = 6'd51;
  localparam int addr_offset_nbits_at_capture_addr_dst_id = $clog2(NUM_BANKS*BANK_DEPTH);
  logic [CGRA_ID_W-1:0] addr2controller_lut [0:NUM_CGRAS-1];
  logic [CGRA_ID_W-1:0] addr_dst_id;
  logic [31:0] dma_bytes;
  logic [31:0] dma_dram_addr_hi;
  logic [31:0] dma_dram_addr_lo;
  logic [31:0] dma_spm_addr;
  logic [7:0] dma_tag;
  logic [CGRA_X_W-1:0] idTo2d_x_lut [0:NUM_CGRAS-1];
  logic [CGRA_Y_W-1:0] idTo2d_y_lut [0:NUM_CGRAS-1];

  logic [0:0] crossbar__clk;
  logic [0:0] crossbar__reset;
  controller_xbar_t crossbar__recv__msg [0:6];
  logic [0:0] crossbar__recv__rdy [0:6];
  logic [0:0] crossbar__recv__val [0:6];
  controller_xbar_t crossbar__send__msg [0:0];
  logic [0:0] crossbar__send__rdy [0:0];
  logic [0:0] crossbar__send__val [0:0];

  cgra_xbar #(.WIDTH(NOC_BITS+1), .INPUTS(7), .OUTPUTS(1), .DST_LSB(NOC_BITS), .DST_WIDTH(1), .INPUT_BYPASS(0)) crossbar (
    .clk(crossbar__clk),
    .reset(crossbar__reset),
    .recv_msg(crossbar__recv__msg),
    .recv_rdy(crossbar__recv__rdy),
    .recv_val(crossbar__recv__val),
    .send_msg(crossbar__send__msg),
    .send_rdy(crossbar__send__rdy),
    .send_val(crossbar__send__val)
  );

  logic [0:0] global_reduce_unit__clk;
  logic [0:0] global_reduce_unit__reset;
  noc_packet_t global_reduce_unit__recv_count__msg;
  logic [0:0] global_reduce_unit__recv_count__rdy;
  logic [0:0] global_reduce_unit__recv_count__val;
  noc_packet_t global_reduce_unit__recv_data__msg;
  logic [0:0] global_reduce_unit__recv_data__rdy;
  logic [0:0] global_reduce_unit__recv_data__val;
  controller_xbar_t global_reduce_unit__send__msg;
  logic [0:0] global_reduce_unit__send__rdy;
  logic [0:0] global_reduce_unit__send__val;

  cgra_global_reduce #(`CGRA_PROFILE_BIND) global_reduce_unit (
    .clk(global_reduce_unit__clk),
    .reset(global_reduce_unit__reset),
    .recv_count__msg(global_reduce_unit__recv_count__msg),
    .recv_count__rdy(global_reduce_unit__recv_count__rdy),
    .recv_count__val(global_reduce_unit__recv_count__val),
    .recv_data__msg(global_reduce_unit__recv_data__msg),
    .recv_data__rdy(global_reduce_unit__recv_data__rdy),
    .recv_data__val(global_reduce_unit__recv_data__val),
    .send__msg(global_reduce_unit__send__msg),
    .send__rdy(global_reduce_unit__send__rdy),
    .send__val(global_reduce_unit__send__val)
  );

  logic [0:0] recv_from_cpu_pkt_queue__clk;
  logic [1:0] recv_from_cpu_pkt_queue__count;
  logic [0:0] recv_from_cpu_pkt_queue__reset;
  host_packet_t recv_from_cpu_pkt_queue__recv__msg;
  logic [0:0] recv_from_cpu_pkt_queue__recv__rdy;
  logic [0:0] recv_from_cpu_pkt_queue__recv__val;
  host_packet_t recv_from_cpu_pkt_queue__send__msg;
  logic [0:0] recv_from_cpu_pkt_queue__send__rdy;
  logic [0:0] recv_from_cpu_pkt_queue__send__val;

  cgra_queue #(.WIDTH(HOST_BITS), .DEPTH(2), .BYPASS(0)) recv_from_cpu_pkt_queue (
    .clk(recv_from_cpu_pkt_queue__clk),
    .count(recv_from_cpu_pkt_queue__count),
    .reset(recv_from_cpu_pkt_queue__reset),
    .recv_msg(recv_from_cpu_pkt_queue__recv__msg),
    .recv_rdy(recv_from_cpu_pkt_queue__recv__rdy),
    .recv_val(recv_from_cpu_pkt_queue__recv__val),
    .send_msg(recv_from_cpu_pkt_queue__send__msg),
    .send_rdy(recv_from_cpu_pkt_queue__send__rdy),
    .send_val(recv_from_cpu_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] recv_from_im2col_pkt_queue__clk;
  logic [0:0] recv_from_im2col_pkt_queue__reset;
  host_packet_t recv_from_im2col_pkt_queue__recv__msg;
  logic [0:0] recv_from_im2col_pkt_queue__recv__rdy;
  logic [0:0] recv_from_im2col_pkt_queue__recv__val;
  host_packet_t recv_from_im2col_pkt_queue__send__msg;
  logic [0:0] recv_from_im2col_pkt_queue__send__rdy;
  logic [0:0] recv_from_im2col_pkt_queue__send__val;

  cgra_channel #(.WIDTH(HOST_BITS), .LATENCY(1)) recv_from_im2col_pkt_queue (
    .clk(recv_from_im2col_pkt_queue__clk),
    .reset(recv_from_im2col_pkt_queue__reset),
    .recv_msg(recv_from_im2col_pkt_queue__recv__msg),
    .recv_rdy(recv_from_im2col_pkt_queue__recv__rdy),
    .recv_val(recv_from_im2col_pkt_queue__recv__val),
    .send_msg(recv_from_im2col_pkt_queue__send__msg),
    .send_rdy(recv_from_im2col_pkt_queue__send__rdy),
    .send_val(recv_from_im2col_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] recv_from_tile_load_request_pkt_queue__clk;
  logic [0:0] recv_from_tile_load_request_pkt_queue__reset;
  noc_packet_t recv_from_tile_load_request_pkt_queue__recv__msg;
  logic [0:0] recv_from_tile_load_request_pkt_queue__recv__rdy;
  logic [0:0] recv_from_tile_load_request_pkt_queue__recv__val;
  noc_packet_t recv_from_tile_load_request_pkt_queue__send__msg;
  logic [0:0] recv_from_tile_load_request_pkt_queue__send__rdy;
  logic [0:0] recv_from_tile_load_request_pkt_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) recv_from_tile_load_request_pkt_queue (
    .clk(recv_from_tile_load_request_pkt_queue__clk),
    .reset(recv_from_tile_load_request_pkt_queue__reset),
    .recv_msg(recv_from_tile_load_request_pkt_queue__recv__msg),
    .recv_rdy(recv_from_tile_load_request_pkt_queue__recv__rdy),
    .recv_val(recv_from_tile_load_request_pkt_queue__recv__val),
    .send_msg(recv_from_tile_load_request_pkt_queue__send__msg),
    .send_rdy(recv_from_tile_load_request_pkt_queue__send__rdy),
    .send_val(recv_from_tile_load_request_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] recv_from_tile_load_response_pkt_queue__clk;
  logic [0:0] recv_from_tile_load_response_pkt_queue__reset;
  noc_packet_t recv_from_tile_load_response_pkt_queue__recv__msg;
  logic [0:0] recv_from_tile_load_response_pkt_queue__recv__rdy;
  logic [0:0] recv_from_tile_load_response_pkt_queue__recv__val;
  noc_packet_t recv_from_tile_load_response_pkt_queue__send__msg;
  logic [0:0] recv_from_tile_load_response_pkt_queue__send__rdy;
  logic [0:0] recv_from_tile_load_response_pkt_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) recv_from_tile_load_response_pkt_queue (
    .clk(recv_from_tile_load_response_pkt_queue__clk),
    .reset(recv_from_tile_load_response_pkt_queue__reset),
    .recv_msg(recv_from_tile_load_response_pkt_queue__recv__msg),
    .recv_rdy(recv_from_tile_load_response_pkt_queue__recv__rdy),
    .recv_val(recv_from_tile_load_response_pkt_queue__recv__val),
    .send_msg(recv_from_tile_load_response_pkt_queue__send__msg),
    .send_rdy(recv_from_tile_load_response_pkt_queue__send__rdy),
    .send_val(recv_from_tile_load_response_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] recv_from_tile_store_request_pkt_queue__clk;
  logic [0:0] recv_from_tile_store_request_pkt_queue__reset;
  noc_packet_t recv_from_tile_store_request_pkt_queue__recv__msg;
  logic [0:0] recv_from_tile_store_request_pkt_queue__recv__rdy;
  logic [0:0] recv_from_tile_store_request_pkt_queue__recv__val;
  noc_packet_t recv_from_tile_store_request_pkt_queue__send__msg;
  logic [0:0] recv_from_tile_store_request_pkt_queue__send__rdy;
  logic [0:0] recv_from_tile_store_request_pkt_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) recv_from_tile_store_request_pkt_queue (
    .clk(recv_from_tile_store_request_pkt_queue__clk),
    .reset(recv_from_tile_store_request_pkt_queue__reset),
    .recv_msg(recv_from_tile_store_request_pkt_queue__recv__msg),
    .recv_rdy(recv_from_tile_store_request_pkt_queue__recv__rdy),
    .recv_val(recv_from_tile_store_request_pkt_queue__recv__val),
    .send_msg(recv_from_tile_store_request_pkt_queue__send__msg),
    .send_rdy(recv_from_tile_store_request_pkt_queue__send__rdy),
    .send_val(recv_from_tile_store_request_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] send_to_cpu_pkt_queue__clk;
  logic [1:0] send_to_cpu_pkt_queue__count;
  logic [0:0] send_to_cpu_pkt_queue__reset;
  host_packet_t send_to_cpu_pkt_queue__recv__msg;
  logic [0:0] send_to_cpu_pkt_queue__recv__rdy;
  logic [0:0] send_to_cpu_pkt_queue__recv__val;
  host_packet_t send_to_cpu_pkt_queue__send__msg;
  logic [0:0] send_to_cpu_pkt_queue__send__rdy;
  logic [0:0] send_to_cpu_pkt_queue__send__val;

  cgra_queue #(.WIDTH(HOST_BITS), .DEPTH(2), .BYPASS(0)) send_to_cpu_pkt_queue (
    .clk(send_to_cpu_pkt_queue__clk),
    .count(send_to_cpu_pkt_queue__count),
    .reset(send_to_cpu_pkt_queue__reset),
    .recv_msg(send_to_cpu_pkt_queue__recv__msg),
    .recv_rdy(send_to_cpu_pkt_queue__recv__rdy),
    .recv_val(send_to_cpu_pkt_queue__recv__val),
    .send_msg(send_to_cpu_pkt_queue__send__msg),
    .send_rdy(send_to_cpu_pkt_queue__send__rdy),
    .send_val(send_to_cpu_pkt_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] send_to_mem_load_request_queue__clk;
  logic [0:0] send_to_mem_load_request_queue__reset;
  noc_packet_t send_to_mem_load_request_queue__recv__msg;
  logic [0:0] send_to_mem_load_request_queue__recv__rdy;
  logic [0:0] send_to_mem_load_request_queue__recv__val;
  noc_packet_t send_to_mem_load_request_queue__send__msg;
  logic [0:0] send_to_mem_load_request_queue__send__rdy;
  logic [0:0] send_to_mem_load_request_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) send_to_mem_load_request_queue (
    .clk(send_to_mem_load_request_queue__clk),
    .reset(send_to_mem_load_request_queue__reset),
    .recv_msg(send_to_mem_load_request_queue__recv__msg),
    .recv_rdy(send_to_mem_load_request_queue__recv__rdy),
    .recv_val(send_to_mem_load_request_queue__recv__val),
    .send_msg(send_to_mem_load_request_queue__send__msg),
    .send_rdy(send_to_mem_load_request_queue__send__rdy),
    .send_val(send_to_mem_load_request_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] send_to_mem_store_request_queue__clk;
  logic [0:0] send_to_mem_store_request_queue__reset;
  noc_packet_t send_to_mem_store_request_queue__recv__msg;
  logic [0:0] send_to_mem_store_request_queue__recv__rdy;
  logic [0:0] send_to_mem_store_request_queue__recv__val;
  noc_packet_t send_to_mem_store_request_queue__send__msg;
  logic [0:0] send_to_mem_store_request_queue__send__rdy;
  logic [0:0] send_to_mem_store_request_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) send_to_mem_store_request_queue (
    .clk(send_to_mem_store_request_queue__clk),
    .reset(send_to_mem_store_request_queue__reset),
    .recv_msg(send_to_mem_store_request_queue__recv__msg),
    .recv_rdy(send_to_mem_store_request_queue__recv__rdy),
    .recv_val(send_to_mem_store_request_queue__recv__val),
    .send_msg(send_to_mem_store_request_queue__send__msg),
    .send_rdy(send_to_mem_store_request_queue__send__rdy),
    .send_val(send_to_mem_store_request_queue__send__val),
    .clear(1'b0)
  );

  logic [0:0] send_to_tile_load_response_queue__clk;
  logic [0:0] send_to_tile_load_response_queue__reset;
  noc_packet_t send_to_tile_load_response_queue__recv__msg;
  logic [0:0] send_to_tile_load_response_queue__recv__rdy;
  logic [0:0] send_to_tile_load_response_queue__recv__val;
  noc_packet_t send_to_tile_load_response_queue__send__msg;
  logic [0:0] send_to_tile_load_response_queue__send__rdy;
  logic [0:0] send_to_tile_load_response_queue__send__val;

  cgra_channel #(.WIDTH(NOC_BITS), .LATENCY(1)) send_to_tile_load_response_queue (
    .clk(send_to_tile_load_response_queue__clk),
    .reset(send_to_tile_load_response_queue__reset),
    .recv_msg(send_to_tile_load_response_queue__recv__msg),
    .recv_rdy(send_to_tile_load_response_queue__recv__rdy),
    .recv_val(send_to_tile_load_response_queue__recv__val),
    .send_msg(send_to_tile_load_response_queue__send__msg),
    .send_rdy(send_to_tile_load_response_queue__send__rdy),
    .send_val(send_to_tile_load_response_queue__send__val),
    .clear(1'b0)
  );

  payload_t update_dma_cmd_regs_cpu_payload;
  logic [5:0] update_dma_cmd_regs_cpu_cmd;
  logic [31:0] update_dma_cmd_regs_cpu_data;
  payload_t update_received_msg_cpu_payload;
  logic [5:0] update_received_msg_cpu_cmd;
  noc_packet_t update_received_msg_received_pkt;

  always_comb begin : capture_addr_dst_id
    addr_dst_id = addr2controller_lut[CGRA_ID_W'(crossbar__send__msg[1'd0].inter_cgra_pkt.payload.data_addr >> addr_offset_nbits_at_capture_addr_dst_id)];
  end

  always_comb begin : update_dma_spm_forwarding
    if ( 1'( has_dma_ports_at_update_dma_spm_forwarding ) ) begin
      send_to_sram_store_request_from_dma__val = recv_from_dma_spm_wr_req__val;
      recv_from_dma_spm_wr_req__rdy = send_to_sram_store_request_from_dma__rdy;
      p_send_to_sram_store_request_from_dma__msg = p_recv_from_dma_spm_wr_req__msg;
      send_to_sram_load_request_from_dma__val = recv_from_dma_spm_rd_req__val;
      recv_from_dma_spm_rd_req__rdy = send_to_sram_load_request_from_dma__rdy;
      p_send_to_sram_load_request_from_dma__msg = p_recv_from_dma_spm_rd_req__msg;
      send_to_dma_spm_rd_resp__val = recv_from_sram_load_response__val;
      recv_from_sram_load_response__rdy = send_to_dma_spm_rd_resp__rdy;
      p_send_to_dma_spm_rd_resp__msg = p_recv_from_sram_load_response__msg;
    end
    else begin
      send_to_sram_store_request_from_dma__val = 1'd0;
      p_send_to_sram_store_request_from_dma__msg = '0;
      send_to_sram_load_request_from_dma__val = 1'd0;
      p_send_to_sram_load_request_from_dma__msg = 32'd0;
      recv_from_sram_load_response__rdy = 1'd0;
      recv_from_dma_spm_wr_req__rdy = 1'd0;
      recv_from_dma_spm_rd_req__rdy = 1'd0;
      send_to_dma_spm_rd_resp__val = 1'd0;
      p_send_to_dma_spm_rd_resp__msg = 32'd0;
    end
  end

  always_comb begin : update_received_msg
    send_to_cpu_pkt_queue__recv__val = 1'd0;
    send_to_cpu_pkt_queue__recv__msg = '0;
    recv_from_ctrl_ring_pkt__rdy = 1'd0;
    dma_cmd__val = 1'd0;
    p_dma_cmd__msg = { 3'd0, { dma_dram_addr_hi, dma_dram_addr_lo }, dma_spm_addr, dma_bytes, dma_tag };
    dma_done__rdy = 1'd0;
    send_to_im2col_engine_pkt__val = 1'd0;
    p_send_to_im2col_engine_pkt__msg = '0;
    recv_from_im2col_pkt_queue__send__rdy = 1'd0;
    for ( int unsigned i = 1'd0; i < 3'( CONTROLLER_CROSSBAR_INPORTS ); i += 1'd1 ) begin
      crossbar__recv__val[3'(i)] = 1'd0;
      crossbar__recv__msg[3'(i)] = '0;
    end
    crossbar__recv__val[3'( kFromInterTileRingIdx )] = recv_from_ctrl_ring_pkt__val;
    recv_from_ctrl_ring_pkt__rdy = crossbar__recv__rdy[3'( kFromInterTileRingIdx )];
    crossbar__recv__msg[3'( kFromInterTileRingIdx )] = { 1'd0, { cgra_id, p_recv_from_ctrl_ring_pkt__msg.dst_cgra_id, idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], p_recv_from_ctrl_ring_pkt__msg.dst_cgra_x, p_recv_from_ctrl_ring_pkt__msg.dst_cgra_y, p_recv_from_ctrl_ring_pkt__msg.src, p_recv_from_ctrl_ring_pkt__msg.dst, MEM_PORT_W'(0), 8'd0, 2'd0, p_recv_from_ctrl_ring_pkt__msg.payload } };
    crossbar__recv__val[3'( kLoadRequestInportIdx )] = recv_from_tile_load_request_pkt_queue__send__val;
    recv_from_tile_load_request_pkt_queue__send__rdy = crossbar__recv__rdy[3'( kLoadRequestInportIdx )];
    crossbar__recv__msg[3'( kLoadRequestInportIdx )] = { 1'd0, recv_from_tile_load_request_pkt_queue__send__msg };
    crossbar__recv__val[3'( kStoreRequestInportIdx )] = recv_from_tile_store_request_pkt_queue__send__val;
    recv_from_tile_store_request_pkt_queue__send__rdy = crossbar__recv__rdy[3'( kStoreRequestInportIdx )];
    crossbar__recv__msg[3'( kStoreRequestInportIdx )] = { 1'd0, recv_from_tile_store_request_pkt_queue__send__msg };
    crossbar__recv__val[3'( kLoadResponseInportIdx )] = recv_from_tile_load_response_pkt_queue__send__val;
    recv_from_tile_load_response_pkt_queue__send__rdy = crossbar__recv__rdy[3'( kLoadResponseInportIdx )];
    crossbar__recv__msg[3'( kLoadResponseInportIdx )] = { 1'd0, recv_from_tile_load_response_pkt_queue__send__msg };
    crossbar__recv__val[3'( kFromReduceUnitIdx )] = global_reduce_unit__send__val;
    global_reduce_unit__send__rdy = crossbar__recv__rdy[3'( kFromReduceUnitIdx )];
    crossbar__recv__msg[3'( kFromReduceUnitIdx )] = global_reduce_unit__send__msg;
    crossbar__recv__val[3'( kFromIm2colIdx )] = recv_from_im2col_pkt_queue__send__val;
    recv_from_im2col_pkt_queue__send__rdy = crossbar__recv__rdy[3'( kFromIm2colIdx )];
    crossbar__recv__msg[3'( kFromIm2colIdx )] = { 1'd0, { cgra_id, recv_from_im2col_pkt_queue__send__msg.dst_cgra_id, CGRA_X_W'(0), CGRA_Y_W'(0), idTo2d_x_lut[recv_from_im2col_pkt_queue__send__msg.dst_cgra_id], idTo2d_y_lut[recv_from_im2col_pkt_queue__send__msg.dst_cgra_id], TILE_ID_W'( num_tiles_at_update_received_msg ), recv_from_im2col_pkt_queue__send__msg.dst, MEM_PORT_W'(0), 8'd0, 2'd0, recv_from_im2col_pkt_queue__send__msg.payload } };
    update_received_msg_cpu_payload = recv_from_cpu_pkt_queue__send__msg.payload;
    update_received_msg_cpu_cmd = update_received_msg_cpu_payload.cmd;
    if ( 1'( has_dma_ports_at_update_received_msg ) & ( ( ( ( ( update_received_msg_cpu_cmd == 6'( CMD_DMA_CONFIG_DRAM_ADDR_LO ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_DMA_CONFIG_DRAM_ADDR_HI ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_DMA_CONFIG_SPM_ADDR ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_DMA_CONFIG_BYTES ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_DMA_CONFIG_TAG ) ) ) ) begin
      recv_from_cpu_pkt_queue__send__rdy = 1'd1;
    end
    else if ( 1'( has_dma_ports_at_update_received_msg ) & ( ( update_received_msg_cpu_cmd == 6'( CMD_DMA_MVIN ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_DMA_MVOUT ) ) ) ) begin
      dma_cmd__val = recv_from_cpu_pkt_queue__send__val;
      if ( update_received_msg_cpu_cmd == 6'( CMD_DMA_MVIN ) ) begin
        p_dma_cmd__msg = { 3'd0, { dma_dram_addr_hi, dma_dram_addr_lo }, dma_spm_addr, dma_bytes, dma_tag };
      end
      else
        p_dma_cmd__msg = { 3'd1, { dma_dram_addr_hi, dma_dram_addr_lo }, dma_spm_addr, dma_bytes, dma_tag };
      recv_from_cpu_pkt_queue__send__rdy = dma_cmd__rdy;
    end
    else if ( 1'( has_im2col_engine_at_update_received_msg ) & ( ( ( ( ( ( ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_LAUNCH ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_H ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_W ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_KH ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_KW ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_LOG2_STRIDE ) ) ) | ( update_received_msg_cpu_cmd == 6'( CMD_IM2COL_DST_SRAM_BASE ) ) ) ) begin
      send_to_im2col_engine_pkt__val = recv_from_cpu_pkt_queue__send__val;
      p_send_to_im2col_engine_pkt__msg = recv_from_cpu_pkt_queue__send__msg;
      recv_from_cpu_pkt_queue__send__rdy = send_to_im2col_engine_pkt__rdy;
    end
    else begin
      crossbar__recv__val[3'( kFromCpuCtrlAndDataIdx )] = recv_from_cpu_pkt_queue__send__val;
      recv_from_cpu_pkt_queue__send__rdy = crossbar__recv__rdy[3'( kFromCpuCtrlAndDataIdx )];
      crossbar__recv__msg[3'( kFromCpuCtrlAndDataIdx )] = { 1'd0, { cgra_id, recv_from_cpu_pkt_queue__send__msg.dst_cgra_id, CGRA_X_W'(0), CGRA_Y_W'(0), idTo2d_x_lut[recv_from_cpu_pkt_queue__send__msg.dst_cgra_id], idTo2d_y_lut[recv_from_cpu_pkt_queue__send__msg.dst_cgra_id], TILE_ID_W'( num_tiles_at_update_received_msg ), recv_from_cpu_pkt_queue__send__msg.dst, MEM_PORT_W'(0), 8'd0, 2'd0, recv_from_cpu_pkt_queue__send__msg.payload } };
    end
    send_to_mem_load_request_queue__recv__val = 1'd0;
    send_to_mem_store_request_queue__recv__val = 1'd0;
    send_to_tile_load_response_queue__recv__val = 1'd0;
    send_to_mem_load_request_queue__recv__msg = '0;
    send_to_mem_store_request_queue__recv__msg = '0;
    send_to_tile_load_response_queue__recv__msg = '0;
    recv_from_inter_cgra_noc__rdy = 1'd0;
    send_to_ctrl_ring_pkt__val = 1'd0;
    p_send_to_ctrl_ring_pkt__msg = '0;
    global_reduce_unit__recv_count__val = 1'd0;
    global_reduce_unit__recv_count__msg = '0;
    global_reduce_unit__recv_data__val = 1'd0;
    global_reduce_unit__recv_data__msg = '0;
    update_received_msg_received_pkt = p_recv_from_inter_cgra_noc__msg;
    if ( recv_from_inter_cgra_noc__val ) begin
      if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_LOAD_REQUEST ) ) begin
        send_to_mem_load_request_queue__recv__val = 1'd1;
        if ( send_to_mem_load_request_queue__recv__rdy ) begin
          recv_from_inter_cgra_noc__rdy = 1'd1;
          send_to_mem_load_request_queue__recv__msg = update_received_msg_received_pkt;
        end
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_STORE_REQUEST ) ) begin
        send_to_mem_store_request_queue__recv__msg = update_received_msg_received_pkt;
        send_to_mem_store_request_queue__recv__val = 1'd1;
        if ( send_to_mem_store_request_queue__recv__rdy ) begin
          recv_from_inter_cgra_noc__rdy = 1'd1;
        end
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_LOAD_RESPONSE ) ) begin
        if ( p_recv_from_inter_cgra_noc__msg.dst_tile_id == TILE_ID_W'( num_tiles_at_update_received_msg ) ) begin
          recv_from_inter_cgra_noc__rdy = send_to_cpu_pkt_queue__recv__rdy;
          send_to_cpu_pkt_queue__recv__val = 1'd1;
          send_to_cpu_pkt_queue__recv__msg = { p_recv_from_inter_cgra_noc__msg.src_tile_id, p_recv_from_inter_cgra_noc__msg.dst_tile_id, p_recv_from_inter_cgra_noc__msg.src, p_recv_from_inter_cgra_noc__msg.dst, p_recv_from_inter_cgra_noc__msg.src_x, p_recv_from_inter_cgra_noc__msg.src_y, p_recv_from_inter_cgra_noc__msg.dst_x, p_recv_from_inter_cgra_noc__msg.dst_y, 8'd0, 1'd0, p_recv_from_inter_cgra_noc__msg.payload };
        end
        else begin
          recv_from_inter_cgra_noc__rdy = send_to_tile_load_response_queue__recv__rdy;
          send_to_tile_load_response_queue__recv__msg = update_received_msg_received_pkt;
          send_to_tile_load_response_queue__recv__val = 1'd1;
        end
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_COMPLETE ) ) begin
        recv_from_inter_cgra_noc__rdy = send_to_cpu_pkt_queue__recv__rdy;
        send_to_cpu_pkt_queue__recv__val = 1'd1;
        send_to_cpu_pkt_queue__recv__msg = { p_recv_from_inter_cgra_noc__msg.src_tile_id, p_recv_from_inter_cgra_noc__msg.dst_tile_id, p_recv_from_inter_cgra_noc__msg.src, p_recv_from_inter_cgra_noc__msg.dst, p_recv_from_inter_cgra_noc__msg.src_x, p_recv_from_inter_cgra_noc__msg.src_y, p_recv_from_inter_cgra_noc__msg.dst_x, p_recv_from_inter_cgra_noc__msg.dst_y, 8'd0, 1'd0, p_recv_from_inter_cgra_noc__msg.payload };
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_LEAF_COUNTER_COMPLETE ) ) begin
        recv_from_inter_cgra_noc__rdy = 1'd1;
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD ) ) begin
        recv_from_inter_cgra_noc__rdy = global_reduce_unit__recv_data__rdy;
        global_reduce_unit__recv_data__val = 1'd1;
        global_reduce_unit__recv_data__msg = p_recv_from_inter_cgra_noc__msg;
      end
      else if ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_COUNT ) ) begin
        recv_from_inter_cgra_noc__rdy = global_reduce_unit__recv_count__rdy;
        global_reduce_unit__recv_count__val = 1'd1;
        global_reduce_unit__recv_count__msg = p_recv_from_inter_cgra_noc__msg;
      end
      else if ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_FU_CROSSBAR ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_TOTAL_CTRL_COUNT ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_COUNT_PER_ITER ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_CTRL_LOWER_BOUND ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONST ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD_RESPONSE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL_RESPONSE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_START_ADDR ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_STRIDE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_STREAMING_LD_END_ADDR ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_PAUSE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_PRESERVE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_RESUME ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_RECORD_PHI_ADDR ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_TERMINATE ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_LAUNCH ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_LOWER ) ) ) | ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_UPPER ) ) ) | ( ( p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'( CMD_CONFIG_LOOP_STEP ) ) | (p_recv_from_inter_cgra_noc__msg.payload.cmd == 6'd43) ) ) begin
        recv_from_inter_cgra_noc__rdy = send_to_ctrl_ring_pkt__rdy;
        send_to_ctrl_ring_pkt__val = recv_from_inter_cgra_noc__val;
        p_send_to_ctrl_ring_pkt__msg = { p_recv_from_inter_cgra_noc__msg.src_tile_id, p_recv_from_inter_cgra_noc__msg.dst_tile_id, p_recv_from_inter_cgra_noc__msg.src, p_recv_from_inter_cgra_noc__msg.dst, p_recv_from_inter_cgra_noc__msg.src_x, p_recv_from_inter_cgra_noc__msg.src_y, p_recv_from_inter_cgra_noc__msg.dst_x, p_recv_from_inter_cgra_noc__msg.dst_y, 8'd0, 1'd0, p_recv_from_inter_cgra_noc__msg.payload };
      end
    end
    if ( 1'( has_dma_ports_at_update_received_msg ) & dma_done__val ) begin
      dma_done__rdy = send_to_cpu_pkt_queue__recv__rdy;
      send_to_cpu_pkt_queue__recv__val = 1'd1;
      send_to_cpu_pkt_queue__recv__msg = { TILE_ID_W'( num_tiles_at_update_received_msg ), TILE_ID_W'( num_tiles_at_update_received_msg ), cgra_id, cgra_id, idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], idTo2d_x_lut[cgra_id], idTo2d_y_lut[cgra_id], p_dma_done__msg.dma_tag, 1'd0, { 6'( CMD_DMA_DONE ), { { { (DATA_W-8) { 1'b0 } }, p_dma_done__msg.dma_tag }, 1'd1, 1'd0, 1'd0 }, GLOBAL_ADDR_W'(0), CTRL_BITS'(0), CTRL_ADDR_W'(0) } };
    end
  end

  always_comb begin : update_sending_to_noc_msg
    send_to_inter_cgra_noc__val = crossbar__send__val[1'd0];
    crossbar__send__rdy[1'd0] = send_to_inter_cgra_noc__rdy;
    p_send_to_inter_cgra_noc__msg = crossbar__send__msg[1'd0].inter_cgra_pkt;
    if ( ( crossbar__send__msg[1'd0].inter_cgra_pkt.payload.cmd == 6'( CMD_LOAD_REQUEST ) ) | ( crossbar__send__msg[1'd0].inter_cgra_pkt.payload.cmd == 6'( CMD_STORE_REQUEST ) ) ) begin
      p_send_to_inter_cgra_noc__msg.dst = addr_dst_id;
      p_send_to_inter_cgra_noc__msg.dst_x = idTo2d_x_lut[addr_dst_id];
      p_send_to_inter_cgra_noc__msg.dst_y = idTo2d_y_lut[addr_dst_id];
    end
  end

  always_ff @(posedge clk) begin : update_dma_cmd_regs
    if ( reset ) begin
      dma_dram_addr_lo <= 32'd0;
      dma_dram_addr_hi <= 32'd0;
      dma_spm_addr <= 32'd0;
      dma_bytes <= 32'd0;
      dma_tag <= 8'd0;
    end
    else if ( 1'( has_dma_ports_at_update_dma_cmd_regs ) ) begin
      update_dma_cmd_regs_cpu_payload = recv_from_cpu_pkt_queue__send__msg.payload;
      update_dma_cmd_regs_cpu_cmd = update_dma_cmd_regs_cpu_payload.cmd;
      update_dma_cmd_regs_cpu_data = update_dma_cmd_regs_cpu_payload.data.payload;
      if ( recv_from_cpu_pkt_queue__send__val & recv_from_cpu_pkt_queue__send__rdy ) begin
        if ( update_dma_cmd_regs_cpu_cmd == 6'( CMD_DMA_CONFIG_DRAM_ADDR_LO ) ) begin
          dma_dram_addr_lo <= 32'( update_dma_cmd_regs_cpu_data );
        end
        else if ( update_dma_cmd_regs_cpu_cmd == 6'( CMD_DMA_CONFIG_DRAM_ADDR_HI ) ) begin
          dma_dram_addr_hi <= 32'( update_dma_cmd_regs_cpu_data );
        end
        else if ( update_dma_cmd_regs_cpu_cmd == 6'( CMD_DMA_CONFIG_SPM_ADDR ) ) begin
          dma_spm_addr <= { { (32-GLOBAL_ADDR_W) { 1'b0 } }, update_dma_cmd_regs_cpu_payload.data_addr };
        end
        else if ( update_dma_cmd_regs_cpu_cmd == 6'( CMD_DMA_CONFIG_BYTES ) ) begin
          dma_bytes <= 32'( update_dma_cmd_regs_cpu_data );
        end
        else if ( update_dma_cmd_regs_cpu_cmd == 6'( CMD_DMA_CONFIG_TAG ) ) begin
          dma_tag <= 8'(update_dma_cmd_regs_cpu_data);
        end
      end
    end
  end

  assign recv_from_tile_load_request_pkt_queue__clk = clk;
  assign recv_from_tile_load_request_pkt_queue__reset = reset;
  assign recv_from_tile_load_response_pkt_queue__clk = clk;
  assign recv_from_tile_load_response_pkt_queue__reset = reset;
  assign recv_from_tile_store_request_pkt_queue__clk = clk;
  assign recv_from_tile_store_request_pkt_queue__reset = reset;
  assign send_to_mem_load_request_queue__clk = clk;
  assign send_to_mem_load_request_queue__reset = reset;
  assign send_to_tile_load_response_queue__clk = clk;
  assign send_to_tile_load_response_queue__reset = reset;
  assign send_to_mem_store_request_queue__clk = clk;
  assign send_to_mem_store_request_queue__reset = reset;
  assign crossbar__clk = clk;
  assign crossbar__reset = reset;
  assign recv_from_cpu_pkt_queue__clk = clk;
  assign recv_from_cpu_pkt_queue__reset = reset;
  assign recv_from_im2col_pkt_queue__clk = clk;
  assign recv_from_im2col_pkt_queue__reset = reset;
  assign send_to_cpu_pkt_queue__clk = clk;
  assign send_to_cpu_pkt_queue__reset = reset;
  assign global_reduce_unit__clk = clk;
  assign global_reduce_unit__reset = reset;
  for (genvar id=0; id<NUM_CGRAS; id++) begin : address_mapping
    assign addr2controller_lut[id] = CUSTOM_ADDR_MAP ? ADDR_MAP[id*CGRA_ID_W+:CGRA_ID_W] : CGRA_ID_W'(id);
  end
  for (genvar id=0; id<NUM_CGRAS; id++) begin : coordinates
    assign idTo2d_x_lut[id] = CUSTOM_COORD_MAP ? COORD_X_MAP[id*CGRA_X_W+:CGRA_X_W] : CGRA_X_W'(id%MULTI_COLS);
    assign idTo2d_y_lut[id] = CUSTOM_COORD_MAP ? COORD_Y_MAP[id*CGRA_Y_W+:CGRA_Y_W] : CGRA_Y_W'(id/MULTI_COLS);
  end
  assign recv_from_tile_load_request_pkt_queue__recv__msg = p_recv_from_tile_load_request_pkt__msg;
  assign recv_from_tile_load_request_pkt__rdy = recv_from_tile_load_request_pkt_queue__recv__rdy;
  assign recv_from_tile_load_request_pkt_queue__recv__val = recv_from_tile_load_request_pkt__val;
  assign recv_from_tile_load_response_pkt_queue__recv__msg = p_recv_from_tile_load_response_pkt__msg;
  assign recv_from_tile_load_response_pkt__rdy = recv_from_tile_load_response_pkt_queue__recv__rdy;
  assign recv_from_tile_load_response_pkt_queue__recv__val = recv_from_tile_load_response_pkt__val;
  assign recv_from_tile_store_request_pkt_queue__recv__msg = p_recv_from_tile_store_request_pkt__msg;
  assign recv_from_tile_store_request_pkt__rdy = recv_from_tile_store_request_pkt_queue__recv__rdy;
  assign recv_from_tile_store_request_pkt_queue__recv__val = recv_from_tile_store_request_pkt__val;
  assign p_send_to_sram_load_request_from_noc__msg = send_to_mem_load_request_queue__send__msg;
  assign send_to_mem_load_request_queue__send__rdy = send_to_sram_load_request_from_noc__rdy;
  assign send_to_sram_load_request_from_noc__val = send_to_mem_load_request_queue__send__val;
  assign p_send_to_tile_load_response__msg = send_to_tile_load_response_queue__send__msg;
  assign send_to_tile_load_response_queue__send__rdy = send_to_tile_load_response__rdy;
  assign send_to_tile_load_response__val = send_to_tile_load_response_queue__send__val;
  assign p_send_to_sram_store_request_from_noc__msg = send_to_mem_store_request_queue__send__msg;
  assign send_to_mem_store_request_queue__send__rdy = send_to_sram_store_request_from_noc__rdy;
  assign send_to_sram_store_request_from_noc__val = send_to_mem_store_request_queue__send__val;
  assign recv_from_cpu_pkt_queue__recv__msg = p_recv_from_cpu_pkt__msg;
  assign recv_from_cpu_pkt__rdy = recv_from_cpu_pkt_queue__recv__rdy;
  assign recv_from_cpu_pkt_queue__recv__val = recv_from_cpu_pkt__val;
  assign p_send_to_cpu_pkt__msg = send_to_cpu_pkt_queue__send__msg;
  assign send_to_cpu_pkt_queue__send__rdy = send_to_cpu_pkt__rdy;
  assign send_to_cpu_pkt__val = send_to_cpu_pkt_queue__send__val;
  assign recv_from_im2col_pkt_queue__recv__val = HAS_IM2COL ? recv_from_im2col_pkt__val : 1'b0;
  assign recv_from_im2col_pkt_queue__recv__msg = HAS_IM2COL ? recv_from_im2col_pkt__msg : '0;
  if (HAS_IM2COL) assign recv_from_im2col_pkt__rdy = recv_from_im2col_pkt_queue__recv__rdy;

endmodule
