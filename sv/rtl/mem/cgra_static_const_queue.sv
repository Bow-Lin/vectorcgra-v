// Constant ROM, entry zero in the low DATA_BITS of CONST_WORDS.
module cgra_static_const_queue #(
  parameter integer DATA_BITS = 35,
  parameter integer NUM_CONST = 3,
  parameter logic [((NUM_CONST > 0) ? NUM_CONST : 1)*DATA_BITS-1:0] CONST_WORDS = '0,
  parameter bit LEGACY_PYTHON = 0
)(
  input logic clk, reset,
  output logic [DATA_BITS-1:0] send_const__msg,
  output logic send_const__val,
  input logic send_const__rdy
);
  localparam integer INDEX_W = (NUM_CONST > 0) ? $clog2(NUM_CONST+1) : 1;
  logic [INDEX_W-1:0] cursor;
  generate if (NUM_CONST > 0) begin : rom
    assign send_const__msg = CONST_WORDS[cursor*DATA_BITS +: DATA_BITS];
    assign send_const__val = LEGACY_PYTHON || !reset;
    if (LEGACY_PYTHON) begin : legacy
      initial cursor = '0;
      always @(posedge clk)
        if (send_const__rdy)
          cursor <= (cursor == NUM_CONST-1) ? '0 : cursor + 1'b1;
    end else begin : native_mode
      always @(posedge clk)
        if (reset) cursor <= '0;
        else if (send_const__rdy)
          cursor <= (cursor == NUM_CONST-1) ? '0 : cursor + 1'b1;
    end
  end else begin : empty
    assign send_const__msg = '0;
    assign send_const__val = 1'b0;
    assign cursor = '0;
  end endgenerate
`ifndef SYNTHESIS
  initial begin
    if (DATA_BITS < 1 || NUM_CONST < 0) $fatal(1, "STATIC_CONST_PARAM");
    if (LEGACY_PYTHON && NUM_CONST < 1) $fatal(1, "STATIC_CONST_LEGACY_DOMAIN");
  end
`endif
endmodule
