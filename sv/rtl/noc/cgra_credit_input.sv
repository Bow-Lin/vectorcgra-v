// InputUnitCreditRTL: one normal queue per virtual channel.
module cgra_credit_input #(
  parameter int WIDTH = 32,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = $clog2(VCS)
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_en,
  output logic [VCS-1:0] recv_credit,
  output logic [WIDTH-1:0] send_msg [0:VCS-1],
  output logic send_val [0:VCS-1],
  input logic send_rdy [0:VCS-1]
);
  for (genvar v = 0; v < VCS; v++) begin : vcs
    logic queue_recv_val;
    assign queue_recv_val = recv_en & (recv_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v));
    assign recv_credit[v] = send_val[v] & send_rdy[v];
    cgra_queue #(.WIDTH(WIDTH), .DEPTH(CREDITS)) buffer (
      .clk, .reset, .clear(1'b0), .recv_msg, .recv_val(queue_recv_val), .recv_rdy(),
      .send_msg(send_msg[v]), .send_val(send_val[v]), .send_rdy(send_rdy[v]), .count()
    );
  end
endmodule
