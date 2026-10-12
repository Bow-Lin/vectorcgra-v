`timescale 1ns/1ps
module tb_noc_ring_guard #(parameter int VCS=2,CREDITS=2);
  logic clk=0,reset=1;
  logic [31:0] recv_msg[0:1],send_msg[0:1];
  logic recv_val[0:1],recv_rdy[0:1],send_val[0:1],send_rdy[0:1];
  cgra_credit_ring #(.WIDTH(32),.NODES(2),.DST_LSB(2),.DST_WIDTH(1),.VC_LSB(0),.VC_WIDTH(2),
    .VCS(VCS),.CREDITS(CREDITS)) dut(.*);
  initial begin
    for(int i=0;i<2;i++)begin recv_msg[i]=0;recv_val[i]=0;send_rdy[i]=0;end
    #5;clk=1;#5;$fatal(1,"NOC_MISSING_RING_GUARD");
  end
endmodule
