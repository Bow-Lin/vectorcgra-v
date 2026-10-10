`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
// Homogeneous arrays with the original host-at-CGRA0 and physical mesh links.
// Ring profiles use MULTI_ROWS=1, as in the baseline's legal packet geometry.
module cgra_multi #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS,
  parameter int TOPOLOGY=0, TILE_VARIANT=0
) (
  input logic clk, reset,
  input logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg,
  input logic recv_from_cpu_pkt__val,
  output logic recv_from_cpu_pkt__rdy,
  output logic [HOST_BITS-1:0] send_to_cpu_pkt__msg,
  output logic send_to_cpu_pkt__val,
  input logic send_to_cpu_pkt__rdy
);
  logic [NOC_BITS-1:0] noc_recv_msg[0:NUM_CGRAS-1], noc_send_msg[0:NUM_CGRAS-1];
  logic noc_recv_val[0:NUM_CGRAS-1], noc_recv_rdy[0:NUM_CGRAS-1];
  logic noc_send_val[0:NUM_CGRAS-1], noc_send_rdy[0:NUM_CGRAS-1];
  localparam int NOC_DST_Y_LSB=PAYLOAD_BITS+10+MEM_PORT_W+2*TILE_ID_W;
  localparam int NOC_DST_X_LSB=NOC_DST_Y_LSB+CGRA_Y_W;
  localparam int NOC_DST_LSB=NOC_BITS-2*CGRA_ID_W;
  initial begin
    if(HAS_DMA || HAS_IM2COL) $fatal(1,"Multi-CGRA wrappers have no peripheral ports; use cgra_system for external peripheral integration");
    if(TOPOLOGY<0 || TOPOLOGY>1) $fatal(1,"TOPOLOGY must be 0 Mesh or 1 Ring");
    if(TOPOLOGY==0 && (MULTI_ROWS<2 || MULTI_COLS<2)) $fatal(1,"ac96 Mesh requires at least two rows and columns");
    if(TOPOLOGY==1 && (MULTI_ROWS!=1 || MULTI_COLS<2)) $fatal(1,"ac96 Ring packet geometry requires one row and at least two CGRAs");
    if(64'(NUM_CGRAS)*64'(NUM_BANKS)*64'(BANK_DEPTH)>(64'd1<<GLOBAL_ADDR_W)) $fatal(1,"Global memory cannot contain all CGRA address ranges");
  end
  if(TOPOLOGY==0) begin : mesh
    cgra_inter_mesh #(.LEGACY_PYTHON(NOC_LEGACY_PYTHON),.WIDTH(NOC_BITS),.COLS(MULTI_COLS),.ROWS(MULTI_ROWS),
      .DST_X_LSB(NOC_DST_X_LSB),.DST_Y_LSB(NOC_DST_Y_LSB),.X_WIDTH(CGRA_X_W),.Y_WIDTH(CGRA_Y_W)) network (
      .clk,.reset,.recv_msg(noc_recv_msg),.recv_val(noc_recv_val),.recv_rdy(noc_recv_rdy),
      .send_msg(noc_send_msg),.send_val(noc_send_val),.send_rdy(noc_send_rdy)
    );
  end else begin : ring
    cgra_inter_ring #(.LEGACY_PYTHON(NOC_LEGACY_PYTHON),.WIDTH(NOC_BITS),.NODES(NUM_CGRAS),.DST_LSB(NOC_DST_LSB),
      .DST_WIDTH(CGRA_ID_W),.VC_LSB(PAYLOAD_BITS),.VC_WIDTH(2)) network (
      .clk,.reset,.recv_msg(noc_recv_msg),.recv_val(noc_recv_val),.recv_rdy(noc_recv_rdy),
      .send_msg(noc_send_msg),.send_val(noc_send_val),.send_rdy(noc_send_rdy)
    );
  end
  function automatic int address_slot(input int id);
    address_slot=id;
    if(CUSTOM_ADDR_MAP) begin
      for(int slot=0;slot<NUM_CGRAS;slot++)
        if(ADDR_MAP[slot*CGRA_ID_W+:CGRA_ID_W]==CGRA_ID_W'(id)) address_slot=slot;
    end
  endfunction
  logic [DATA_BITS-1:0] recv_north_msg[0:NUM_CGRAS-1][0:COLS-1];
  logic recv_north_val[0:NUM_CGRAS-1][0:COLS-1], recv_north_rdy[0:NUM_CGRAS-1][0:COLS-1];
  logic [DATA_BITS-1:0] send_north_msg[0:NUM_CGRAS-1][0:COLS-1];
  logic send_north_val[0:NUM_CGRAS-1][0:COLS-1], send_north_rdy[0:NUM_CGRAS-1][0:COLS-1];
  logic [DATA_BITS-1:0] recv_south_msg[0:NUM_CGRAS-1][0:COLS-1];
  logic recv_south_val[0:NUM_CGRAS-1][0:COLS-1], recv_south_rdy[0:NUM_CGRAS-1][0:COLS-1];
  logic [DATA_BITS-1:0] send_south_msg[0:NUM_CGRAS-1][0:COLS-1];
  logic send_south_val[0:NUM_CGRAS-1][0:COLS-1], send_south_rdy[0:NUM_CGRAS-1][0:COLS-1];
  logic [DATA_BITS-1:0] recv_east_msg[0:NUM_CGRAS-1][0:ROWS-1];
  logic recv_east_val[0:NUM_CGRAS-1][0:ROWS-1], recv_east_rdy[0:NUM_CGRAS-1][0:ROWS-1];
  logic [DATA_BITS-1:0] send_east_msg[0:NUM_CGRAS-1][0:ROWS-1];
  logic send_east_val[0:NUM_CGRAS-1][0:ROWS-1], send_east_rdy[0:NUM_CGRAS-1][0:ROWS-1];
  logic [DATA_BITS-1:0] recv_west_msg[0:NUM_CGRAS-1][0:ROWS-1];
  logic recv_west_val[0:NUM_CGRAS-1][0:ROWS-1], recv_west_rdy[0:NUM_CGRAS-1][0:ROWS-1];
  logic [DATA_BITS-1:0] send_west_msg[0:NUM_CGRAS-1][0:ROWS-1];
  logic send_west_val[0:NUM_CGRAS-1][0:ROWS-1], send_west_rdy[0:NUM_CGRAS-1][0:ROWS-1];
  for(genvar c=0;c<NUM_CGRAS;c++) begin : cgras
    localparam int X=c%MULTI_COLS,Y=c/MULTI_COLS;
    logic host_recv_rdy, host_send_val;
    logic [HOST_BITS-1:0] host_send_msg;
    if(c==0) begin : host_connection
      assign recv_from_cpu_pkt__rdy=host_recv_rdy;
      assign send_to_cpu_pkt__msg=host_send_msg;
      assign send_to_cpu_pkt__val=host_send_val;
    end
    cgra_system #(`CGRA_PROFILE_BIND,`CGRA_FU_BIND,.IS_MULTI(1),.TILE_VARIANT(TILE_VARIANT)) cgra (
      .clk,.reset,.cgra_id(CGRA_ID_W'(c)),
      .address_lower(GLOBAL_ADDR_W'(address_slot(c)*NUM_BANKS*BANK_DEPTH)),
      .address_upper(GLOBAL_ADDR_W'((address_slot(c)+1)*NUM_BANKS*BANK_DEPTH-1)),
      .recv_from_cpu_pkt__msg(c==0 ? recv_from_cpu_pkt__msg : HOST_BITS'(0)),
      .recv_from_cpu_pkt__val(c==0 ? recv_from_cpu_pkt__val : 1'b0),.recv_from_cpu_pkt__rdy(host_recv_rdy),
      .send_to_cpu_pkt__msg(host_send_msg),.send_to_cpu_pkt__val(host_send_val),
      .send_to_cpu_pkt__rdy(c==0 ? send_to_cpu_pkt__rdy : 1'b0),
      .recv_from_inter_cgra_noc__msg(noc_send_msg[c]),.recv_from_inter_cgra_noc__val(noc_send_val[c]),.recv_from_inter_cgra_noc__rdy(noc_send_rdy[c]),
      .send_to_inter_cgra_noc__msg(noc_recv_msg[c]),.send_to_inter_cgra_noc__val(noc_recv_val[c]),.send_to_inter_cgra_noc__rdy(noc_recv_rdy[c]),
      .dma_cmd__msg(),.dma_cmd__val(),.dma_cmd__rdy(1'b0),.dma_done__msg(8'd0),.dma_done__val(1'b0),.dma_done__rdy(),
      .recv_from_dma_spm_rd_req__msg(32'd0),.recv_from_dma_spm_rd_req__val(1'b0),.recv_from_dma_spm_rd_req__rdy(),
      .recv_from_dma_spm_wr_req__msg(68'd0),.recv_from_dma_spm_wr_req__val(1'b0),.recv_from_dma_spm_wr_req__rdy(),
      .send_to_dma_spm_rd_resp__msg(),.send_to_dma_spm_rd_resp__val(),.send_to_dma_spm_rd_resp__rdy(1'b0),
      .recv_from_im2col_pkt__msg(HOST_BITS'(0)),.recv_from_im2col_pkt__val(1'b0),.recv_from_im2col_pkt__rdy(),
      .send_to_im2col_engine_pkt__msg(),.send_to_im2col_engine_pkt__val(),.send_to_im2col_engine_pkt__rdy(1'b0),
      .recv_data_on_boundary_north__msg(recv_north_msg[c]),
      .recv_data_on_boundary_north__val(recv_north_val[c]),
      .recv_data_on_boundary_north__rdy(recv_north_rdy[c]),
      .send_data_on_boundary_north__msg(send_north_msg[c]),
      .send_data_on_boundary_north__val(send_north_val[c]),
      .send_data_on_boundary_north__rdy(send_north_rdy[c]),
      .recv_data_on_boundary_south__msg(recv_south_msg[c]),
      .recv_data_on_boundary_south__val(recv_south_val[c]),
      .recv_data_on_boundary_south__rdy(recv_south_rdy[c]),
      .send_data_on_boundary_south__msg(send_south_msg[c]),
      .send_data_on_boundary_south__val(send_south_val[c]),
      .send_data_on_boundary_south__rdy(send_south_rdy[c]),
      .recv_data_on_boundary_east__msg(recv_east_msg[c]),
      .recv_data_on_boundary_east__val(recv_east_val[c]),
      .recv_data_on_boundary_east__rdy(recv_east_rdy[c]),
      .send_data_on_boundary_east__msg(send_east_msg[c]),
      .send_data_on_boundary_east__val(send_east_val[c]),
      .send_data_on_boundary_east__rdy(send_east_rdy[c]),
      .recv_data_on_boundary_west__msg(recv_west_msg[c]),
      .recv_data_on_boundary_west__val(recv_west_val[c]),
      .recv_data_on_boundary_west__rdy(recv_west_rdy[c]),
      .send_data_on_boundary_west__msg(send_west_msg[c]),
      .send_data_on_boundary_west__val(send_west_val[c]),
      .send_data_on_boundary_west__rdy(send_west_rdy[c])
    );
    for(genvar p=0;p<COLS;p++) begin : north_boundary
      if(Y<MULTI_ROWS-1) begin : connected
        assign recv_north_msg[c][p]=send_south_msg[c+MULTI_COLS][p];
        assign recv_north_val[c][p]=send_south_val[c+MULTI_COLS][p];
        assign send_north_rdy[c][p]=recv_south_rdy[c+MULTI_COLS][p];
      end else begin : grounded
        assign recv_north_msg[c][p]='0;
        assign recv_north_val[c][p]=1'b0;
        assign send_north_rdy[c][p]=1'b0;
      end
    end
    for(genvar p=0;p<COLS;p++) begin : south_boundary
      if(Y>0) begin : connected
        assign recv_south_msg[c][p]=send_north_msg[c-MULTI_COLS][p];
        assign recv_south_val[c][p]=send_north_val[c-MULTI_COLS][p];
        assign send_south_rdy[c][p]=recv_north_rdy[c-MULTI_COLS][p];
      end else begin : grounded
        assign recv_south_msg[c][p]='0;
        assign recv_south_val[c][p]=1'b0;
        assign send_south_rdy[c][p]=1'b0;
      end
    end
    for(genvar p=0;p<ROWS;p++) begin : east_boundary
      if(X<MULTI_COLS-1) begin : connected
        assign recv_east_msg[c][p]=send_west_msg[c+1][p];
        assign recv_east_val[c][p]=send_west_val[c+1][p];
        assign send_east_rdy[c][p]=recv_west_rdy[c+1][p];
      end else begin : grounded
        assign recv_east_msg[c][p]='0;
        assign recv_east_val[c][p]=1'b0;
        assign send_east_rdy[c][p]=1'b0;
      end
    end
    for(genvar p=0;p<ROWS;p++) begin : west_boundary
      if(X>0) begin : connected
        assign recv_west_msg[c][p]=send_east_msg[c-1][p];
        assign recv_west_val[c][p]=send_east_val[c-1][p];
        assign send_west_rdy[c][p]=recv_east_rdy[c-1][p];
      end else begin : grounded
        assign recv_west_msg[c][p]='0;
        assign recv_west_val[c][p]=1'b0;
        assign send_west_rdy[c][p]=1'b0;
      end
    end
  end
endmodule
