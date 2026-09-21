`include "cgra_profile_defs.svh"
// ac96 combinational single-read/single-write data bank. RAM is not reset.
module cgra_data_bank #(`CGRA_PROFILE_PARAMETERS) (
  input logic clk, reset,
  input logic [MEM_BITS-1:0] recv_rd__msg,
  input logic recv_rd__val,
  output logic recv_rd__rdy,
  input logic [MEM_BITS-1:0] recv_wr__msg,
  input logic recv_wr__val,
  output logic recv_wr__rdy,
  output logic [MEM_BITS-1:0] send__msg,
  output logic send__val,
  input logic send__rdy
);
  `include "cgra_profile.svh"
  mem_request_t rd, wr;
  mem_response_t response;
  data_t memory [0:BANK_DEPTH-1];
  assign rd = recv_rd__msg;
  assign wr = recv_wr__msg;
  assign recv_rd__rdy = send__rdy;
  assign recv_wr__rdy = 1'b1;
  assign send__val = recv_rd__val;
  assign send__msg = response;
  always_comb begin
    response = '0;
    if (recv_rd__val) begin
      response.src = rd.dst;
      response.dst = rd.src;
      response.addr = rd.addr;
      response.data = memory[rd.addr[BANK_ADDR_W-1:0]];
      response.src_cgra = rd.src_cgra;
      response.src_tile = rd.src_tile;
      response.remote_src_port = rd.remote_src_port;
    end
  end
  // Like the baseline RegisterFile, writes are not gated by reset.
  always_ff @(posedge clk) begin
    if (recv_wr__val) memory[wr.addr[BANK_ADDR_W-1:0]] <= wr.data;
  end
endmodule
