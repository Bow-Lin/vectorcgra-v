// Inter-CGRA RingNetworkRTL shares the control ring's credit architecture.
// Packet vc_id may be two bits although the original network has two VCs;
// vc_id 2/3 therefore cannot enter. CHANNEL_LATENCY is ignored by ac96.
module cgra_inter_ring #(
  parameter int WIDTH=32,NODES=4,
  parameter int DST_LSB=2,DST_WIDTH=$clog2(NODES),
  parameter int VC_LSB=0,VC_WIDTH=2,
  parameter int CHANNEL_LATENCY=1,VCS=2,CREDITS=2,
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
  initial begin
    if(NODES<2 || DST_WIDTH!=$clog2(NODES))$fatal(1,"Ring destination width must match NODES>=2");
    if(VC_WIDTH<1 || DST_LSB<0 || VC_LSB<0 || DST_LSB+DST_WIDTH>WIDTH || VC_LSB+VC_WIDTH>WIDTH)
      $fatal(1,"Ring destination and VC fields must fit the packet");
  end
  cgra_credit_ring #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH),.NODES(NODES),.DST_LSB(DST_LSB),.DST_WIDTH(DST_WIDTH),
    .VC_LSB(VC_LSB),.VC_WIDTH(VC_WIDTH),.VCS(VCS),.CREDITS(CREDITS)) ring (
    .clk,.reset,.recv_msg,.recv_val,.recv_rdy,.send_msg,.send_val,.send_rdy);
endmodule
