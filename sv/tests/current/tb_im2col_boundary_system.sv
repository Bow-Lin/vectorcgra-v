`timescale 1ns/1ps
module tb_im2col_boundary_system #(parameter bit LEGACY_SYSTEM=0);
  localparam int HOST_BITS=190,CTRL_BITS=119,PAYLOAD_BITS=6+35+6+CTRL_BITS+3;
  int cycles=0,done_count=0,load_count=0,blocked_cycles=0;
  logic[5:0] address_lower=0;
  logic[5:0] address_upper=0;
  logic[0:0] cgra_id=0;
  logic[0:0] clk=0;
  logic[0:0] reset=0;
  logic[34:0] recv_data_on_boundary_east__msg [0:1];
  logic[0:0] recv_data_on_boundary_east__rdy [0:1];
  logic[0:0] recv_data_on_boundary_east__val [0:1];
  logic[34:0] recv_data_on_boundary_north__msg [0:1];
  logic[0:0] recv_data_on_boundary_north__rdy [0:1];
  logic[0:0] recv_data_on_boundary_north__val [0:1];
  logic[34:0] recv_data_on_boundary_south__msg [0:1];
  logic[0:0] recv_data_on_boundary_south__rdy [0:1];
  logic[0:0] recv_data_on_boundary_south__val [0:1];
  logic[34:0] recv_data_on_boundary_west__msg [0:1];
  logic[0:0] recv_data_on_boundary_west__rdy [0:1];
  logic[0:0] recv_data_on_boundary_west__val [0:1];
  logic[189:0] recv_from_cpu_pkt__msg=0;
  logic[0:0] recv_from_cpu_pkt__rdy;
  logic[0:0] recv_from_cpu_pkt__val=0;
  logic[34:0] send_data_on_boundary_east__msg [0:1];
  logic[0:0] send_data_on_boundary_east__rdy [0:1];
  logic[0:0] send_data_on_boundary_east__val [0:1];
  logic[34:0] send_data_on_boundary_north__msg [0:1];
  logic[0:0] send_data_on_boundary_north__rdy [0:1];
  logic[0:0] send_data_on_boundary_north__val [0:1];
  logic[34:0] send_data_on_boundary_south__msg [0:1];
  logic[0:0] send_data_on_boundary_south__rdy [0:1];
  logic[0:0] send_data_on_boundary_south__val [0:1];
  logic[34:0] send_data_on_boundary_west__msg [0:1];
  logic[0:0] send_data_on_boundary_west__rdy [0:1];
  logic[0:0] send_data_on_boundary_west__val [0:1];
  logic[189:0] send_to_cpu_pkt__msg;
  logic[0:0] send_to_cpu_pkt__rdy=0;
  logic[0:0] send_to_cpu_pkt__val;
`ifdef MEMORY_SYSTEM_POST_SYNTH
  im2col_system_netlist dut (
    .address_lower(address_lower),
    .address_upper(address_upper),
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .recv_data_on_boundary_east__msg({recv_data_on_boundary_east__msg[0],recv_data_on_boundary_east__msg[1]}),
    .recv_data_on_boundary_east__rdy({recv_data_on_boundary_east__rdy[0],recv_data_on_boundary_east__rdy[1]}),
    .recv_data_on_boundary_east__val({recv_data_on_boundary_east__val[0],recv_data_on_boundary_east__val[1]}),
    .recv_data_on_boundary_north__msg({recv_data_on_boundary_north__msg[0],recv_data_on_boundary_north__msg[1]}),
    .recv_data_on_boundary_north__rdy({recv_data_on_boundary_north__rdy[0],recv_data_on_boundary_north__rdy[1]}),
    .recv_data_on_boundary_north__val({recv_data_on_boundary_north__val[0],recv_data_on_boundary_north__val[1]}),
    .recv_data_on_boundary_south__msg({recv_data_on_boundary_south__msg[0],recv_data_on_boundary_south__msg[1]}),
    .recv_data_on_boundary_south__rdy({recv_data_on_boundary_south__rdy[0],recv_data_on_boundary_south__rdy[1]}),
    .recv_data_on_boundary_south__val({recv_data_on_boundary_south__val[0],recv_data_on_boundary_south__val[1]}),
    .recv_data_on_boundary_west__msg({recv_data_on_boundary_west__msg[0],recv_data_on_boundary_west__msg[1]}),
    .recv_data_on_boundary_west__rdy({recv_data_on_boundary_west__rdy[0],recv_data_on_boundary_west__rdy[1]}),
    .recv_data_on_boundary_west__val({recv_data_on_boundary_west__val[0],recv_data_on_boundary_west__val[1]}),
    .recv_from_cpu_pkt__msg(recv_from_cpu_pkt__msg),
    .recv_from_cpu_pkt__rdy(recv_from_cpu_pkt__rdy),
    .recv_from_cpu_pkt__val(recv_from_cpu_pkt__val),
    .send_data_on_boundary_east__msg({send_data_on_boundary_east__msg[0],send_data_on_boundary_east__msg[1]}),
    .send_data_on_boundary_east__rdy({send_data_on_boundary_east__rdy[0],send_data_on_boundary_east__rdy[1]}),
    .send_data_on_boundary_east__val({send_data_on_boundary_east__val[0],send_data_on_boundary_east__val[1]}),
    .send_data_on_boundary_north__msg({send_data_on_boundary_north__msg[0],send_data_on_boundary_north__msg[1]}),
    .send_data_on_boundary_north__rdy({send_data_on_boundary_north__rdy[0],send_data_on_boundary_north__rdy[1]}),
    .send_data_on_boundary_north__val({send_data_on_boundary_north__val[0],send_data_on_boundary_north__val[1]}),
    .send_data_on_boundary_south__msg({send_data_on_boundary_south__msg[0],send_data_on_boundary_south__msg[1]}),
    .send_data_on_boundary_south__rdy({send_data_on_boundary_south__rdy[0],send_data_on_boundary_south__rdy[1]}),
    .send_data_on_boundary_south__val({send_data_on_boundary_south__val[0],send_data_on_boundary_south__val[1]}),
    .send_data_on_boundary_west__msg({send_data_on_boundary_west__msg[0],send_data_on_boundary_west__msg[1]}),
    .send_data_on_boundary_west__rdy({send_data_on_boundary_west__rdy[0],send_data_on_boundary_west__rdy[1]}),
    .send_data_on_boundary_west__val({send_data_on_boundary_west__val[0],send_data_on_boundary_west__val[1]}),
    .send_to_cpu_pkt__msg(send_to_cpu_pkt__msg),
    .send_to_cpu_pkt__rdy(send_to_cpu_pkt__rdy),
    .send_to_cpu_pkt__val(send_to_cpu_pkt__val),
    .recv_from_inter_cgra_noc__msg('0),
    .recv_from_inter_cgra_noc__val(1'b0),
    .recv_from_inter_cgra_noc__rdy(),
    .send_to_inter_cgra_noc__msg(),
    .send_to_inter_cgra_noc__val(),
    .send_to_inter_cgra_noc__rdy(1'b0)
  );
`else
  cgra_integrated_im2col #(
    .PERIPHERAL_LEGACY_PYTHON(LEGACY_SYSTEM),.MEMORY_LEGACY_PYTHON(LEGACY_SYSTEM),
    .COLS(2),
    .ROWS(2),
    .DATA_W(32),
    .TILE_PORTS(4),
    .CTRL_DEPTH(8),
    .REG_DEPTH(16),
    .BANK_DEPTH(16),
    .NUM_BANKS(4),
    .GLOBAL_ADDR_W(6),
    .NUM_CTRL(1),
    .TOTAL_STEPS(1),
    .HAS_DMA(0),
    .HAS_IM2COL(1),
    .FU_COUNT(4),
    .SCRATCH_DEPTH(64),
    .FU_KINDS(32'h03020100),
    .PRELOAD_IMAGE(2048'h19b0000018a0000017900000168000001570000014600000135000001240000011300000102000000f1000000e0000000cf000000be000000ad0000009c0000008b0000007a00000069000000580000004700000036000000250000001400000003)) dut (
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
    .recv_from_cpu_pkt__rdy(recv_from_cpu_pkt__rdy),
    .recv_from_cpu_pkt__val(recv_from_cpu_pkt__val),
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
    .recv_from_inter_cgra_noc__msg('0),
    .recv_from_inter_cgra_noc__val(1'b0),
    .recv_from_inter_cgra_noc__rdy(),
    .send_to_inter_cgra_noc__msg(),
    .send_to_inter_cgra_noc__val(),
    .send_to_inter_cgra_noc__rdy(1'b0)
  );
`endif
  function automatic logic[HOST_BITS-1:0] packet(input int cmd,input logic[31:0] value,input int addr);
    logic[HOST_BITS-1:0] p;p=0;p[3+CTRL_BITS+:6]=6'(addr);
    p[3+CTRL_BITS+6+:35]={value,3'b100};p[PAYLOAD_BITS-6+:6]=6'(cmd);return p;
  endfunction
  function automatic logic[31:0] word_pattern(input int i);return 32'h12340011+32'(i)*32'h10023;endfunction
  logic[31:0] expected_load[0:63];int expected_loads=0;int expected_tag=0;
  task automatic sample_cpu;
    if(!reset && !recv_from_cpu_pkt__rdy)blocked_cycles++;
    if(!reset && send_to_cpu_pkt__val && send_to_cpu_pkt__rdy)begin
      if(send_to_cpu_pkt__msg[PAYLOAD_BITS-6+:6]==51)begin
        if(send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]!==32'(expected_tag) || send_to_cpu_pkt__msg[PAYLOAD_BITS+1+:8]!==8'(expected_tag))
          $fatal(1,"Integrated DMA done tag");done_count++;
      end else if(send_to_cpu_pkt__msg[PAYLOAD_BITS-6+:6]==11)begin
        if(load_count>=expected_loads || send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]!==(expected_load[load_count]^32'($test$plusargs("EXPECT_FAILURE") && load_count==0)))
          $fatal(1,"Integrated load %0d expected=%h got=%h",load_count,expected_load[load_count],send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]);
        load_count++;
      end else $fatal(1,"Unexpected CPU response command");
    end
  endtask


  task automatic step;
    send_to_cpu_pkt__rdy=cycles%7<4;
    #3;sample_cpu();#2;clk=1;#5;clk=0;cycles++;
    if(cycles>10000)$fatal(1,"Integrated Im2col TIMEOUT");
  endtask


  task automatic command(input int cmd,input logic[31:0] data,input int addr);
    bit accepted;accepted=0;recv_from_cpu_pkt__val=1;recv_from_cpu_pkt__msg=packet(cmd,data,addr);
    while(!accepted)begin #1;accepted=recv_from_cpu_pkt__rdy;step();end
    recv_from_cpu_pkt__val=0;
  endtask

  integer total_loads=0;
  task automatic run_and_read(input integer h,w,kh,kw,lg,base,input bit configure_again=1);
    integer oh,ow,index;
    load_count=0;expected_loads=kh*kw*(((h-kh)>>lg)+1)*(((w-kw)>>lg)+1);index=0;
    oh=((h-kh)>>lg)+1;ow=((w-kw)>>lg)+1;
    for(integer ky=0;ky<kh;ky++)for(integer kx=0;kx<kw;kx++)for(integer oy=0;oy<oh;oy++)for(integer ox=0;ox<ow;ox++)begin
      expected_load[index]=32'(3+17*(((oy<<lg)+ky)*w+(ox<<lg)+kx));index++;
    end
    if(configure_again)begin
      command(53,32'(h),0);command(54,32'(w),0);command(55,32'(kh),0);command(56,32'(kw),0);command(57,32'(lg),0);command(58,0,base);
    end
    command(52,0,0);
    // Immediately present reads: the integrated launch boundary must serialize them.
    for(integer i=0;i<expected_loads;i++)command(10,0,base+i);
    while(load_count<expected_loads)step();repeat(12)step();total_loads+=load_count;
  endtask
  initial begin
    for(int i=0;i<2;i++)recv_data_on_boundary_east__msg[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_east__val[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_north__msg[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_north__val[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_south__msg[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_south__val[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_west__msg[i]=0;
    for(int i=0;i<2;i++)recv_data_on_boundary_west__val[i]=0;
    for(int i=0;i<2;i++)send_data_on_boundary_east__rdy[i]=0;
    for(int i=0;i<2;i++)send_data_on_boundary_north__rdy[i]=0;
    for(int i=0;i<2;i++)send_data_on_boundary_south__rdy[i]=0;
    for(int i=0;i<2;i++)send_data_on_boundary_west__rdy[i]=0;

    address_lower=0;address_upper=63;reset=1;repeat(3)step();reset=0;step();
    run_and_read(3,3,2,2,0,8);
    run_and_read(3,3,2,2,0,8,0); // Relaunch directly while previous DONE remains asserted.
    run_and_read(5,5,2,2,1,0);
    // Abort through the public global reset, then reconfigure and read back.
    command(53,5,0);command(54,5,0);command(55,2,0);command(56,2,0);command(57,1,0);command(58,0,32);command(52,0,0);
    repeat(12)step();reset=1;repeat(3)step();reset=0;step();
    run_and_read(1,1,1,1,0,63);
    if(done_count!=0 || blocked_cycles<32 || total_loads!=49)$fatal(1,"IM2COL_SYSTEM_COVERAGE");
    $display("IM2COL_BOUNDARY_SYSTEM_PASS cycles=%0d loads=%0d CPU_blocked_cycles=%0d",cycles,total_loads,blocked_cycles);$finish;
  end
endmodule
