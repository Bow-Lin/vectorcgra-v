// PyMTL primitive RegisterFile semantics: asynchronous reads, no reset or
// initialization of storage, and later write ports win on address collisions.
module cgra_register_file #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16,
  parameter int RD_PORTS = 1,
  parameter int WR_PORTS = 1,
  parameter bit CONST_ZERO = 0,
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input logic clk, reset,
  input logic [ADDR_WIDTH-1:0] raddr [0:RD_PORTS-1],
  output logic [WIDTH-1:0] rdata [0:RD_PORTS-1],
  input logic [ADDR_WIDTH-1:0] waddr [0:WR_PORTS-1],
  input logic [WIDTH-1:0] wdata [0:WR_PORTS-1],
  input logic wen [0:WR_PORTS-1]
);
  logic [WIDTH-1:0] regs [0:DEPTH-1];
  always_comb
    for (int i = 0; i < RD_PORTS; i++) rdata[i] = regs[raddr[i]];
  always_ff @(posedge clk)
    for (int i = 0; i < WR_PORTS; i++)
      if (wen[i] && (!CONST_ZERO || waddr[i] != '0)) regs[waddr[i]] <= wdata[i];
endmodule
