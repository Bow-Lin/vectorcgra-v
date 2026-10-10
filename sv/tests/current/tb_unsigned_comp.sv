`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_native_extensions.svh"
module tb_unsigned_comp #(`CGRA_PROFILE_PARAMETERS);
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
  scalar_comp #(`CGRA_PROFILE_BIND) dut(.*);
  int checked=0;
  ctrl_t control;
  data_t a_msg,b_msg,result;
  localparam logic [DATA_W-1:0] HIGH=DATA_W'(1)<<(DATA_W-1);
  task automatic check_case(input logic [DATA_W-1:0] a,b,input bit answer,input bit constant_mode,input bit signed_mode=0);
    control='0;control.fu_in[0]=3;control.fu_in[1]=1;
    control.operation=constant_mode ? (signed_mode ? `CGRA_OPT_LT_CONST : `CGRA_OPT_ULT_CONST) : (signed_mode ? `CGRA_OPT_LT : `CGRA_OPT_ULT);
    recv_opt__msg=control;recv_opt__val=1;
    a_msg='0;a_msg.payload=a;a_msg.predicate=1;
    b_msg='0;b_msg.payload=b;b_msg.predicate=1;
    recv_in__msg[2]=a_msg;recv_in__msg[0]=b_msg;recv_const__msg=b_msg;
    recv_in__val[2]=1;recv_in__val[0]=1;recv_const__val=1;
    send_out__rdy[0]=0;#2;
    result=send_out__msg[0];
    if(!send_out__val[0] || result.payload!=DATA_W'(answer) || !result.predicate || recv_opt__rdy || recv_const__rdy || recv_in__rdy[0] || recv_in__rdy[2])
      $fatal(1,"COMPARE_STALL a=%h b=%h mode=%b%b got=%h",a,b,signed_mode,constant_mode,result);
    send_out__rdy[0]=1;#2;
    if(!recv_opt__rdy || !recv_in__rdy[2] || recv_const__rdy!=constant_mode || recv_in__rdy[0]==constant_mode)
      $fatal(1,"COMPARE_HANDSHAKE");
    a_msg.predicate=0;recv_in__msg[2]=a_msg;#2;result=send_out__msg[0];
    if(!send_out__val[0] || result.predicate || result.payload!=DATA_W'(answer)) $fatal(1,"COMPARE_PREDICATE");
    recv_in__val[2]=0;#2;
    if(send_out__val[0] || recv_opt__rdy || recv_const__rdy) $fatal(1,"COMPARE_MISSING_OPERAND");
    clk=1;#2;clk=0;checked++;
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
    for(int mode=0;mode<2;mode++) begin
      check_case(0,1,1,1'(mode));check_case(1,0,0,1'(mode));
      check_case('1,1,0,1'(mode));check_case(1,'1,1,1'(mode));
      check_case(HIGH,0,0,1'(mode));check_case(0,HIGH,1,1'(mode));
      check_case(HIGH,HIGH,0,1'(mode));check_case('1,HIGH,0,1'(mode));
      check_case(HIGH,'1,1,1'(mode));
      check_case('1,1,1,1'(mode),1);check_case(1,'1,0,1'(mode),1);
      check_case(HIGH,0,1,1'(mode),1);
    end
    $display("NATIVE_UNSIGNED_COMPARE_PASS width=%0d cases=%0d",DATA_W,checked);
    $finish;
  end
endmodule
