`timescale 1ns/1ps
module tb_current_dma #(parameter int DRAM_DATA_W=128);
  localparam int WORDS=DRAM_DATA_W/32, MASK=DRAM_DATA_W/8;
  logic clk=0,reset=0;
  logic [138:0] dma_cmd__msg;
  logic dma_cmd__val,dma_cmd__rdy;
  logic [7:0] dma_done__msg;
  logic dma_done__val,dma_done__rdy;
  logic [63:0] send_to_dram_rd_req__msg;
  logic send_to_dram_rd_req__val,send_to_dram_rd_req__rdy;
  logic [DRAM_DATA_W-1:0] recv_from_dram_rd_resp__msg;
  logic recv_from_dram_rd_resp__val,recv_from_dram_rd_resp__rdy;
  logic [64+DRAM_DATA_W+MASK-1:0] send_to_dram_wr_req__msg;
  logic send_to_dram_wr_req__val,send_to_dram_wr_req__rdy;
  logic recv_from_dram_wr_resp__msg,recv_from_dram_wr_resp__val,recv_from_dram_wr_resp__rdy;
  logic [67:0] send_to_spm_wr_req__msg;
  logic send_to_spm_wr_req__val,send_to_spm_wr_req__rdy;
  logic [31:0] send_to_spm_rd_req__msg;
  logic send_to_spm_rd_req__val,send_to_spm_rd_req__rdy;
  logic [31:0] recv_from_spm_rd_resp__msg;
  logic recv_from_spm_rd_resp__val,recv_from_spm_rd_resp__rdy;
  cgra_dma_engine #(.DRAM_DATA_W(DRAM_DATA_W)) dut(.*);
  int cycles=0,transactions=0,word_writes=0,word_reads=0,beat_reads=0,beat_writes=0;
  int total,wr_seen,rd_seen,br_seen,bw_seen;
  bit dr_pending=0,sr_pending=0,ack_pending=0;
  logic [DRAM_DATA_W-1:0] dr_data;
  logic [31:0] sr_data;
  function automatic logic [31:0] pattern(input int n);
    return 32'h80010003 ^ (32'(n)*32'h10203) ^ (32'(transactions)*32'h701);
  endfunction
  task automatic tick;
    #5;clk=1;#5;clk=0;cycles++;
    if(cycles>10000) $fatal(1,"DMA_TIMEOUT");
  endtask
  task automatic step;
    logic [63:0] wa;
    logic [DRAM_DATA_W-1:0] wd;
    logic [MASK-1:0] wm,expected_mask;
    int valid_words;
    send_to_dram_rd_req__rdy=cycles%5!=0;
    send_to_dram_wr_req__rdy=cycles%7<4;
    send_to_spm_rd_req__rdy=cycles%6<3;
    send_to_spm_wr_req__rdy=cycles%4!=1;
    recv_from_dram_rd_resp__val=dr_pending && cycles%3!=0;
    recv_from_dram_rd_resp__msg=dr_data;
    recv_from_spm_rd_resp__val=sr_pending && cycles%3!=1;
    recv_from_spm_rd_resp__msg=sr_data;
    recv_from_dram_wr_resp__val=ack_pending && cycles%3!=2;
    #2;
    if(recv_from_dram_rd_resp__val && recv_from_dram_rd_resp__rdy) dr_pending=0;
    if(recv_from_spm_rd_resp__val && recv_from_spm_rd_resp__rdy) sr_pending=0;
    if(recv_from_dram_wr_resp__val && recv_from_dram_wr_resp__rdy) ack_pending=0;
    if(send_to_dram_rd_req__val && send_to_dram_rd_req__rdy) begin
      if(dr_pending || send_to_dram_rd_req__msg!=64'(4096+br_seen*MASK)) $fatal(1,"DMA read address/overlap");
      for(int w=0;w<WORDS;w++) dr_data[w*32+:32]=pattern(br_seen*WORDS+w);
      br_seen++;beat_reads++;dr_pending=1;
    end
    if(send_to_spm_wr_req__val && send_to_spm_wr_req__rdy) begin
      if(send_to_spm_wr_req__msg!={32'(64+wr_seen),pattern(wr_seen),4'hf}) $fatal(1,"DMA word write index=%0d",wr_seen);
      wr_seen++;word_writes++;
    end
    if(send_to_spm_rd_req__val && send_to_spm_rd_req__rdy) begin
      if(sr_pending || send_to_spm_rd_req__msg!=32'(64+rd_seen)) $fatal(1,"DMA SPM read address/overlap");
      sr_data=pattern(rd_seen);rd_seen++;word_reads++;sr_pending=1;
    end
    if(send_to_dram_wr_req__val && send_to_dram_wr_req__rdy) begin
      {wa,wd,wm}=send_to_dram_wr_req__msg;
      if(ack_pending || wa!=64'(4096+bw_seen*MASK)) $fatal(1,"DMA write address/overlap");
      valid_words=total-bw_seen*WORDS;if(valid_words>WORDS)valid_words=WORDS;
      expected_mask='0;
      for(int w=0;w<WORDS;w++) begin
        if(w<valid_words) begin
          expected_mask[w*4+:4]=4'hf;
          if(wd[w*32+:32]!=pattern(bw_seen*WORDS+w)) $fatal(1,"DMA packed word beat=%0d lane=%0d",bw_seen,w);
        end else if(wd[w*32+:32]!=0) $fatal(1,"DMA unused lane must be zero");
      end
      if(wm!=expected_mask) $fatal(1,"DMA partial mask got=%h expected=%h",wm,expected_mask);
      bw_seen++;beat_writes++;ack_pending=1;
    end
    tick();
  endtask
  task automatic transfer(input bit mvout,input int count);
    int timeout_cycle;
    total=count;wr_seen=0;rd_seen=0;br_seen=0;bw_seen=0;
    dma_cmd__msg={3'(mvout),64'd4096,32'd64,32'(count*4),8'(transactions)};
    dma_cmd__val=1;#1;
    if(!dma_cmd__rdy)$fatal(1,"DMA command busy");
    tick();dma_cmd__val=0;timeout_cycle=cycles+1000;
    while(!dma_done__val) begin
      if(cycles>=timeout_cycle)$fatal(1,"DMA transfer timeout");
      step();
    end
    if(dma_done__msg!=8'(transactions))$fatal(1,"DMA completion tag");
    if((mvout && (rd_seen!=count || bw_seen!=(count+WORDS-1)/WORDS || wr_seen!=0)) ||
       (!mvout && (wr_seen!=count || br_seen!=(count+WORDS-1)/WORDS || rd_seen!=0)))$fatal(1,"DMA transfer counts");
    repeat(3) begin
      step();if(!dma_done__val || dma_cmd__rdy)$fatal(1,"DMA completion backpressure");
    end
    dma_done__rdy=1;tick();dma_done__rdy=0;transactions++;
  endtask
  initial begin
    dma_cmd__msg=0;dma_cmd__val=0;dma_done__rdy=0;
    send_to_dram_rd_req__rdy=0;send_to_dram_wr_req__rdy=0;
    send_to_spm_rd_req__rdy=0;send_to_spm_wr_req__rdy=0;
    recv_from_dram_rd_resp__msg=0;recv_from_dram_rd_resp__val=0;
    recv_from_spm_rd_resp__msg=0;recv_from_spm_rd_resp__val=0;
    recv_from_dram_wr_resp__msg=0;recv_from_dram_wr_resp__val=0;
    dr_data=0;sr_data=0;reset=1;tick();reset=0;
    for(int direction=0;direction<2;direction++) begin
      transfer(1'(direction),0);
      // Every possible final mask, plus multiple complete beats.
      for(int n=1;n<=2*WORDS+1;n++) transfer(1'(direction),n);
    end
    $display("CURRENT_DMA_PASS width=%0d cycles=%0d transactions=%0d words_in=%0d words_out=%0d reads=%0d writes=%0d",DRAM_DATA_W,cycles,transactions,word_writes,word_reads,beat_reads,beat_writes);
    $finish;
  end
endmodule
