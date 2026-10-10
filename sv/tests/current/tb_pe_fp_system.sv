`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tb_pe_fp_system #(`CGRA_PROFILE_PARAMETERS,parameter bit LEGACY_FP=0);
  `include "cgra_profile.svh"
  logic [GLOBAL_ADDR_W-1:0] address_lower, address_upper;
  logic [CGRA_ID_W-1:0] cgra_id;
  logic clk, reset;
  logic [DATA_BITS-1:0] recv_data_on_boundary_east__msg [0:ROWS-1];
  logic recv_data_on_boundary_east__rdy [0:ROWS-1];
  logic recv_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_north__msg [0:COLS-1];
  logic recv_data_on_boundary_north__rdy [0:COLS-1];
  logic recv_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_south__msg [0:COLS-1];
  logic recv_data_on_boundary_south__rdy [0:COLS-1];
  logic recv_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_west__msg [0:ROWS-1];
  logic recv_data_on_boundary_west__rdy [0:ROWS-1];
  logic recv_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg;
  logic recv_from_cpu_pkt__rdy;
  logic recv_from_cpu_pkt__val;
  logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg;
  logic recv_from_inter_cgra_noc__rdy;
  logic recv_from_inter_cgra_noc__val;
  logic [DATA_BITS-1:0] send_data_on_boundary_east__msg [0:ROWS-1];
  logic send_data_on_boundary_east__rdy [0:ROWS-1];
  logic send_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_north__msg [0:COLS-1];
  logic send_data_on_boundary_north__rdy [0:COLS-1];
  logic send_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_south__msg [0:COLS-1];
  logic send_data_on_boundary_south__rdy [0:COLS-1];
  logic send_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_west__msg [0:ROWS-1];
  logic send_data_on_boundary_west__rdy [0:ROWS-1];
  logic send_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] send_to_cpu_pkt__msg;
  logic send_to_cpu_pkt__rdy;
  logic send_to_cpu_pkt__val;
  logic [NOC_BITS-1:0] send_to_inter_cgra_noc__msg;
  logic send_to_inter_cgra_noc__rdy;
  logic send_to_inter_cgra_noc__val;
  logic [138:0] dma_cmd__msg;
  logic dma_cmd__val;
  logic dma_cmd__rdy;
  logic [7:0] dma_done__msg;
  logic dma_done__val;
  logic dma_done__rdy;
  logic [31:0] recv_from_dma_spm_rd_req__msg;
  logic recv_from_dma_spm_rd_req__val;
  logic recv_from_dma_spm_rd_req__rdy;
  logic [67:0] recv_from_dma_spm_wr_req__msg;
  logic recv_from_dma_spm_wr_req__val;
  logic recv_from_dma_spm_wr_req__rdy;
  logic [31:0] send_to_dma_spm_rd_resp__msg;
  logic send_to_dma_spm_rd_resp__val;
  logic send_to_dma_spm_rd_resp__rdy;
  logic [HOST_BITS-1:0] recv_from_im2col_pkt__msg;
  logic recv_from_im2col_pkt__val;
  logic recv_from_im2col_pkt__rdy;
  logic [HOST_BITS-1:0] send_to_im2col_engine_pkt__msg;
  logic send_to_im2col_engine_pkt__val;
  logic send_to_im2col_engine_pkt__rdy;
  cgra_system #(`CGRA_PROFILE_BIND,.FP_LEGACY_PYTHON(LEGACY_FP),.FU_COUNT(2),
    .TILE_FU_COUNTS({32'd1,32'd1,32'd2,32'd2}),
    .TILE_FU_KINDS({16'h0003,16'h0003,16'h0003,16'h031c})) dut(.*);
  int cycles=0,injected=0,outputs_seen=0,completions=0,stalls=0;
  host_packet_t packet;
  ctrl_t control;
  data_t value;
  localparam logic [31:0] EXPECTED=LEGACY_FP ? 32'h40000000 : 32'h40400000;
  task automatic tick;
    #5;clk=1;#5;clk=0;cycles++;
    if(cycles>180)$fatal(1,"PE_FP_SYSTEM_TIMEOUT");
  endtask
  task automatic send_packet(input int cmd,input int data,input ctrl_t ctrl);
    packet='0;packet.dst=0;packet.payload.cmd=6'(cmd);packet.payload.data.payload=32'(data);
    packet.payload.data.predicate=1;packet.payload.ctrl=ctrl;
    recv_from_cpu_pkt__msg=packet;recv_from_cpu_pkt__val=1;
    #1;while(!recv_from_cpu_pkt__rdy)begin tick();#1;end
    tick();recv_from_cpu_pkt__val=0;
  endtask
  initial begin
    address_lower=0;
    address_upper=0;
    cgra_id=0;
    clk=0;
    reset=0;
    foreach(recv_data_on_boundary_east__msg[i]) recv_data_on_boundary_east__msg[i]=0;
    foreach(recv_data_on_boundary_east__val[i]) recv_data_on_boundary_east__val[i]=0;
    foreach(recv_data_on_boundary_north__msg[i]) recv_data_on_boundary_north__msg[i]=0;
    foreach(recv_data_on_boundary_north__val[i]) recv_data_on_boundary_north__val[i]=0;
    foreach(recv_data_on_boundary_south__msg[i]) recv_data_on_boundary_south__msg[i]=0;
    foreach(recv_data_on_boundary_south__val[i]) recv_data_on_boundary_south__val[i]=0;
    foreach(recv_data_on_boundary_west__msg[i]) recv_data_on_boundary_west__msg[i]=0;
    foreach(recv_data_on_boundary_west__val[i]) recv_data_on_boundary_west__val[i]=0;
    recv_from_cpu_pkt__msg=0;
    recv_from_cpu_pkt__val=0;
    recv_from_inter_cgra_noc__msg=0;
    recv_from_inter_cgra_noc__val=0;
    foreach(send_data_on_boundary_east__rdy[i]) send_data_on_boundary_east__rdy[i]=0;
    foreach(send_data_on_boundary_north__rdy[i]) send_data_on_boundary_north__rdy[i]=0;
    foreach(send_data_on_boundary_south__rdy[i]) send_data_on_boundary_south__rdy[i]=0;
    foreach(send_data_on_boundary_west__rdy[i]) send_data_on_boundary_west__rdy[i]=0;
    send_to_cpu_pkt__rdy=0;
    send_to_inter_cgra_noc__rdy=0;
    dma_cmd__rdy=0;
    dma_done__msg=0;
    dma_done__val=0;
    recv_from_dma_spm_rd_req__msg=0;
    recv_from_dma_spm_rd_req__val=0;
    recv_from_dma_spm_wr_req__msg=0;
    recv_from_dma_spm_wr_req__val=0;
    send_to_dma_spm_rd_resp__rdy=0;
    recv_from_im2col_pkt__msg=0;
    recv_from_im2col_pkt__val=0;
    send_to_im2col_engine_pkt__rdy=0;
    address_upper=31;reset=1;tick();tick();reset=0;tick();
    control='0;control.operation=39;control.fu_in[0]=1;
    control.routing_xbar_outport[TILE_PORTS]=3;control.fu_xbar_outport[2]=1;
    send_packet(13,32'h3fc00000,'0);send_packet(3,0,control);
    send_packet(7,1,'0);send_packet(8,1,'0);send_packet(0,0,'0);
    while(outputs_seen!=1 || completions!=1)begin
      value='0;value.payload=32'h3fc00000;value.predicate=1;
      recv_data_on_boundary_west__msg[0]=value;recv_data_on_boundary_west__val[0]=injected==0;
      send_data_on_boundary_west__rdy[0]=cycles>45;send_to_cpu_pkt__rdy=cycles>55;
      #2;
      if(recv_data_on_boundary_west__val[0] && recv_data_on_boundary_west__rdy[0])injected++;
      if(send_data_on_boundary_west__val[0])begin
        value=send_data_on_boundary_west__msg[0];
        if(value.payload!==(EXPECTED ^ 32'($test$plusargs("EXPECT_FAILURE"))) || !value.predicate)
          $fatal(1,"PE_FP_SYSTEM_RESULT legacy=%0d expected=%h got=%h",LEGACY_FP,EXPECTED,value.payload);
        if(send_data_on_boundary_west__rdy[0])outputs_seen++;else stalls++;
      end
      if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy)begin
        packet=send_to_cpu_pkt__msg;
        if(packet.payload.cmd!=14 || packet.src!=0)$fatal(1,"PE_FP_SYSTEM_COMPLETION");
        completions++;
      end
      tick();
    end
    if(injected!=1 || outputs_seen!=1 || completions!=1 || stalls<5)$fatal(1,"PE_FP_SYSTEM_COUNTS");
    $display("PE_FP_SYSTEM_PASS legacy=%0d result=%h cycles=%0d stalls=%0d",LEGACY_FP,EXPECTED,cycles,stalls);$finish;
  end
endmodule
