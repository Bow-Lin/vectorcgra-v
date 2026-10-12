`timescale 1ns/1ps
// External credit conservation and per-VC order, including bypass and reset flush.
module tb_noc_credit #(parameter bit LEGACY=0);
  logic clk=0,reset=1;
  logic [31:0] input_msg=0,link_msg,output_msg;
  logic input_val=0,input_rdy,link_en,output_val,output_rdy=0;
  logic [1:0] credit,returned;
  bit bad_credit=0;
  assign returned=bad_credit ? 2'b01 : credit;
  cgra_credit_send #(.WIDTH(32),.VC_WIDTH(2),.LEGACY_PYTHON(LEGACY)) source (
    .clk,.reset,.recv_msg(input_msg),.recv_val(input_val),.recv_rdy(input_rdy),
    .send_msg(link_msg),.send_en(link_en),.send_credit(returned),.available_credit());
  cgra_credit_recv #(.WIDTH(32),.VC_WIDTH(2),.LEGACY_PYTHON(LEGACY)) sink (
    .clk,.reset,.recv_msg(link_msg),.recv_en(link_en),.recv_credit(credit),
    .send_msg(output_msg),.send_val(output_val),.send_rdy(output_rdy));
  int sent[0:1],received[0:1],outstanding[0:1];
  int cycles=0,stalls=0,simultaneous=0,invalid_vcs=0,epoch;
  bit held=0;
  logic [31:0] held_msg;
  task automatic tick(input bit observe=1);
    #2;
    if(observe && !reset)begin
      if(input_rdy!=link_en)$fatal(1,"NOC_CREDIT_READY_ENABLE");
      if(credit !== ((output_val && output_rdy) ? (2'b01 << output_msg[1:0]) : 2'b00))
        $fatal(1,"NOC_CREDIT_RETURN_IDENTITY");
      if(held && (!output_val || output_msg!==held_msg))$fatal(1,"NOC_CREDIT_STALL_CHANGED");
      if(output_val && !output_rdy)stalls++;
      held=output_val && !output_rdy;held_msg=output_msg;
      if(link_en)begin
        int vc;vc=int'(link_msg[1:0]);
        if(vc>1)$fatal(1,"NOC_CREDIT_INVALID_ACCEPT");
        sent[vc]++;outstanding[vc]++;
      end
      if(output_val && output_rdy)begin
        int vc;logic [31:0] expected;
        vc=int'(output_msg[1:0]);
        if(vc>1)$fatal(1,"NOC_CREDIT_INVALID_OUTPUT");
        expected=(32'(epoch)<<24)|(32'(received[vc])<<8)|32'(vc);
        if(output_msg!==(expected ^ 32'($test$plusargs("EXPECT_FAILURE"))))$fatal(1,"NOC_CREDIT_RESULT expected=%h got=%h",expected,output_msg);
        received[vc]++;
      end
      for(int v=0;v<2;v++)begin
        if(credit[v])outstanding[v]--;
        if(credit[v] && link_en && link_msg[1:0]==2'(v))simultaneous++;
        if(outstanding[v]<0 || outstanding[v]>2 || received[v]>sent[v])$fatal(1,"NOC_CREDIT_CONSERVATION vc=%0d",v);
      end
    end
    #3;clk=1;#5;clk=0;cycles++;
  endtask
  task automatic reset_pair;
    reset=1;input_val=1;output_rdy=1;#1;
    if(input_rdy || link_en || output_val || credit!='0)$fatal(1,"NOC_CREDIT_RESET_HANDSHAKE");
    tick(0);held=0;reset=0;input_val=0;output_rdy=0;
    for(int v=0;v<2;v++)begin sent[v]=0;received[v]=0;outstanding[v]=0;end
  endtask
  initial begin
    for(int v=0;v<2;v++)begin sent[v]=0;received[v]=0;outstanding[v]=0;end
    tick(0);reset=0;
    if($test$plusargs("BAD_CREDIT"))begin bad_credit=1;tick();$fatal(1,"NOC_MISSING_CREDIT_ASSERTION");end
    // Fill both VCs before reset; every accepted old-epoch packet must be flushed.
    epoch=7;
    for(int n=0;n<4;n++)begin
      input_msg=(32'(epoch)<<24)|(32'(n/2)<<8)|32'(n%2);input_val=1;tick();
    end
    if(sent[0]!=2 || sent[1]!=2)$fatal(1,"NOC_CREDIT_RESET_SETUP");
    reset_pair();epoch=8;
    for(int n=0;n<160;n++)begin
      int vc;
      vc=n%2;
      if(!input_val && sent[vc]<12)begin
        input_msg=(32'(epoch)<<24)|(32'(sent[vc])<<8)|32'(vc);input_val=1;
      end
      output_rdy=n>=12 && n%5!=0;
      #1;
      begin bit fire;fire=input_val && input_rdy;tick();if(fire)input_val=0;end
    end
    if(sent[0]!=12 || sent[1]!=12 || received[0]!=12 || received[1]!=12 || outstanding[0]!=0 || outstanding[1]!=0 || stalls<8 || simultaneous==0)
      $fatal(1,"NOC_CREDIT_COVERAGE sent=%0d/%0d received=%0d/%0d simultaneous=%0d",sent[0],sent[1],received[0],received[1],simultaneous);
    for(int v=2;v<4;v++)begin
      input_msg=32'(v);input_val=1;#1;
      if(input_rdy || link_en)$fatal(1,"NOC_CREDIT_INVALID_VC_READY");tick();invalid_vcs++;
    end
    input_val=0;reset_pair();
    $display("NOC_CREDIT_PASS cycles=%0d stalls=%0d simultaneous=%0d invalid_vcs=%0d",cycles,stalls,simultaneous,invalid_vcs);$finish;
  end
endmodule
