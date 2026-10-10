`timescale 1ns/1ps
module tb_loop_controller_native #(
  parameter int DATA_W=32, CTRL_BITS=107, NUM_CCUS=8, MAX_TARGETS=4,
  parameter int DATA_ADDR_W=3, CTRL_ADDR_W=3,
  parameter bit LEGACY_DISPATCH_WRAP=0, LEGACY_PYTHON=0,
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
    .LEGACY_PYTHON(LEGACY_PYTHON),.LEGACY_DISPATCH_WRAP(LEGACY_DISPATCH_WRAP)) dut(.*);
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
    require(all_loops_complete==LEGACY_PYTHON && !send_to_tile__val && !send_to_remote__val,"idle/reset");
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
  task automatic remote_complete(input integer ccu=0);
    recv_from_remote__msg=packet(40,0,0,ccu); recv_from_remote__val=1;
    #1; require(recv_from_remote__rdy,"remote completion accepted"); tick(); recv_from_remote__val=0;
  endtask
  task automatic quiet(input string reason);
    #1; require(!send_to_tile__val && !send_to_remote__val,reason);
  endtask
  task automatic dispatch(input bit remote, shadow, input int addr, input word_t value=0);
    logic [P-1:0] expected;
    expected=packet(shadow ? 26 : 27,shadow ? value : word_t'(0),shadow,addr);
    if (bad_oracle) expected[0]=~expected[0];
    // Registered ancestor notifications may add bounded latency before dispatch.
    for (integer wait_cycle=0;wait_cycle<NUM_CCUS+3 && !send_to_tile__val && !send_to_remote__val;wait_cycle++) tick();
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

  task automatic both(input integer tile_addr=0, remote_ccu=0);
    recv_from_tile__val=1;recv_from_tile__msg=packet(31,0,0,tile_addr);
    recv_from_remote__val=1;recv_from_remote__msg=packet(40,0,0,remote_ccu);
    #1;require(recv_from_tile__rdy && recv_from_remote__rdy,"both completions accepted");
    tick();recv_from_tile__val=0;recv_from_remote__val=0;#1;
  endtask
  task automatic defect(input string name);
    logic [P-1:0] held;
    restart();
    if (name=="complete") begin
      require(!all_loops_complete,"DEFECT_COMPLETE");
    end else if (name=="simultaneous") begin
      setup_ccu(0,0,2,1,2,1);target(0,0);config_word(38);both();
      require(send_to_tile__val,"DEFECT_SIMULTANEOUS");
      dispatch(0,0,0);both();require(all_loops_complete,"simultaneous terminal count");
    end else if (name=="siblings") begin
      setup_ccu(0,0,1,1,2,1);target(0,2,0,1);
      setup_ccu(1,0,1,1,1,0,0);target(1,0);
      setup_ccu(2,0,1,1,1,0,0);target(2,1,1,1);
      config_word(38);both(0,2);repeat(NUM_CCUS+1) tick();require(all_loops_complete,"DEFECT_SIBLINGS");
    end else if (name=="grandparent") begin
      setup_ccu(0,0,1,1,1,1);target(0,2,0,1);
      setup_ccu(1,0,1,1,1,0,0);target(1,1,0,1);
      setup_ccu(2,0,1,1,1,0,1);target(2,0);
      config_word(38);leaf();repeat(NUM_CCUS+1) tick();#1;require(all_loops_complete,"DEFECT_GRANDPARENT");
    end else if (name=="remote_target") begin
      setup_ccu(0,0,2,1,1,1);target(0,0,1,1);
      setup_ccu(1,0,2,1,1,1);target(1,1,1,1);
      config_word(38);remote_complete(1);#1;
      require(send_to_remote__val && send_to_remote__msg==packet(26,1,1,1),"DEFECT_REMOTE_TARGET");
      dispatch(1,1,1,1);remote_complete(1);#1;require(!all_loops_complete,"other root still running");
      remote_complete(0);dispatch(1,1,0,1);remote_complete(0);#1;require(all_loops_complete,"addressed roots finish");
    end else if (name=="preempt") begin
      setup_ccu(0,0,2,1,1,1);target(0,0);
      setup_ccu(1,0,2,1,1,1);target(1,1);
      config_word(38);leaf(1);#1;held=send_to_tile__msg;
      require(send_to_tile__val && held==packet(27,0,0,1),"high CCU offers first");
      tick();leaf(0);#1;
      require(send_to_tile__val && send_to_tile__msg===held,"DEFECT_PREEMPT");
      dispatch(0,0,1);dispatch(0,0,0);leaf(1);leaf(0);#1;require(all_loops_complete,"held arbitration completes");
    end else if (name=="reset") begin
      setup_ccu(0,0,2,1,1,1);target(0,0);config_word(38);leaf();
      recv_config__val=1;recv_config__msg=packet(32);reset=1;#1;
      require(!send_to_tile__val && !send_to_remote__val && !recv_config__rdy &&
        !recv_from_tile__rdy && !recv_from_remote__rdy && !all_loops_complete,"DEFECT_RESET");
      tick();reset=0;idle_inputs();
    end else if (name=="busy_config") begin
      setup_ccu(0,0,3,1,1,1);target(0,0,1,1);config_word(38);remote_complete();
      recv_config__val=1;recv_config__msg=packet(32,777,1);#1;
      require(!recv_config__rdy,"DEFECT_BUSY_CONFIG");
      dispatch(1,1,0,1);remote_complete();dispatch(1,1,0,2);remote_complete();
      #1;require(all_loops_complete && recv_config__rdy,"configuration released after completion");
      tick();recv_config__val=0;#1;require(!all_loops_complete && recv_config__rdy,"reconfiguration opens new configuration phase");
    end else $fatal(1,"LOOP_UNKNOWN_DEFECT");
    $display("LOOP_SEMANTIC_FIXED %s",name);
  endtask
  task automatic invalid_config(input string kind);
    restart();
    if ((kind=="NO_ROOT")) begin config_word(38);$fatal(1,"missing no-root rejection");end
    setup_ccu(0,0,2,(kind=="RANGE")?0:1,1,1);
    if ((kind=="CCU")) begin config_word(32,0,NUM_CCUS);$fatal(1,"missing CCU rejection");end
    if ((kind=="PARENT")) begin config_word(37,word_t'(NUM_CCUS));$fatal(1,"missing parent rejection");end
    if ((kind=="TARGET")) begin
      for(integer t=0;t<=MAX_TARGETS;t++) target(0,0);
      $fatal(1,"missing target rejection");
    end
    if ((kind=="PARENT_CYCLE")) begin
      setup_ccu(0,0,2,1,1,0,1);setup_ccu(1,0,2,1,1,0,0);
    end
    if ((kind=="PARENT_UNCONFIGURED")) setup_ccu(1,0,2,1,1,0,2);
    config_word(38);$fatal(1,"missing invalid-configuration rejection");
  endtask
  task automatic native_tests;
    word_t lo;
    lo=DATA_W>32?(word_t'(1)<<40)+7:word_t'(7);
    restart();require(!all_loops_complete,"no execution means no completion");
    setup_ccu(0,lo,lo+6,2,2,1);
    for (integer t=0;t<MAX_TARGETS;t++) target(0,t,t%2==1,t!=0);
    config_word(38);
    for (integer iteration=1;iteration<=3;iteration++) begin
      leaf();quiet("barrier waits for second completion");leaf();
      if (iteration<3) for (integer t=0;t<MAX_TARGETS;t++) dispatch(t%2==1,t!=0,t,lo+word_t'(2*iteration));
    end
    #1;require(all_loops_complete,"all targets dispatched once per iteration");
    config_word(38);leaf();leaf();#1;require(send_to_tile__val,"relaunch");restart();
    // Two accepted credits for threshold one must survive the intervening dispatch.
    setup_ccu(0,0,2,1,1,1);target(0,0);config_word(38);both();dispatch(0,0,0);tick();#1;
    require(all_loops_complete,"accepted surplus credit retained across dispatch");
    // Extended unsigned addition terminates even if DATA_W addition would wrap.
    restart();setup_ccu(0,{DATA_W{1'b1}}-2,{DATA_W{1'b1}},5,1,1);target(0,0);config_word(38);leaf();
    #1;require(all_loops_complete,"counter overflow crosses upper bound");
    defect("complete");defect("simultaneous");defect("reset");defect("busy_config");
    if (NUM_CCUS>=2 && CTRL_ADDR_W>=2) begin
      defect("preempt");defect("remote_target");
      restart();setup_ccu(0,0,1,1,1,1);config_word(38);remote_complete();require(all_loops_complete,"first execution done");
      setup_ccu(1,0,1,1,1,1);require(!all_loops_complete,"new CCU invalidates completed program");config_word(38);
      remote_complete(0);remote_complete(1);require(all_loops_complete,"new CCU added without reset");
    end
    if (NUM_CCUS>=3 && CTRL_ADDR_W>=2) begin
      defect("siblings");defect("grandparent");
      // Three nested binary loops: eight leaf completions, seven dispatches.
      restart();setup_ccu(0,0,2,1,1,1);target(0,2,0,1);
      setup_ccu(1,0,2,1,1,0,0);target(1,1,0,1);
      setup_ccu(2,0,2,1,1,0,1);target(2,0);config_word(38);
      for (integer outer=0;outer<2;outer++) begin
        for (integer middle=0;middle<2;middle++) begin
          leaf();dispatch(0,0,0);leaf();
          if (middle==0) dispatch(0,1,1,1);
        end
        if (outer==0) dispatch(0,1,2,1);
      end
      repeat(NUM_CCUS+1) tick();#1;require(all_loops_complete,"complete configured subtree restarts");quiet("no terminal dispatch");
      // Targetless parents are configured and launched; remote leaf completion
      // propagates through both ancestors without a broadcast side effect.
      restart();setup_ccu(0,0,1,1,1,1);setup_ccu(1,0,1,1,1,0,0);
      setup_ccu(2,0,1,1,1,0,1);target(2,0,1,1);config_word(38);remote_complete(2);
      repeat(NUM_CCUS+1) tick();#1;require(all_loops_complete,"remote parent and grandparent notification");
      // Adding a new root after completion must reopen configuration fully.
      setup_ccu(2,0,1,1,1,1);config_word(38);
      remote_complete(2);repeat(NUM_CCUS+1) tick();
      // Root 0 waits on middle 1; its child was reconfigured as an independent root.
      require(!all_loops_complete,"new root reconfiguration retains unfinished roots");
      remote_complete(1);repeat(NUM_CCUS+1) tick();require(all_loops_complete,"reconfigured roots finish");
      // A root completing cannot hide a still-running independent configured CCU.
      restart();setup_ccu(0,0,1,1,1,1);setup_ccu(1,0,2,1,1,1);target(1,0,1,1);
      config_word(38);remote_complete(0);#1;require(!all_loops_complete,"all configured roots participate");
    end
    restart();
    $display("LOOP_NATIVE_SEMANTICS_PASS width=%0d ccus=%0d targets=%0d checks=%0d dispatches=%0d",DATA_W,NUM_CCUS,MAX_TARGETS,checks,dispatches);
  endtask
  string name;
  initial begin
    bad_oracle=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("DEFECT=%s",name)) defect(name);
    else if ($value$plusargs("INVALID=%s",name)) invalid_config(name);
    else if ($test$plusargs("EMPTY_LAUNCH")) begin
      restart();config_word(38);repeat(5) tick();
      require(!all_loops_complete && !send_to_tile__val && !send_to_remote__val,"empty launch never signals completion");
      $display("LOOP_EMPTY_LAUNCH_INERT");
    end
    else native_tests();
    $finish;
  end
  initial begin #1000000;$fatal(1,"LOOP_TIMEOUT");end
endmodule
