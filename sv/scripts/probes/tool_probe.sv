package tool_probe_pkg;
  typedef struct packed {
    logic [15:0] payload;
    logic predicate;
  } data_t;
endpackage

module tool_probe_stage #(
  parameter type MsgType = tool_probe_pkg::data_t
) (
  input logic clk,
  input logic reset,
  input MsgType recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output MsgType send_msg,
  output logic send_val,
  input logic send_rdy
);
  assign recv_rdy = !send_val || send_rdy;
  always_ff @(posedge clk) begin
    if (reset) begin
      send_msg <= '0;
      send_val <= 1'b0;
    end else if (recv_rdy) begin
      send_val <= recv_val;
      if (recv_val) send_msg <= recv_msg;
    end
  end
endmodule

module tool_probe (
  input logic clk,
  input logic reset,
  input tool_probe_pkg::data_t recv_msg [2],
  input logic [1:0] recv_val,
  output logic [1:0] recv_rdy,
  output tool_probe_pkg::data_t send_msg [2],
  output logic [1:0] send_val,
  input logic [1:0] send_rdy
);
  for (genvar i = 0; i < 2; i++) begin : stages
    tool_probe_stage #(.MsgType(tool_probe_pkg::data_t)) stage (
      .clk, .reset,
      .recv_msg(recv_msg[i]), .recv_val(recv_val[i]), .recv_rdy(recv_rdy[i]),
      .send_msg(send_msg[i]), .send_val(send_val[i]), .send_rdy(send_rdy[i])
    );
  end
endmodule
