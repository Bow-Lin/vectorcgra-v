// PyOCN XbarRTL/XbarBypassQueueRTL: depth-two input queues, destination
// routing, per-output round-robin switches, and unbuffered output units.
module cgra_xbar #(
  parameter int WIDTH = 32,
  parameter int INPUTS = 2,
  parameter int OUTPUTS = 2,
  parameter int DST_LSB = 0,
  parameter int DST_WIDTH = (OUTPUTS <= 1) ? 1 : $clog2(OUTPUTS),
  parameter bit INPUT_BYPASS = 0,
  parameter int DIR_WIDTH = (OUTPUTS <= 1) ? 1 : $clog2(OUTPUTS),
  parameter bit LEGACY_PYTHON=0
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg [0:INPUTS-1],
  input logic recv_val [0:INPUTS-1],
  output logic recv_rdy [0:INPUTS-1],
  output logic [WIDTH-1:0] send_msg [0:OUTPUTS-1],
  output logic send_val [0:OUTPUTS-1],
  input logic send_rdy [0:OUTPUTS-1]
);
  logic [WIDTH-1:0] queued_msg [0:INPUTS-1];
  logic queued_val [0:INPUTS-1], queued_rdy [0:INPUTS-1];
  logic [DIR_WIDTH-1:0] destination [0:INPUTS-1];
  logic route_val [0:INPUTS-1][0:OUTPUTS-1];
  logic route_rdy [0:INPUTS-1][0:OUTPUTS-1];
  for (genvar i = 0; i < INPUTS; i++) begin : inputs
    logic queue_recv_rdy;
    assign recv_rdy[i]=(LEGACY_PYTHON || !reset) && queue_recv_rdy;
    cgra_queue #(.WIDTH(WIDTH), .DEPTH(2), .BYPASS(INPUT_BYPASS)) queue (
      .clk, .reset, .clear(1'b0), .recv_msg(recv_msg[i]), .recv_val(recv_val[i] && (LEGACY_PYTHON || !reset)), .recv_rdy(queue_recv_rdy),
      .send_msg(queued_msg[i]), .send_val(queued_val[i]), .send_rdy(queued_rdy[i]), .count()
    );
    assign destination[i] = DIR_WIDTH'(queued_msg[i][DST_LSB +: DST_WIDTH]);
    // Static element writers keep sv2v's flattened two-dimensional array
    // disjoint across inputs. Dynamic writes in separate processes otherwise
    // become overlapping whole-vector drivers after flattening.
    for (genvar j = 0; j < OUTPUTS; j++) begin : destinations
      always_comb begin
        route_val[i][j] = 0;
        if (queued_val[i] && destination[i] == DIR_WIDTH'(j)) route_val[i][j] = 1;
      end
    end
    assign queued_rdy[i] = route_rdy[i][destination[i]];
  end
  for (genvar o = 0; o < OUTPUTS; o++) begin : outputs
    logic [WIDTH-1:0] switch_msg [0:INPUTS-1];
    logic switch_val [0:INPUTS-1], switch_rdy [0:INPUTS-1];
    for (genvar i = 0; i < INPUTS; i++) begin : ports
      assign switch_msg[i] = queued_msg[i];
      assign switch_val[i] = route_val[i][o];
      assign route_rdy[i][o] = switch_rdy[i];
    end
    cgra_switch #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH), .INPUTS(INPUTS)) switch_unit (
      .clk, .reset, .recv_msg(switch_msg), .recv_val(switch_val), .recv_rdy(switch_rdy),
      .send_msg(send_msg[o]), .send_val(send_val[o]), .send_rdy(send_rdy[o])
    );
  end
endmodule
