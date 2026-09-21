// Native, statically elaborated rendition of the existing DW02_multp model's
// radix-4 Booth partial-product and ordered 3:2 compression algorithm.
// Both partial outputs are preserved, not merely their sum. No registers.
// Original dependency notice (also retained in vendor/dp_fpfma/DW02_multp.v):
// This confidential and proprietary software may be used only as authorized
// by a licensing agreement from Synopsys Inc. In the event of publication,
// the following notice is applicable:
// (C) COPYRIGHT 1998 - 2009 SYNOPSYS INC. ALL RIGHTS RESERVED.
// The entire notice above must be reproduced on all authorized copies.
module cgra_multp #(
  parameter int A_W=8, B_W=8, OUT_W=A_W+B_W+2,
  localparam int X_W=A_W+B_W+1,
  localparam int NPP=A_W/2+2
) (
  input logic [A_W-1:0] a,
  input logic [B_W-1:0] b,
  input logic tc,
  output logic [OUT_W-1:0] out0, out1
);
  initial if(A_W<1||B_W<1||OUT_W<A_W+B_W+2)
    $fatal(1,"cgra_multp requires positive operands and OUT_W>=A_W+B_W+2");
  logic [A_W+2:0] padded_a;
  logic [X_W-1:0] padded_b;
  logic [X_W-1:0] partial [0:NPP][0:NPP-1];
  logic extension_sign, unknown_input;
  assign padded_a={tc&a[A_W-1],tc&a[A_W-1],a,1'b0};
  assign padded_b={{(A_W+1){tc&b[B_W-1]}},b};
  assign partial[0][0]='0;
  for(genvar pair=0;pair<NPP-1;pair++)begin : booth
    logic [2:0] group_bits;
    logic [X_W-1:0] value;
    assign group_bits=3'(padded_a>>(2*pair));
    always_comb begin
      case(group_bits)
        3'b001,3'b010:value=padded_b;
        3'b011:value=padded_b<<1;
        3'b100:value=~(padded_b<<1)+X_W'(1);
        3'b101,3'b110:value=~padded_b+X_W'(1);
        default:value='0;
      endcase
    end
    assign partial[0][pair+1]=value<<(2*pair);
  end
  function automatic int count_at(input int stage);
    int count;
    count=NPP;
    for(int i=0;i<stage;i++)if(count>2)count=count-count/3;
    return count;
  endfunction
  // NPP is a constant upper bound on compression passes. Once two terms
  // remain, subsequent elaborated stages are wires and optimize away.
  for(genvar stage=0;stage<NPP;stage++)begin : compression
    localparam int COUNT=count_at(stage);
    localparam int GROUPS=(COUNT>2)?COUNT/3:0;
    localparam int NEXT=(COUNT>2)?COUNT-COUNT/3:COUNT;
    for(genvar term=0;term<NPP;term++)begin : terms
      if(term<2*GROUPS)begin : compressed
        localparam int BASE=(term/2)*3;
        if(term%2==0)
          assign partial[stage+1][term]=partial[stage][BASE]^partial[stage][BASE+1]^partial[stage][BASE+2];
        else
          assign partial[stage+1][term]=((partial[stage][BASE]&partial[stage][BASE+1])|
            (partial[stage][BASE+1]&partial[stage][BASE+2])|
            (partial[stage][BASE]&partial[stage][BASE+2]))<<1;
      end else if(term<NEXT)begin : remainder
        assign partial[stage+1][term]=partial[stage][3*GROUPS+term-2*GROUPS];
      end else begin : unused
        // These terms never feed an active compression term or an output.
        assign partial[stage+1][term]='0;
      end
    end
  end
  assign extension_sign=partial[NPP][0][X_W-1]|partial[NPP][1][X_W-1];
  // Preserve the simulation model's explicit four-state unknown propagation.
  assign unknown_input=((^(a^a)!==1'b0)|(^(b^b)!==1'b0)|(^(tc^tc)!==1'b0));
  assign out0=unknown_input ? 'x : {{(OUT_W-X_W){1'b0}},partial[NPP][0]};
  assign out1=unknown_input ? 'x : {{(OUT_W-X_W){extension_sign}},partial[NPP][1]};
endmodule
