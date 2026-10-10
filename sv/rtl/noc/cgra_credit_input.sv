// InputUnitCreditRTL: one normal queue per virtual channel.
module cgra_credit_input #(
  parameter int WIDTH = 32,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = $clog2(VCS),
  parameter bit LEGACY_PYTHON = 0
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_en,
  output logic [VCS-1:0] recv_credit,
  output logic [WIDTH-1:0] send_msg [0:VCS-1],
  output logic send_val [0:VCS-1],
  input logic send_rdy [0:VCS-1]
);

  initial if(WIDTH<1 || VCS<1 || CREDITS<1 || VC_WIDTH<1 || VC_LSB<0 || VC_LSB+VC_WIDTH>WIDTH || (64'(VCS)>(64'd1<<VC_WIDTH)))
    $fatal(1,"NOC_CREDIT_PARAMETERS");
`ifndef SYNTHESIS
  always @(posedge clk) if(!LEGACY_PYTHON && !reset && recv_en && int'(recv_msg[VC_LSB+:VC_WIDTH])>=VCS)
    $fatal(1,"NOC_INVALID_CREDIT_VC");
`endif
  for (genvar v = 0; v < VCS; v++) begin : vcs
    logic queue_recv_val, queue_recv_rdy, queue_send_val;
    assign send_val[v]=(LEGACY_PYTHON || !reset) && queue_send_val;
    assign queue_recv_val = (LEGACY_PYTHON || !reset) & recv_en & (recv_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v));
    assign recv_credit[v] = (LEGACY_PYTHON || !reset) & send_val[v] & send_rdy[v];
`ifndef SYNTHESIS
    always @(posedge clk) if(!LEGACY_PYTHON && !reset && queue_recv_val && !queue_recv_rdy)
      $fatal(1,"NOC_CREDIT_INPUT_OVERFLOW vc=%0d",v);
`endif
    cgra_queue #(.WIDTH(WIDTH), .DEPTH(CREDITS)) buffer (
      .clk, .reset, .clear(1'b0), .recv_msg, .recv_val(queue_recv_val), .recv_rdy(queue_recv_rdy),
      .send_msg(send_msg[v]), .send_val(queue_send_val), .send_rdy(send_rdy[v]), .count()
    );
  end
endmodule
