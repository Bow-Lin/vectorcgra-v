`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_native_extensions.svh"
module tb_native_phi #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  logic [0:0] clear;
  logic [0:0] clk;
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport;
  logic [0:0] reset;
  logic [DATA_BITS-1:0] from_mem_rdata__msg;
  logic [0:0] from_mem_rdata__rdy;
  logic [0:0] from_mem_rdata__val;
  logic [DATA_BITS-1:0] recv_const__msg;
  logic [0:0] recv_const__rdy;
  logic [0:0] recv_const__val;
  logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg;
  logic [0:0] recv_from_ctrl_mem__rdy;
  logic [0:0] recv_from_ctrl_mem__val;
  logic [DATA_BITS-1:0] recv_in__msg [0:3];
  logic [0:0] recv_in__rdy [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [CTRL_BITS-1:0] recv_opt__msg;
  logic [0:0] recv_opt__rdy;
  logic [0:0] recv_opt__val;
  logic [DATA_BITS-1:0] send_out__msg [0:1];
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg;
  logic [0:0] send_to_ctrl_mem__rdy;
  logic [0:0] send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg;
  logic [0:0] to_mem_raddr__rdy;
  logic [0:0] to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg;
  logic [0:0] to_mem_waddr__rdy;
  logic [0:0] to_mem_waddr__val;
  logic [DATA_BITS-1:0] to_mem_wdata__msg;
  logic [0:0] to_mem_wdata__rdy;
  logic [0:0] to_mem_wdata__val;
`ifdef NATIVE_PHI_POST_SYNTH
  scalar_phi_netlist dut(
    .recv_in__msg({recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3]}),
    .recv_in__val({recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3]}),
    .recv_in__rdy({recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3]}),
    .send_out__msg({send_out__msg[0],send_out__msg[1]}),
    .send_out__val({send_out__val[0],send_out__val[1]}),
    .send_out__rdy({send_out__rdy[0],send_out__rdy[1]}), .*);
`else
  scalar_phi #(`CGRA_PROFILE_BIND) dut(.*);
