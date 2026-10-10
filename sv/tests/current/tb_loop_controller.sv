`timescale 1ns/1ps
module tb_loop_controller #(
  parameter int DATA_W=32, CTRL_BITS=107, NUM_CCUS=8, MAX_TARGETS=4,
  parameter int DATA_ADDR_W=3, CTRL_ADDR_W=3,
  parameter bit LEGACY_DISPATCH_WRAP=0,
  localparam int P=6+DATA_W+3+DATA_ADDR_W+CTRL_BITS+CTRL_ADDR_W,
  localparam int CCU_W=NUM_CCUS>1 ? $clog2(NUM_CCUS) : 1
);
  logic clk=0, reset=0;
  logic [P-1:0] recv_config__msg=0, recv_from_tile__msg=0, recv_from_remote__msg=0;
  logic recv_config__val=0, recv_from_tile__val=0, recv_from_remote__val=0;
  logic recv_config__rdy, recv_from_tile__rdy, recv_from_remote__rdy;
  logic [P-1:0] send_to_tile__msg, send_to_remote__msg;
  logic send_to_tile__val, send_to_remote__val, send_to_tile__rdy=0, send_to_remote__rdy=0;
  logic all_loops_complete;
`ifdef LOOP_POST_SYNTH
  cgra_loop_controller_netlist dut(.*);
