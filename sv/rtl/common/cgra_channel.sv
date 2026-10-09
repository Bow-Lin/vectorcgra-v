// PyOCN ChannelRTL: LATENCY normal queues, each with two entries.
module cgra_channel #(
  parameter int WIDTH = 32,
  parameter int LATENCY = 0
) (
  input logic clk, reset, clear,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg,
  output logic send_val,
  input logic send_rdy
);
  logic [WIDTH-1:0] messages [0:LATENCY];
  logic valid [0:LATENCY];
  logic ready [0:LATENCY];
  assign messages[0] = recv_msg;
  assign valid[0] = recv_val;
  assign recv_rdy = ready[0];
  assign send_msg = messages[LATENCY];
  assign send_val = valid[LATENCY];
  assign ready[LATENCY] = send_rdy;
  for (genvar i = 0; i < LATENCY; i++) begin : stages
    cgra_queue #(.WIDTH(WIDTH), .DEPTH(2)) queue (
      .clk, .reset, .clear,
      .recv_msg(messages[i]), .recv_val(valid[i]), .recv_rdy(ready[i]),
      .send_msg(messages[i+1]), .send_val(valid[i+1]), .send_rdy(ready[i+1]), .count()
    );
  end
endmodule
