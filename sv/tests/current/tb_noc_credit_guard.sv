`timescale 1ns/1ps
module tb_noc_credit_guard #(parameter bit EJECTION=0);
  logic clk=0,reset=1,recv_en=0;
  logic [31:0] recv_msg=0,send_msg[0:1],eject_msg;
  logic [1:0] recv_credit;
  logic send_val[0:1],send_rdy[0:1],eject_val;
  if(EJECTION)begin
    cgra_credit_recv #(.WIDTH(32),.VC_WIDTH(2)) dut(.clk,.reset,.recv_msg,.recv_en,.recv_credit,
      .send_msg(eject_msg),.send_val(eject_val),.send_rdy(1'b0));
  end else begin
    cgra_credit_input #(.WIDTH(32),.VC_WIDTH(2)) dut(.*);
  end
  task automatic tick;#5;clk=1;#5;clk=0;endtask
  initial begin
    send_rdy[0]=0;send_rdy[1]=0;tick();reset=0;recv_en=1;
    if($test$plusargs("BAD_VC"))recv_msg=2;
    repeat(3)tick();
    $fatal(1,"NOC_MISSING_RECEIVER_ASSERTION");
  end
endmodule
