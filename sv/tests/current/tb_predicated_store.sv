`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_native_extensions.svh"
module tb_predicated_store #(`CGRA_PROFILE_PARAMETERS);
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
`ifdef PREDICATED_STORE_POST_SYNTH
  // sv2v packs ascending unpacked arrays with index zero at the high end.
  predicated_store_netlist dut(
    .recv_in__msg({recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3]}),
    .recv_in__val({recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3]}),
    .recv_in__rdy({recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3]}),
    .send_out__msg({send_out__msg[0],send_out__msg[1]}),
    .send_out__val({send_out__val[0],send_out__val[1]}),
    .send_out__rdy({send_out__rdy[0],send_out__rdy[1]}),.*);
`else
  tile_memory_fu #(`CGRA_PROFILE_BIND) dut(.*);
`endif
  ctrl_t control;
  data_t a,b,k;
  bit expected_ready,active,predicated_on;
  int checks=0;
  initial begin
    clear=0;clk=0;reset=0;ctrl_addr_inport=0;
    from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_ctrl_mem__msg=0;recv_from_ctrl_mem__val=0;
    send_to_ctrl_mem__rdy=0;to_mem_raddr__rdy=0;
    for(int i=0;i<2;i++)send_out__rdy[i]=0;
    for(int constant_op=0;constant_op<2;constant_op++)
      for(int predicates=0;predicates<4;predicates++)
        for(int valids=0;valids<4;valids++)
          for(int ready=0;ready<4;ready++)
            for(int flushing=0;flushing<3;flushing++) begin
              control='0;control.operation=constant_op!=0 ? 58 : 13;control.fu_in[0]=3;control.fu_in[1]=1;
              recv_opt__msg=control;recv_opt__val=1;
              reset=flushing==1;clear=flushing==2;
              a='0;a.payload=3;a.predicate=predicates[0];
              b='0;b.payload=DATA_W'('hffffffff);b.predicate=predicates[1];
              k='0;k.payload=5;k.predicate=predicates[1];
              for(int i=0;i<4;i++)begin recv_in__val[i]=0;recv_in__msg[i]='0;end
              recv_in__msg[2]=a;recv_in__msg[0]=b;
              recv_in__val[2]=valids[0];recv_in__val[0]=valids[1];
              recv_const__msg=k;recv_const__val=valids[1];
              to_mem_waddr__rdy=ready[0];to_mem_wdata__rdy=ready[1];
              active=valids==3 && flushing==0;predicated_on=predicates==3;
              expected_ready=active && (!predicated_on || ready==3);
              if($test$plusargs("EXPECT_FAILURE") && checks==300)expected_ready=!expected_ready;
              #2;
              if(recv_opt__rdy!==expected_ready || recv_in__rdy[2]!==expected_ready ||
                 (constant_op!=0 ? recv_const__rdy : recv_in__rdy[0])!==expected_ready)
                $fatal(1,"PREDICATED_STORE_WAIT op=%0d predicates=%0d valids=%0d ready=%0d flushing=%0d",constant_op,predicates,valids,ready,flushing);
              if(to_mem_waddr__val!==(active && predicated_on) || to_mem_wdata__val!==(active && predicated_on) ||
                 recv_in__rdy[1] || recv_in__rdy[3] || (constant_op!=0 && recv_in__rdy[0]) || (constant_op==0 && recv_const__rdy))
                $fatal(1,"PREDICATED_STORE_PORT");
              checks++;
              recv_opt__val=0;#2;
              if(recv_opt__rdy || to_mem_waddr__val || to_mem_wdata__val)$fatal(1,"PREDICATED_STORE_CONTROL");
            end
    $display("PREDICATED_STORE_PASS width=%0d checks=%0d",DATA_W,checks);$finish;
  end
endmodule
