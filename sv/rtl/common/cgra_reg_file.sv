// Legacy rf/RegFile.py API. Writes are UNCONDITIONAL on every rising edge,
// including reset, invalid inputs, and output backpressure. This is not a
// decoupled memory port; the current PE uses register_cluster instead.
module cgra_reg_file #(
  parameter int DATA_BITS = 32,
  parameter int DEPTH = 16,
  parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input logic clk, reset,
  input logic [ADDR_W-1:0] recv_waddr__msg,
  input logic recv_waddr__val,
  output logic recv_waddr__rdy,
  input logic [DATA_BITS-1:0] recv_wdata__msg,
  input logic recv_wdata__val,
  output logic recv_wdata__rdy,
  input logic [ADDR_W-1:0] recv_raddr__msg,
  input logic recv_raddr__val,
  output logic recv_raddr__rdy,
  output logic [DATA_BITS-1:0] send_rdata__msg,
  output logic send_rdata__val,
  input logic send_rdata__rdy
);
  initial begin
    if (DATA_BITS < 1 || DEPTH < 1 || ADDR_W != ((DEPTH <= 1) ? 1 : $clog2(DEPTH)))
      $fatal(1, "REG_FILE_PARAMETER");
  end
  cgra_register_file #(.WIDTH(DATA_BITS), .DEPTH(DEPTH), .ADDR_WIDTH(ADDR_W)) storage (
    .clk(clk), .reset(reset), .raddr('{recv_raddr__msg}), .rdata('{send_rdata__msg}),
    .waddr('{recv_waddr__msg}), .wdata('{recv_wdata__msg}), .wen('{1'b1})
  );
  assign recv_raddr__rdy = send_rdata__rdy;
  assign recv_waddr__rdy = send_rdata__rdy;
  assign recv_wdata__rdy = send_rdata__rdy;
  assign send_rdata__val = recv_raddr__val;
endmodule
