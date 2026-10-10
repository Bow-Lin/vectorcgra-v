`timescale 1ns/1ps
module tb_arithmetic_defects #(parameter bit LEGACY_PYTHON=0);
  logic clk=0, reset=1;
  logic [31:0] dividend=0, divisor=1, quotient, remainder;
  logic [15:0] rhs_0=0, rhs_1=0, rhs_1b=0, lhs_0;
  logic [5:0] rhs_2=3;
  scalar_div_pipeline #(.WIDTH(32),.CYCLE(3),.LEGACY_PARTITION(LEGACY_PYTHON)) div(.*);
  cgra_alu_gen_mac_core #(.LEGACY_PYTHON(LEGACY_PYTHON)) mac(.*);
  task automatic tick; #2;clk=1;#2;clk=0;#2;endtask
  initial begin
    tick();reset=0;
    if ($test$plusargs("MAC")) begin
      rhs_0=16'h8000;rhs_1=16'h0001;#2;
      if(lhs_0!==16'd1) $fatal(1,"MAC_SIGNED_OVERFLOW got=%h expected=1",lhs_0);
    end else begin
      dividend=32'hffffffff;divisor=3;repeat(4) tick();
      if(quotient!==32'h55555555 || remainder!==0)
        $fatal(1,"DIV_REMAINDER_ITERATIONS got=%h rem=%h expected=55555555/0",quotient,remainder);
    end
    $display("ARITHMETIC_DEFECT_FIXED");$finish;
  end
endmodule
