`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_native_extensions.svh"
module tb_sub_const #(`CGRA_PROFILE_PARAMETERS);
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
  tile_adder #(`CGRA_PROFILE_BIND) dut(.*);
  ctrl_t control;
  data_t value,constant_data,result;
  int count=0;
  initial begin
    clear=0;clk=0;reset=1;ctrl_addr_inport=0;
    from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_ctrl_mem__msg=0;recv_from_ctrl_mem__val=0;
    recv_opt__val=0;recv_const__msg=0;recv_const__val=0;
    send_to_ctrl_mem__rdy=0;to_mem_raddr__rdy=0;to_mem_waddr__rdy=0;to_mem_wdata__rdy=0;
    for(int i=0;i<4;i++)begin recv_in__val[i]=0;recv_in__msg[i]=0;end
    for(int i=0;i<2;i++)send_out__rdy[i]=0;
    #2;clk=1;#2;clk=0;reset=0;
    control='0;control.operation=`CGRA_OPT_SUB_CONST;control.fu_in[0]=3;control.fu_in[1]=1;
    recv_opt__msg=control;recv_opt__val=1;
    value='0;value.payload=7;value.predicate=1;
    recv_in__msg[2]=value;recv_in__val[2]=1;
    // Three distinct constants prove that each operation requests its own token.
    for(int k=0;k<3;k++)begin
      constant_data='0;constant_data.payload=DATA_W'(k*5);constant_data.predicate=1;
      recv_const__msg=constant_data;recv_const__val=1;send_out__rdy[0]=0;#2;
      result=send_out__msg[0];
      if(!send_out__val[0] || result.payload!==DATA_W'(7-k*5) || !result.predicate || recv_const__rdy || recv_opt__rdy)$fatal(1,"SUB_CONST stalled result");
      send_out__rdy[0]=1;#2;
      if(!recv_const__rdy || !recv_in__rdy[2] || recv_in__rdy[0] || !recv_opt__rdy)$fatal(1,"SUB_CONST wrong operand consumed");
      constant_data.predicate=0;recv_const__msg=constant_data;#2;result=send_out__msg[0];
      if(result.predicate || !send_out__val[0])$fatal(1,"SUB_CONST predicate");
      recv_const__val=0;#2;
      if(send_out__val[0] || recv_in__rdy[2] || recv_const__rdy || recv_opt__rdy)$fatal(1,"SUB_CONST absent constant");
      clk=1;#2;clk=0;count++;
    end
    $display("NATIVE_SUB_CONST_PASS width=%0d cases=%0d",DATA_W,count);$finish;
  end
endmodule