`endif
  ctrl_t control;
  data_t value,result;
  int checked=0;
  task automatic tick;
    #2;clk=1;#2;clk=0;#2;
  endtask
  task automatic operand(input int lane,input logic [DATA_W-1:0] payload,input bit predicate,input bit valid=1);
    value='0;value.payload=payload;value.predicate=predicate;
    recv_in__msg[lane]=value;recv_in__val[lane]=valid;
  endtask
  task automatic check_result(input logic [DATA_W-1:0] payload,input bit predicate,input bit valid,input bit ready,input logic [3:0] consumed);
    #2;result=send_out__msg[0];
    if(result.payload!==payload || result.predicate!==predicate || send_out__val[0]!==valid || recv_opt__rdy!==ready)
      $fatal(1,"PHI_RESULT op=%0d got=%h/%b expected=%h/%b valid=%b ready=%b",control.operation,result.payload,result.predicate,payload,predicate,send_out__val[0],recv_opt__rdy);
    for(int i=0;i<4;i++) if(recv_in__rdy[i]!==consumed[i])$fatal(1,"PHI_HANDSHAKE lane=%0d",i);
    if(recv_const__rdy || send_out__val[1] || to_mem_raddr__val || to_mem_waddr__val || send_to_ctrl_mem__val)$fatal(1,"PHI_SIDE_EFFECT");
    checked++;
  endtask
  task automatic start_slot(input int slot,input bit predicate);
    ctrl_addr_inport=CTRL_ADDR_W'(slot);
    control='0;control.operation=`CGRA_OPT_PHI_START_PRED;control.fu_in[0]=3;control.fu_in[1]=1;
    recv_opt__msg=control;recv_opt__val=1;send_out__rdy[0]=0;
    operand(2,DATA_W'(17),predicate);operand(0,DATA_W'(91),1,0);
    repeat(5)begin check_result(17,predicate,1,0,0);tick();end
    recv_in__val[2]=0;send_out__rdy[0]=1;
    check_result(17,predicate,0,0,0);tick();
    recv_in__val[2]=1;
    check_result(17,predicate,1,1,4'b0100);tick();
  endtask
  initial begin
    clear='0;
    clk='0;
    ctrl_addr_inport='0;
    reset='0;
    from_mem_rdata__msg='0;
    from_mem_rdata__val='0;
    recv_const__msg='0;
    recv_const__val='0;
    recv_from_ctrl_mem__msg='0;
    recv_from_ctrl_mem__val='0;
    for(int i=0;i<=3;i++) recv_in__msg[i]='0;
    for(int i=0;i<=3;i++) recv_in__val[i]='0;
    recv_opt__msg='0;
    recv_opt__val='0;
    for(int i=0;i<=1;i++) send_out__rdy[i]='0;
    send_to_ctrl_mem__rdy='0;
    to_mem_raddr__rdy='0;
    to_mem_waddr__rdy='0;
    to_mem_wdata__rdy='0;
    reset=1;#2;clk=1;#2;clk=0;reset=0;

    for(int count=1;count<=4;count++) begin
      control='0;control.operation=`CGRA_OPT_PHI_N;
      // Operand order differs from physical lane order.
      control.fu_in[0]=3;if(count>1)control.fu_in[1]=1;
      if(count>2)control.fu_in[2]=4;if(count>3)control.fu_in[3]=2;
      recv_opt__msg=control;recv_opt__val=1;
      for(int mask=0;mask<16;mask++) begin : predicates
        logic [DATA_W-1:0] answer;
        logic [3:0] consumed;
        bit predicate,selected;
        for(int lane=0;lane<4;lane++)operand(lane,(DATA_W'(1)<<(DATA_W-1))+DATA_W'(lane+11),1'(mask>>lane));
        answer=(DATA_W'(1)<<(DATA_W-1))+13;predicate=0;selected=0;consumed=0;
        for(int i=0;i<count;i++)begin
          int lane;lane=int'(control.fu_in[i])-1;consumed[lane]=1;
          if(!selected && ((mask>>lane)&1))begin selected=1;predicate=1;answer=(DATA_W'(1)<<(DATA_W-1))+DATA_W'(lane+11);end
        end
        if($test$plusargs("EXPECT_FAILURE") && count==1 && mask==0)answer^=1;
        send_out__rdy[0]=0;check_result(answer,predicate,1,0,0);tick();
        check_result(answer,predicate,1,0,0);
        send_out__rdy[0]=1;check_result(answer,predicate,1,1,consumed);
        for(int i=0;i<count;i++)begin
          recv_in__val[control.fu_in[i]-1]=0;
          check_result(answer,predicate,0,0,0);
          recv_in__val[control.fu_in[i]-1]=1;
        end
        tick();
      end
    end
    control.fu_in='0;recv_opt__msg=control;
    check_result(0,0,0,0,0);
    start_slot(0,0);
    operand(2,17,0);operand(0,91,1);send_out__rdy[0]=1;
    check_result(91,1,1,1,4'b0101);tick();
    start_slot(1,1); // A different address still executes its initial arm.
    ctrl_addr_inport=0;operand(2,17,0);operand(0,91,1);
    check_result(91,1,1,1,4'b0101);
    recv_opt__val=0;clear=1;tick();clear=0;
    start_slot(0,0);
    // Frozen binary/start opcodes keep their original behavior.
    recv_opt__val=0;reset=1;tick();reset=0;
    control='0;control.operation=`CGRA_OPT_PHI_START;control.fu_in[0]=3;control.fu_in[1]=1;
    recv_opt__msg=control;recv_opt__val=1;operand(2,17,0);operand(0,91,0);
    check_result(17,1,1,1,4'b0100);tick();
    control.operation=`CGRA_OPT_PHI;control.fu_in[2]=4;recv_opt__msg=control;operand(3,55,1);
    check_result(17,0,1,1,4'b0101);
    // Native vector replay advances only on acceptance, even with long stalls.
    recv_opt__val=0;reset=1;tick();reset=0;
    control='0;control.operation=`CGRA_OPT_PHI_START_PRED;control.fu_in[0]=3;control.fu_in[1]=1;
    control.vector_factor_power=2;control.is_last_ctrl=1;recv_opt__msg=control;recv_opt__val=1;
    operand(2,17,1);operand(0,91,1,0);
    for(int beat=0;beat<4;beat++)begin
      send_out__rdy[0]=0;
      repeat(3)begin check_result(17,beat==3,1,0,0);tick();end
      send_out__rdy[0]=1;check_result(17,beat==3,1,1,4'b0100);tick();
    end
    operand(2,17,0);operand(0,91,1);check_result(91,0,1,1,4'b0101);
    $display("NATIVE_PHI_PASS width=%0d checks=%0d",DATA_W,checked);$finish;
  end
endmodule
