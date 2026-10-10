// Independent end-to-end CPU -> DMA -> SPM -> CPU/DRAM acceptance.
// Current arithmetic expectations replace the archived translated-slice defect.
`timescale 1ns/1ps
module tb_current_dma_system #(parameter int DRAM_DATA_W=128);
  localparam int WORDS=DRAM_DATA_W/32, MASK=DRAM_DATA_W/8;
  localparam int HOST_BITS=214,CTRL_BITS=143,PAYLOAD_BITS=6+35+6+CTRL_BITS+3;
  int cycles=0,done_count=0,load_count=0,blocked_cycles=0;
  logic[5:0] address_lower=0;
  logic[5:0] address_upper=0;
  logic[0:0] cgra_id=0;
  logic[0:0] clk=0;
  logic[0:0] reset=0;
  logic[213:0] recv_from_cpu_pkt__msg=0;
  logic[0:0] recv_from_cpu_pkt__rdy;
  logic[0:0] recv_from_cpu_pkt__val=0;
  logic[DRAM_DATA_W-1:0] recv_from_dram_rd_resp__msg=0;
  logic[0:0] recv_from_dram_rd_resp__rdy;
  logic[0:0] recv_from_dram_rd_resp__val=0;
  logic[0:0] recv_from_dram_wr_resp__msg=0;
  logic[0:0] recv_from_dram_wr_resp__rdy;
  logic[0:0] recv_from_dram_wr_resp__val=0;
  logic[213:0] send_to_cpu_pkt__msg;
  logic[0:0] send_to_cpu_pkt__rdy=0;
  logic[0:0] send_to_cpu_pkt__val;
  logic[63:0] send_to_dram_rd_req__msg;
  logic[0:0] send_to_dram_rd_req__rdy=0;
  logic[0:0] send_to_dram_rd_req__val;
  logic[64+DRAM_DATA_W+MASK-1:0] send_to_dram_wr_req__msg;
  logic[0:0] send_to_dram_wr_req__rdy=0;
  logic[0:0] send_to_dram_wr_req__val;
  logic[34:0] zero_data[0:1];logic zero_bit[0:1];
  cgra_integrated_dma #(
    .DRAM_DATA_W(DRAM_DATA_W),
    .COLS(2),
    .ROWS(2),
    .DATA_W(32),
    .TILE_PORTS(8),
    .CTRL_DEPTH(8),
    .REG_DEPTH(16),
    .BANK_DEPTH(16),
    .NUM_BANKS(4),
    .GLOBAL_ADDR_W(6),
    .NUM_CTRL(1),
    .TOTAL_STEPS(1),
    .HAS_DMA(1),
    .HAS_IM2COL(0),
    .FU_COUNT(4),
    .CUSTOM_TOPOLOGY(1),
    .FU_KINDS(32'h030d0200),
    .LINK_COUNT(12),
    .LINK_ENABLED(12'hfff),
    .LINK_SRC_TILE(384'h000000020000000100000003000000000000000300000001000000020000000000000003000000020000000100000000),
    .LINK_SRC_PORT(384'h000000060000000400000007000000050000000100000000000000010000000000000002000000030000000200000003),
    .LINK_DST_TILE(384'h000000010000000200000000000000030000000100000003000000000000000200000002000000030000000000000001),
    .LINK_DST_PORT(384'h000000040000000600000005000000070000000000000001000000000000000100000003000000020000000300000002),
    .READ_PORT_TILE(96'h000000010000000200000000),
    .WRITE_PORT_TILE(96'h000000010000000200000000)) dut (
    .address_lower(address_lower),
    .address_upper(address_upper),
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .recv_from_cpu_pkt__msg(recv_from_cpu_pkt__msg),
    .recv_from_cpu_pkt__rdy(recv_from_cpu_pkt__rdy),
    .recv_from_cpu_pkt__val(recv_from_cpu_pkt__val),
    .recv_from_dram_rd_resp__msg(recv_from_dram_rd_resp__msg),
    .recv_from_dram_rd_resp__rdy(recv_from_dram_rd_resp__rdy),
    .recv_from_dram_rd_resp__val(recv_from_dram_rd_resp__val),
    .recv_from_dram_wr_resp__msg(recv_from_dram_wr_resp__msg),
    .recv_from_dram_wr_resp__rdy(recv_from_dram_wr_resp__rdy),
    .recv_from_dram_wr_resp__val(recv_from_dram_wr_resp__val),
    .send_to_cpu_pkt__msg(send_to_cpu_pkt__msg),
    .send_to_cpu_pkt__rdy(send_to_cpu_pkt__rdy),
    .send_to_cpu_pkt__val(send_to_cpu_pkt__val),
    .send_to_dram_rd_req__msg(send_to_dram_rd_req__msg),
    .send_to_dram_rd_req__rdy(send_to_dram_rd_req__rdy),
    .send_to_dram_rd_req__val(send_to_dram_rd_req__val),
    .send_to_dram_wr_req__msg(send_to_dram_wr_req__msg),
    .send_to_dram_wr_req__rdy(send_to_dram_wr_req__rdy),
    .send_to_dram_wr_req__val(send_to_dram_wr_req__val),
    .recv_from_inter_cgra_noc__msg('0),
    .recv_from_inter_cgra_noc__val(1'b0),
    .recv_from_inter_cgra_noc__rdy(),
    .send_to_inter_cgra_noc__msg(),
    .send_to_inter_cgra_noc__val(),
    .send_to_inter_cgra_noc__rdy(1'b0),
    .recv_data_on_boundary_east__msg(zero_data),
    .recv_data_on_boundary_east__val(zero_bit),
    .recv_data_on_boundary_east__rdy(),
    .send_data_on_boundary_east__msg(),
    .send_data_on_boundary_east__val(),
    .send_data_on_boundary_east__rdy(zero_bit),
    .recv_data_on_boundary_north__msg(zero_data),
    .recv_data_on_boundary_north__val(zero_bit),
    .recv_data_on_boundary_north__rdy(),
    .send_data_on_boundary_north__msg(),
    .send_data_on_boundary_north__val(),
    .send_data_on_boundary_north__rdy(zero_bit),
    .recv_data_on_boundary_south__msg(zero_data),
    .recv_data_on_boundary_south__val(zero_bit),
    .recv_data_on_boundary_south__rdy(),
    .send_data_on_boundary_south__msg(),
    .send_data_on_boundary_south__val(),
    .send_data_on_boundary_south__rdy(zero_bit),
    .recv_data_on_boundary_west__msg(zero_data),
    .recv_data_on_boundary_west__val(zero_bit),
    .recv_data_on_boundary_west__rdy(),
    .send_data_on_boundary_west__msg(),
    .send_data_on_boundary_west__val(),
    .send_data_on_boundary_west__rdy(zero_bit)
  );
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


  bit read_pending=0,ack_pending=0;int read_due,ack_due,read_beats=0,write_beats=0;logic[DRAM_DATA_W-1:0] read_data;
  task automatic step;
    send_to_cpu_pkt__rdy=cycles%7<4;send_to_dram_rd_req__rdy=cycles%5<3;send_to_dram_wr_req__rdy=cycles%6<3;
    recv_from_dram_rd_resp__val=read_pending && cycles>=read_due;recv_from_dram_rd_resp__msg=read_data;
    recv_from_dram_wr_resp__val=ack_pending && cycles>=ack_due;
    #3;sample_cpu();
    if(recv_from_dram_rd_resp__val && recv_from_dram_rd_resp__rdy)read_pending=0;
    if(recv_from_dram_wr_resp__val && recv_from_dram_wr_resp__rdy)ack_pending=0;
    if(!reset && send_to_dram_rd_req__val && send_to_dram_rd_req__rdy)begin
      if(send_to_dram_rd_req__msg!==64'h123400000100+64'(MASK*read_beats) || read_pending)$fatal(1,"Integrated DRAM read address");
      for(int j=0;j<WORDS;j++)read_data[j*32+:32]=word_pattern(read_beats*WORDS+j);
      read_pending=1;read_due=cycles+3;read_beats++;
    end
    if(!reset && send_to_dram_wr_req__val && send_to_dram_wr_req__rdy)begin
      logic[DRAM_DATA_W-1:0] data_expected;logic[MASK-1:0] mask_expected;
      data_expected='0;mask_expected='0;
      for(int j=0;j<WORDS;j++) if(write_beats*WORDS+j<WORDS+1) begin
        data_expected[j*32+:32]=word_pattern(write_beats*WORDS+j);
        mask_expected[j*4+:4]=4'hf;
      end
      if(send_to_dram_wr_req__msg!=={64'h123400000200+64'(MASK*write_beats),data_expected,mask_expected} || ack_pending)
        $fatal(1,"Integrated DRAM write beat %0d",write_beats);
      ack_pending=1;ack_due=cycles+4;write_beats++;
    end
    #2;clk=1;#5;clk=0;cycles++;if(cycles>2500)$fatal(1,"Integrated DMA TIMEOUT");
  endtask


  task automatic command(input int cmd,input logic[31:0] data,input int addr);
    bit accepted;accepted=0;recv_from_cpu_pkt__val=1;recv_from_cpu_pkt__msg=packet(cmd,data,addr);
    while(!accepted)begin #1;accepted=recv_from_cpu_pkt__rdy;step();end
    recv_from_cpu_pkt__val=0;
  endtask


  task automatic dma_command(input int cmd,input int lowaddr,input int tag);
    expected_tag=tag;command(44,32'(lowaddr),0);command(45,32'h1234,0);command(46,0,4);
    command(47,4*(WORDS+1),0);command(48,32'(tag),0);command(cmd,0,0);
  endtask
  initial begin
    for(int i=0;i<2;i++)begin zero_data[i]=0;zero_bit[i]=0;end
    address_lower=0;address_upper=15;reset=1;repeat(3)step();reset=0;step();
    dma_command(49,'h100,'h5a);while(done_count<1)step();
    expected_loads=WORDS+1;
    for(int i=0;i<WORDS+1;i++)expected_load[i]=word_pattern(i);
    for(int i=0;i<WORDS+1;i++)command(10,0,4+i);
    while(load_count<WORDS+1)step();
    dma_command(50,'h200,'ha5);while(done_count<2)step();repeat(12)step();
    if(read_beats!=2 || write_beats!=2 || done_count!=2 || load_count!=WORDS+1)$fatal(1,"Integrated DMA coverage");
    $display("CURRENT_DMA_SYSTEM_PASS width=%0d cycles=%0d done=%0d loads=%0d read_beats=%0d write_beats=%0d",DRAM_DATA_W,cycles,done_count,load_count,read_beats,write_beats);$finish;
  end
endmodule
