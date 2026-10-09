`timescale 1ns/1ps
// Differential tests against unchanged modules in the frozen ac96 reference.
// Messages are compared on every sampled cycle, including val=0.
module tb_native_noc;
  logic clk = 0, reset = 1;
  always #5 clk = ~clk;
  int cycle;
  logic [31:0] random_state = 32'h31415926;
  function automatic logic [31:0] random_word();
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return random_state;
  endfunction
  function automatic logic [190:0] random_packet();
    return 191'({random_word(),random_word(),random_word(),random_word(),random_word(),random_word()});
  endfunction
  task automatic same(input string label, input logic [255:0] actual, expected);
    if (actual !== expected)
      $fatal(1,"NATIVE_NOC_MISMATCH cycle=%0d component=%s actual=%h gold=%h",cycle,label,actual,expected);
  endtask

  logic [190:0] q_msg, nq_msg, nq_gold_msg, bq_msg, bq_gold_msg;
  logic q_val,q_ready,nq_rdy,nq_gold_rdy,nq_val,nq_gold_val,bq_rdy,bq_gold_rdy,bq_val,bq_gold_val;
  logic [1:0] nq_count,nq_gold_count,bq_count,bq_gold_count;
  cgra_queue #(.WIDTH(191),.DEPTH(2)) normal_q (
    .clk,.reset,.clear(1'b0),.recv_msg(q_msg),.recv_val(q_val),.recv_rdy(nq_rdy),
    .send_msg(nq_msg),.send_val(nq_val),.send_rdy(q_ready),.count(nq_count));
  NormalQueueRTL__27b5f6f42d39604e normal_gold (
    .clk,.reset,.recv__msg(q_msg),.recv__val(q_val),.recv__rdy(nq_gold_rdy),
    .send__msg(nq_gold_msg),.send__val(nq_gold_val),.send__rdy(q_ready),.count(nq_gold_count));
  cgra_queue #(.WIDTH(191),.DEPTH(2),.BYPASS(1)) bypass_q (
    .clk,.reset,.clear(1'b0),.recv_msg(q_msg),.recv_val(q_val),.recv_rdy(bq_rdy),
    .send_msg(bq_msg),.send_val(bq_val),.send_rdy(q_ready),.count(bq_count));
  BypassQueueRTL__27b5f6f42d39604e bypass_gold (
    .clk,.reset,.recv__msg(q_msg),.recv__val(q_val),.recv__rdy(bq_gold_rdy),
    .send__msg(bq_gold_msg),.send__val(bq_gold_val),.send__rdy(q_ready),.count(bq_gold_count));

  logic [193:0] b1_input, b1_msg, b1_gold_msg;
  logic b1_val,b1_gold_val,b1_rdy,b1_gold_rdy,b1_count,b1_gold_count;
  cgra_queue #(.WIDTH(194),.DEPTH(1),.BYPASS(1)) bypass_one (
    .clk,.reset,.clear(1'b0),.recv_msg(b1_input),.recv_val(q_val),.recv_rdy(b1_rdy),
    .send_msg(b1_msg),.send_val(b1_val),.send_rdy(q_ready),.count(b1_count));
  BypassQueueRTL__d2ce06ef3a7ce29e bypass_one_gold (
    .clk,.reset,.recv__msg(b1_input),.recv__val(q_val),.recv__rdy(b1_gold_rdy),
    .send__msg(b1_gold_msg),.send__val(b1_gold_val),.send__rdy(q_ready),.count(b1_gold_count));

  logic [6:0] requests, grants, gold_grants;
  logic arb_en;
  cgra_round_robin #(.INPUTS(7)) rr (.clk,.reset,.en(arb_en),.reqs(requests),.grants);
  RoundRobinArbiterEn__nreqs_7 rr_gold (.clk,.reset,.en(arb_en),.reqs(requests),.grants(gold_grants));

  logic [34:0] rf_data [0:0], rf_gold_data [0:0], rf_write [0:0];
  logic [2:0] rf_ra [0:0], rf_wa [0:0];
  logic rf_we [0:0];
  cgra_register_file #(.WIDTH(35),.DEPTH(8)) rf (
    .clk,.reset,.raddr(rf_ra),.rdata(rf_data),.waddr(rf_wa),.wdata(rf_write),.wen(rf_we));
  RegisterFile__14fb828f022f9b03 rf_gold (
    .clk,.reset,.raddr(rf_ra),.rdata(rf_gold_data),.waddr(rf_wa),.wdata(rf_write),.wen(rf_we));

  logic [194:0] x_input [0:6], x_msg [0:0], x_gold_msg [0:0];
  logic x_val [0:6],x_rdy [0:6],x_gold_rdy [0:6],x_outval [0:0],x_gold_val [0:0],x_ready [0:0];
  cgra_xbar #(.WIDTH(195),.INPUTS(7),.OUTPUTS(1),.DST_LSB(194),.DST_WIDTH(1)) xbar (
    .clk,.reset,.recv_msg(x_input),.recv_val(x_val),.recv_rdy(x_rdy),
    .send_msg(x_msg),.send_val(x_outval),.send_rdy(x_ready));
  XbarRTL__b5022c8fd1dc7623 xbar_gold (
    .clk,.reset,.recv__msg(x_input),.recv__val(x_val),.recv__rdy(x_gold_rdy),
    .send__msg(x_gold_msg),.send__val(x_gold_val),.send__rdy(x_ready));

  logic [51:0] bx_input [0:2], bx_msg [0:3], bx_gold_msg [0:3];
  logic bx_val [0:2],bx_rdy [0:2],bx_gold_rdy [0:2],bx_outval [0:3],bx_gold_val [0:3],bx_ready [0:3];
  cgra_xbar #(.WIDTH(52),.INPUTS(3),.OUTPUTS(4),.DST_LSB(48),.DST_WIDTH(2),.INPUT_BYPASS(1)) bxbar (
    .clk,.reset,.recv_msg(bx_input),.recv_val(bx_val),.recv_rdy(bx_rdy),
    .send_msg(bx_msg),.send_val(bx_outval),.send_rdy(bx_ready));
  XbarBypassQueueRTL__8ef00c39f57f0208 bxbar_gold (
    .clk,.reset,.recv__msg(bx_input),.recv__val(bx_val),.recv__rdy(bx_gold_rdy),
    .send__msg(bx_gold_msg),.send__val(bx_gold_val),.send__rdy(bx_ready));

  logic [190:0] ring_input [0:4],ring_msg [0:4],ring_gold_msg [0:4];
  logic ring_val [0:4],ring_rdy [0:4],ring_gold_rdy [0:4],ring_outval [0:4],ring_gold_val [0:4],ring_ready [0:4];
  int ring_accepted=0,ring_delivered=0;
  cgra_credit_ring ring (
    .clk,.reset,.recv_msg(ring_input),.recv_val(ring_val),.recv_rdy(ring_rdy),
    .send_msg(ring_msg),.send_val(ring_outval),.send_rdy(ring_ready));
  RingNetworkRTL__06419ffd7f2ed639 ring_gold (
    .clk,.reset,.recv__msg(ring_input),.recv__val(ring_val),.recv__rdy(ring_gold_rdy),
    .send__msg(ring_gold_msg),.send__val(ring_gold_val),.send__rdy(ring_ready));

  initial begin
    for(cycle=0;cycle<500;cycle++) begin
      @(negedge clk);
      reset=(cycle<3)||((cycle>=200)&&(cycle<203));
      q_msg=random_packet(); b1_input=194'({random_word(),random_packet()});
      q_val=1'(random_word()); q_ready=1'(random_word());
      requests=7'(random_word()); arb_en=1'(random_word());
      rf_ra[0]=3'(random_word());rf_wa[0]=3'(random_word());
      rf_write[0]=35'({random_word(),random_word()});rf_we[0]=1'(random_word());
      for(int i=0;i<7;i++) begin
        x_input[i]=195'({random_word(),random_packet()});x_input[i][194]=0;
        x_val[i]=1'(random_word());
      end
      x_ready[0]=1'(random_word());
      for(int i=0;i<3;i++) begin
        bx_input[i]=52'({random_word(),random_word()});bx_val[i]=1'(random_word());
      end
      for(int o=0;o<4;o++) bx_ready[o]=1'(random_word());
      for(int n=0;n<5;n++) begin
        ring_input[n]=random_packet();
        ring_input[n][187:185]=3'(random_word()%5);
        ring_input[n][190:188]=3'(n);
        ring_input[n][170]=0;
        ring_val[n]=(cycle<400)&&1'(random_word());
        ring_ready[n]=(cycle>=400)||1'(random_word());
      end
      @(posedge clk);
      same("normal",256'({nq_count,nq_rdy,nq_val,nq_msg}),256'({nq_gold_count,nq_gold_rdy,nq_gold_val,nq_gold_msg}));
      same("bypass2",256'({bq_count,bq_rdy,bq_val,bq_msg}),256'({bq_gold_count,bq_gold_rdy,bq_gold_val,bq_gold_msg}));
      same("bypass1",256'({b1_count,b1_rdy,b1_val,b1_msg}),256'({b1_gold_count,b1_gold_rdy,b1_gold_val,b1_gold_msg}));
      same("round_robin",256'(grants),256'(gold_grants));
      same("register_file",256'(rf_data[0]),256'(rf_gold_data[0]));
      for(int i=0;i<7;i++) same("xbar_rdy",256'(x_rdy[i]),256'(x_gold_rdy[i]));
      same("xbar_output",256'({x_outval[0],x_msg[0]}),256'({x_gold_val[0],x_gold_msg[0]}));
      for(int i=0;i<3;i++) same("bypass_xbar_rdy",256'(bx_rdy[i]),256'(bx_gold_rdy[i]));
      for(int o=0;o<4;o++) same("bypass_xbar_output",256'({bx_outval[o],bx_msg[o]}),256'({bx_gold_val[o],bx_gold_msg[o]}));
      if(reset) begin ring_accepted=0;ring_delivered=0;end
      for(int n=0;n<5;n++) begin
        same($sformatf("ring_node%0d",n),256'({ring_rdy[n],ring_outval[n],ring_msg[n]}),256'({ring_gold_rdy[n],ring_gold_val[n],ring_gold_msg[n]}));
        if(!reset) begin
          if(ring_val[n]&&ring_rdy[n])ring_accepted++;
          if(ring_outval[n]&&ring_ready[n])ring_delivered++;
        end
      end
    end
    if(ring_accepted != ring_delivered || ring_accepted < 100)
      $fatal(1,"Ring conservation/coverage failure accepted=%0d delivered=%0d",ring_accepted,ring_delivered);
    $display("NATIVE_NOC_PASS cycles=500 seed=31415926 ring_accepted=%0d ring_delivered=%0d full_invalid_msg_comparison=1",ring_accepted,ring_delivered);
    $finish;
  end
endmodule
