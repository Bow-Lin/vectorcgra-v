`timescale 1ns/1ps
module tb_selector #(
  parameter integer DATA_BITS=35,NUM_INPUTS=5,
  parameter bit LEGACY_PYTHON=0,
  parameter integer SEL_W=(NUM_INPUTS>1)?$clog2(NUM_INPUTS):1
);
  localparam integer IN_BITS=2+SEL_W+NUM_INPUTS*(DATA_BITS+1),OUT_BITS=DATA_BITS+1+NUM_INPUTS;
  logic clk=0,reset=0;
  logic [SEL_W-1:0] recv_from=0;
  logic [DATA_BITS-1:0] recv__msg [0:NUM_INPUTS-1];
  logic [NUM_INPUTS-1:0] recv__val=0,recv__rdy;
  logic [DATA_BITS-1:0] send__msg;
  logic send__val,send__rdy=0;
`ifdef SELECTOR_POST_SYNTH
  wire [NUM_INPUTS*DATA_BITS-1:0] flat_msg;
  for (genvar i=0;i<NUM_INPUTS;i++) assign flat_msg[(NUM_INPUTS-1-i)*DATA_BITS +: DATA_BITS]=recv__msg[i];
  selector_netlist dut (.recv__msg(flat_msg),.*);
`else
  cgra_selector #(.DATA_BITS(DATA_BITS),.NUM_INPUTS(NUM_INPUTS),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
`endif
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  bit wrong;
  logic [31:0] rng=32'h310ab;
  function automatic logic [31:0] rand32();
    rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);return rng;
  endfunction
  function automatic logic [DATA_BITS-1:0] randword();
    logic [DATA_BITS-1:0] value;
    value='0;
    for (integer b=0;b<DATA_BITS;b+=16) value=(value<<16)|DATA_BITS'(rand32()&65535);
    return value;
  endfunction
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  task automatic require(input bit ok,input string label);
    checks++;if (!ok) $fatal(1,"SELECTOR_CHECK %s sample=%0d",label,samples);
  endtask
  task automatic replay(input string path);
    integer fd,scan,pos;
    logic [IN_BITS-1:0] ins;
    logic [OUT_BITS-1:0] expected,actual;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"SELECTOR_VECTOR_FORMAT");
      pos=IN_BITS-1;reset=ins[pos];pos--;send__rdy=ins[pos];pos--;
      recv_from=ins[pos -: SEL_W];pos-=SEL_W;
      for (integer i=0;i<NUM_INPUTS;i++) begin
        recv__val[i]=ins[pos];pos--;recv__msg[i]=ins[pos -: DATA_BITS];pos-=DATA_BITS;
      end
      #1;actual=OUT_BITS'({send__val,send__msg});
      for (integer i=0;i<NUM_INPUTS;i++) actual=(actual<<1)|OUT_BITS'(recv__rdy[i]);
      if (wrong && samples==4) expected=expected^1;
      if (actual!==expected) $fatal(1,"SELECTOR_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,actual,expected);
      samples++;tick();
    end
    $fclose(fd);require(samples==320,"replay coverage");
    $display("SELECTOR_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic native_checks;
    logic [DATA_BITS-1:0] expected;
    for (integer select_port=0;select_port<NUM_INPUTS;select_port++) begin
      recv_from=SEL_W'(select_port);
      for (integer mask=0;mask<(1<<NUM_INPUTS);mask++) begin
        recv__val=NUM_INPUTS'(mask);
        for (integer ready=0;ready<2;ready++) for (integer rst=0;rst<2;rst++) begin
          reset=1'(rst);send__rdy=1'(ready);
          for (integer i=0;i<NUM_INPUTS;i++) recv__msg[i]=randword();
          expected=recv__msg[select_port];
          if (wrong && samples==4) expected=expected^1;
          #1;require(send__msg===expected,"full selected message including invalid and metadata");
          require(send__val==recv__val[select_port],"selected valid");
          for (integer i=0;i<NUM_INPUTS;i++) require(recv__rdy[i]==(i==select_port && ready==1),"only selected input ready");
          tick();samples++;
        end
      end
    end
    require(samples==NUM_INPUTS*4*(1<<NUM_INPUTS),"all selectors / valid masks / ready / reset");
    $display("SELECTOR_NATIVE_PASS samples=%0d checks=%0d",samples,checks);
  endtask
  task automatic stale_ready;
    recv_from=0;send__rdy=1;tick();recv_from=SEL_W'(1);send__rdy=0;#1;
    require(recv__rdy=='0,"DEFECT_UNSELECTED_READY");
    $display("SELECTOR_DEFECT_FIXED");
  endtask
  string path;
  initial begin
    for (integer i=0;i<NUM_INPUTS;i++) recv__msg[i]='0;
    wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($test$plusargs("DEFECT")) stale_ready();
    else if ($test$plusargs("INVALID_INDEX")) begin recv_from=SEL_W'(NUM_INPUTS);tick();$fatal(1,"INDEX_NOT_REJECTED");end
    else native_checks();
    $finish;
  end
endmodule
