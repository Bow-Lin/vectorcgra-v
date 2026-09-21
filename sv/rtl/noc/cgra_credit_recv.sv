// CreditRecvRTL2SendRTL: bypass buffers and round-robin ejection.
// Selection advances on valid grants even if the external sink is stalled.
module cgra_credit_recv #(
  parameter int WIDTH = 32,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = $clog2(VCS),
  parameter int SELECT_WIDTH = (VCS <= 1) ? 1 : $clog2(VCS)
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_en,
  output logic [VCS-1:0] recv_credit,
  output logic [WIDTH-1:0] send_msg,
  output logic send_val,
  input logic send_rdy
);
  logic [WIDTH-1:0] queued_msg [0:VCS-1];
  logic queued_val [0:VCS-1], queued_rdy [0:VCS-1];
  logic [VCS-1:0] requests, grants;
  logic [SELECT_WIDTH-1:0] selected;
  for (genvar v = 0; v < VCS; v++) begin : vcs
    logic queue_recv_val;
    assign queue_recv_val = recv_en & (recv_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v));
    assign recv_credit[v] = queued_val[v] & queued_rdy[v];
    assign requests[v] = queued_val[v];
    cgra_queue #(.WIDTH(WIDTH), .DEPTH(CREDITS), .BYPASS(1'b1)) buffer (
      .clk, .reset, .clear(1'b0), .recv_msg, .recv_val(queue_recv_val), .recv_rdy(),
      .send_msg(queued_msg[v]), .send_val(queued_val[v]), .send_rdy(queued_rdy[v]), .count()
    );
  end
  cgra_round_robin #(.INPUTS(VCS)) arbiter (
    .clk, .reset, .en(send_val), .reqs(requests), .grants
  );
  always_comb begin
    selected = '0;
    for (int v = 0; v < VCS; v++) if (grants[v]) selected = SELECT_WIDTH'(v);
  end
  always_comb begin
    for (int v = 0; v < VCS; v++) queued_rdy[v] = 0;
    send_msg = queued_msg[selected];
    send_val = grants != 0;
    if (grants != 0) queued_rdy[selected] = send_rdy;
  end
endmodule
