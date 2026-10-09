`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_tile_units;
  logic clk=0;
  always #5 clk=~clk;
  test_fu fu(clk);
  test_regs regs(clk);
  test_route route(clk);
  test_fuxbar fuxbar(clk);
  initial begin #20000; $display("TILE_UNITS_PASS clock_cycles=2000 samples_per_unit=1999 units=4"); $finish; end
endmodule
module test_fu #(`CGRA_PROFILE_PARAMETERS)(input logic clk);
  logic [0:0] clear [0:3];
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [2:0] prologue_count_inport ;
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg [0:3];
  logic [0:0] from_mem_rdata__rdy [0:3];
  logic [0:0] gold_from_mem_rdata__rdy [0:3];
  logic [0:0] from_mem_rdata__val [0:3];
  logic [DATA_BITS-1:0] recv_const__msg ;
  logic [0:0] recv_const__rdy ;
  logic [0:0] gold_recv_const__rdy ;
  logic [0:0] recv_const__val ;
  logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ;
  logic [0:0] recv_from_ctrl_mem__rdy ;
  logic [0:0] gold_recv_from_ctrl_mem__rdy ;
  logic [0:0] recv_from_ctrl_mem__val ;
  logic [DATA_BITS-1:0] recv_in__msg [0:3];
  logic [0:0] recv_in__rdy [0:3];
  logic [0:0] gold_recv_in__rdy [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] recv_opt__rdy ;
  logic [0:0] gold_recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [HOST_BITS-1:0] recv_pkt_from_controller__msg ;
  logic [0:0] recv_pkt_from_controller__rdy ;
  logic [0:0] gold_recv_pkt_from_controller__rdy ;
  logic [0:0] recv_pkt_from_controller__val ;
  logic [DATA_BITS-1:0] send_out__msg [0:1];
  logic [DATA_BITS-1:0] gold_send_out__msg [0:1];
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] send_out__val [0:1];
  logic [0:0] gold_send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ;
  logic [PAYLOAD_BITS-1:0] gold_send_to_ctrl_mem__msg ;
  logic [0:0] send_to_ctrl_mem__rdy ;
  logic [0:0] send_to_ctrl_mem__val ;
  logic [0:0] gold_send_to_ctrl_mem__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg [0:3];
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_raddr__msg [0:3];
  logic [0:0] to_mem_raddr__rdy [0:3];
  logic [0:0] to_mem_raddr__val [0:3];
  logic [0:0] gold_to_mem_raddr__val [0:3];
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg [0:3];
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_waddr__msg [0:3];
  logic [0:0] to_mem_waddr__rdy [0:3];
  logic [0:0] to_mem_waddr__val [0:3];
  logic [0:0] gold_to_mem_waddr__val [0:3];
  logic [DATA_BITS-1:0] to_mem_wdata__msg [0:3];
  logic [DATA_BITS-1:0] gold_to_mem_wdata__msg [0:3];
  logic [0:0] to_mem_wdata__rdy [0:3];
  logic [0:0] to_mem_wdata__val [0:3];
  logic [0:0] gold_to_mem_wdata__val [0:3];
  tile_flexible_fu #(`CGRA_PROFILE_BIND) dut (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .recv_pkt_from_controller__msg(recv_pkt_from_controller__msg),
    .recv_pkt_from_controller__rdy(recv_pkt_from_controller__rdy),
    .recv_pkt_from_controller__val(recv_pkt_from_controller__val),
    .send_out__msg(send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(send_out__val),
    .send_to_ctrl_mem__msg(send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(send_to_ctrl_mem__val),
    .to_mem_raddr__msg(to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(to_mem_raddr__val),
    .to_mem_waddr__msg(to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(to_mem_waddr__val),
    .to_mem_wdata__msg(to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(to_mem_wdata__val)
  );
  Fixed2x2_FlexibleFuRTL__6b922149d55f8d70 gold (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(gold_from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(gold_recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(gold_recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(gold_recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(gold_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .recv_pkt_from_controller__msg(recv_pkt_from_controller__msg),
    .recv_pkt_from_controller__rdy(gold_recv_pkt_from_controller__rdy),
    .recv_pkt_from_controller__val(recv_pkt_from_controller__val),
    .send_out__msg(gold_send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(gold_send_out__val),
    .send_to_ctrl_mem__msg(gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(gold_to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(gold_to_mem_raddr__val),
    .to_mem_waddr__msg(gold_to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(gold_to_mem_waddr__val),
    .to_mem_wdata__msg(gold_to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(gold_to_mem_wdata__val)
  );
  initial begin
    foreach(clear[i]) clear[i]='0;
    ctrl_addr_inport='0;
    prologue_count_inport='0;
    reset='0;
    tile_id='0;
    foreach(from_mem_rdata__msg[i]) from_mem_rdata__msg[i]='0;
    foreach(from_mem_rdata__val[i]) from_mem_rdata__val[i]='0;
    recv_const__msg='0;
    recv_const__val='0;
    recv_from_ctrl_mem__msg='0;
    recv_from_ctrl_mem__val='0;
    foreach(recv_in__msg[i]) recv_in__msg[i]='0;
    foreach(recv_in__val[i]) recv_in__val[i]='0;
    recv_opt__msg='0;
    recv_opt__val='0;
    recv_pkt_from_controller__msg='0;
    recv_pkt_from_controller__val='0;
    foreach(send_out__rdy[i]) send_out__rdy[i]='0;
    send_to_ctrl_mem__rdy='0;
    foreach(to_mem_raddr__rdy[i]) to_mem_raddr__rdy[i]='0;
    foreach(to_mem_waddr__rdy[i]) to_mem_waddr__rdy[i]='0;
    foreach(to_mem_wdata__rdy[i]) to_mem_wdata__rdy[i]='0;
    for(int c=0;c<1999;c++) begin
      @(negedge clk);
      reset=(c<3 || c%251<3);
      foreach(clear[i]) clear[i]=(c%127==0);
      ctrl_addr_inport={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      prologue_count_inport={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      tile_id=TILE_ID_W'(1);
      foreach(from_mem_rdata__msg[i]) from_mem_rdata__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(from_mem_rdata__val[i]) from_mem_rdata__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      recv_const__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_const__val=(c%17==0) ? 1'b0 : 1'b1;
      recv_from_ctrl_mem__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_from_ctrl_mem__val=(c%17==0) ? 1'b0 : 1'b1;
      foreach(recv_in__msg[i]) recv_in__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_in__val[i]) recv_in__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      recv_opt__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_opt__val=(c%17==0) ? 1'b0 : 1'b1;
      recv_pkt_from_controller__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_pkt_from_controller__val=(c%17==0) ? 1'b0 : 1'b1;
      foreach(send_out__rdy[i]) send_out__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      send_to_ctrl_mem__rdy={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(to_mem_raddr__rdy[i]) to_mem_raddr__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(to_mem_waddr__rdy[i]) to_mem_waddr__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(to_mem_wdata__rdy[i]) to_mem_wdata__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      #1;
      foreach(from_mem_rdata__rdy[i]) if(from_mem_rdata__rdy[i] !== gold_from_mem_rdata__rdy[i]) $fatal(1,"unit=fu cycle=%0d port=from_mem_rdata__rdy got=%h expected=%h",c,from_mem_rdata__rdy[i],gold_from_mem_rdata__rdy[i]);
      if(recv_const__rdy !== gold_recv_const__rdy) $fatal(1,"unit=fu cycle=%0d port=recv_const__rdy got=%h expected=%h",c,recv_const__rdy,gold_recv_const__rdy);
      if(recv_from_ctrl_mem__rdy !== gold_recv_from_ctrl_mem__rdy) $fatal(1,"unit=fu cycle=%0d port=recv_from_ctrl_mem__rdy got=%h expected=%h",c,recv_from_ctrl_mem__rdy,gold_recv_from_ctrl_mem__rdy);
      foreach(recv_in__rdy[i]) if(recv_in__rdy[i] !== gold_recv_in__rdy[i]) $fatal(1,"unit=fu cycle=%0d port=recv_in__rdy got=%h expected=%h",c,recv_in__rdy[i],gold_recv_in__rdy[i]);
      if(recv_opt__rdy !== gold_recv_opt__rdy) $fatal(1,"unit=fu cycle=%0d port=recv_opt__rdy got=%h expected=%h",c,recv_opt__rdy,gold_recv_opt__rdy);
      if(recv_pkt_from_controller__rdy !== gold_recv_pkt_from_controller__rdy) $fatal(1,"unit=fu cycle=%0d port=recv_pkt_from_controller__rdy got=%h expected=%h",c,recv_pkt_from_controller__rdy,gold_recv_pkt_from_controller__rdy);
      foreach(send_out__msg[i]) if(send_out__msg[i] !== gold_send_out__msg[i]) $fatal(1,"unit=fu cycle=%0d port=send_out__msg got=%h expected=%h",c,send_out__msg[i],gold_send_out__msg[i]);
      foreach(send_out__val[i]) if(send_out__val[i] !== gold_send_out__val[i]) $fatal(1,"unit=fu cycle=%0d port=send_out__val got=%h expected=%h",c,send_out__val[i],gold_send_out__val[i]);
      if(send_to_ctrl_mem__msg !== gold_send_to_ctrl_mem__msg) $fatal(1,"unit=fu cycle=%0d port=send_to_ctrl_mem__msg got=%h expected=%h",c,send_to_ctrl_mem__msg,gold_send_to_ctrl_mem__msg);
      if(send_to_ctrl_mem__val !== gold_send_to_ctrl_mem__val) $fatal(1,"unit=fu cycle=%0d port=send_to_ctrl_mem__val got=%h expected=%h",c,send_to_ctrl_mem__val,gold_send_to_ctrl_mem__val);
      foreach(to_mem_raddr__msg[i]) if(to_mem_raddr__msg[i] !== gold_to_mem_raddr__msg[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_raddr__msg got=%h expected=%h",c,to_mem_raddr__msg[i],gold_to_mem_raddr__msg[i]);
      foreach(to_mem_raddr__val[i]) if(to_mem_raddr__val[i] !== gold_to_mem_raddr__val[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_raddr__val got=%h expected=%h",c,to_mem_raddr__val[i],gold_to_mem_raddr__val[i]);
      foreach(to_mem_waddr__msg[i]) if(to_mem_waddr__msg[i] !== gold_to_mem_waddr__msg[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_waddr__msg got=%h expected=%h",c,to_mem_waddr__msg[i],gold_to_mem_waddr__msg[i]);
      foreach(to_mem_waddr__val[i]) if(to_mem_waddr__val[i] !== gold_to_mem_waddr__val[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_waddr__val got=%h expected=%h",c,to_mem_waddr__val[i],gold_to_mem_waddr__val[i]);
      foreach(to_mem_wdata__msg[i]) if(to_mem_wdata__msg[i] !== gold_to_mem_wdata__msg[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_wdata__msg got=%h expected=%h",c,to_mem_wdata__msg[i],gold_to_mem_wdata__msg[i]);
      foreach(to_mem_wdata__val[i]) if(to_mem_wdata__val[i] !== gold_to_mem_wdata__val[i]) $fatal(1,"unit=fu cycle=%0d port=to_mem_wdata__val got=%h expected=%h",c,to_mem_wdata__val[i],gold_to_mem_wdata__val[i]);
    end
  end
endmodule
module test_regs #(`CGRA_PROFILE_PARAMETERS)(input logic clk);
  logic [0:0] clear ;
  logic [0:0] inport_ctrl_proceed ;
  logic [CTRL_BITS-1:0] inport_opt ;
  logic [0:0] reset ;
  logic [DATA_BITS-1:0] recv_data_from_const__msg [0:3];
  logic [0:0] recv_data_from_const__rdy [0:3];
  logic [0:0] gold_recv_data_from_const__rdy [0:3];
  logic [0:0] recv_data_from_const__val [0:3];
  logic [DATA_BITS-1:0] recv_data_from_fu_crossbar__msg [0:3];
  logic [0:0] recv_data_from_fu_crossbar__rdy [0:3];
  logic [0:0] gold_recv_data_from_fu_crossbar__rdy [0:3];
  logic [0:0] recv_data_from_fu_crossbar__val [0:3];
  logic [DATA_BITS-1:0] recv_data_from_routing_crossbar__msg [0:3];
  logic [0:0] recv_data_from_routing_crossbar__rdy [0:3];
  logic [0:0] gold_recv_data_from_routing_crossbar__rdy [0:3];
  logic [0:0] recv_data_from_routing_crossbar__val [0:3];
  logic [DATA_BITS-1:0] send_data_to_fu__msg [0:3];
  logic [DATA_BITS-1:0] gold_send_data_to_fu__msg [0:3];
  logic [0:0] send_data_to_fu__rdy [0:3];
  logic [0:0] send_data_to_fu__val [0:3];
  logic [0:0] gold_send_data_to_fu__val [0:3];
  logic [DATA_BITS-1:0] send_data_to_routing_crossbar__msg [0:3];
  logic [DATA_BITS-1:0] gold_send_data_to_routing_crossbar__msg [0:3];
  logic [0:0] send_data_to_routing_crossbar__rdy [0:3];
  logic [0:0] send_data_to_routing_crossbar__val [0:3];
  logic [0:0] gold_send_data_to_routing_crossbar__val [0:3];
  register_cluster #(`CGRA_PROFILE_BIND) dut (
    .clear(clear),
    .clk(clk),
    .inport_ctrl_proceed(inport_ctrl_proceed),
    .inport_opt(inport_opt),
    .reset(reset),
    .recv_data_from_const__msg(recv_data_from_const__msg),
    .recv_data_from_const__rdy(recv_data_from_const__rdy),
    .recv_data_from_const__val(recv_data_from_const__val),
    .recv_data_from_fu_crossbar__msg(recv_data_from_fu_crossbar__msg),
    .recv_data_from_fu_crossbar__rdy(recv_data_from_fu_crossbar__rdy),
    .recv_data_from_fu_crossbar__val(recv_data_from_fu_crossbar__val),
    .recv_data_from_routing_crossbar__msg(recv_data_from_routing_crossbar__msg),
    .recv_data_from_routing_crossbar__rdy(recv_data_from_routing_crossbar__rdy),
    .recv_data_from_routing_crossbar__val(recv_data_from_routing_crossbar__val),
    .send_data_to_fu__msg(send_data_to_fu__msg),
    .send_data_to_fu__rdy(send_data_to_fu__rdy),
    .send_data_to_fu__val(send_data_to_fu__val),
    .send_data_to_routing_crossbar__msg(send_data_to_routing_crossbar__msg),
    .send_data_to_routing_crossbar__rdy(send_data_to_routing_crossbar__rdy),
    .send_data_to_routing_crossbar__val(send_data_to_routing_crossbar__val)
  );
  Fixed2x2_RegisterClusterRTL__56b19f471f8ad63e gold (
    .clear(clear),
    .clk(clk),
    .inport_ctrl_proceed(inport_ctrl_proceed),
    .inport_opt(inport_opt),
    .reset(reset),
    .recv_data_from_const__msg(recv_data_from_const__msg),
    .recv_data_from_const__rdy(gold_recv_data_from_const__rdy),
    .recv_data_from_const__val(recv_data_from_const__val),
    .recv_data_from_fu_crossbar__msg(recv_data_from_fu_crossbar__msg),
    .recv_data_from_fu_crossbar__rdy(gold_recv_data_from_fu_crossbar__rdy),
    .recv_data_from_fu_crossbar__val(recv_data_from_fu_crossbar__val),
    .recv_data_from_routing_crossbar__msg(recv_data_from_routing_crossbar__msg),
    .recv_data_from_routing_crossbar__rdy(gold_recv_data_from_routing_crossbar__rdy),
    .recv_data_from_routing_crossbar__val(recv_data_from_routing_crossbar__val),
    .send_data_to_fu__msg(gold_send_data_to_fu__msg),
    .send_data_to_fu__rdy(send_data_to_fu__rdy),
    .send_data_to_fu__val(gold_send_data_to_fu__val),
    .send_data_to_routing_crossbar__msg(gold_send_data_to_routing_crossbar__msg),
    .send_data_to_routing_crossbar__rdy(send_data_to_routing_crossbar__rdy),
    .send_data_to_routing_crossbar__val(gold_send_data_to_routing_crossbar__val)
  );
  initial begin
    clear='0;
    inport_ctrl_proceed='0;
    inport_opt='0;
    reset='0;
    foreach(recv_data_from_const__msg[i]) recv_data_from_const__msg[i]='0;
    foreach(recv_data_from_const__val[i]) recv_data_from_const__val[i]='0;
    foreach(recv_data_from_fu_crossbar__msg[i]) recv_data_from_fu_crossbar__msg[i]='0;
    foreach(recv_data_from_fu_crossbar__val[i]) recv_data_from_fu_crossbar__val[i]='0;
    foreach(recv_data_from_routing_crossbar__msg[i]) recv_data_from_routing_crossbar__msg[i]='0;
    foreach(recv_data_from_routing_crossbar__val[i]) recv_data_from_routing_crossbar__val[i]='0;
    foreach(send_data_to_fu__rdy[i]) send_data_to_fu__rdy[i]='0;
    foreach(send_data_to_routing_crossbar__rdy[i]) send_data_to_routing_crossbar__rdy[i]='0;
    for(int c=0;c<1999;c++) begin
      @(negedge clk);
      reset=(c<3 || c%251<3);
      clear=(c%127==0);
      inport_ctrl_proceed={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      inport_opt={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data_from_const__msg[i]) recv_data_from_const__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data_from_const__val[i]) recv_data_from_const__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      foreach(recv_data_from_fu_crossbar__msg[i]) recv_data_from_fu_crossbar__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data_from_fu_crossbar__val[i]) recv_data_from_fu_crossbar__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      foreach(recv_data_from_routing_crossbar__msg[i]) recv_data_from_routing_crossbar__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data_from_routing_crossbar__val[i]) recv_data_from_routing_crossbar__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      foreach(send_data_to_fu__rdy[i]) send_data_to_fu__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(send_data_to_routing_crossbar__rdy[i]) send_data_to_routing_crossbar__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      #1;
      foreach(recv_data_from_const__rdy[i]) if(recv_data_from_const__rdy[i] !== gold_recv_data_from_const__rdy[i]) $fatal(1,"unit=regs cycle=%0d port=recv_data_from_const__rdy got=%h expected=%h",c,recv_data_from_const__rdy[i],gold_recv_data_from_const__rdy[i]);
      foreach(recv_data_from_fu_crossbar__rdy[i]) if(recv_data_from_fu_crossbar__rdy[i] !== gold_recv_data_from_fu_crossbar__rdy[i]) $fatal(1,"unit=regs cycle=%0d port=recv_data_from_fu_crossbar__rdy got=%h expected=%h",c,recv_data_from_fu_crossbar__rdy[i],gold_recv_data_from_fu_crossbar__rdy[i]);
      foreach(recv_data_from_routing_crossbar__rdy[i]) if(recv_data_from_routing_crossbar__rdy[i] !== gold_recv_data_from_routing_crossbar__rdy[i]) $fatal(1,"unit=regs cycle=%0d port=recv_data_from_routing_crossbar__rdy got=%h expected=%h",c,recv_data_from_routing_crossbar__rdy[i],gold_recv_data_from_routing_crossbar__rdy[i]);
      foreach(send_data_to_fu__msg[i]) if(send_data_to_fu__msg[i] !== gold_send_data_to_fu__msg[i]) $fatal(1,"unit=regs cycle=%0d port=send_data_to_fu__msg got=%h expected=%h",c,send_data_to_fu__msg[i],gold_send_data_to_fu__msg[i]);
      foreach(send_data_to_fu__val[i]) if(send_data_to_fu__val[i] !== gold_send_data_to_fu__val[i]) $fatal(1,"unit=regs cycle=%0d port=send_data_to_fu__val got=%h expected=%h",c,send_data_to_fu__val[i],gold_send_data_to_fu__val[i]);
      foreach(send_data_to_routing_crossbar__msg[i]) if(send_data_to_routing_crossbar__msg[i] !== gold_send_data_to_routing_crossbar__msg[i]) $fatal(1,"unit=regs cycle=%0d port=send_data_to_routing_crossbar__msg got=%h expected=%h",c,send_data_to_routing_crossbar__msg[i],gold_send_data_to_routing_crossbar__msg[i]);
      foreach(send_data_to_routing_crossbar__val[i]) if(send_data_to_routing_crossbar__val[i] !== gold_send_data_to_routing_crossbar__val[i]) $fatal(1,"unit=regs cycle=%0d port=send_data_to_routing_crossbar__val got=%h expected=%h",c,send_data_to_routing_crossbar__val[i],gold_send_data_to_routing_crossbar__val[i]);
    end
  end
endmodule
module test_route #(`CGRA_PROFILE_PARAMETERS)(input logic clk);
  localparam int INPUTS=8, SELECT_W=$clog2(INPUTS+1);
  logic [0:0] cgra_id ;
  logic [0:0] clear ;
  logic [0:0] compute_done ;
  logic [0:0] crossbar_id ;
  logic [SELECT_W-1:0] crossbar_outport [0:7];
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [2:0] prologue_count_inport [0:CTRL_DEPTH-1][0:INPUTS-1];
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] recv_data__msg [0:INPUTS-1];
  logic [0:0] recv_data__rdy [0:INPUTS-1];
  logic [0:0] gold_recv_data__rdy [0:INPUTS-1];
  logic [0:0] recv_data__val [0:INPUTS-1];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] recv_opt__rdy ;
  logic [0:0] gold_recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [DATA_BITS-1:0] send_data__msg [0:7];
  logic [DATA_BITS-1:0] gold_send_data__msg [0:7];
  logic [0:0] send_data__rdy [0:7];
  logic [0:0] send_data__val [0:7];
  logic [0:0] gold_send_data__val [0:7];
  tile_static_crossbar #(`CGRA_PROFILE_BIND,.INPUTS(8)) dut (
    .cgra_id(cgra_id),
    .clear(clear),
    .clk(clk),
    .compute_done(compute_done),
    .crossbar_id(crossbar_id),
    .crossbar_outport(crossbar_outport),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_data__msg(send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(send_data__val)
  );
  Fixed2x2_CrossbarRTL__5a5d5a8fac2536a3 gold (
    .cgra_id(cgra_id),
    .clear(clear),
    .clk(clk),
    .compute_done(compute_done),
    .crossbar_id(crossbar_id),
    .crossbar_outport(crossbar_outport),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(gold_recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(gold_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_data__msg(gold_send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(gold_send_data__val)
  );
  initial begin
    cgra_id='0;
    clear='0;
    compute_done='0;
    crossbar_id='0;
    foreach(crossbar_outport[i]) crossbar_outport[i]='0;
    ctrl_addr_inport='0;
    foreach(prologue_count_inport[i,j]) prologue_count_inport[i][j]='0;
    reset='0;
    tile_id='0;
    foreach(recv_data__msg[i]) recv_data__msg[i]='0;
    foreach(recv_data__val[i]) recv_data__val[i]='0;
    recv_opt__msg='0;
    recv_opt__val='0;
    foreach(send_data__rdy[i]) send_data__rdy[i]='0;
    for(int c=0;c<1999;c++) begin
      @(negedge clk);
      reset=(c<3 || c%251<3);
      cgra_id=1'b0;
      clear=(c%127==0);
      compute_done={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      crossbar_id={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(crossbar_outport[i]) crossbar_outport[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      ctrl_addr_inport={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(prologue_count_inport[i,j]) prologue_count_inport[i][j]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      tile_id=TILE_ID_W'(1);
      foreach(recv_data__msg[i]) recv_data__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data__val[i]) recv_data__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      recv_opt__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_opt__val=(c%17==0) ? 1'b0 : 1'b1;
      foreach(send_data__rdy[i]) send_data__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      #1;
      foreach(recv_data__rdy[i]) if(recv_data__rdy[i] !== gold_recv_data__rdy[i]) $fatal(1,"unit=route cycle=%0d port=recv_data__rdy got=%h expected=%h",c,recv_data__rdy[i],gold_recv_data__rdy[i]);
      if(recv_opt__rdy !== gold_recv_opt__rdy) $fatal(1,"unit=route cycle=%0d port=recv_opt__rdy got=%h expected=%h",c,recv_opt__rdy,gold_recv_opt__rdy);
      foreach(send_data__msg[i]) if(send_data__msg[i] !== gold_send_data__msg[i]) $fatal(1,"unit=route cycle=%0d port=send_data__msg got=%h expected=%h",c,send_data__msg[i],gold_send_data__msg[i]);
      foreach(send_data__val[i]) if(send_data__val[i] !== gold_send_data__val[i]) $fatal(1,"unit=route cycle=%0d port=send_data__val got=%h expected=%h",c,send_data__val[i],gold_send_data__val[i]);
    end
  end
endmodule
module test_fuxbar #(`CGRA_PROFILE_PARAMETERS)(input logic clk);
  localparam int INPUTS=2, SELECT_W=$clog2(INPUTS+1);
  logic [0:0] cgra_id ;
  logic [0:0] clear ;
  logic [0:0] compute_done ;
  logic [0:0] crossbar_id ;
  logic [SELECT_W-1:0] crossbar_outport [0:7];
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [2:0] prologue_count_inport [0:CTRL_DEPTH-1][0:INPUTS-1];
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] recv_data__msg [0:INPUTS-1];
  logic [0:0] recv_data__rdy [0:INPUTS-1];
  logic [0:0] gold_recv_data__rdy [0:INPUTS-1];
  logic [0:0] recv_data__val [0:INPUTS-1];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] recv_opt__rdy ;
  logic [0:0] gold_recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [DATA_BITS-1:0] send_data__msg [0:7];
  logic [DATA_BITS-1:0] gold_send_data__msg [0:7];
  logic [0:0] send_data__rdy [0:7];
  logic [0:0] send_data__val [0:7];
  logic [0:0] gold_send_data__val [0:7];
  tile_static_crossbar #(`CGRA_PROFILE_BIND,.INPUTS(2)) dut (
    .cgra_id(cgra_id),
    .clear(clear),
    .clk(clk),
    .compute_done(compute_done),
    .crossbar_id(crossbar_id),
    .crossbar_outport(crossbar_outport),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_data__msg(send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(send_data__val)
  );
  Fixed2x2_CrossbarRTL__340adbb3284d08b4 gold (
    .cgra_id(cgra_id),
    .clear(clear),
    .clk(clk),
    .compute_done(compute_done),
    .crossbar_id(crossbar_id),
    .crossbar_outport(crossbar_outport),
    .ctrl_addr_inport(ctrl_addr_inport),
    .prologue_count_inport(prologue_count_inport),
    .reset(reset),
    .tile_id(tile_id),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(gold_recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(gold_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_data__msg(gold_send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(gold_send_data__val)
  );
  initial begin
    cgra_id='0;
    clear='0;
    compute_done='0;
    crossbar_id='0;
    foreach(crossbar_outport[i]) crossbar_outport[i]='0;
    ctrl_addr_inport='0;
    foreach(prologue_count_inport[i,j]) prologue_count_inport[i][j]='0;
    reset='0;
    tile_id='0;
    foreach(recv_data__msg[i]) recv_data__msg[i]='0;
    foreach(recv_data__val[i]) recv_data__val[i]='0;
    recv_opt__msg='0;
    recv_opt__val='0;
    foreach(send_data__rdy[i]) send_data__rdy[i]='0;
    for(int c=0;c<1999;c++) begin
      @(negedge clk);
      reset=(c<3 || c%251<3);
      cgra_id=1'b0;
      clear=(c%127==0);
      compute_done={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      crossbar_id={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(crossbar_outport[i]) crossbar_outport[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      ctrl_addr_inport={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(prologue_count_inport[i,j]) prologue_count_inport[i][j]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      tile_id=TILE_ID_W'(1);
      foreach(recv_data__msg[i]) recv_data__msg[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      foreach(recv_data__val[i]) recv_data__val[i]=(c%17==0) ? 1'b0 : 1'b1;
      recv_opt__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_opt__val=(c%17==0) ? 1'b0 : 1'b1;
      foreach(send_data__rdy[i]) send_data__rdy[i]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      #1;
      foreach(recv_data__rdy[i]) if(recv_data__rdy[i] !== gold_recv_data__rdy[i]) $fatal(1,"unit=fuxbar cycle=%0d port=recv_data__rdy got=%h expected=%h",c,recv_data__rdy[i],gold_recv_data__rdy[i]);
      if(recv_opt__rdy !== gold_recv_opt__rdy) $fatal(1,"unit=fuxbar cycle=%0d port=recv_opt__rdy got=%h expected=%h",c,recv_opt__rdy,gold_recv_opt__rdy);
      foreach(send_data__msg[i]) if(send_data__msg[i] !== gold_send_data__msg[i]) $fatal(1,"unit=fuxbar cycle=%0d port=send_data__msg got=%h expected=%h",c,send_data__msg[i],gold_send_data__msg[i]);
      foreach(send_data__val[i]) if(send_data__val[i] !== gold_send_data__val[i]) $fatal(1,"unit=fuxbar cycle=%0d port=send_data__val got=%h expected=%h",c,send_data__val[i],gold_send_data__val[i]);
    end
  end
endmodule
