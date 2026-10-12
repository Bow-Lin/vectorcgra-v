// Standalone CtrlMemRTL API. See STATIC_MEMORY_API.md for native/legacy rules.
module cgra_static_ctrl_mem #(
  parameter integer CTRL_BITS = 119,
  parameter integer DEPTH = 8,
  parameter integer COUNT_PER_ITER = 4,
  parameter integer TOTAL_STEPS = 4,
  parameter integer OP_LSB = CTRL_BITS-7,
  parameter bit LEGACY_PYTHON = 0,
  parameter integer ADDR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
  input logic clk, reset,
  input logic [ADDR_W-1:0] recv_waddr__msg,
  input logic recv_waddr__val,
  output logic recv_waddr__rdy,
  input logic [CTRL_BITS-1:0] recv_ctrl__msg,
  input logic recv_ctrl__val,
  output logic recv_ctrl__rdy,
  output logic [CTRL_BITS-1:0] send_ctrl__msg,
  output logic send_ctrl__val,
  input logic send_ctrl__rdy
);
  localparam integer TIME_W = (TOTAL_STEPS > 0) ? $clog2(TOTAL_STEPS+1) : 1;
  logic [CTRL_BITS-1:0] words [0:DEPTH-1];
  logic [ADDR_W-1:0] pc;
  logic [TIME_W-1:0] steps;
  wire [ADDR_W-1:0] legacy_next = pc + 1'b1;
  wire running = send_ctrl__msg[OP_LSB +: 7] != 7'd0; // OPT_START
  wire budget = (TOTAL_STEPS == 0) || (steps < TOTAL_STEPS);
  // A live instruction must remain stable while its consumer is stalled.
  wire writable = (recv_waddr__msg < DEPTH) &&
    !(send_ctrl__val && !send_ctrl__rdy && recv_waddr__msg == pc);
  assign send_ctrl__msg = words[pc];
  assign send_ctrl__val = running && budget && (LEGACY_PYTHON || !reset);
  assign recv_waddr__rdy = LEGACY_PYTHON || (!reset && writable && recv_ctrl__val);
  assign recv_ctrl__rdy = LEGACY_PYTHON || (!reset && writable && recv_waddr__val);

  generate if (LEGACY_PYTHON) begin : legacy
    // Models PyMTL simulation's implicit zero startup. No runtime reset in Python.
    initial begin
      pc = '0;
      steps = '0;
      for (integer i=0; i<DEPTH; i=i+1) words[i] = '0;
    end
    always @(posedge clk) begin
      if (recv_waddr__val && recv_ctrl__val && recv_waddr__msg < DEPTH)
        words[recv_waddr__msg] <= recv_ctrl__msg;
      if (running) begin
        if (steps < TOTAL_STEPS) steps <= steps + 1'b1;
        if (send_ctrl__rdy)
          pc <= (legacy_next == COUNT_PER_ITER) ? '0 : legacy_next;
      end
    end
  end else begin : native_mode
    always @(posedge clk) begin
      if (reset) begin
        pc <= '0;
        steps <= '0;
        for (integer i=0; i<DEPTH; i=i+1) words[i] <= '0;
      end else begin
        if (recv_waddr__val && recv_ctrl__val && recv_waddr__rdy)
          words[recv_waddr__msg] <= recv_ctrl__msg;
        if (send_ctrl__val && send_ctrl__rdy) begin
          if (TOTAL_STEPS > 0) steps <= steps + 1'b1;
          pc <= (pc == COUNT_PER_ITER-1) ? '0 : pc + 1'b1;
        end
      end
    end
  end endgenerate

`ifndef SYNTHESIS
  initial begin
    if (CTRL_BITS < 7 || OP_LSB < 0 || OP_LSB+7 > CTRL_BITS || DEPTH < 1 ||
        COUNT_PER_ITER < 1 || COUNT_PER_ITER > DEPTH || TOTAL_STEPS < 0 ||
        ADDR_W != ((DEPTH > 1) ? $clog2(DEPTH) : 1))
      $fatal(1, "STATIC_CTRL_PARAM");
    if (LEGACY_PYTHON && (DEPTH < 2 || TOTAL_STEPS < 1))
      $fatal(1, "STATIC_CTRL_LEGACY_DOMAIN");
  end
  always @(posedge clk)
    if ((LEGACY_PYTHON || !reset) && recv_waddr__val && recv_ctrl__val &&
        recv_waddr__msg >= DEPTH) $fatal(1, "STATIC_CTRL_ADDRESS");
`endif
endmodule
