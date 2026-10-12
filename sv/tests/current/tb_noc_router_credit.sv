`timescale 1ns/1ps
// An exhausted VC must not reserve the physical output against another VC.
module tb_noc_router_credit;
  logic clk=0,reset=1;
  logic [1:0] pos=0;
  logic [31:0] recv_msg[0:2],send_msg[0:2];
  logic recv_en[0:2],send_en[0:2];
  logic [1:0] recv_credit[0:2],send_credit[0:2];
  cgra_ring_router #(.WIDTH(32),.NODES(4),.DST_LSB(2),.DST_WIDTH(2),.VC_LSB(0),.VC_WIDTH(2)) dut(.*);
  int cycles=0,delivered=0;
  function automatic logic [31:0] packet(input int id,vc);
    return (32'(id)<<4)|32'(4|vc); // destination 1; from node 0, route right.
  endfunction
  task automatic tick;
    #2;
    for(int p=0;p<3;p++)if(send_en[p] && !reset)begin
      logic [31:0] expected;
      case(delivered)
        0:expected=packet(10,0);
        1:expected=packet(11,0);
        2:expected=packet(30,1);
        3:expected=packet(20,0);
        default:$fatal(1,"NOC_ROUTER_DUPLICATE");
      endcase
      if(p!=1 || send_msg[p]!==(expected ^ 32'($test$plusargs("EXPECT_FAILURE"))))
        $fatal(1,"NOC_ROUTER_RESULT index=%0d expected=%h got=%h",delivered,expected,send_msg[p]);
      delivered++;
    end
    #3;clk=1;#5;clk=0;cycles++;
    if(cycles>40)$fatal(1,"NOC_ROUTER_BLOCKED_ELIGIBLE_VC delivered=%0d",delivered);
  endtask
  task automatic inject(input int id,vc);
    recv_msg[2]=packet(id,vc);recv_en[2]=1;tick();recv_en[2]=0;
  endtask
  initial begin
    for(int p=0;p<3;p++)begin recv_msg[p]=0;recv_en[p]=0;send_credit[p]=0;end
    tick();reset=0;
    inject(10,0);inject(11,0);while(delivered<2)tick();
    // No VC0 credits remain. Let its third head reach output arbitration first.
    inject(20,0);repeat(3)tick();
    inject(30,1);while(delivered<3)tick();
    repeat(3)tick();if(delivered!=3)$fatal(1,"NOC_ROUTER_EXHAUSTED_VC_SENT");
    send_credit[1]=2'b01;tick();send_credit[1]=0;
    while(delivered<4)tick();repeat(3)tick();
    $display("NOC_ROUTER_CREDIT_PASS cycles=%0d delivered=%0d",cycles,delivered);$finish;
  end
endmodule
