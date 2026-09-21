// ac96 lib/basic/val_rdy/queues.py. Full queues do not accept replacement
// on a simultaneous dequeue. Storage remains unreset, including clear cycles.
module cgra_queue #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 2,
  parameter bit BYPASS = 0,
  parameter int COUNT_WIDTH = $clog2(DEPTH+1),
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input logic clk, reset, clear,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg,
  output logic send_val,
  input logic send_rdy,
  output logic [COUNT_WIDTH-1:0] count
);
  if (DEPTH == 1) begin : one
    logic full;
    logic [WIDTH-1:0] entry;
    assign count = COUNT_WIDTH'(full);
    assign recv_rdy = ~full;
    assign send_val = full | (BYPASS && recv_val);
    assign send_msg = (BYPASS && !full) ? recv_msg : entry;
    always_ff @(posedge clk) begin
      if (reset | clear) full <= 0;
      else if (BYPASS) full <= ~send_rdy & (full | recv_val);
      else full <= (recv_val & ~full) | (full & ~send_rdy);
      if (recv_val & ~full & (!BYPASS || !send_rdy)) entry <= recv_msg;
    end
  end else begin : many
    logic [ADDR_WIDTH-1:0] head, tail;
    logic [WIDTH-1:0] storage [0:DEPTH-1];
    logic recv_xfer, send_xfer;
    assign recv_rdy = count < COUNT_WIDTH'(DEPTH);
    assign send_val = (count > 0) | (BYPASS && recv_val);
    assign send_msg = (BYPASS && count == 0) ? recv_msg : storage[head];
    assign recv_xfer = recv_val & recv_rdy;
    assign send_xfer = send_val & send_rdy;
    always_ff @(posedge clk) begin
      if (recv_xfer) storage[tail] <= recv_msg;
      if (reset | clear) begin
        head <= 0;
        tail <= 0;
        count <= 0;
      end else begin
        if (recv_xfer) tail <= (tail < ADDR_WIDTH'(DEPTH-1)) ? tail + 1'b1 : '0;
        if (send_xfer) head <= (head < ADDR_WIDTH'(DEPTH-1)) ? head + 1'b1 : '0;
        if (recv_xfer & ~send_xfer) count <= count + 1'b1;
        else if (~recv_xfer & send_xfer) count <= count - 1'b1;
      end
    end
  end
endmodule
