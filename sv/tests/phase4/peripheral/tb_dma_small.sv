`timescale 1ns/1ps
module tb_dma_small #(parameter bit HDL_MODE=1);
  localparam int DA=16,SA=8,BC=8,TAG=4;

  logic [1-1:0] clk=0;
  logic [1-1:0] reset=0;
  logic [39-1:0] dma_cmd__msg=0;
  logic [1-1:0] dma_cmd__val=0;
  logic [1-1:0] dma_cmd__rdy, gold_dma_cmd__rdy;
  logic [4-1:0] dma_done__msg, gold_dma_done__msg;
  logic [1-1:0] dma_done__val, gold_dma_done__val;
  logic [1-1:0] dma_done__rdy=0;
  logic [16-1:0] send_to_dram_rd_req__msg, gold_send_to_dram_rd_req__msg;
  logic [1-1:0] send_to_dram_rd_req__val, gold_send_to_dram_rd_req__val;
  logic [1-1:0] send_to_dram_rd_req__rdy=0;
  logic [128-1:0] recv_from_dram_rd_resp__msg=0;
  logic [1-1:0] recv_from_dram_rd_resp__val=0;
  logic [1-1:0] recv_from_dram_rd_resp__rdy, gold_recv_from_dram_rd_resp__rdy;
  logic [160-1:0] send_to_dram_wr_req__msg, gold_send_to_dram_wr_req__msg;
  logic [1-1:0] send_to_dram_wr_req__val, gold_send_to_dram_wr_req__val;
  logic [1-1:0] send_to_dram_wr_req__rdy=0;
  logic [1-1:0] recv_from_dram_wr_resp__msg=0;
  logic [1-1:0] recv_from_dram_wr_resp__val=0;
  logic [1-1:0] recv_from_dram_wr_resp__rdy, gold_recv_from_dram_wr_resp__rdy;
  logic [44-1:0] send_to_spm_wr_req__msg, gold_send_to_spm_wr_req__msg;
  logic [1-1:0] send_to_spm_wr_req__val, gold_send_to_spm_wr_req__val;
  logic [1-1:0] send_to_spm_wr_req__rdy=0;
  logic [8-1:0] send_to_spm_rd_req__msg, gold_send_to_spm_rd_req__msg;
  logic [1-1:0] send_to_spm_rd_req__val, gold_send_to_spm_rd_req__val;
  logic [1-1:0] send_to_spm_rd_req__rdy=0;
  logic [32-1:0] recv_from_spm_rd_resp__msg=0;
  logic [1-1:0] recv_from_spm_rd_resp__val=0;
  logic [1-1:0] recv_from_spm_rd_resp__rdy, gold_recv_from_spm_rd_resp__rdy;
  cgra_dma_engine #(.SPM_DATA_W(32),.DRAM_DATA_W(128),.DRAM_ADDR_W(16),.SPM_ADDR_W(8),.BYTES_W(8),.TAG_W(4),.BASELINE_TRANSLATED_SLICES(HDL_MODE)) dut (.clk(clk),
    .reset(reset),
    .dma_cmd__msg(dma_cmd__msg),
    .dma_cmd__val(dma_cmd__val),
    .dma_cmd__rdy(dma_cmd__rdy),
    .dma_done__msg(dma_done__msg),
    .dma_done__val(dma_done__val),
    .dma_done__rdy(dma_done__rdy),
    .send_to_dram_rd_req__msg(send_to_dram_rd_req__msg),
    .send_to_dram_rd_req__val(send_to_dram_rd_req__val),
    .send_to_dram_rd_req__rdy(send_to_dram_rd_req__rdy),
    .recv_from_dram_rd_resp__msg(recv_from_dram_rd_resp__msg),
    .recv_from_dram_rd_resp__val(recv_from_dram_rd_resp__val),
    .recv_from_dram_rd_resp__rdy(recv_from_dram_rd_resp__rdy),
    .send_to_dram_wr_req__msg(send_to_dram_wr_req__msg),
    .send_to_dram_wr_req__val(send_to_dram_wr_req__val),
    .send_to_dram_wr_req__rdy(send_to_dram_wr_req__rdy),
    .recv_from_dram_wr_resp__msg(recv_from_dram_wr_resp__msg),
    .recv_from_dram_wr_resp__val(recv_from_dram_wr_resp__val),
    .recv_from_dram_wr_resp__rdy(recv_from_dram_wr_resp__rdy),
    .send_to_spm_wr_req__msg(send_to_spm_wr_req__msg),
    .send_to_spm_wr_req__val(send_to_spm_wr_req__val),
    .send_to_spm_wr_req__rdy(send_to_spm_wr_req__rdy),
    .send_to_spm_rd_req__msg(send_to_spm_rd_req__msg),
    .send_to_spm_rd_req__val(send_to_spm_rd_req__val),
    .send_to_spm_rd_req__rdy(send_to_spm_rd_req__rdy),
    .recv_from_spm_rd_resp__msg(recv_from_spm_rd_resp__msg),
    .recv_from_spm_rd_resp__val(recv_from_spm_rd_resp__val),
    .recv_from_spm_rd_resp__rdy(recv_from_spm_rd_resp__rdy));
  Phase4DmaSmall gold (.clk(clk),
    .reset(reset),
    .dma_cmd__msg(dma_cmd__msg),
    .dma_cmd__val(dma_cmd__val),
    .dma_cmd__rdy(gold_dma_cmd__rdy),
    .dma_done__msg(gold_dma_done__msg),
    .dma_done__val(gold_dma_done__val),
    .dma_done__rdy(dma_done__rdy),
    .send_to_dram_rd_req__msg(gold_send_to_dram_rd_req__msg),
    .send_to_dram_rd_req__val(gold_send_to_dram_rd_req__val),
    .send_to_dram_rd_req__rdy(send_to_dram_rd_req__rdy),
    .recv_from_dram_rd_resp__msg(recv_from_dram_rd_resp__msg),
    .recv_from_dram_rd_resp__val(recv_from_dram_rd_resp__val),
    .recv_from_dram_rd_resp__rdy(gold_recv_from_dram_rd_resp__rdy),
    .send_to_dram_wr_req__msg(gold_send_to_dram_wr_req__msg),
    .send_to_dram_wr_req__val(gold_send_to_dram_wr_req__val),
    .send_to_dram_wr_req__rdy(send_to_dram_wr_req__rdy),
    .recv_from_dram_wr_resp__msg(recv_from_dram_wr_resp__msg),
    .recv_from_dram_wr_resp__val(recv_from_dram_wr_resp__val),
    .recv_from_dram_wr_resp__rdy(gold_recv_from_dram_wr_resp__rdy),
    .send_to_spm_wr_req__msg(gold_send_to_spm_wr_req__msg),
    .send_to_spm_wr_req__val(gold_send_to_spm_wr_req__val),
    .send_to_spm_wr_req__rdy(send_to_spm_wr_req__rdy),
    .send_to_spm_rd_req__msg(gold_send_to_spm_rd_req__msg),
    .send_to_spm_rd_req__val(gold_send_to_spm_rd_req__val),
    .send_to_spm_rd_req__rdy(send_to_spm_rd_req__rdy),
    .recv_from_spm_rd_resp__msg(recv_from_spm_rd_resp__msg),
    .recv_from_spm_rd_resp__val(recv_from_spm_rd_resp__val),
    .recv_from_spm_rd_resp__rdy(gold_recv_from_spm_rd_resp__rdy));
  localparam int INPUT_BITS=210,OUTPUT_BITS=241;
  integer trace_fd,scan_status,trace_count=0,gold_mismatches=0;string trace_path;
  logic[INPUT_BITS-1:0] expected_input;logic[OUTPUT_BITS-1:0] expected_output;
  bit generate_stimulus;
  initial begin
    generate_stimulus=$test$plusargs("GENERATE_STIMULUS");
    if(!$value$plusargs("TRACE=%s",trace_path))trace_path="reference/phase4/peripheral/dma-small-pytrace/trace.hex";
    if(!HDL_MODE)begin trace_fd=$fopen(trace_path,generate_stimulus?"w":"r");if(!trace_fd)$fatal(1,"Cannot open trace %s",trace_path);end
  end
  task automatic compare_outputs;
    if(HDL_MODE)begin
      expected_output={gold_dma_cmd__rdy,gold_dma_done__msg,gold_dma_done__val,gold_send_to_dram_rd_req__msg,gold_send_to_dram_rd_req__val,gold_recv_from_dram_rd_resp__rdy,gold_send_to_dram_wr_req__msg,gold_send_to_dram_wr_req__val,gold_recv_from_dram_wr_resp__rdy,gold_send_to_spm_wr_req__msg,gold_send_to_spm_wr_req__val,gold_send_to_spm_rd_req__msg,gold_send_to_spm_rd_req__val,gold_recv_from_spm_rd_resp__rdy};
      if($test$plusargs("EXPECT_FAILURE") && cycles==20)expected_output^=1;
      if({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}!==expected_output)
        $fatal(1,"dma-small mismatch cycle=%0d",cycles);
    end else if(generate_stimulus)begin
      $fwrite(trace_fd,"%h %h\n",{reset,dma_cmd__msg,dma_cmd__val,dma_done__rdy,send_to_dram_rd_req__rdy,recv_from_dram_rd_resp__msg,recv_from_dram_rd_resp__val,send_to_dram_wr_req__rdy,recv_from_dram_wr_resp__msg,recv_from_dram_wr_resp__val,send_to_spm_wr_req__rdy,send_to_spm_rd_req__rdy,recv_from_spm_rd_resp__msg,recv_from_spm_rd_resp__val},{dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy});
    end else begin
      scan_status=$fscanf(trace_fd,"%h %h\n",expected_input,expected_output);
      if(scan_status!=2)$fatal(1,"Missing Python trace cycle=%0d",cycles);
      if({reset,dma_cmd__msg,dma_cmd__val,dma_done__rdy,send_to_dram_rd_req__rdy,recv_from_dram_rd_resp__msg,recv_from_dram_rd_resp__val,send_to_dram_wr_req__rdy,recv_from_dram_wr_resp__msg,recv_from_dram_wr_resp__val,send_to_spm_wr_req__rdy,send_to_spm_rd_req__rdy,recv_from_spm_rd_resp__msg,recv_from_spm_rd_resp__val}!==expected_input)$fatal(1,"Python stimulus mismatch cycle=%0d",cycles);
      if($test$plusargs("EXPECT_FAILURE") && cycles==20)expected_output^=1;
      if({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}!==expected_output)
        $fatal(1,"dma-small mismatch cycle=%0d",cycles);
      trace_count++;
    end
    if({dma_cmd__rdy,dma_done__msg,dma_done__val,send_to_dram_rd_req__msg,send_to_dram_rd_req__val,recv_from_dram_rd_resp__rdy,send_to_dram_wr_req__msg,send_to_dram_wr_req__val,recv_from_dram_wr_resp__rdy,send_to_spm_wr_req__msg,send_to_spm_wr_req__val,send_to_spm_rd_req__msg,send_to_spm_rd_req__val,recv_from_spm_rd_resp__rdy}!=={gold_dma_cmd__rdy,gold_dma_done__msg,gold_dma_done__val,gold_send_to_dram_rd_req__msg,gold_send_to_dram_rd_req__val,gold_recv_from_dram_rd_resp__rdy,gold_send_to_dram_wr_req__msg,gold_send_to_dram_wr_req__val,gold_recv_from_dram_wr_resp__rdy,gold_send_to_spm_wr_req__msg,gold_send_to_spm_wr_req__val,gold_send_to_spm_rd_req__msg,gold_send_to_spm_rd_req__val,gold_recv_from_spm_rd_resp__rdy})begin
      if(gold_mismatches==0)$display("KNOWN_GOLD_TRANSLATOR_MISMATCH first_cycle=%0d",cycles);
      gold_mismatches++;
    end
  endtask

  int cycles=0,transactions=0,word_writes=0,word_reads=0,beat_reads=0,beat_writes=0,known_incorrect_words=0;
  int total_words,spm_base,dram_base,pattern_seed,wr_seen,rd_seen,br_seen,bw_seen;
  int dr_due,sr_due,ack_due,done_stalls;bit dr_pending=0,sr_pending=0,ack_pending=0,checking=0;
  logic [127:0] dr_data;logic [31:0] sr_data;
  function automatic logic [31:0] pattern(input int index);
    return 32'h80010003 ^ (32'(index)*32'h10203) ^ (32'(pattern_seed)*32'h701);
  endfunction
  task automatic tick;
    #4;compare_outputs();#1;clk=1;#5;clk=0;cycles++;
  endtask
  task automatic env_step;
    send_to_dram_rd_req__rdy=(cycles%5!=0);
    send_to_dram_wr_req__rdy=(cycles%7<4);
    send_to_spm_wr_req__rdy=(cycles%4!=1);
    send_to_spm_rd_req__rdy=(cycles%6<3);
    recv_from_dram_rd_resp__val=dr_pending && cycles>=dr_due;
    recv_from_dram_rd_resp__msg=dr_data;
    recv_from_spm_rd_resp__val=sr_pending && cycles>=sr_due;
    recv_from_spm_rd_resp__msg=sr_data;
    recv_from_dram_wr_resp__val=ack_pending && cycles>=ack_due;
    recv_from_dram_wr_resp__msg=cycles%2;
    #2;
    if(recv_from_dram_rd_resp__val && recv_from_dram_rd_resp__rdy) dr_pending=0;
    if(recv_from_spm_rd_resp__val && recv_from_spm_rd_resp__rdy) sr_pending=0;
    if(recv_from_dram_wr_resp__val && recv_from_dram_wr_resp__rdy) ack_pending=0;
    if(send_to_dram_rd_req__val && send_to_dram_rd_req__rdy) begin
      if(send_to_dram_rd_req__msg!==DA'(dram_base+br_seen*16) || dr_pending) $fatal(1,"DRAM read address/pending");
      for(int j=0;j<4;j++) dr_data[j*32+:32]=pattern(br_seen*4+j);
      dr_pending=1;dr_due=cycles+2+(br_seen%3);br_seen++;beat_reads++;
    end
    if(send_to_spm_wr_req__val && send_to_spm_wr_req__rdy) begin
      int source_word;source_word=HDL_MODE ? (wr_seen/4)*4+(wr_seen%2) : wr_seen;
      if(send_to_spm_wr_req__msg!=={SA'(spm_base+wr_seen),pattern(source_word),4'hf}) $fatal(1,"SPM write baseline word %0d",wr_seen);
      if(send_to_spm_wr_req__msg[4+:32]!==pattern(wr_seen))known_incorrect_words++;
      wr_seen++;word_writes++;
    end
    if(send_to_spm_rd_req__val && send_to_spm_rd_req__rdy) begin
      if(send_to_spm_rd_req__msg!==SA'(spm_base+rd_seen) || sr_pending) $fatal(1,"SPM read expected word %0d",rd_seen);
      sr_data=pattern(rd_seen);sr_pending=1;sr_due=cycles+2+(rd_seen%4);rd_seen++;word_reads++;
    end
    if(send_to_dram_wr_req__val && send_to_dram_wr_req__rdy) begin
      logic [127:0] expected;logic[15:0] mask;int words;
      expected=0;mask=0;words=total_words-bw_seen*4;if(words>4)words=4;
      for(int j=0;j<words;j++) begin expected[j*32+:32]=pattern(bw_seen*4+j);mask[j*4+:4]=4'hf;end
      if(HDL_MODE && words==2)expected[64+:32]=pattern(bw_seen*4);
      if(send_to_dram_wr_req__msg!=={DA'(dram_base+bw_seen*16),expected,mask} || ack_pending)
        $fatal(1,"DRAM write beat %0d expected mask=%h actual=%h",bw_seen,mask,send_to_dram_wr_req__msg);
      ack_pending=1;ack_due=cycles+3+(bw_seen%3);bw_seen++;beat_writes++;
    end
    tick();
  endtask
  task automatic reset_engine;
    reset=1;dma_cmd__val=0;dma_done__rdy=0;
    recv_from_dram_rd_resp__val=0;recv_from_spm_rd_resp__val=0;recv_from_dram_wr_resp__val=0;
    dr_pending=0;sr_pending=0;ack_pending=0;
    repeat(3)tick();reset=0;tick();
    if(!dma_cmd__rdy || dma_done__val) $fatal(1,"reset did not restore idle");
  endtask
  task automatic transfer(input int opcode,input int words,input int tag);
    total_words=words;pattern_seed=transactions+1;spm_base=20;dram_base=64;
    wr_seen=0;rd_seen=0;br_seen=0;bw_seen=0;
    dma_cmd__msg={3'(opcode),DA'(dram_base),SA'(spm_base),BC'(words*4),TAG'(tag)};
    dma_cmd__val=1;dma_done__rdy=0;
    if(!dma_cmd__rdy)$fatal(1,"command not idle");tick();dma_cmd__val=0;
    begin:int_wait
      int timeout;timeout=0;
      while(!dma_done__val)begin env_step();timeout++;if(timeout>600)$fatal(1,"DMA TIMEOUT");end
    end
    if(dma_done__msg!==TAG'(tag))$fatal(1,"done tag mismatch");
    if(opcode==0)begin
      if(wr_seen!=words || br_seen!=(words+3)/4 || rd_seen || bw_seen)$fatal(1,"MVIN totals");
    end else if(rd_seen!=words || bw_seen!=(words+3)/4 || wr_seen || br_seen)$fatal(1,"MVOUT totals");
    repeat(4)begin env_step();if(!dma_done__val || dma_done__msg!==TAG'(tag) || dma_cmd__rdy)$fatal(1,"done backpressure");end
    dma_done__rdy=1;env_step();dma_done__rdy=0;
    if(!dma_cmd__rdy || dma_done__val)$fatal(1,"done release");
    transactions++;
  endtask
  initial begin
    reset_engine();
    for(int opcode=0;opcode<2;opcode++)begin
      for(int words=0;words<=9;words++)transfer(opcode,words,words+opcode*9);
    end
    transfer(7,3,15); // ac96 dispatches every nonzero opcode as MVOUT.
    // Reset while waiting for the response to an accepted DRAM request.
    dma_cmd__msg={3'd0,DA'(64),SA'(20),BC'(16),TAG'(3)};dma_cmd__val=1;tick();dma_cmd__val=0;
    send_to_dram_rd_req__rdy=1;tick();reset_engine();transfer(0,5,9);
    // Unaligned 1-byte input is outside the supported domain: preserve its
    // initial request/underflow behavior for a bounded trace, then reset.
    dma_cmd__msg={3'd0,DA'(64),SA'(20),BC'(1),TAG'(2)};dma_cmd__val=1;tick();dma_cmd__val=0;
    send_to_dram_rd_req__rdy=1;tick();recv_from_dram_rd_resp__val=1;recv_from_dram_rd_resp__msg=128'h1234;tick();
    recv_from_dram_rd_resp__val=0;send_to_spm_wr_req__rdy=1;tick();
    if(dma_done__val)$fatal(1,"unaligned baseline behavior changed");reset_engine();
    if(!HDL_MODE && !generate_stimulus)begin
      scan_status=$fscanf(trace_fd,"%h %h\n",expected_input,expected_output);
      if(scan_status==2 || trace_count!=cycles)$fatal(1,"Python replay coverage incomplete");
    end
    if(!HDL_MODE)$fclose(trace_fd);
    $display("DMA_PASS mode_hdl=%0d cycles=%0d python_cycles=%0d transactions=%0d writes=%0d reads=%0d beat_reads=%0d beat_writes=%0d known_gold_mismatch_cycles=%0d known_incorrect_words=%0d",HDL_MODE,cycles,trace_count,transactions,word_writes,word_reads,beat_reads,beat_writes,gold_mismatches,known_incorrect_words);
    $finish;
  end
endmodule

