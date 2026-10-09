// Direct HDL replacement for the original PyMTL AddFN/MulFN wiring.
module cgra_hardfloat_fn #(
  parameter int EXP_W=9, SIG_W=23,
  parameter bit MULTIPLY=0,
  localparam int WIDTH=EXP_W+SIG_W
) (
  input logic [WIDTH-1:0] a, b,
  input logic sub_op,
  output logic [WIDTH-1:0] result
);
  logic [WIDTH:0] rec_a, rec_b, rec_result;
  logic [4:0] exception_flags;
  fNToRecFN #(EXP_W, SIG_W) convert_a (.in_(a), .out(rec_a));
  fNToRecFN #(EXP_W, SIG_W) convert_b (.in_(b), .out(rec_b));
  if (MULTIPLY) begin : multiply
    mulRecFN #(EXP_W, SIG_W) op (.control(1'b1), .a(rec_a), .b(rec_b),
      .roundingMode(3'b000), .out(rec_result), .exceptionFlags(exception_flags));
  end else begin : add_subtract
    addRecFN #(EXP_W, SIG_W) op (.control(1'b1), .subOp(sub_op), .a(rec_a), .b(rec_b),
      .roundingMode(3'b000), .out(rec_result), .exceptionFlags(exception_flags));
  end
  recFNToFN #(EXP_W, SIG_W) convert_result (.in_(rec_result), .out(result));
endmodule
