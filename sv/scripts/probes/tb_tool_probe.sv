`timescale 1ns/1ps
module tb_tool_probe;
  import tool_probe_pkg::*;
  logic clk = 0;
  logic reset = 1;
  data_t recv_msg [2];
  data_t send_msg [2];
  logic [1:0] recv_val = 0;
  logic [1:0] recv_rdy;
  logic [1:0] send_val;
  logic [1:0] send_rdy = 0;
  tool_probe dut (.*);
  always #5 clk = ~clk;
  initial begin
    recv_msg[0] = '0;
    recv_msg[1] = '0;
    repeat (2) @(negedge clk);
    reset = 0;
    recv_msg[0] = '{payload:16'd28, predicate:1'b1};
    recv_msg[1] = '{payload:16'd93, predicate:1'b0};
    recv_val = 2'b11;
    @(negedge clk);
    recv_val = 0;
    if (send_val !== 2'b11 || recv_rdy !== 0) $fatal(1, "queue/backpressure");
    repeat (3) begin
      @(negedge clk);
      if (send_msg[0] !== 17'd57 || send_msg[1] !== 17'd186 || send_val !== 2'b11)
        $fatal(1, "packed data or stalled state changed");
    end
    send_rdy = 2'b11;
    @(negedge clk);
    if (send_val !== 0) $fatal(1, "queue did not drain");
    if ($test$plusargs("EXPECT_FAILURE")) $fatal(1, "intentional negative control");
    $display("TOOL_PROBE_PASS");
    $finish;
  end
  initial begin
    #1000;
    $fatal(1, "probe timeout");
  end
endmodule
