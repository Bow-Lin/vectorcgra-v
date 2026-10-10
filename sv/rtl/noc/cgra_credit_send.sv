// Shared semantics of RecvRTL2CreditSendRTL and OutputUnitCreditRTL.
module cgra_credit_send #(
  parameter int WIDTH = 32,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = $clog2(VCS),
  parameter int COUNT_WIDTH = $clog2(CREDITS+1),
  parameter bit LEGACY_PYTHON = 0
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg,
  output logic send_en,
  input logic [VCS-1:0] send_credit,
  // Registered capacity, independent of the currently selected message/valid.
  output logic [VCS-1:0] available_credit
);
  initial if(WIDTH<1 || VCS<1 || CREDITS<1 || COUNT_WIDTH<$clog2(CREDITS+1) || VC_WIDTH<1 || VC_LSB<0 || VC_LSB+VC_WIDTH>WIDTH || (64'(VCS)>(64'd1<<VC_WIDTH)))
    $fatal(1,"NOC_CREDIT_PARAMETERS");
  logic [COUNT_WIDTH-1:0] credit_count [0:VCS-1];
  logic [VCS-1:0] decrement;
  assign send_msg = recv_msg;
  always_comb begin
    send_en = 0;
    recv_rdy = 0;
    if (recv_val && (LEGACY_PYTHON || !reset))
      for (int v = 0; v < VCS; v++)
        if ((recv_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v)) && credit_count[v] > 0) begin
          send_en = 1;
          recv_rdy = 1;
        end
    for (int v = 0; v < VCS; v++)
      decrement[v] = send_en & (send_msg[VC_LSB +: VC_WIDTH] == VC_WIDTH'(v));
  end
  for (genvar v = 0; v < VCS; v++) begin : vcs
    assign available_credit[v]=(LEGACY_PYTHON || !reset) && credit_count[v]>0;
`ifndef SYNTHESIS
    always @(posedge clk) if(!LEGACY_PYTHON && !reset && send_credit[v] && !decrement[v] && credit_count[v]>=COUNT_WIDTH'(CREDITS))
      $fatal(1,"NOC_CREDIT_OVERFLOW vc=%0d",v);
`endif
    always_ff @(posedge clk) begin
      if (reset) credit_count[v] <= COUNT_WIDTH'(CREDITS);
      else if (send_credit[v] & ~decrement[v]) credit_count[v] <= credit_count[v] + 1'b1;
      else if (~send_credit[v] & decrement[v]) credit_count[v] <= credit_count[v] - 1'b1;
    end
  end
endmodule
