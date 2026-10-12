`timescale 1ns/1ps
module tb_im2col_system;
  localparam int HOST_BITS=190,CTRL_BITS=119,PAYLOAD_BITS=6+35+6+CTRL_BITS+3;
  int cycles=0,done_count=0,load_count=0,blocked_cycles=0;
  logic[5:0] address_lower=0;
  logic[5:0] address_upper=0;
  logic[0:0] cgra_id=0;
  logic[0:0] clk=0;
  logic[0:0] reset=0;
  logic[34:0] recv_data_on_boundary_east__msg [0:1];
  logic[0:0] recv_data_on_boundary_east__rdy [0:1];
  logic[0:0] gold_recv_data_on_boundary_east__rdy [0:1];
  logic[0:0] recv_data_on_boundary_east__val [0:1];
  logic[34:0] recv_data_on_boundary_north__msg [0:1];
  logic[0:0] recv_data_on_boundary_north__rdy [0:1];
  logic[0:0] gold_recv_data_on_boundary_north__rdy [0:1];
  logic[0:0] recv_data_on_boundary_north__val [0:1];
  logic[34:0] recv_data_on_boundary_south__msg [0:1];
  logic[0:0] recv_data_on_boundary_south__rdy [0:1];
  logic[0:0] gold_recv_data_on_boundary_south__rdy [0:1];
  logic[0:0] recv_data_on_boundary_south__val [0:1];
  logic[34:0] recv_data_on_boundary_west__msg [0:1];
  logic[0:0] recv_data_on_boundary_west__rdy [0:1];
  logic[0:0] gold_recv_data_on_boundary_west__rdy [0:1];
  logic[0:0] recv_data_on_boundary_west__val [0:1];
  logic[189:0] recv_from_cpu_pkt__msg=0;
  logic[0:0] recv_from_cpu_pkt__rdy;
  logic[0:0] gold_recv_from_cpu_pkt__rdy;
  logic[0:0] recv_from_cpu_pkt__val=0;
  logic[34:0] send_data_on_boundary_east__msg [0:1];
  logic[34:0] gold_send_data_on_boundary_east__msg [0:1];
  logic[0:0] send_data_on_boundary_east__rdy [0:1];
  logic[0:0] send_data_on_boundary_east__val [0:1];
  logic[0:0] gold_send_data_on_boundary_east__val [0:1];
  logic[34:0] send_data_on_boundary_north__msg [0:1];
  logic[34:0] gold_send_data_on_boundary_north__msg [0:1];
  logic[0:0] send_data_on_boundary_north__rdy [0:1];
  logic[0:0] send_data_on_boundary_north__val [0:1];
  logic[0:0] gold_send_data_on_boundary_north__val [0:1];
  logic[34:0] send_data_on_boundary_south__msg [0:1];
  logic[34:0] gold_send_data_on_boundary_south__msg [0:1];
  logic[0:0] send_data_on_boundary_south__rdy [0:1];
  logic[0:0] send_data_on_boundary_south__val [0:1];
  logic[0:0] gold_send_data_on_boundary_south__val [0:1];
  logic[34:0] send_data_on_boundary_west__msg [0:1];
  logic[34:0] gold_send_data_on_boundary_west__msg [0:1];
  logic[0:0] send_data_on_boundary_west__rdy [0:1];
  logic[0:0] send_data_on_boundary_west__val [0:1];
  logic[0:0] gold_send_data_on_boundary_west__val [0:1];
  logic[189:0] send_to_cpu_pkt__msg;
  logic[189:0] gold_send_to_cpu_pkt__msg;
  logic[0:0] send_to_cpu_pkt__rdy=0;
  logic[0:0] send_to_cpu_pkt__val;
  logic[0:0] gold_send_to_cpu_pkt__val;
  cgra_integrated_im2col #(.PERIPHERAL_LEGACY_PYTHON(1),.MEMORY_LEGACY_PYTHON(1),
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
  Phase4Im2ColSystem gold (
    .address_lower(address_lower),
    .address_upper(address_upper),
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .recv_data_on_boundary_east__msg(recv_data_on_boundary_east__msg),
    .recv_data_on_boundary_east__rdy(gold_recv_data_on_boundary_east__rdy),
    .recv_data_on_boundary_east__val(recv_data_on_boundary_east__val),
    .recv_data_on_boundary_north__msg(recv_data_on_boundary_north__msg),
    .recv_data_on_boundary_north__rdy(gold_recv_data_on_boundary_north__rdy),
    .recv_data_on_boundary_north__val(recv_data_on_boundary_north__val),
    .recv_data_on_boundary_south__msg(recv_data_on_boundary_south__msg),
    .recv_data_on_boundary_south__rdy(gold_recv_data_on_boundary_south__rdy),
    .recv_data_on_boundary_south__val(recv_data_on_boundary_south__val),
    .recv_data_on_boundary_west__msg(recv_data_on_boundary_west__msg),
    .recv_data_on_boundary_west__rdy(gold_recv_data_on_boundary_west__rdy),
    .recv_data_on_boundary_west__val(recv_data_on_boundary_west__val),
    .recv_from_cpu_pkt__msg(recv_from_cpu_pkt__msg),
    .recv_from_cpu_pkt__rdy(gold_recv_from_cpu_pkt__rdy),
    .recv_from_cpu_pkt__val(recv_from_cpu_pkt__val),
    .send_data_on_boundary_east__msg(gold_send_data_on_boundary_east__msg),
    .send_data_on_boundary_east__rdy(send_data_on_boundary_east__rdy),
    .send_data_on_boundary_east__val(gold_send_data_on_boundary_east__val),
    .send_data_on_boundary_north__msg(gold_send_data_on_boundary_north__msg),
    .send_data_on_boundary_north__rdy(send_data_on_boundary_north__rdy),
    .send_data_on_boundary_north__val(gold_send_data_on_boundary_north__val),
    .send_data_on_boundary_south__msg(gold_send_data_on_boundary_south__msg),
    .send_data_on_boundary_south__rdy(send_data_on_boundary_south__rdy),
    .send_data_on_boundary_south__val(gold_send_data_on_boundary_south__val),
    .send_data_on_boundary_west__msg(gold_send_data_on_boundary_west__msg),
    .send_data_on_boundary_west__rdy(send_data_on_boundary_west__rdy),
    .send_data_on_boundary_west__val(gold_send_data_on_boundary_west__val),
    .send_to_cpu_pkt__msg(gold_send_to_cpu_pkt__msg),
    .send_to_cpu_pkt__rdy(send_to_cpu_pkt__rdy),
    .send_to_cpu_pkt__val(gold_send_to_cpu_pkt__val)
  );
  task automatic compare_outputs;
    if({recv_data_on_boundary_east__rdy[0],recv_data_on_boundary_east__rdy[1],recv_data_on_boundary_north__rdy[0],recv_data_on_boundary_north__rdy[1],recv_data_on_boundary_south__rdy[0],recv_data_on_boundary_south__rdy[1],recv_data_on_boundary_west__rdy[0],recv_data_on_boundary_west__rdy[1],recv_from_cpu_pkt__rdy,send_data_on_boundary_east__msg[0],send_data_on_boundary_east__msg[1],send_data_on_boundary_east__val[0],send_data_on_boundary_east__val[1],send_data_on_boundary_north__msg[0],send_data_on_boundary_north__msg[1],send_data_on_boundary_north__val[0],send_data_on_boundary_north__val[1],send_data_on_boundary_south__msg[0],send_data_on_boundary_south__msg[1],send_data_on_boundary_south__val[0],send_data_on_boundary_south__val[1],send_data_on_boundary_west__msg[0],send_data_on_boundary_west__msg[1],send_data_on_boundary_west__val[0],send_data_on_boundary_west__val[1],send_to_cpu_pkt__msg,send_to_cpu_pkt__val}!==({gold_recv_data_on_boundary_east__rdy[0],gold_recv_data_on_boundary_east__rdy[1],gold_recv_data_on_boundary_north__rdy[0],gold_recv_data_on_boundary_north__rdy[1],gold_recv_data_on_boundary_south__rdy[0],gold_recv_data_on_boundary_south__rdy[1],gold_recv_data_on_boundary_west__rdy[0],gold_recv_data_on_boundary_west__rdy[1],gold_recv_from_cpu_pkt__rdy,gold_send_data_on_boundary_east__msg[0],gold_send_data_on_boundary_east__msg[1],gold_send_data_on_boundary_east__val[0],gold_send_data_on_boundary_east__val[1],gold_send_data_on_boundary_north__msg[0],gold_send_data_on_boundary_north__msg[1],gold_send_data_on_boundary_north__val[0],gold_send_data_on_boundary_north__val[1],gold_send_data_on_boundary_south__msg[0],gold_send_data_on_boundary_south__msg[1],gold_send_data_on_boundary_south__val[0],gold_send_data_on_boundary_south__val[1],gold_send_data_on_boundary_west__msg[0],gold_send_data_on_boundary_west__msg[1],gold_send_data_on_boundary_west__val[0],gold_send_data_on_boundary_west__val[1],gold_send_to_cpu_pkt__msg,gold_send_to_cpu_pkt__val} ^ (($test$plusargs("EXPECT_FAILURE") && cycles==20)?1:0)))begin
      if(recv_data_on_boundary_east__rdy[0]!==gold_recv_data_on_boundary_east__rdy[0])$display("recv_data_on_boundary_east__rdy[0]: native=%h gold=%h",recv_data_on_boundary_east__rdy[0],gold_recv_data_on_boundary_east__rdy[0]);
      if(recv_data_on_boundary_east__rdy[1]!==gold_recv_data_on_boundary_east__rdy[1])$display("recv_data_on_boundary_east__rdy[1]: native=%h gold=%h",recv_data_on_boundary_east__rdy[1],gold_recv_data_on_boundary_east__rdy[1]);
      if(recv_data_on_boundary_north__rdy[0]!==gold_recv_data_on_boundary_north__rdy[0])$display("recv_data_on_boundary_north__rdy[0]: native=%h gold=%h",recv_data_on_boundary_north__rdy[0],gold_recv_data_on_boundary_north__rdy[0]);
      if(recv_data_on_boundary_north__rdy[1]!==gold_recv_data_on_boundary_north__rdy[1])$display("recv_data_on_boundary_north__rdy[1]: native=%h gold=%h",recv_data_on_boundary_north__rdy[1],gold_recv_data_on_boundary_north__rdy[1]);
      if(recv_data_on_boundary_south__rdy[0]!==gold_recv_data_on_boundary_south__rdy[0])$display("recv_data_on_boundary_south__rdy[0]: native=%h gold=%h",recv_data_on_boundary_south__rdy[0],gold_recv_data_on_boundary_south__rdy[0]);
      if(recv_data_on_boundary_south__rdy[1]!==gold_recv_data_on_boundary_south__rdy[1])$display("recv_data_on_boundary_south__rdy[1]: native=%h gold=%h",recv_data_on_boundary_south__rdy[1],gold_recv_data_on_boundary_south__rdy[1]);
      if(recv_data_on_boundary_west__rdy[0]!==gold_recv_data_on_boundary_west__rdy[0])$display("recv_data_on_boundary_west__rdy[0]: native=%h gold=%h",recv_data_on_boundary_west__rdy[0],gold_recv_data_on_boundary_west__rdy[0]);
      if(recv_data_on_boundary_west__rdy[1]!==gold_recv_data_on_boundary_west__rdy[1])$display("recv_data_on_boundary_west__rdy[1]: native=%h gold=%h",recv_data_on_boundary_west__rdy[1],gold_recv_data_on_boundary_west__rdy[1]);
      if(recv_from_cpu_pkt__rdy!==gold_recv_from_cpu_pkt__rdy)$display("recv_from_cpu_pkt__rdy: native=%h gold=%h",recv_from_cpu_pkt__rdy,gold_recv_from_cpu_pkt__rdy);
      if(send_data_on_boundary_east__msg[0]!==gold_send_data_on_boundary_east__msg[0])$display("send_data_on_boundary_east__msg[0]: native=%h gold=%h",send_data_on_boundary_east__msg[0],gold_send_data_on_boundary_east__msg[0]);
      if(send_data_on_boundary_east__msg[1]!==gold_send_data_on_boundary_east__msg[1])$display("send_data_on_boundary_east__msg[1]: native=%h gold=%h",send_data_on_boundary_east__msg[1],gold_send_data_on_boundary_east__msg[1]);
      if(send_data_on_boundary_east__val[0]!==gold_send_data_on_boundary_east__val[0])$display("send_data_on_boundary_east__val[0]: native=%h gold=%h",send_data_on_boundary_east__val[0],gold_send_data_on_boundary_east__val[0]);
      if(send_data_on_boundary_east__val[1]!==gold_send_data_on_boundary_east__val[1])$display("send_data_on_boundary_east__val[1]: native=%h gold=%h",send_data_on_boundary_east__val[1],gold_send_data_on_boundary_east__val[1]);
      if(send_data_on_boundary_north__msg[0]!==gold_send_data_on_boundary_north__msg[0])$display("send_data_on_boundary_north__msg[0]: native=%h gold=%h",send_data_on_boundary_north__msg[0],gold_send_data_on_boundary_north__msg[0]);
      if(send_data_on_boundary_north__msg[1]!==gold_send_data_on_boundary_north__msg[1])$display("send_data_on_boundary_north__msg[1]: native=%h gold=%h",send_data_on_boundary_north__msg[1],gold_send_data_on_boundary_north__msg[1]);
      if(send_data_on_boundary_north__val[0]!==gold_send_data_on_boundary_north__val[0])$display("send_data_on_boundary_north__val[0]: native=%h gold=%h",send_data_on_boundary_north__val[0],gold_send_data_on_boundary_north__val[0]);
      if(send_data_on_boundary_north__val[1]!==gold_send_data_on_boundary_north__val[1])$display("send_data_on_boundary_north__val[1]: native=%h gold=%h",send_data_on_boundary_north__val[1],gold_send_data_on_boundary_north__val[1]);
      if(send_data_on_boundary_south__msg[0]!==gold_send_data_on_boundary_south__msg[0])$display("send_data_on_boundary_south__msg[0]: native=%h gold=%h",send_data_on_boundary_south__msg[0],gold_send_data_on_boundary_south__msg[0]);
      if(send_data_on_boundary_south__msg[1]!==gold_send_data_on_boundary_south__msg[1])$display("send_data_on_boundary_south__msg[1]: native=%h gold=%h",send_data_on_boundary_south__msg[1],gold_send_data_on_boundary_south__msg[1]);
      if(send_data_on_boundary_south__val[0]!==gold_send_data_on_boundary_south__val[0])$display("send_data_on_boundary_south__val[0]: native=%h gold=%h",send_data_on_boundary_south__val[0],gold_send_data_on_boundary_south__val[0]);
      if(send_data_on_boundary_south__val[1]!==gold_send_data_on_boundary_south__val[1])$display("send_data_on_boundary_south__val[1]: native=%h gold=%h",send_data_on_boundary_south__val[1],gold_send_data_on_boundary_south__val[1]);
      if(send_data_on_boundary_west__msg[0]!==gold_send_data_on_boundary_west__msg[0])$display("send_data_on_boundary_west__msg[0]: native=%h gold=%h",send_data_on_boundary_west__msg[0],gold_send_data_on_boundary_west__msg[0]);
      if(send_data_on_boundary_west__msg[1]!==gold_send_data_on_boundary_west__msg[1])$display("send_data_on_boundary_west__msg[1]: native=%h gold=%h",send_data_on_boundary_west__msg[1],gold_send_data_on_boundary_west__msg[1]);
      if(send_data_on_boundary_west__val[0]!==gold_send_data_on_boundary_west__val[0])$display("send_data_on_boundary_west__val[0]: native=%h gold=%h",send_data_on_boundary_west__val[0],gold_send_data_on_boundary_west__val[0]);
      if(send_data_on_boundary_west__val[1]!==gold_send_data_on_boundary_west__val[1])$display("send_data_on_boundary_west__val[1]: native=%h gold=%h",send_data_on_boundary_west__val[1],gold_send_data_on_boundary_west__val[1]);
      if(send_to_cpu_pkt__msg!==gold_send_to_cpu_pkt__msg)$display("send_to_cpu_pkt__msg: native=%h gold=%h",send_to_cpu_pkt__msg,gold_send_to_cpu_pkt__msg);
      if(send_to_cpu_pkt__val!==gold_send_to_cpu_pkt__val)$display("send_to_cpu_pkt__val: native=%h gold=%h",send_to_cpu_pkt__val,gold_send_to_cpu_pkt__val);
      $fatal(1,"im2col-system mismatch cycle=%0d",cycles);end
  endtask

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
        if(load_count>=expected_loads || send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]!==expected_load[load_count])
          $fatal(1,"Integrated load %0d expected=%h got=%h",load_count,expected_load[load_count],send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]);
        load_count++;
      end else $fatal(1,"Unexpected CPU response command");
    end
  endtask


  task automatic step;
    send_to_cpu_pkt__rdy=cycles%7<4;
    #3;compare_outputs();sample_cpu();#2;clk=1;#5;clk=0;cycles++;
    if(cycles>2500)$fatal(1,"Integrated Im2col TIMEOUT");
  endtask


  task automatic command(input int cmd,input logic[31:0] data,input int addr);
    bit accepted;accepted=0;recv_from_cpu_pkt__val=1;recv_from_cpu_pkt__msg=packet(cmd,data,addr);
    while(!accepted)begin #1;accepted=recv_from_cpu_pkt__rdy;step();end
    recv_from_cpu_pkt__val=0;
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
    command(53,3,0);command(54,3,0);command(55,2,0);command(56,2,0);command(57,0,0);command(58,0,8);command(52,0,0);
    repeat(140)step();
    expected_loads=16;
    begin:int_expected
      int i;i=0;
      for(int ky=0;ky<2;ky++)for(int kx=0;kx<2;kx++)for(int oy=0;oy<2;oy++)for(int ox=0;ox<2;ox++)begin
        expected_load[i]=32'(3+17*((oy+ky)*3+ox+kx));i++;
      end
    end
    for(int i=0;i<16;i++)command(10,0,8+i);
    while(load_count<16)step();repeat(12)step();
    if(done_count!=0 || blocked_cycles<16)$fatal(1,"Integrated Im2col gate/response coverage");
    $display("IM2COL_SYSTEM_PASS cycles=%0d loads=%0d CPU_blocked_cycles=%0d",cycles,load_count,blocked_cycles);$finish;
  end
endmodule

