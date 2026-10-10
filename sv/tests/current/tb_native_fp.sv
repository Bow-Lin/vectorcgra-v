`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_native_extensions.svh"
module tb_native_fp #(`CGRA_PROFILE_PARAMETERS, parameter int EXP=8, FRAC=23, parameter bit MULTIPLY=0);
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
  tile_fp_fu #(`CGRA_PROFILE_BIND, .FP_EXP_W(EXP), .FP_SIG_W(FRAC), .MULTIPLY(MULTIPLY)) dut(.*);
  localparam int BIAS=(1<<(EXP-1))-1;
  localparam logic [DATA_W-1:0] ONE=DATA_W'(BIAS)<<FRAC;
  localparam logic [DATA_W-1:0] TWO=DATA_W'(BIAS+1)<<FRAC;
  localparam logic [DATA_W-1:0] HALF=DATA_W'(BIAS-1)<<FRAC;
  localparam logic [DATA_W-1:0] ONE_HALF=ONE|(DATA_W'(1)<<(FRAC-1));
  localparam logic [DATA_W-1:0] SIGN=DATA_W'(1)<<(DATA_W-1);
  localparam logic [DATA_W-1:0] INF=((DATA_W'(1)<<EXP)-1)<<FRAC;
  ctrl_t control;
  data_t am,bm,result;
  int count=0;
  task automatic check(input int opcode,input logic [DATA_W-1:0] a,b,answer,input bit nan=0);
    bit constant_op,increment;
    if($test$plusargs("EXPECT_FAILURE") && count==0) answer^=1;
    constant_op=opcode==39 || opcode==42;increment=opcode==40;
    control='0;control.operation=7'(opcode);control.fu_in[0]=2;control.fu_in[1]=4;
    recv_opt__msg=control;recv_opt__val=1;
    am='0;am.payload=a;am.predicate=1;bm='0;bm.payload=b;bm.predicate=1;
    recv_in__msg[1]=am;recv_in__msg[3]=bm;recv_const__msg=bm;
    recv_in__val[1]=1;recv_in__val[3]=1;recv_const__val=1;
    send_out__rdy[0]=0;#2;result=send_out__msg[0];
    if(!send_out__val[0] || !result.predicate || recv_opt__rdy || recv_const__rdy || recv_in__rdy[1] || recv_in__rdy[3])$fatal(1,"FP stalled handshake op=%0d",opcode);
    if(nan)begin
      if((result.payload&INF)!=INF || (result.payload&((DATA_W'(1)<<FRAC)-1))==0)$fatal(1,"FP expected NaN");
    end else if(result.payload!==answer)$fatal(1,"FP arithmetic op=%0d a=%h b=%h got=%h expected=%h",opcode,a,b,result.payload,answer);
    send_out__rdy[0]=1;#2;
    if(!recv_opt__rdy || !recv_in__rdy[1] || recv_const__rdy!=constant_op || recv_in__rdy[3]!=( !constant_op && !increment))$fatal(1,"FP consumed wrong operand");
    if(constant_op)begin
      bm.predicate=0;recv_const__msg=bm;#2;result=send_out__msg[0];
      if(!send_out__val[0] || result.predicate)$fatal(1,"FP constant predicate");
      recv_const__val=0;
    end else recv_in__val[1]=0;
    #2;if(send_out__val[0] || recv_opt__rdy || recv_const__rdy || recv_in__rdy[1] || recv_in__rdy[3])$fatal(1,"FP absent operand");
    clk=1;#2;clk=0;count++;
  endtask
  initial begin
    clear=0;clk=0;reset=1;ctrl_addr_inport=0;
    from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_ctrl_mem__msg=0;recv_from_ctrl_mem__val=0;
    recv_opt__val=0;recv_opt__msg=0;recv_const__msg=0;recv_const__val=0;
    send_to_ctrl_mem__rdy=0;to_mem_raddr__rdy=0;to_mem_waddr__rdy=0;to_mem_wdata__rdy=0;
    for(int i=0;i<4;i++)begin recv_in__val[i]=0;recv_in__msg[i]=0;end
    for(int i=0;i<2;i++)send_out__rdy[i]=0;
    #2;clk=1;#2;clk=0;reset=0;
    if(MULTIPLY)begin
      check(41,ONE,TWO,TWO);check(41,ONE_HALF,TWO,ONE_HALF+(DATA_W'(1)<<FRAC));
      check(41,ONE|SIGN,HALF,HALF|SIGN);check(41,0,ONE,0);
      check(41,SIGN,ONE,SIGN);check(41,1,TWO,2);
      check(41,INF-1,TWO,INF);check(41,INF,0,0,1);
      check(42,TWO,HALF,ONE);check(42,ONE,ONE|SIGN,ONE|SIGN);
    end else begin
      check(37,ONE,ONE,TWO);check(37,ONE,HALF,ONE_HALF);
      check(38,ONE,ONE,0);check(38,HALF,ONE,HALF|SIGN);
      check(37,SIGN,SIGN,SIGN);check(37,1,1,2);
      check(37,ONE,DATA_W'(BIAS-FRAC-1)<<FRAC,ONE);
      check(37,ONE|1,DATA_W'(BIAS-FRAC-1)<<FRAC,ONE|2);
      check(37,INF,INF|SIGN,0,1);check(37,INF,ONE,INF);
      check(39,ONE,HALF,ONE_HALF);check(40,HALF,0,ONE_HALF);
    end
    $display("NATIVE_IEEE_FP_PASS width=%0d multiply=%0d cases=%0d",DATA_W,MULTIPLY,count);$finish;
  end
endmodule
