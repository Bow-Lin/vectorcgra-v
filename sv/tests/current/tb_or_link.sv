`timescale 1ns/1ps
module tb_or_link #(parameter integer DATA_W=32, NUM_INPUTS=5);
  localparam integer BITS=DATA_W+3, IN_BITS=2+NUM_INPUTS*(BITS+1), OUT_BITS=BITS+1+NUM_INPUTS;
  logic clk=0,reset=0;
  logic [BITS-1:0] recv__msg [0:NUM_INPUTS-1];
  logic [NUM_INPUTS-1:0] recv__val,recv__rdy;
  logic [BITS-1:0] send__msg;
  logic send__val,send__rdy;
`ifdef OR_LINK_POST_SYNTH
  wire [NUM_INPUTS*BITS-1:0] flat_msg;
  for (genvar i=0;i<NUM_INPUTS;i++) assign flat_msg[(NUM_INPUTS-1-i)*BITS +: BITS]=recv__msg[i];
  or_link_netlist dut (.recv__msg(flat_msg),.*);
`else
  cgra_or_link #(.DATA_W(DATA_W),.NUM_INPUTS(NUM_INPUTS)) dut (.*);
`endif
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  integer invalid_nonzero /* verilator public_flat_rw */ =0;
  bit wrong;
  logic [31:0] rng=32'h30abce;
  function automatic logic [31:0] rand32();
    rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);return rng;
  endfunction
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  task automatic require(input bit ok,input string label);
    checks++;if (!ok) $fatal(1,"OR_LINK_CHECK %s sample=%0d",label,samples);
  endtask
  task automatic replay(input string path);
    integer fd,scan,pos;
    logic [IN_BITS-1:0] ins;
    logic [OUT_BITS-1:0] expected,actual;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"OR_LINK_VECTOR_FORMAT");
      pos=IN_BITS-1;reset=ins[pos];pos--;send__rdy=ins[pos];pos--;
      for (integer i=0;i<NUM_INPUTS;i++) begin
        recv__val[i]=ins[pos];pos--;recv__msg[i]=ins[pos -: BITS];pos-=BITS;
      end
      #1;actual=OUT_BITS'({send__val,send__msg});
      for (integer i=0;i<NUM_INPUTS;i++) actual=(actual<<1)|OUT_BITS'(recv__rdy[i]);
      if (wrong && samples==4) expected=expected^1;
      if (actual!==expected) $fatal(1,"OR_LINK_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,actual,expected);
      samples++;tick();
    end
    $fclose(fd);require(samples==320,"replay coverage");
    $display("OR_LINK_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic mathematical_checks;
    integer active,ones;
    logic [BITS-1:0] expected;
    logic [BITS:0] held;
    // Enumerate every valid mask, both ready values and both reset values.
    for (integer mask=0;mask<(1<<NUM_INPUTS);mask++) begin
      recv__val=NUM_INPUTS'(mask);
      for (integer ready=0;ready<2;ready++) for (integer rst=0;rst<2;rst++) begin
        reset=1'(rst);send__rdy=1'(ready);active=0;expected='0;
        for (integer i=0;i<NUM_INPUTS;i++) begin
          recv__msg[i]='0;
          for (integer b=0;b<BITS;b++) recv__msg[i][b]=1'(rand32());
          recv__msg[i][1:0]=2'b11;
          if (recv__val[i]) active++;
          else if (recv__msg[i]!=0) invalid_nonzero++;
        end
        // Count set bits across all inputs, independent of val; clear metadata.
        if (active>0) for (integer b=2;b<BITS;b++) begin
          ones=0;for (integer i=0;i<NUM_INPUTS;i++) if (recv__msg[i][b]) ones++;
          expected[b]=(ones!=0);
        end
        if (wrong && samples==4) expected=expected^4;
        #1;require(send__val==(active!=0),"valid reduction");
        require(send__msg===expected,"bitwise payload/predicate OR and zero metadata");
        for (integer i=0;i<NUM_INPUTS;i++) require(recv__rdy[i]==send__rdy,"ready broadcast");
        held={send__val,send__msg};tick();
        require({send__val,send__msg}===held,"combinational link unchanged for stable inputs");
        samples++;
      end
    end
    require(samples==4*(1<<NUM_INPUTS) && invalid_nonzero>0,"exhaustive mask coverage");
    $display("OR_LINK_NATIVE_PASS samples=%0d checks=%0d invalid_nonzero=%0d",samples,checks,invalid_nonzero);
  endtask
  string path;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);else mathematical_checks();
    $finish;
  end
endmodule
