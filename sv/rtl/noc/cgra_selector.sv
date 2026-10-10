// Standalone SelectorRTL API. Selection is routing control, held by the caller
// until the selected transfer completes; this module is not an arbiter/queue.
module cgra_selector #(
  parameter integer DATA_BITS=35, NUM_INPUTS=3,
  parameter bit LEGACY_PYTHON=0,
  parameter integer SEL_W=(NUM_INPUTS>1)?$clog2(NUM_INPUTS):1
)(
  input logic clk,reset,
  input logic [SEL_W-1:0] recv_from,
  input logic [DATA_BITS-1:0] recv__msg [0:NUM_INPUTS-1],
  input logic [NUM_INPUTS-1:0] recv__val,
  output logic [NUM_INPUTS-1:0] recv__rdy,
  output logic [DATA_BITS-1:0] send__msg,
  output logic send__val,
  input logic send__rdy
);
  always_comb begin
    send__msg='0;send__val=0;
    for (integer i=0;i<NUM_INPUTS;i++) if (recv_from==SEL_W'(i)) begin
      send__msg=recv__msg[i];send__val=recv__val[i];
    end
  end
  generate for (genvar i=0;i<NUM_INPUTS;i++) begin : ports
    if (LEGACY_PYTHON) begin : legacy
      // Explicitly retain the original missing-default ready latch.
      initial recv__rdy[i]=0;
      always_latch if (recv_from==SEL_W'(i)) recv__rdy[i]=send__rdy;
    end else begin : native_mode
      assign recv__rdy[i]=(recv_from==SEL_W'(i)) && send__rdy;
    end
  end endgenerate
`ifndef SYNTHESIS
  initial begin
    if (DATA_BITS<1 || NUM_INPUTS<1 || SEL_W!=((NUM_INPUTS>1)?$clog2(NUM_INPUTS):1))
      $fatal(1,"SELECTOR_PARAMETER");
    if (LEGACY_PYTHON && NUM_INPUTS==1) $fatal(1,"SELECTOR_LEGACY_DOMAIN");
  end
  always @(posedge clk) if (!reset && recv_from>=NUM_INPUTS) $fatal(1,"SELECTOR_INDEX");
`endif
endmodule
