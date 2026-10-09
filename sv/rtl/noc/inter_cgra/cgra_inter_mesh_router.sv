// Five normal depth-two input queues, Y-first routes, and independent
// advancing round-robin output switches. No output queue in ac96.
module cgra_inter_mesh_router #(
  parameter int WIDTH=32, X_WIDTH=2, Y_WIDTH=2,
  parameter int DST_X_LSB=2, DST_Y_LSB=0
) (
  input logic clk,reset,
  input logic [X_WIDTH-1:0] pos_x,
  input logic [Y_WIDTH-1:0] pos_y,
  input logic [WIDTH-1:0] recv_msg [0:4],
  input logic recv_val [0:4],
  output logic recv_rdy [0:4],
  output logic [WIDTH-1:0] send_msg [0:4],
  output logic send_val [0:4],
  input logic send_rdy [0:4]
);
  logic [WIDTH-1:0] routed_msg [0:4][0:4];
  logic routed_val [0:4][0:4],routed_rdy [0:4][0:4];
  for(genvar input_port=0;input_port<5;input_port++)begin : inputs
    logic [WIDTH-1:0] queued_msg;
    logic queued_val,queued_rdy;
    cgra_queue #(.WIDTH(WIDTH),.DEPTH(2)) input_queue (
      .clk,.reset,.clear(1'b0),.recv_msg(recv_msg[input_port]),
      .recv_val(recv_val[input_port]),.recv_rdy(recv_rdy[input_port]),
      .send_msg(queued_msg),.send_val(queued_val),.send_rdy(queued_rdy),.count());
    cgra_inter_mesh_route #(.WIDTH(WIDTH),.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),
      .DST_X_LSB(DST_X_LSB),.DST_Y_LSB(DST_Y_LSB)) route (
      .pos_x,.pos_y,.recv_msg(queued_msg),.recv_val(queued_val),.recv_rdy(queued_rdy),
      .send_msg(routed_msg[input_port]),.send_val(routed_val[input_port]),.send_rdy(routed_rdy[input_port]));
  end
  for(genvar output_port=0;output_port<5;output_port++)begin : outputs
    logic [WIDTH-1:0] candidates [0:4];
    logic valid [0:4],ready [0:4];
    for(genvar input_port=0;input_port<5;input_port++)begin : transpose
      assign candidates[input_port]=routed_msg[input_port][output_port];
      assign valid[input_port]=routed_val[input_port][output_port];
      assign routed_rdy[input_port][output_port]=ready[input_port];
    end
    cgra_switch #(.WIDTH(WIDTH),.INPUTS(5)) switch_unit (
      .clk,.reset,.recv_msg(candidates),.recv_val(valid),.recv_rdy(ready),
      .send_msg(send_msg[output_port]),.send_val(send_val[output_port]),.send_rdy(send_rdy[output_port]));
  end
endmodule
