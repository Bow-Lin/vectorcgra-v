// Same one-hot priority and doubled request scan as RoundRobinArbiterEn.
// en is an arbitration enable, not an implicit downstream handshake.
module cgra_round_robin #(parameter int INPUTS = 2) (
  input logic clk, reset, en,
  input logic [INPUTS-1:0] reqs,
  output logic [INPUTS-1:0] grants
);
  logic [INPUTS-1:0] priority_state;
  logic [2*INPUTS-1:0] reqs_twice, priority_twice, grants_twice;
  logic [2*INPUTS:0] kills;
  always_comb begin
    reqs_twice = {reqs, reqs};
    priority_twice = {{INPUTS{1'b0}}, priority_state};
    kills = '0;
    kills[0] = 1'b1;
    for (int i = 0; i < 2*INPUTS; i++) begin
      if (priority_twice[i]) begin
        kills[i+1] = reqs_twice[i];
        grants_twice[i] = reqs_twice[i];
      end else begin
        kills[i+1] = kills[i] | (~kills[i] & reqs_twice[i]);
        grants_twice[i] = ~kills[i] & reqs_twice[i];
      end
    end
    for (int i = 0; i < INPUTS; i++) grants[i] = grants_twice[i] | grants_twice[INPUTS+i];
  end
  always_ff @(posedge clk) begin
    if (reset) priority_state <= INPUTS'(1);
    else if ((grants != 0) && en)
      priority_state <= (grants << 1) | (grants >> (INPUTS-1));
  end
endmodule
