// RingRouteUnitRTL: shortest direction; ties go right. Crossing the
// dateline changes vc_id only on the selected valid output.
module cgra_ring_route #(
  parameter int WIDTH = 32,
  parameter int NODES = 5,
  parameter int DST_LSB = 0,
  parameter int DST_WIDTH = $clog2(NODES),
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = 1,
  parameter int POS_WIDTH = $clog2(NODES)
) (
  input logic [POS_WIDTH-1:0] pos,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg [0:2],
  output logic send_val [0:2],
  input logic send_rdy [0:2]
);
  logic [POS_WIDTH-1:0] left_dist, right_dist;
  logic [DST_WIDTH-1:0] destination;
  logic [1:0] direction;
  logic [WIDTH-1:0] routed_msg;
  assign destination = recv_msg[DST_LSB +: DST_WIDTH];
  always_comb begin
    if (destination < pos) begin
      left_dist = pos - POS_WIDTH'(destination);
      right_dist = POS_WIDTH'(NODES-1) - pos + POS_WIDTH'(destination) + 1'b1;
    end else begin
      left_dist = POS_WIDTH'(NODES) + pos - POS_WIDTH'(destination);
      right_dist = POS_WIDTH'(destination) - pos;
    end
  end
  always_comb begin
    direction = 0;
    routed_msg = recv_msg;
    if (recv_val) begin
      if (pos == destination) direction = 2;
      else if (left_dist < right_dist) direction = 0;
      else direction = 1;
      if (((pos == POS_WIDTH'(NODES-1)) && direction == 1) ||
          ((pos == 0) && direction == 0))
        routed_msg[VC_LSB +: VC_WIDTH] = VC_WIDTH'(1);
    end
  end
  // Static output slices avoid a wide variable part-select after sv2v.
  // Preserve the original invalid-message value on every unselected output.
  for (genvar o = 0; o < 3; o++) begin : outputs
    assign send_val[o] = recv_val && (direction == 2'(o));
    assign send_msg[o] = send_val[o] ? routed_msg : recv_msg;
  end
  assign recv_rdy = send_rdy[direction];
endmodule
