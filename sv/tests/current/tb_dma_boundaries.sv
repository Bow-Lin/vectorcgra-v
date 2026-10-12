`timescale 1ns/1ps
module tb_dma_boundaries #(parameter int DRAM_DATA_W=128, parameter bit LEGACY_PYTHON=0);
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
`ifdef DMA_BOUNDARIES_POST_SYNTH
  dma_boundaries_netlist dut(.*);
`else
  cgra_dma_engine #(.DRAM_DATA_W(DRAM_DATA_W),.LEGACY_PYTHON(LEGACY_PYTHON)) dut(.*);
`endif
  bit wrong;
  integer reset_checks=0;
  integer samples /* verilator public_flat_rw */ =0;
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
      if(send_to_spm_wr_req__msg!={32'(64+wr_seen),pattern(wr_seen)^(wrong && word_writes==0 ? 32'd1 : 32'd0),4'hf}) $fatal(1,"DMA word write index=%0d",wr_seen);
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
  task automatic defaults;
    dma_cmd__msg=0;dma_cmd__val=0;dma_done__rdy=0;
    send_to_dram_rd_req__rdy=0;send_to_dram_wr_req__rdy=0;
    send_to_spm_rd_req__rdy=0;send_to_spm_wr_req__rdy=0;
    recv_from_dram_rd_resp__msg=0;recv_from_dram_rd_resp__val=0;
    recv_from_spm_rd_resp__msg=0;recv_from_spm_rd_resp__val=0;
    recv_from_dram_wr_resp__msg=0;recv_from_dram_wr_resp__val=0;
    dr_data=0;sr_data=0;dr_pending=0;sr_pending=0;ack_pending=0;
  endtask
  task automatic no_transactions;
    #1;
    if({dma_cmd__rdy,dma_done__val,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,
        send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__val,
        send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}!==9'b0)
      $fatal(1,"DMA_RESET_ISOLATION");
    reset_checks++;
  endtask
  task automatic reset_at_boundary(input integer boundary);
    defaults();reset=1;tick();reset=0;
    // Reach each phase through its public request/response handshakes.
    dma_cmd__msg={3'(boundary>=4),64'd4096,32'd64,32'(boundary==8?0:4),8'h55};
    dma_cmd__val=1;#1;if(!dma_cmd__rdy)$fatal(1,"DMA boundary command not ready");
    tick();dma_cmd__val=0;
    if(boundary>=2 && boundary<=3) begin
      #1;if(!send_to_dram_rd_req__val)$fatal(1,"DMA expected MVIN request");
      send_to_dram_rd_req__rdy=1;tick();send_to_dram_rd_req__rdy=0;
      #1;if(!recv_from_dram_rd_resp__rdy)$fatal(1,"DMA expected MVIN response phase");
    end
    if(boundary==3) begin
      recv_from_dram_rd_resp__msg='1;recv_from_dram_rd_resp__val=1;tick();recv_from_dram_rd_resp__val=0;
      #1;if(!send_to_spm_wr_req__val)$fatal(1,"DMA expected SPM write phase");
    end
    if(boundary>=5 && boundary<=7) begin
      #1;if(!send_to_spm_rd_req__val)$fatal(1,"DMA expected MVOUT request");
      send_to_spm_rd_req__rdy=1;tick();send_to_spm_rd_req__rdy=0;
      #1;if(!recv_from_spm_rd_resp__rdy)$fatal(1,"DMA expected SPM response phase");
    end
    if(boundary>=6 && boundary<=7) begin
      recv_from_spm_rd_resp__msg='1;recv_from_spm_rd_resp__val=1;tick();recv_from_spm_rd_resp__val=0;
      #1;if(!send_to_dram_wr_req__val)$fatal(1,"DMA expected DRAM write phase");
    end
    if(boundary==7) begin
      send_to_dram_wr_req__rdy=1;tick();send_to_dram_wr_req__rdy=0;
      #1;if(!recv_from_dram_wr_resp__rdy)$fatal(1,"DMA expected DRAM acknowledgement phase");
    end
    if(boundary==8) begin #1;if(!dma_done__val)$fatal(1,"DMA expected completion phase");end
    // Global reset flushes the endpoint response model too. This does not claim
    // rollback of accepted writes or safe reuse of unidentified late responses.
    reset=1;no_transactions();tick();no_transactions();defaults();reset=0;#1;
    if(!dma_cmd__rdy || dma_done__val)$fatal(1,"DMA clean restart");
    transfer(1'(boundary%2),1+boundary%3);
  endtask
  task automatic replay(input string path);
    integer fd,scan;
    logic [$bits({reset,dma_cmd__msg,dma_cmd__val,dma_done__rdy,send_to_dram_rd_req__rdy,recv_from_dram_rd_resp__msg,recv_from_dram_rd_resp__val,send_to_dram_wr_req__rdy,recv_from_dram_wr_resp__msg,recv_from_dram_wr_resp__val,send_to_spm_wr_req__rdy,send_to_spm_rd_req__rdy,recv_from_spm_rd_resp__msg,recv_from_spm_rd_resp__val})-1:0] inputs;
    logic [$bits({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy})-1:0] expected;
    fd=$fopen(path,"r");if(!fd)$fatal(1,"DMA_REPLAY_OPEN");
    while(!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",inputs,expected);if(scan!=2)$fatal(1,"DMA_REPLAY_FORMAT");
      {reset,dma_cmd__msg,dma_cmd__val,dma_done__rdy,send_to_dram_rd_req__rdy,recv_from_dram_rd_resp__msg,recv_from_dram_rd_resp__val,send_to_dram_wr_req__rdy,recv_from_dram_wr_resp__msg,recv_from_dram_wr_resp__val,send_to_spm_wr_req__rdy,send_to_spm_rd_req__rdy,recv_from_spm_rd_resp__msg,recv_from_spm_rd_resp__val}=inputs;#1;
      if(wrong && samples==7) expected^=1;
      if({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}!==expected)$fatal(1,"DMA_REPLAY_MISMATCH sample=%0d",samples);
      samples++;tick();
    end
    $fclose(fd);if(samples!=600)$fatal(1,"DMA_REPLAY_COVERAGE");
    $display("DMA_REPLAY_PASS width=%0d samples=%0d output_bits=%0d",DRAM_DATA_W,samples,$bits({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}));
  endtask
  string vectors,invalid;
  initial begin
    clk=0;wrong=$test$plusargs("EXPECT_FAILURE");defaults();
    if($value$plusargs("VECTORS=%s",vectors)) begin
      // Compare from a defined reset state, independent of synthesis FSM encoding.
      reset=1;tick();defaults();
      replay(vectors);$finish;
    end
    reset=1;tick();reset=0;
    if($value$plusargs("INVALID=%s",invalid)) begin
      dma_cmd__msg={3'(invalid=="opcode"?2:0),64'd4096,32'd64,32'(invalid=="length"?3:4),8'h33};
      dma_cmd__val=1;#1;
      if(dma_cmd__rdy)$fatal(1,"DMA_INVALID_COMMAND_ACCEPTED");
`ifdef DMA_BOUNDARIES_POST_SYNTH
      repeat(4) begin tick();if(dma_cmd__rdy || send_to_dram_rd_req__val || send_to_spm_rd_req__val || dma_done__val)$fatal(1,"DMA_INVALID_COMMAND_ACCEPTED");end
      $display("DMA_INVALID_COMMAND_REJECT_PASS");$finish;
`else
      tick();$fatal(1,"DMA_MISSING_INVALID_DIAGNOSTIC");
`endif
    end

    for(int direction=0;direction<2;direction++) begin
      transfer(1'(direction),0);
      // Every possible final mask, plus multiple complete beats.
      for(int n=1;n<=2*WORDS+1;n++) transfer(1'(direction),n);
    end
    for(integer phase=1;phase<=8;phase++) reset_at_boundary(phase);
    $display("DMA_BOUNDARIES_PASS width=%0d cycles=%0d transactions=%0d reset_checks=%0d words_in=%0d words_out=%0d reads=%0d writes=%0d",DRAM_DATA_W,cycles,transactions,reset_checks,word_writes,word_reads,beat_reads,beat_writes);
    $finish;
  end
endmodule
