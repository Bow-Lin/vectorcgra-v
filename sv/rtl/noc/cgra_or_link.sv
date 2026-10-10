// N-input combinational OR link, matching noc/OrLinkRTL.py.
// DataType layout: {payload[DATA_W-1:0], predicate, bypass, delay}.
// Invalid input payloads/predicates participate; this is not an arbiter.
module cgra_or_link #(
  parameter integer DATA_W=32, NUM_INPUTS=3
)(
  input logic clk, reset,
  input logic [DATA_W+2:0] recv__msg [0:NUM_INPUTS-1],
  input logic [NUM_INPUTS-1:0] recv__val,
  output logic [NUM_INPUTS-1:0] recv__rdy,
  output logic [DATA_W+2:0] send__msg,
  output logic send__val,
  input logic send__rdy
);
  logic [DATA_W:0] merged;
  always_comb begin
    merged='0;
    for (integer i=0;i<NUM_INPUTS;i++) merged=merged | recv__msg[i][DATA_W+2:2];
  end
  assign send__val=|recv__val;
  assign send__msg=send__val ? {merged,2'b00} : '0;
  assign recv__rdy={NUM_INPUTS{send__rdy}};
`ifndef SYNTHESIS
  initial if (DATA_W<1 || NUM_INPUTS<1) $fatal(1,"OR_LINK_PARAMETER");
`endif
endmodule
