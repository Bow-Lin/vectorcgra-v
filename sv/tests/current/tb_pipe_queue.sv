`timescale 1ns/1ps
module tb_pipe_queue #(
  parameter integer DATA_BITS=35,DEPTH=2,
  parameter bit LEGACY_PYTHON=0,USE_NORMAL_QUEUE=0,BAD_WIDTH=0
);
  localparam integer COUNT_W=$clog2(DEPTH+1),IN_BITS=DATA_BITS+3,OUT_BITS=DATA_BITS+COUNT_W+2;
  logic clk=0,reset=0,recv__val=0,recv__rdy,send__val,send__rdy=0;
  logic [DATA_BITS-1:0] recv__msg='0,send__msg;
  logic [COUNT_W-1:0] count;
`ifdef PIPE_QUEUE_POST_SYNTH
  pipe_queue_netlist dut (.*);
`else
  if (USE_NORMAL_QUEUE) begin : normal_mutant
    cgra_queue #(.WIDTH(DATA_BITS),.DEPTH(DEPTH)) dut (.clk,.reset,.clear(1'b0),
      .recv_msg(recv__msg),.recv_val(recv__val),.recv_rdy(recv__rdy),
      .send_msg(send__msg),.send_val(send__val),.send_rdy(send__rdy),.count);
  end else begin : pipe
    cgra_pipe_queue #(.DATA_BITS(DATA_BITS),.DEPTH(DEPTH),.LEGACY_PYTHON(LEGACY_PYTHON),
      .COUNT_W(COUNT_W+int'(BAD_WIDTH))) dut (.*);
  end
`endif
  logic [DATA_BITS-1:0] expected_queue[$];
  logic [31:0] rng=32'h320ca;
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  integer enqueued /* verilator public_flat_rw */ =0;
  integer dequeued /* verilator public_flat_rw */ =0;
  integer replacements /* verilator public_flat_rw */ =0;
  integer discarded /* verilator public_flat_rw */ =0;
  bit wrong;
  function automatic logic [31:0] rand32();
    rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);return rng;
  endfunction
  function automatic logic [DATA_BITS-1:0] randword();
    logic [DATA_BITS-1:0] v;
    v='0;for (integer i=0;i<DATA_BITS;i+=16) v=(v<<16)|DATA_BITS'(rand32()&65535);return v;
  endfunction
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  task automatic require(input bit ok,input string label);
    checks++;if (!ok) $fatal(1,"PIPE_QUEUE_CHECK %s sample=%0d",label,samples);
  endtask
  task automatic replay(input string path);
    integer fd,scan;
    logic [IN_BITS-1:0] ins;
    logic [OUT_BITS-1:0] expected;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"PIPE_QUEUE_VECTOR_FORMAT");
      {reset,recv__val,recv__msg,send__rdy}=ins;#1;
      if (wrong && samples==4) expected=expected^1;
      if ({recv__rdy,send__val,send__msg,count}!==expected)
        $fatal(1,"PIPE_QUEUE_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,{recv__rdy,send__val,send__msg,count},expected);
      samples++;tick();
    end
    $fclose(fd);require(samples==311+DEPTH,"replay coverage");
    $display("PIPE_QUEUE_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic check_native;
    bit expected_ready,expected_valid,put,get;
    integer expected_count;
    logic [DATA_BITS-1:0] expected_word,popped;
    expected_count=reset?0:expected_queue.size();
    expected_valid=!reset && expected_queue.size()!=0;
    expected_ready=!reset && (expected_queue.size()<DEPTH || send__rdy);
    expected_word=expected_valid?expected_queue[0]:'0;
    if (wrong && samples==4) expected_count=expected_count^1;
    #1;require(count==expected_count,"occupancy");
    require(recv__rdy==expected_ready,"PIPE_READY full replacement");
    require(send__val==expected_valid,"registered output valid / no empty bypass");
    require(send__msg===expected_word,"FIFO order and every message bit");
    put=recv__val && expected_ready;get=send__rdy && expected_valid;
    if (reset) begin discarded+=expected_queue.size();expected_queue.delete();end
    else begin
      if (expected_queue.size()==DEPTH && put && get) replacements++;
      if (get) begin popped=expected_queue.pop_front();dequeued++;end
      if (put) begin expected_queue.push_back(recv__msg);enqueued++;end
    end
    samples++;tick();
  endtask
  task automatic native_checks;
    bit held;
    reset=1;check_native();reset=0;
    recv__val=1;send__rdy=0;
    for (integer i=0;i<DEPTH;i++) begin recv__msg=DATA_BITS'(i+1);check_native();end
    // Every cycle must accept a replacement while retaining full occupancy.
    send__rdy=1;
    for (integer i=0;i<40;i++) begin recv__msg=randword();check_native();end
    send__rdy=0;recv__msg=randword();repeat(8) check_native();
    send__rdy=1;check_native();
    for (integer n=0;n<400;n++) begin
      reset=(n==83 || n==84 || n==207 || n==301);
      held=recv__val && !recv__rdy && !reset;
      if (!held) begin recv__val=1'(rand32());recv__msg=randword();end
      send__rdy=(rand32()%3!=0);check_native();
    end
    reset=0;recv__val=0;send__rdy=1;
    repeat(DEPTH+2) check_native();
    require(expected_queue.size()==0 && enqueued==dequeued+discarded,"FIFO conservation across reset");
    require(replacements>=40,"full replacement coverage");
    $display("PIPE_QUEUE_NATIVE_PASS samples=%0d checks=%0d enqueued=%0d dequeued=%0d discarded=%0d replacements=%0d",
      samples,checks,enqueued,dequeued,discarded,replacements);
  endtask
  task automatic full_replacement;
    reset=1;tick();reset=0;recv__val=1;
    for (integer n=0;n<DEPTH;n++) begin recv__msg=DATA_BITS'(n);tick();end
    send__rdy=1;#1;require(recv__rdy,"DEFECT_NORMAL_FULL_REPLACE");
    tick();require(count==DEPTH,"replacement preserves occupancy");
    $display("PIPE_QUEUE_FULL_REPLACE_PASS");
  endtask
  task automatic reset_handshake;
    reset=1;tick();reset=0;recv__val=1;tick();recv__val=0;reset=1;#1;
    require(!recv__rdy && !send__val,"DEFECT_RESET_HANDSHAKE");
    $display("PIPE_QUEUE_RESET_FIXED");
  endtask
  string path;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($test$plusargs("FULL_REPLACE")) full_replacement();
    else if ($test$plusargs("RESET_HANDSHAKE")) reset_handshake();
    else native_checks();
    $finish;
  end
endmodule
