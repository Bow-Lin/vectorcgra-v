module data_mem_synth #(
  parameter integer DATA_BITS=35, DEPTH=16, RD_PORTS=1, WR_PORTS=1,
  parameter bit PRELOAD_ENABLE=0, LEGACY_PYTHON=0,
  parameter bit ORIGINAL=0,
  parameter integer ADDR_W=(DEPTH>1)?$clog2(DEPTH):1
)(
  input logic clk, reset,
  input logic [ADDR_W-1:0] recv_raddr__msg [0:RD_PORTS-1],
  input logic [RD_PORTS-1:0] recv_raddr__val,
  output logic [RD_PORTS-1:0] recv_raddr__rdy,
  output logic [DATA_BITS-1:0] send_rdata__msg [0:RD_PORTS-1],
  output logic [RD_PORTS-1:0] send_rdata__val,
  input logic [RD_PORTS-1:0] send_rdata__rdy,
  input logic [ADDR_W-1:0] recv_waddr__msg [0:WR_PORTS-1],
  input logic [WR_PORTS-1:0] recv_waddr__val,
  output logic [WR_PORTS-1:0] recv_waddr__rdy,
  input logic [DATA_BITS-1:0] recv_wdata__msg [0:WR_PORTS-1],
  input logic [WR_PORTS-1:0] recv_wdata__val,
  output logic [WR_PORTS-1:0] recv_wdata__rdy
);
  `include "data_mem_fixture.svh"
  cgra_data_mem #(.DATA_BITS(DATA_BITS),.DEPTH(DEPTH),.RD_PORTS(RD_PORTS),.WR_PORTS(WR_PORTS),
    .PRELOAD_ENABLE(PRELOAD_ENABLE),.PRELOAD_WORDS(WORDS),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
endmodule
