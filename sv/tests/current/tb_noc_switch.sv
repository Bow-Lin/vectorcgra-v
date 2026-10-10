`timescale 1ns/1ps
module tb_noc_switch #(parameter int INPUTS=3, parameter bit LEGACY=0);
  logic clk=0,reset=1;
  logic [31:0] recv_msg[0:INPUTS-1],send_msg;
  logic recv_val[0:INPUTS-1],recv_rdy[0:INPUTS-1],send_val,send_rdy=0;
  cgra_switch #(.WIDTH(32),.INPUTS(INPUTS),.LEGACY_PYTHON(LEGACY)) dut(.*);
  int accepted=0,stalls=0;
  task automatic tick;#5;clk=1;#5;clk=0;endtask
  task automatic check(input int port,input bit ready);
    #1;
    if(!send_val || send_msg !== (recv_msg[port] ^ 32'($test$plusargs("EXPECT_FAILURE"))))
      $fatal(1,"NOC_SWITCH_RESULT port=%0d got=%h",port,send_msg);
    for(int i=0;i<INPUTS;i++)if(recv_rdy[i] !== (ready && i==port))$fatal(1,"NOC_SWITCH_ACCEPTED_WRONG_INPUT");
    if(ready)accepted++;else stalls++;
  endtask
  initial begin
    for(int i=0;i<INPUTS;i++)begin recv_msg[i]=32'(100+i);recv_val[i]=0;end
    tick();reset=0;recv_val[INPUTS-1]=1;
    check(INPUTS-1,0);tick();
    // Earlier-priority arrivals must not replace the already offered packet.
    for(int i=0;i<INPUTS;i++)recv_val[i]=1;
    repeat(4)begin check(INPUTS-1,0);tick();end
    send_rdy=1;check(INPUTS-1,1);tick();
    for(int n=0;n<3*INPUTS;n++)begin
      check(n%INPUTS,1);tick();recv_msg[n%INPUTS]+=1000;
    end
    for(int i=0;i<INPUTS;i++)recv_val[i]=0;
    #1;if(send_val)$fatal(1,"NOC_SWITCH_EMPTY_VALID");
    for(int i=0;i<INPUTS;i++)if(recv_rdy[i])$fatal(1,"NOC_SWITCH_EMPTY_READY");
    for(int i=0;i<INPUTS;i++)recv_val[i]=1;
    reset=1;#1;
    if(send_val)$fatal(1,"NOC_SWITCH_RESET_VALID");
    for(int i=0;i<INPUTS;i++)if(recv_rdy[i])$fatal(1,"NOC_SWITCH_RESET_READY");
    tick();reset=0;check(0,1);tick();
    if(accepted!=3*INPUTS+2 || stalls!=5)$fatal(1,"NOC_SWITCH_COVERAGE");
    $display("NOC_SWITCH_PASS inputs=%0d accepted=%0d stalls=%0d",INPUTS,accepted,stalls);$finish;
  end
endmodule
