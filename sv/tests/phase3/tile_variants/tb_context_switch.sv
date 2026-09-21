`timescale 1ns/1ps
module tb_context_switch;
  logic clk=0, reset, recv_cmd_vld, progress_in_val, overwrite_fu_outport__rdy;
  logic [5:0] recv_cmd;
  logic [2:0] phi_addr, ctrl_mem_rd_addr;
  logic [6:0] recv_opt;
  logic [34:0] progress_in, overwrite_fu_outport__msg;
  logic overwrite_fu_outport__val;
  logic [57:0] stimulus;
  logic [35:0] expected;
  integer fd, count=0, rc, suppressed=0, restored=0;
  tile_context_switch dut(.*);
  initial begin
    fd=$fopen("reference/phase3/tile_variants/context-pyreplay/cycles.txt","r");
    if (!fd) $fatal(1,"missing context reference");
    while (!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",stimulus,expected);
      if(rc!=2) $fatal(1,"malformed context trace");
      {reset,recv_cmd,recv_cmd_vld,phi_addr,recv_opt,progress_in,progress_in_val,ctrl_mem_rd_addr,overwrite_fu_outport__rdy}=stimulus;
      #4;
      if($test$plusargs("EXPECT_FAILURE") && count==20) expected[0]=~expected[0];
      if ({overwrite_fu_outport__val,overwrite_fu_outport__msg} !== expected)
        $fatal(1,"context mismatch cycle=%0d actual=%h expected=%h",count,{overwrite_fu_outport__val,overwrite_fu_outport__msg},expected);
      if(count==11 && (overwrite_fu_outport__val!==1 || overwrite_fu_outport__msg!==0))
        $fatal(1,"PAUSE must suppress even invalid progress");
      if(count==38 && (overwrite_fu_outport__val!==0))
        $fatal(1,"RESUME must consume saved progress despite output backpressure");
      if(overwrite_fu_outport__val && overwrite_fu_outport__msg==0) suppressed++;
      if(overwrite_fu_outport__val && overwrite_fu_outport__msg!=0) restored++;
      clk=1; #1; clk=0; #1; count++;
    end
    if(count!=360 || suppressed==0 || restored==0) $fatal(1,"incomplete context coverage");
    $display("CONTEXT_SWITCH_PASS cycles=%0d suppressed=%0d restored=%0d",count,suppressed,restored);
    $finish;
  end
endmodule