`else
  cgra_loop_controller #(.DATA_W(DATA_W),.CTRL_BITS(CTRL_BITS),.NUM_CCUS(NUM_CCUS),
    .MAX_TARGETS(MAX_TARGETS),.DATA_ADDR_W(DATA_ADDR_W),.CTRL_ADDR_W(CTRL_ADDR_W),
    .LEGACY_PYTHON(1),.LEGACY_DISPATCH_WRAP(LEGACY_DISPATCH_WRAP)) dut(.*);
`endif
  int checks /* verilator public_flat_rw */ = 0;
  int samples /* verilator public_flat_rw */ = 0;
  int dispatches /* verilator public_flat_rw */ = 0;
  bit bad_oracle;
  typedef logic [DATA_W-1:0] word_t;
  function automatic logic [P-1:0] packet(input int cmd, input word_t value=0,
    input bit predicate=0, input int addr=0, input int data_addr=0);
    return {6'(cmd),value,predicate,2'b00,DATA_ADDR_W'(data_addr),{CTRL_BITS{1'b0}},CTRL_ADDR_W'(addr)};
  endfunction
  task automatic require(input bit condition, input string reason);
    checks++;
    if (!condition) $fatal(1,"LOOP_CHECK %s checks=%0d",reason,checks);
  endtask
  task automatic tick;
    #2; clk=1; #2; clk=0; #2;
  endtask
  task automatic idle_inputs;
    recv_config__val=0; recv_from_tile__val=0; recv_from_remote__val=0;
    recv_config__msg=0; recv_from_tile__msg=0; recv_from_remote__msg=0;
    send_to_tile__rdy=0; send_to_remote__rdy=0;
  endtask
  task automatic restart;
    idle_inputs(); reset=1; tick(); reset=0; #1;
    require(all_loops_complete && !send_to_tile__val && !send_to_remote__val,"idle/reset");
  endtask
  task automatic config_word(input int cmd, input word_t value=0, input int ccu=0,
    input bit predicate=0, input int data_addr=0);
    recv_config__val=1; recv_config__msg=packet(cmd,value,predicate,ccu,data_addr);
    #1; require(recv_config__rdy,"configuration accepted"); tick(); recv_config__val=0;
  endtask
  task automatic setup_ccu(input int ci, input word_t lo, hi, stride,
    input int children, input bit root, input int parent=0);
    config_word(32,lo,ci,1); config_word(33,hi,ci,1); config_word(34,stride,ci,1);
    config_word(35,word_t'(children),ci);
    config_word(37,word_t'(parent | (int'(root)<<CCU_W)),ci);
  endtask
  task automatic target(input int ci, addr, input bit remote=0, shadow=0);
    config_word(36,word_t'(addr),ci,remote,int'(shadow)<<(DATA_ADDR_W-1));
  endtask
  task automatic leaf(input int addr=0);
    recv_from_tile__msg=packet(31,0,0,addr); recv_from_tile__val=1;
    #1; require(recv_from_tile__rdy,"leaf completion accepted"); tick(); recv_from_tile__val=0;
  endtask
  task automatic remote_complete;
    recv_from_remote__msg=packet(40); recv_from_remote__val=1;
    #1; require(recv_from_remote__rdy,"remote completion accepted"); tick(); recv_from_remote__val=0;
  endtask
  task automatic quiet(input string reason);
    #1; require(!send_to_tile__val && !send_to_remote__val,reason);
  endtask
  task automatic dispatch(input bit remote, shadow, input int addr, input word_t value=0);
    logic [P-1:0] expected;
    expected=packet(shadow ? 26 : 27,shadow ? value : word_t'(0),shadow,addr);
    if (bad_oracle) expected[0]=~expected[0];
    // The inactive output can be ready while the selected output is stalled.
    for (int k=0;k<3;k++) begin
      send_to_tile__rdy=remote && k[0]; send_to_remote__rdy=!remote && k[0];
      #1;
      require(send_to_tile__val == !remote && send_to_remote__val == remote,"dispatch destination");
      require((remote ? send_to_remote__msg : send_to_tile__msg) === expected,"dispatch payload / stable under backpressure");
      require((remote ? send_to_tile__msg : send_to_remote__msg) == 0,"inactive message zero");
      require(!all_loops_complete,"root still active while dispatching");
      tick();
    end
    send_to_tile__rdy=!remote; send_to_remote__rdy=remote;
    tick(); dispatches++; send_to_tile__rdy=0; send_to_remote__rdy=0;
  endtask

  task automatic native_tests;
    word_t lo;
    lo=DATA_W>32 ? (word_t'(1)<<40)+7 : word_t'(7);
    restart();
    // Unmatched completion is held, but unknown commands are consumed.
    recv_from_tile__val=1; recv_from_tile__msg=packet(31);
    recv_from_remote__val=1; recv_from_remote__msg=packet(40);
    #1; require(!recv_from_tile__rdy && !recv_from_remote__rdy,"idle completions held");
    recv_from_tile__msg=packet(0); recv_from_remote__msg=packet(0);
    #1; require(recv_from_tile__rdy && recv_from_remote__rdy,"unknown events ignored");
    idle_inputs();
    setup_ccu(0,lo,lo+6,2,2,1);
    for(int t=0;t<MAX_TARGETS;t++) target(0,t,t%2==1,t!=0);
    if ($test$plusargs("INVALID_TARGET")) begin target(0,0); $fatal(1,"missing capacity rejection"); end
    if ($test$plusargs("INVALID_CCU")) begin config_word(32,0,NUM_CCUS); $fatal(1,"missing CCU rejection"); end
    if ($test$plusargs("INVALID_PARENT")) begin config_word(37,word_t'(NUM_CCUS),0); $fatal(1,"missing parent rejection"); end
    config_word(38);
    #1; require(!all_loops_complete,"launch active"); quiet("no initial dispatch");
    for(int iteration=1;iteration<=3;iteration++) begin
      leaf(); quiet("barrier waits for second event");
      leaf();
      if(iteration<3) begin
        for(int t=0;t<MAX_TARGETS;t++) dispatch(t%2==1,t!=0,t,lo+word_t'(2*iteration));
        quiet("all targets dispatched exactly once");
      end
    end
    #1; require(all_loops_complete,"capacity loop completed");
    repeat(4) begin quiet("no stale terminal dispatch"); tick(); end
    // Relaunch retains configuration; reset discards it even mid-dispatch.
    config_word(38); leaf(); leaf();
    #1; require(send_to_tile__val,"relaunch"); restart();

    // Shadow to remote path with nonzero upper DATA_W bits and unknown ctrl.
    setup_ccu(0,lo,lo+6,3,1,1); target(0,0,1,1); config_word(38);
    remote_complete(); dispatch(1,1,0,lo+3); remote_complete();
    #1; require(all_loops_complete,"remote root completed"); quiet("remote no stale dispatch");

    if (NUM_CCUS>=2 && MAX_TARGETS>=2 && CTRL_ADDR_W>=2) begin
      restart();
      setup_ccu(0,0,2,1,1,1); target(0,1,0,1);
      setup_ccu(1,0,2,1,1,0,0); target(1,0); target(1,2,0,1);
      config_word(38);
      for(int outer=1;outer<=2;outer++) begin
        leaf(); dispatch(0,0,0); dispatch(0,1,2,1);
        leaf();
        if(outer==1) dispatch(0,1,1,1);
      end
      #1; require(all_loops_complete,"nested parent notification and child restart");
      quiet("nested terminal dispatch suppressed");

      restart();
      setup_ccu(0,0,2,1,1,1); target(0,0,1,1);
      setup_ccu(1,10,12,1,1,1); target(1,1,0,1);
      config_word(38); remote_complete();
      // Both CCUs dispatch after the broadcast. Lowest index has priority.
      dispatch(1,1,0,1); dispatch(0,1,1,11);
      remote_complete();
      #1; require(all_loops_complete,"two independent roots / remote broadcast");
      quiet("priority arbitration drain");
    end
    require(dispatches>=2*MAX_TARGETS+1,"native dispatch coverage");
    $display("LOOP_NATIVE_PASS width=%0d ccus=%0d targets=%0d checks=%0d dispatches=%0d",DATA_W,NUM_CCUS,MAX_TARGETS,checks,dispatches);
  endtask

  task automatic replay(input string path);
    int fd, rc;
    logic [3*P+5:0] in_bits;
    logic [2*P+5:0] expected, actual;
    fd=$fopen(path,"r"); if(!fd) $fatal(1,"LOOP_FILE %s",path);
    restart();
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",in_bits,expected);
      if(rc!=2) $fatal(1,"LOOP_FORMAT sample=%0d",samples);
      {reset,recv_config__val,recv_config__msg,recv_from_tile__val,recv_from_tile__msg,
       recv_from_remote__val,recv_from_remote__msg,send_to_tile__rdy,send_to_remote__rdy}=in_bits;
      #1;
      actual={all_loops_complete,recv_config__rdy,recv_from_tile__rdy,recv_from_remote__rdy,
              send_to_tile__val,send_to_tile__msg,send_to_remote__val,send_to_remote__msg};
      if(bad_oracle && samples==1) expected[0]=~expected[0];
      if(!reset && actual !== expected)
        $fatal(1,"LOOP_REPLAY_MISMATCH sample=%0d actual=%h expected=%h",samples,actual,expected);
      tick(); samples++;
    end
    $fclose(fd);
    require(samples>400,"replay includes extended scenarios");
    $display("LOOP_REPLAY_PASS width=%0d ccus=%0d targets=%0d samples=%0d output_bits=%0d",DATA_W,NUM_CCUS,MAX_TARGETS,samples,2*P+6);
  endtask

  string vectors;
  initial begin
    bad_oracle=$test$plusargs("EXPECT_FAILURE");
    if($value$plusargs("VECTORS=%s",vectors)) replay(vectors);
    else native_tests();
    $finish;
  end
  initial begin #1000000; $fatal(1,"LOOP_TIMEOUT"); end
endmodule
