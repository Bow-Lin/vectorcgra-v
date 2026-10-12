`timescale 1ns/1ps
module tb_static_const_queue #(
  parameter integer DATA_BITS=35, NUM_CONST=3,
  parameter bit ORIGINAL=0, LEGACY_PYTHON=0
);
  logic clk=0,reset=0,send_const__rdy=0,send_const__val;
  logic [DATA_BITS-1:0] send_const__msg;
  `include "static_const_fixture.svh"
`ifdef STATIC_POST_SYNTH
  static_const_netlist dut (.*);
`else
  cgra_static_const_queue #(.DATA_BITS(DATA_BITS),.NUM_CONST(NUM_CONST),
    .CONST_WORDS(WORDS),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
`endif
  integer samples /* verilator public_flat_rw */ = 0;
  integer checks /* verilator public_flat_rw */ = 0;
  integer accepted /* verilator public_flat_rw */ = 0;
  integer index=0;
  bit wrong;
  task automatic require(input bit ok,input string label);
    checks++;
    if (!ok) $fatal(1,"STATIC_CONST_CHECK %s checks=%0d",label,checks);
  endtask
  task automatic tick;
    #2; clk=1; #2; clk=0; #1;
  endtask
  task automatic replay(input string path);
    integer fd,scan;
    logic [1:0] ins;
    logic [DATA_BITS:0] expected;
    fd=$fopen(path,"r"); require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"STATIC_CONST_VECTOR_FORMAT");
      {reset,send_const__rdy}=ins; #1;
      if (wrong && samples==3) expected=expected^1;
      if ({send_const__val,send_const__msg} !== expected)
        $fatal(1,"STATIC_CONST_REPLAY_MISMATCH sample=%0d got=%h expected=%h",
          samples,{send_const__val,send_const__msg},expected);
      samples++; tick();
    end
    $fclose(fd); require(samples==160,"replay coverage");
    $display("STATIC_CONST_REPLAY_PASS samples=%0d output_bits=%0d",samples,DATA_BITS+1);
  endtask
  task automatic native_checks;
    logic [DATA_BITS-1:0] expected;
    reset=1; tick(); reset=0;
    for (integer i=0;i<200;i++) begin
      // Reset midstream both with and without ready asserted.
      reset=(i==39 || i==80 || i==121);
      send_const__rdy=(i%5!=1 && i%5!=2);
      #1;
      expected=(NUM_CONST==0)?'0:fixture_word(index);
      if (wrong && i==5) expected=expected^1;
      require(send_const__msg==expected,"ROM payload and all metadata / stall stability");
      require(send_const__val==(NUM_CONST>0 && !reset),"valid incl empty and reset");
      if (reset) index=0;
      else if (send_const__val && send_const__rdy) begin
        accepted++; index++;
        if (index==NUM_CONST) index=0;
      end
      tick();
    end
    $display("STATIC_CONST_NATIVE_PASS bits=%0d count=%0d checks=%0d accepted=%0d",
      DATA_BITS,NUM_CONST,checks,accepted);
  endtask
  task automatic reset_defect;
    reset=1; tick(); reset=0; send_const__rdy=1; tick();
    send_const__rdy=0; reset=1; tick(); reset=0; #1;
    require(send_const__msg==fixture_word(0),"DEFECT_RESET");
    $display("STATIC_CONST_DEFECT_FIXED reset");
  endtask
  string path;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($test$plusargs("DEFECT_RESET")) reset_defect();
    else native_checks();
    $finish;
  end
endmodule
