`include "cgra_profile_defs.svh"
// ac96 single-read/single-write bank with its original optional request queues.
// RAM is not reset; MEM_COMBINATIONAL=0 preserves the one-cycle channel mode.
module cgra_data_bank #(`CGRA_PROFILE_PARAMETERS) (
  input logic clk, reset,
  input logic [MEM_BITS-1:0] recv_rd__msg,
  input logic recv_rd__val,
  output logic recv_rd__rdy,
  input logic [WR_MEM_BITS-1:0] recv_wr__msg,
  input logic recv_wr__val,
  output logic recv_wr__rdy,
  output logic [MEM_BITS-1:0] send__msg,
  output logic send__val,
  input logic send__rdy
);
  `include "cgra_profile.svh"
  mem_request_t rd;
  mem_write_request_t wr;
  logic rd_val, wr_val;
  mem_response_t response;
  data_t memory [0:BANK_DEPTH-1];
  cgra_channel #(.WIDTH(MEM_BITS), .LATENCY(MEM_COMBINATIONAL ? 0 : 1)) channel_rd (
    .clk, .reset, .clear(1'b0), .recv_msg(recv_rd__msg), .recv_val(recv_rd__val), .recv_rdy(recv_rd__rdy),
    .send_msg(rd), .send_val(rd_val), .send_rdy(send__rdy)
  );
  cgra_channel #(.WIDTH(WR_MEM_BITS), .LATENCY(MEM_COMBINATIONAL ? 0 : 1)) channel_wr (
    .clk, .reset, .clear(1'b0), .recv_msg(recv_wr__msg), .recv_val(recv_wr__val), .recv_rdy(recv_wr__rdy),
    .send_msg(wr), .send_val(wr_val), .send_rdy(1'b1)
  );
  assign send__val = rd_val;
  assign send__msg = response;
  always_comb begin
    response = '0;
    if (rd_val) begin
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
    if (wr_val) memory[wr.addr[BANK_ADDR_W-1:0]] <= wr.data;
  end
endmodule
