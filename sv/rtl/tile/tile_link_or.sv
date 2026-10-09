// Native parameterized scalar profile; migrated from ac96 LinkOrRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_link_or #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] recv_fu__msg ,
  output logic [0:0] recv_fu__rdy  ,
  input logic [0:0] recv_fu__val  ,
  input logic [DATA_BITS-1:0] recv_xbar__msg ,
  output logic [0:0] recv_xbar__rdy  ,
  input logic [0:0] recv_xbar__val  ,
  output logic [DATA_BITS-1:0] send__msg ,
  input logic [0:0] send__rdy  ,
  output logic [0:0] send__val  
);
  `include "cgra_profile.svh"
  data_t recv_fu__msg_typed ;
  assign recv_fu__msg_typed = recv_fu__msg;
  data_t recv_xbar__msg_typed ;
  assign recv_xbar__msg_typed = recv_xbar__msg;
  data_t send__msg_typed ;
  assign send__msg = send__msg_typed;
  always_comb begin : process
    send__msg_typed = '0;
    send__msg_typed.predicate = recv_fu__msg_typed.predicate | recv_xbar__msg_typed.predicate;
    send__msg_typed.payload = recv_xbar__msg_typed.payload | recv_fu__msg_typed.payload;
    send__val = recv_fu__val | recv_xbar__val;
    recv_fu__rdy = send__rdy;
    recv_xbar__rdy = send__rdy;
  end
endmodule
