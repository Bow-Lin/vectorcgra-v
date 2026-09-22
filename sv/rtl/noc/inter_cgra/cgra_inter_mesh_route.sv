// ac96 PyOCN DORYMeshRouteUnitRTL. NORTH=0, SOUTH=1, WEST=2,
// EAST=3, SELF=4. Invalid input still selects NORTH for recv_rdy.
module cgra_inter_mesh_route #(
  parameter int WIDTH=32, X_WIDTH=2, Y_WIDTH=2,
  parameter int DST_X_LSB=2, DST_Y_LSB=0
) (
  input logic [X_WIDTH-1:0] pos_x,
  input logic [Y_WIDTH-1:0] pos_y,
  input logic [WIDTH-1:0] recv_msg,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg [0:4],
  output logic send_val [0:4],
  input logic send_rdy [0:4]
);
  logic [2:0] direction;
  logic [X_WIDTH-1:0] dst_x;
  logic [Y_WIDTH-1:0] dst_y;
  assign dst_x=recv_msg[DST_X_LSB+:X_WIDTH];
  assign dst_y=recv_msg[DST_Y_LSB+:Y_WIDTH];
  always_comb begin
    direction=0;
    if(recv_val)begin
      if(pos_x==dst_x && pos_y==dst_y)direction=4;
      else if(dst_y<pos_y)direction=1;
      else if(dst_y>pos_y)direction=0;
      else if(dst_x<pos_x)direction=2;
      else direction=3;
    end
  end
  for(genvar port=0;port<5;port++)begin : outputs
    assign send_msg[port]=recv_msg;
    assign send_val[port]=recv_val && direction==3'(port);
  end
  assign recv_rdy=send_rdy[direction];
endmodule
