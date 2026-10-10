`timescale 1ns/1ps
module tb_static_invalid #(parameter integer BAD_CASE=0);
  if (BAD_CASE<3) begin : ctrl
    cgra_static_ctrl_mem #(
      .DEPTH(BAD_CASE==2?1:4),.COUNT_PER_ITER(BAD_CASE==0?5:1),
      .TOTAL_STEPS(BAD_CASE==1?0:4),.LEGACY_PYTHON(BAD_CASE!=0)
    ) dut (.clk(1'b0),.reset(1'b0),.recv_waddr__msg('0),.recv_waddr__val(1'b0),
      .recv_ctrl__msg('0),.recv_ctrl__val(1'b0),.send_ctrl__rdy(1'b0),
      .recv_waddr__rdy(),.recv_ctrl__rdy(),.send_ctrl__msg(),.send_ctrl__val());
  end else begin : const_queue
    cgra_static_const_queue #(.NUM_CONST(0),.LEGACY_PYTHON(1)) dut (
      .clk(1'b0),.reset(1'b0),.send_const__rdy(1'b0),.send_const__val(),.send_const__msg());
  end
  initial begin #10; $fatal(1,"STATIC_PARAM_ASSERTION_MISSING"); end
endmodule
