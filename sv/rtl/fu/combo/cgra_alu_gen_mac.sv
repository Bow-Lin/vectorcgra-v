// Existing 16-bit fixed-point IP, no added state or handshake adaptation.
module cgra_alu_gen_mac #(parameter bit LEGACY_PYTHON=0) (
  input logic clk, reset,
  input logic [15:0] rhs_0, rhs_1, rhs_1b,
  input logic [5:0] rhs_2,
  output logic [15:0] lhs_0
);
  cgra_alu_gen_mac_core #(.LEGACY_PYTHON(LEGACY_PYTHON)) core (.rhs_0,.rhs_1,.rhs_1b,.rhs_2,.lhs_0);
endmodule
