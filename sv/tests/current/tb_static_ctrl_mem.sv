`timescale 1ns/1ps
module tb_static_ctrl_mem #(
  parameter integer CTRL_BITS=119, DEPTH=4, COUNT_PER_ITER=4, TOTAL_STEPS=9,
  parameter bit LEGACY_PYTHON=0,
  parameter integer OP_LSB=CTRL_BITS-7,
  parameter integer ADDR_W=(DEPTH>1)?$clog2(DEPTH):1
);
  logic clk=0, reset=0;
  logic [ADDR_W-1:0] recv_waddr__msg='0;
  logic recv_waddr__val=0, recv_waddr__rdy;
  logic [CTRL_BITS-1:0] recv_ctrl__msg='0, send_ctrl__msg;
  logic recv_ctrl__val=0, recv_ctrl__rdy, send_ctrl__val, send_ctrl__rdy=0;
`ifdef STATIC_POST_SYNTH
  cgra_static_ctrl_mem_netlist dut (.*);
`else
  cgra_static_ctrl_mem #(.CTRL_BITS(CTRL_BITS),.DEPTH(DEPTH),
    .COUNT_PER_ITER(COUNT_PER_ITER),.TOTAL_STEPS(TOTAL_STEPS),
    .OP_LSB(OP_LSB),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
`endif
  integer checks /* verilator public_flat_rw */ = 0;
  integer samples /* verilator public_flat_rw */ = 0;
  integer accepted /* verilator public_flat_rw */ = 0;
  bit wrong;
  task automatic require(input bit ok, input string label);
    checks++;
    if (!ok) $fatal(1,"STATIC_CTRL_CHECK %s checks=%0d",label,checks);
  endtask
  task automatic tick;
    #2; clk=1; #2; clk=0; #1;
  endtask
  function automatic logic [CTRL_BITS-1:0] word(input integer i);
    logic [CTRL_BITS-1:0] result;
    result='1;
    result[31:0]=32'h98abcdef ^ (i*32'h1020304);
    result[OP_LSB +: 7]=7'(i+1);
    return result;
  endfunction
  task automatic restart;
    reset=1; recv_waddr__val=0; recv_ctrl__val=0; send_ctrl__rdy=1;
    #1;
    require(!send_ctrl__val && !recv_ctrl__rdy && !recv_waddr__rdy,"reset masks handshakes");
    tick(); reset=0; send_ctrl__rdy=0; #1;
    require(!send_ctrl__val && send_ctrl__msg=='0,"reset clears program");
  endtask
  task automatic put(input integer addr, input logic [CTRL_BITS-1:0] data);
    recv_waddr__msg=ADDR_W'(addr); recv_waddr__val=1;
    recv_ctrl__msg=data; recv_ctrl__val=1; #1;
    require(recv_waddr__rdy && recv_ctrl__rdy,"paired write accepted");
    tick(); recv_waddr__val=0; recv_ctrl__val=0; #1;
  endtask
  task automatic load_program;
    // Address zero is the implicit start; write it last.
    for (integer i=COUNT_PER_ITER-1;i>=0;i--) put(i,word(i));
  endtask
  task automatic replay(input string path);
    integer fd,scan;
    logic [CTRL_BITS+ADDR_W+3:0] ins;
    logic [CTRL_BITS+2:0] expected,actual;
    fd=$fopen(path,"r"); require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"STATIC_CTRL_VECTOR_FORMAT");
      {reset,recv_waddr__val,recv_waddr__msg,recv_ctrl__val,recv_ctrl__msg,send_ctrl__rdy}=ins;
      #1;
      actual={recv_waddr__rdy,recv_ctrl__rdy,send_ctrl__val,send_ctrl__msg};
      if (wrong && samples==3) expected=expected^1;
      if (actual !== expected)
        $fatal(1,"STATIC_CTRL_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,actual,expected);
      samples++; tick();
    end
    $fclose(fd); require(samples>200,"replay coverage");
    $display("STATIC_CTRL_REPLAY_PASS samples=%0d output_bits=%0d",samples,CTRL_BITS+3);
  endtask
  task automatic native_checks;
    logic [CTRL_BITS-1:0] expected,held;
    integer target;
    restart();
    if ($test$plusargs("INVALID_ADDRESS")) begin
      recv_waddr__msg=ADDR_W'(DEPTH); recv_waddr__val=1; recv_ctrl__val=1;
      tick(); $fatal(1,"ADDRESS_ASSERTION_MISSING");
    end
    // Each half must remain pending until its partner is present.
    recv_waddr__val=1; recv_ctrl__val=0; #1;
    require(!recv_waddr__rdy,"unpaired address pending"); tick();
    recv_waddr__val=0; recv_ctrl__val=1; recv_ctrl__msg=word(7); #1;
    require(!recv_ctrl__rdy,"unpaired data pending"); tick();
    recv_ctrl__val=0; #1;
    require(!send_ctrl__val && send_ctrl__msg=='0,"unpaired halves never write");
    // Keep address asserted across a delay, then supply its data.
    recv_waddr__val=1; recv_waddr__msg=0; tick(); tick();
    recv_ctrl__val=1; recv_ctrl__msg=word(0); #1;
    require(recv_waddr__rdy && recv_ctrl__rdy,"delayed partner accepted");
    tick(); recv_waddr__val=0; recv_ctrl__val=0;
    #1; require(send_ctrl__val && send_ctrl__msg==word(0),"paired delayed word visible");
    restart(); load_program();
    // Long stalls must neither consume budget nor change the instruction.
    for (integer i=0;i<TOTAL_STEPS+20;i++) begin
      #1; expected=word(0); if (wrong && i==5) expected=expected^1;
      require(send_ctrl__val && send_ctrl__msg==expected,"stable output under stall");
      tick();
    end
    recv_waddr__msg=0; recv_waddr__val=1; recv_ctrl__val=1; recv_ctrl__msg=word(9);
    #1; require(!recv_waddr__rdy && !recv_ctrl__rdy,"protect stalled current word");
    tick(); require(send_ctrl__msg==word(0),"blocked write preserved output");
    recv_waddr__val=0; recv_ctrl__val=0;
    if (COUNT_PER_ITER>1) begin
      put(1,word(8));
      require(send_ctrl__val && send_ctrl__msg==word(0),"other-slot write while stalled");
    end
    target=(TOTAL_STEPS==0)?23:TOTAL_STEPS;
    for (integer i=0;i<target;i++) begin
      expected=(COUNT_PER_ITER>1 && i%COUNT_PER_ITER==1)?word(8):word(i%COUNT_PER_ITER);
      send_ctrl__rdy=0;
      repeat (3) begin
        #1; require(send_ctrl__val && send_ctrl__msg==expected,"cyclic stream with stalls"); tick();
      end
      send_ctrl__rdy=1; #1;
      require(send_ctrl__val && send_ctrl__msg==expected,"ordered accepted word");
      accepted++; tick();
    end
    if (TOTAL_STEPS>0) begin
      held=send_ctrl__msg;
      repeat (10) begin
        require(!send_ctrl__val && send_ctrl__msg==held,"finite budget and frozen done pointer"); tick();
      end
    end else require(send_ctrl__val,"unlimited stream still active");
    restart();
    // A START word at the next slot stops; writing that slot resumes.
    put(0,word(0)); send_ctrl__rdy=1; tick(); send_ctrl__rdy=0;
    if (COUNT_PER_ITER>1) begin
      #1; require(!send_ctrl__val && send_ctrl__msg=='0,"START sentinel blocks");
      repeat (5) tick();
      put(1,word(1)); require(send_ctrl__val && send_ctrl__msg==word(1),"replace START resumes");
    end
    restart(); load_program();
    // Accept old word while replacing the same address on that edge.
    send_ctrl__rdy=1; recv_waddr__msg=0; recv_waddr__val=1;
    recv_ctrl__val=1; recv_ctrl__msg=word(9); #1;
    require(send_ctrl__msg==word(0) && send_ctrl__val && recv_waddr__rdy && recv_ctrl__rdy,
            "read-before-write replacement"); tick();
    recv_waddr__val=0; recv_ctrl__val=0;
    for (integer i=1;i<COUNT_PER_ITER;i++) tick();
    send_ctrl__rdy=0; #1;
    require(send_ctrl__val && send_ctrl__msg==word(9),"replacement visible on next iteration");
    restart();
    $display("STATIC_CTRL_NATIVE_PASS depth=%0d period=%0d total=%0d checks=%0d accepted=%0d",
      DEPTH,COUNT_PER_ITER,TOTAL_STEPS,checks,accepted);
  endtask
  task automatic defect(input string kind);
    // Same stimulus on either implementation, isolate one historical defect.
    reset=1; tick(); reset=0;
    if (kind=="unpaired") begin
      recv_waddr__val=1; #1;
      require(!recv_waddr__rdy,"DEFECT_UNPAIRED");
    end else begin
      load_program();
      if (kind=="budget") begin
        repeat (TOTAL_STEPS+3) tick();
        require(send_ctrl__val,"DEFECT_BUDGET");
      end else begin
        reset=1; tick(); reset=0; #1;
        require(!send_ctrl__val && send_ctrl__msg=='0,"DEFECT_RESET");
      end
    end
    $display("STATIC_CTRL_DEFECT_FIXED %s",kind);
  endtask
  string path,kind;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($value$plusargs("DEFECT=%s",kind)) defect(kind);
    else native_checks();
    $finish;
  end
endmodule
