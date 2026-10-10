// Fixed 16-bit ALUgenMAC with native signed comparisons and cgra_multp replacing
// its simulation-only DW dependency; LEGACY_PYTHON retains the original equations.
// Original Genesis2 notice is preserved in
// vendor/svsrc/ALUgenMAC.sv; this migration does not change its license terms.
module cgra_alu_gen_mac_core #(parameter bit LEGACY_PYTHON=0) (
  input logic [15:0] rhs_0, rhs_1, rhs_1b,
  input logic [5:0] rhs_2,
  output logic [15:0] lhs_0
);
  logic [15:0] multiplier_a, multiplier_b, a, b, c, sum_bits;
  logic [16:0] carry_bits;
  logic [33:0] partial0, partial1;
  logic [15:0] adder_a, adder_b, adder_result;
  logic carry_in;
  assign multiplier_a={16{rhs_2[4]}}&rhs_0;
  assign multiplier_b={16{rhs_2[4]}}&rhs_1;
  cgra_multp #(.A_W(16),.B_W(16),.OUT_W(34)) multiplier (
    .a(multiplier_a),.b(multiplier_b),.tc(1'b0),.out0(partial0),.out1(partial1));
  assign a=partial0[15:0];
  assign b=partial1[15:0];
  assign c={16{rhs_2[5]}}&rhs_1b;
  assign sum_bits=a^b^c;
  assign carry_bits={((a&b)|(a&c)|(b&c)),1'b0};
  assign adder_a=rhs_2[4]?sum_bits:({16{rhs_2[3]}}^rhs_0);
  assign adder_b=rhs_2[4]?carry_bits[15:0]:({16{rhs_2[0]}}^rhs_1);
  assign carry_in=rhs_2[0]|rhs_2[3];
  assign adder_result=adder_a+adder_b+carry_in;
  always_comb begin
    lhs_0=rhs_2[1]?{15'b0,(rhs_2[2]^adder_result[15])}:adder_result;
    if (!LEGACY_PYTHON) case(rhs_2)
      6'd3: lhs_0={15'b0,($signed(rhs_0)<$signed(rhs_1))};
      6'd7: lhs_0={15'b0,($signed(rhs_0)>=$signed(rhs_1))};
      6'd10:lhs_0={15'b0,($signed(rhs_0)>$signed(rhs_1))};
      6'd14:lhs_0={15'b0,($signed(rhs_0)<=$signed(rhs_1))};
      default:begin end
    endcase
  end
endmodule
