// Parameterized ac96 PyOCN MeshNetworkRTL. Node index is y*COLS+x;
// NORTH increases y. Every directed link has CHANNEL_LATENCY normal queues.
module cgra_inter_mesh #(
  parameter int WIDTH=32,COLS=2,ROWS=2,
  parameter int X_WIDTH=(COLS>1)?$clog2(COLS):1,
  parameter int Y_WIDTH=(ROWS>1)?$clog2(ROWS):1,
  parameter int DST_X_LSB=2,DST_Y_LSB=0,CHANNEL_LATENCY=1,
  localparam int NODES=COLS*ROWS,
  parameter bit LEGACY_PYTHON=0
) (
  input logic clk,reset,
  input logic [WIDTH-1:0] recv_msg [0:NODES-1],
  input logic recv_val [0:NODES-1],
  output logic recv_rdy [0:NODES-1],
  output logic [WIDTH-1:0] send_msg [0:NODES-1],
  output logic send_val [0:NODES-1],
  input logic send_rdy [0:NODES-1]
);
  logic [WIDTH-1:0] router_recv_msg [0:NODES-1][0:4],router_send_msg [0:NODES-1][0:4];
  logic router_recv_val [0:NODES-1][0:4],router_recv_rdy [0:NODES-1][0:4];
  logic router_send_val [0:NODES-1][0:4],router_send_rdy [0:NODES-1][0:4];
  initial begin
    // ac96 constructs mk_bits(clog2(dimension)) before wiring the routers.
    // Single-row/column networks fail there; do not silently extend the domain.
    if(COLS<2 || ROWS<2)$fatal(1,"ac96 MeshNetworkRTL requires COLS>=2 and ROWS>=2");
    if(CHANNEL_LATENCY<0)$fatal(1,"Mesh channel latency must be nonnegative");
    if(X_WIDTH!=$clog2(COLS) || Y_WIDTH!=$clog2(ROWS))$fatal(1,"Mesh coordinate widths must match dimensions");
    if(DST_X_LSB<0 || DST_Y_LSB<0 || DST_X_LSB+X_WIDTH>WIDTH || DST_Y_LSB+Y_WIDTH>WIDTH)
      $fatal(1,"Mesh destination fields must fit the packet");
  end
  for(genvar node=0;node<NODES;node++)begin : nodes
    cgra_inter_mesh_router #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH),.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),
      .DST_X_LSB(DST_X_LSB),.DST_Y_LSB(DST_Y_LSB)) router (
      .clk,.reset,.pos_x(X_WIDTH'(node%COLS)),.pos_y(Y_WIDTH'(node/COLS)),
      .recv_msg(router_recv_msg[node]),.recv_val(router_recv_val[node]),.recv_rdy(router_recv_rdy[node]),
      .send_msg(router_send_msg[node]),.send_val(router_send_val[node]),.send_rdy(router_send_rdy[node]));
    assign router_recv_msg[node][4]=recv_msg[node];
    assign router_recv_val[node][4]=recv_val[node];
    assign recv_rdy[node]=router_recv_rdy[node][4];
    assign send_msg[node]=router_send_msg[node][4];
    assign send_val[node]=router_send_val[node][4];
    assign router_send_rdy[node][4]=send_rdy[node];
    for(genvar direction=0;direction<4;direction++)begin : links
      localparam int OPPOSITE=direction^1;
      localparam int TARGET=(direction==0)?node+COLS:(direction==1)?node-COLS:(direction==2)?node-1:node+1;
      localparam bit CONNECTED=(direction==0)?node/COLS<ROWS-1:(direction==1)?node/COLS>0:
        (direction==2)?node%COLS>0:node%COLS<COLS-1;
      if(CONNECTED)begin : connected
        cgra_channel #(.WIDTH(WIDTH),.LATENCY(CHANNEL_LATENCY)) channel (
          .clk,.reset,.clear(1'b0),.recv_msg(router_send_msg[node][direction]),
          .recv_val(router_send_val[node][direction]),.recv_rdy(router_send_rdy[node][direction]),
          .send_msg(router_recv_msg[TARGET][OPPOSITE]),.send_val(router_recv_val[TARGET][OPPOSITE]),
          .send_rdy(router_recv_rdy[TARGET][OPPOSITE]));
      end else begin : boundary
        assign router_send_rdy[node][direction]=0;
        assign router_recv_msg[node][direction]='0;
        assign router_recv_val[node][direction]=0;
      end
    end
  end
endmodule
