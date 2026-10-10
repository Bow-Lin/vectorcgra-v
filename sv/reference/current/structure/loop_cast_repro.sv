module loop_cast(input logic [7:0] in_data, output logic [7:0] out_data);
  localparam int N=8;
  always_comb begin
    for(int unsigned i=0;i<4'(N);i++) out_data[i]=in_data[i];
  end
endmodule
