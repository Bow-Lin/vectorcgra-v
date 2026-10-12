module static_const_synth #(
  parameter integer DATA_BITS=35, NUM_CONST=3,
  parameter bit ORIGINAL=0, LEGACY_PYTHON=0
)(
  input wire clk,reset,
  output wire [DATA_BITS-1:0] send_const__msg,
  output wire send_const__val,
  input wire send_const__rdy
);
  `include "static_const_fixture.svh"
  cgra_static_const_queue #(.DATA_BITS(DATA_BITS),.NUM_CONST(NUM_CONST),
    .CONST_WORDS(WORDS),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
endmodule
