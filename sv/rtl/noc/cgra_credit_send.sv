// Shared semantics of RecvRTL2CreditSendRTL and OutputUnitCreditRTL.
module cgra_credit_send #(
  parameter int WIDTH = 32,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = $clog2(VCS),
  parameter int COUNT_WIDTH = $clog2(CREDITS+1)
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg,
  output logic send_en,
  input logic [VCS-1:0] send_credit
);
  logic [COUNT_WIDTH-1:0] credit_count [0:VCS-1];
  logic [VCS-1:0] decrement;
  assign send_msg = recv_msg;
  always_comb begin
    send_en = 0;
    recv_rdy = 0;
    if (recv_val)
      for (int v = 0; v < VCS; v++)
        if ((recv_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v)) && credit_count[v] > 0) begin
          send_en = 1;
          recv_rdy = 1;
        end
    for (int v = 0; v < VCS; v++)
      decrement[v] = send_en & (send_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v));
  end
  for (genvar v = 0; v < VCS; v++) begin : vcs
    always_ff @(posedge clk) begin
      if (reset) credit_count[v] <= COUNT_WIDTH'(CREDITS);
      else if (send_credit[v] & ~decrement[v]) credit_count[v] <= credit_count[v] + 1'b1;
      else if (~send_credit[v] & decrement[v]) credit_count[v] <= credit_count[v] - 1'b1;
    end
  end
endmodule
