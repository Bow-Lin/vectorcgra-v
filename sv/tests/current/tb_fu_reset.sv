`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tb_fu_reset #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS);
  `include "cgra_profile.svh"
  logic [0:0] clear [0:FU_COUNT-1];
  logic [0:0] clk ;
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [2:0] prologue_count_inport ;
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg [0:FU_COUNT-1];
  logic [0:0] from_mem_rdata__rdy [0:FU_COUNT-1];
  logic [0:0] from_mem_rdata__val [0:FU_COUNT-1];
  logic [DATA_BITS-1:0] recv_const__msg ;
  logic [0:0] recv_const__rdy ;
  logic [0:0] recv_const__val ;
  logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ;
  logic [0:0] recv_from_ctrl_mem__rdy ;
  logic [0:0] recv_from_ctrl_mem__val ;
  logic [DATA_BITS-1:0] recv_in__msg [0:3];
  logic [0:0] recv_in__rdy [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [HOST_BITS-1:0] recv_pkt_from_controller__msg ;
  logic [0:0] recv_pkt_from_controller__rdy ;
  logic [0:0] recv_pkt_from_controller__val ;
  logic [DATA_BITS-1:0] send_out__msg [0:1];
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ;
  logic [0:0] send_to_ctrl_mem__rdy ;
  logic [0:0] send_to_ctrl_mem__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg [0:FU_COUNT-1];
  logic [0:0] to_mem_raddr__rdy [0:FU_COUNT-1];
  logic [0:0] to_mem_raddr__val [0:FU_COUNT-1];
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg [0:FU_COUNT-1];
  logic [0:0] to_mem_waddr__rdy [0:FU_COUNT-1];
  logic [0:0] to_mem_waddr__val [0:FU_COUNT-1];
  logic [DATA_BITS-1:0] to_mem_wdata__msg [0:FU_COUNT-1];
  logic [0:0] to_mem_wdata__rdy [0:FU_COUNT-1];
  logic [0:0] to_mem_wdata__val [0:FU_COUNT-1];
  tile_flexible_fu_configurable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) dut(.*);
  ctrl_t control;
  data_t operand,result_value;
  integer checks=0;
  task automatic tick;#2;clk=1;#2;clk=0;#2;endtask
  task automatic require(input bit good,input string why);
    checks++;if(!good) $fatal(1,"FU_RESET_CHECK %s",why);
  endtask
  task automatic isolated;
    #1;
    require(!recv_opt__rdy && !recv_const__rdy && !recv_from_ctrl_mem__rdy && !recv_pkt_from_controller__rdy,"DEFECT_RESET input interfaces");
    require(!send_to_ctrl_mem__val && send_to_ctrl_mem__msg==0,"control request isolation");
    for(integer i=0;i<4;i++) require(!recv_in__rdy[i],"operand isolation");
    for(integer i=0;i<2;i++) require(!send_out__val[i] && send_out__msg[i]==0,"result isolation");
    for(integer i=0;i<FU_COUNT;i++) begin
      require(!from_mem_rdata__rdy[i],"memory response isolation");
      require(!to_mem_raddr__val[i] && !to_mem_waddr__val[i] && !to_mem_wdata__val[i],"memory request isolation");
    end
  endtask
  initial begin
    for(integer i=0;i<=(FU_COUNT-1);i++) clear[i]='1;
    clk='1;
    ctrl_addr_inport='1;
    prologue_count_inport='1;
    reset='1;
    tile_id='1;
    for(integer i=0;i<=(FU_COUNT-1);i++) from_mem_rdata__msg[i]='1;
    for(integer i=0;i<=(FU_COUNT-1);i++) from_mem_rdata__val[i]='1;
    recv_const__msg='1;
    recv_const__val='1;
    recv_from_ctrl_mem__msg='1;
    recv_from_ctrl_mem__val='1;
    for(integer i=0;i<=(3);i++) recv_in__msg[i]='1;
    for(integer i=0;i<=(3);i++) recv_in__val[i]='1;
    recv_opt__msg='1;
    recv_opt__val='1;
    recv_pkt_from_controller__msg='1;
    recv_pkt_from_controller__val='1;
    for(integer i=0;i<=(1);i++) send_out__rdy[i]='1;
    send_to_ctrl_mem__rdy='1;
    for(integer i=0;i<=(FU_COUNT-1);i++) to_mem_raddr__rdy[i]='1;
    for(integer i=0;i<=(FU_COUNT-1);i++) to_mem_waddr__rdy[i]='1;
    for(integer i=0;i<=(FU_COUNT-1);i++) to_mem_wdata__rdy[i]='1;
    clk=0;ctrl_addr_inport=0;tile_id=0;
    for(integer i=0;i<FU_COUNT;i++) clear[i]=0;
    control='0;control.operation=2;control.fu_in[0]=1;control.fu_in[1]=2;control.fu_in[2]=3;control.fu_in[3]=4;
    recv_opt__msg=control;
    for(integer i=0;i<4;i++) begin operand='0;operand.payload=DATA_W'(5+2*i);operand.predicate=1;recv_in__msg[i]=operand;end
    reset=1;isolated();tick();isolated();tick();reset=0;prologue_count_inport=0;#1;
    result_value=send_out__msg[0];
    require(send_out__val[0] && recv_opt__rdy && result_value.payload==12 && result_value.predicate,"normal operation resumes after reset");
    tick();reset=1;isolated();tick();reset=0;#1;
    require(send_out__val[0],"operation resumes after repeated reset");
    $display("FU_RESET_PASS width=%0d count=%0d checks=%0d",DATA_W,FU_COUNT,checks);$finish;
  end
endmodule
