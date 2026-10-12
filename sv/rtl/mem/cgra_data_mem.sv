// Standalone DataMemRTL API. DATA_BITS includes every metadata bit.
// See DATA_MEMORY_API.md for native and diagnostic Python-compatible contracts.
module cgra_data_mem #(
  parameter integer DATA_BITS=35, DEPTH=16, RD_PORTS=1, WR_PORTS=1,
  parameter bit PRELOAD_ENABLE=0, LEGACY_PYTHON=0,
  parameter logic [DEPTH*DATA_BITS-1:0] PRELOAD_WORDS='0,
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
  logic [DATA_BITS-1:0] mem [0:DEPTH-1];
  logic [DEPTH-1:0] initialized;
  generate if (LEGACY_PYTHON) begin : legacy
    // Simulation power-on values, not a portable ASIC initialization contract.
    initial begin
      initialized='0;
      for (integer a=0;a<DEPTH;a++) mem[a]='0;
    end
    assign recv_raddr__rdy=send_rdata__rdy;
    assign send_rdata__val=recv_raddr__val;
    assign recv_waddr__rdy='1;
    assign recv_wdata__rdy='1;
    for (genvar r=0;r<RD_PORTS;r++) begin : reads
      assign send_rdata__msg[r]=(PRELOAD_ENABLE && !initialized[recv_raddr__msg[r]])
        ? PRELOAD_WORDS[recv_raddr__msg[r]*DATA_BITS +: DATA_BITS]
        : mem[recv_raddr__msg[r]];
    end
    logic [ADDR_W-1:0] write_addr [0:WR_PORTS-1];
    logic [DATA_BITS-1:0] write_data [0:WR_PORTS-1];
    logic [WR_PORTS-1:0] write_enable;
    if (PRELOAD_ENABLE) begin : preload_latches
      initial begin
        write_enable='0;
        for (integer w=0;w<WR_PORTS;w++) begin write_addr[w]='0; write_data[w]='0; end
      end
      // Intentional source defect: deasserting address valid retains write enable.
      for (genvar w=0;w<WR_PORTS;w++) begin : write_port
        always_latch if (recv_waddr__val[w]) begin
          write_addr[w]=recv_waddr__msg[w];
          write_data[w]=recv_wdata__msg[w];
          write_enable[w]=recv_wdata__val[w];
        end
      end
    end else begin : direct_writes
      for (genvar w=0;w<WR_PORTS;w++) begin : write_port
        assign write_addr[w]=recv_waddr__msg[w];
        assign write_data[w]=recv_wdata__msg[w];
        assign write_enable[w]=recv_waddr__val[w] && recv_wdata__val[w];
      end
    end
    always @(posedge clk) begin
      for (integer w=0;w<WR_PORTS;w++) begin
        if (write_enable[w]) mem[write_addr[w]]<=write_data[w];
        if (recv_waddr__val[w]) initialized[recv_waddr__msg[w]]<=1'b1;
      end
      // Higher RegisterFile port indices win, including invalid lazy reads.
      for (integer r=0;r<RD_PORTS;r++) begin
        if (PRELOAD_ENABLE && !initialized[recv_raddr__msg[r]])
          mem[recv_raddr__msg[r]]<=PRELOAD_WORDS[recv_raddr__msg[r]*DATA_BITS +: DATA_BITS];
        if (recv_raddr__val[r]) initialized[recv_raddr__msg[r]]<=1'b1;
      end
    end
  end else begin : native_mode
    logic [RD_PORTS-1:0] held;
    logic [DATA_BITS-1:0] held_data [0:RD_PORTS-1];
    assign recv_raddr__rdy=send_rdata__rdy & {RD_PORTS{!reset}};
    assign send_rdata__val=(recv_raddr__val | held) & {RD_PORTS{!reset}};
    assign recv_waddr__rdy=recv_wdata__val & {WR_PORTS{!reset}};
    assign recv_wdata__rdy=recv_waddr__val & {WR_PORTS{!reset}};
    for (genvar r=0;r<RD_PORTS;r++) begin : reads
      logic [DATA_BITS-1:0] current_word;
      assign current_word=initialized[recv_raddr__msg[r]] ? mem[recv_raddr__msg[r]] :
        PRELOAD_ENABLE ? PRELOAD_WORDS[recv_raddr__msg[r]*DATA_BITS +: DATA_BITS] : '0;
      assign send_rdata__msg[r]=!send_rdata__val[r] ? '0 : held[r] ? held_data[r] : current_word;
      // Capture a read-before-write snapshot on the first stalled edge.
      // Writes remain independent of downstream readiness; no cross-port ready loop.
      always @(posedge clk) begin
        if (reset) begin held[r]<=0; held_data[r]<='0; end
        else if (send_rdata__rdy[r]) held[r]<=0;
        else if (!held[r] && recv_raddr__val[r]) begin
          held[r]<=1; held_data[r]<=current_word;
        end
      end
    end
    always @(posedge clk) begin
      if (reset) initialized<='0;
      else for (integer w=0;w<WR_PORTS;w++)
        if (recv_waddr__val[w] && recv_wdata__val[w]) begin
          mem[recv_waddr__msg[w]]<=recv_wdata__msg[w];
          initialized[recv_waddr__msg[w]]<=1'b1;
        end
    end
  end endgenerate
`ifndef SYNTHESIS
  initial begin
    if (DATA_BITS<1 || DEPTH<1 || RD_PORTS<1 || WR_PORTS<1 ||
        ADDR_W!=((DEPTH>1)?$clog2(DEPTH):1)) $fatal(1,"DATA_MEM_PARAM");
    if (LEGACY_PYTHON && DEPTH<2) $fatal(1,"DATA_MEM_LEGACY_DOMAIN");
  end
  always @(posedge clk) if (!reset) begin
    for (integer r=0;r<RD_PORTS;r++)
      if ((LEGACY_PYTHON || recv_raddr__val[r]) && recv_raddr__msg[r]>=DEPTH)
        $fatal(1,"DATA_MEM_ADDRESS read");
    for (integer w=0;w<WR_PORTS;w++)
      if (recv_waddr__val[w] && recv_waddr__msg[w]>=DEPTH)
        $fatal(1,"DATA_MEM_ADDRESS write");
  end
`endif
endmodule
