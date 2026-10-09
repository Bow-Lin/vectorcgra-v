`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_tile_compare #(`CGRA_PROFILE_PARAMETERS);
  logic [0:0] cgra_id ;
  logic [0:0] clk ;
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg ;
  logic [0:0] from_mem_rdata__rdy ;
  logic [0:0] gold_from_mem_rdata__rdy ;
  logic [0:0] from_mem_rdata__val ;
  logic [DATA_BITS-1:0] recv_data__msg [0:3];
  logic [0:0] recv_data__rdy [0:3];
  logic [0:0] gold_recv_data__rdy [0:3];
  logic [0:0] recv_data__val [0:3];
  logic [HOST_BITS-1:0] recv_from_controller_pkt__msg ;
  logic [0:0] recv_from_controller_pkt__rdy ;
  logic [0:0] gold_recv_from_controller_pkt__rdy ;
  logic [0:0] recv_from_controller_pkt__val ;
  logic [DATA_BITS-1:0] send_data__msg [0:3];
  logic [DATA_BITS-1:0] gold_send_data__msg [0:3];
  logic [0:0] send_data__rdy [0:3];
  logic [0:0] send_data__val [0:3];
  logic [0:0] gold_send_data__val [0:3];
  logic [HOST_BITS-1:0] send_to_controller_pkt__msg ;
  logic [HOST_BITS-1:0] gold_send_to_controller_pkt__msg ;
  logic [0:0] send_to_controller_pkt__rdy ;
  logic [0:0] send_to_controller_pkt__val ;
  logic [0:0] gold_send_to_controller_pkt__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_raddr__msg ;
  logic [0:0] to_mem_raddr__rdy ;
  logic [0:0] to_mem_raddr__val ;
  logic [0:0] gold_to_mem_raddr__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_waddr__msg ;
  logic [0:0] to_mem_waddr__rdy ;
  logic [0:0] to_mem_waddr__val ;
  logic [0:0] gold_to_mem_waddr__val ;
  logic [DATA_BITS-1:0] to_mem_wdata__msg ;
  logic [DATA_BITS-1:0] gold_to_mem_wdata__msg ;
  logic [0:0] to_mem_wdata__rdy ;
  logic [0:0] to_mem_wdata__val ;
  logic [0:0] gold_to_mem_wdata__val ;
  tile_core #(`CGRA_PROFILE_BIND) dut (
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .tile_id(tile_id),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_from_controller_pkt__msg(recv_from_controller_pkt__msg),
    .recv_from_controller_pkt__rdy(recv_from_controller_pkt__rdy),
    .recv_from_controller_pkt__val(recv_from_controller_pkt__val),
    .send_data__msg(send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(send_data__val),
    .send_to_controller_pkt__msg(send_to_controller_pkt__msg),
    .send_to_controller_pkt__rdy(send_to_controller_pkt__rdy),
    .send_to_controller_pkt__val(send_to_controller_pkt__val),
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
  Fixed2x2_TileRTL__0ef778cc16b69f0e gold (
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .tile_id(tile_id),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(gold_from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_data__msg(recv_data__msg),
    .recv_data__rdy(gold_recv_data__rdy),
    .recv_data__val(recv_data__val),
    .recv_from_controller_pkt__msg(recv_from_controller_pkt__msg),
    .recv_from_controller_pkt__rdy(gold_recv_from_controller_pkt__rdy),
    .recv_from_controller_pkt__val(recv_from_controller_pkt__val),
    .send_data__msg(gold_send_data__msg),
    .send_data__rdy(send_data__rdy),
    .send_data__val(gold_send_data__val),
    .send_to_controller_pkt__msg(gold_send_to_controller_pkt__msg),
    .send_to_controller_pkt__rdy(send_to_controller_pkt__rdy),
    .send_to_controller_pkt__val(gold_send_to_controller_pkt__val),
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
  always #5 clk=~clk;
  initial begin
    clk=0;
    cgra_id='0;
    reset='0;
    tile_id='0;
    from_mem_rdata__msg='0;
    from_mem_rdata__val='0;
    for(int p=0;p<=3;p++) recv_data__msg[p]='0;
    for(int p=0;p<=3;p++) recv_data__val[p]='0;
    recv_from_controller_pkt__msg='0;
    recv_from_controller_pkt__val='0;
    for(int p=0;p<=3;p++) send_data__rdy[p]='0;
    send_to_controller_pkt__rdy='0;
    to_mem_raddr__rdy='0;
    to_mem_waddr__rdy='0;
    to_mem_wdata__rdy='0;
    for(int c=0;c<2000;c++) begin
      @(negedge clk);
      reset=(c<3 || c%257<3);
      cgra_id=1'b0;
      tile_id=TILE_ID_W'(1);
      from_mem_rdata__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      from_mem_rdata__val={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      for(int p=0;p<=3;p++) recv_data__msg[p]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      for(int p=0;p<=3;p++) recv_data__val[p]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_from_controller_pkt__msg={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      recv_from_controller_pkt__val={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      for(int p=0;p<=3;p++) send_data__rdy[p]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      send_to_controller_pkt__rdy={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      to_mem_raddr__rdy={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      to_mem_waddr__rdy={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      to_mem_wdata__rdy={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      #1;
      if(from_mem_rdata__rdy !== gold_from_mem_rdata__rdy) $fatal(1,"cycle=%0d port=from_mem_rdata__rdy got=%h expected=%h",c,from_mem_rdata__rdy,gold_from_mem_rdata__rdy);
      for(int p=0;p<=3;p++) if(recv_data__rdy[p] !== gold_recv_data__rdy[p]) $fatal(1,"cycle=%0d port=recv_data__rdy p=%0d got=%h expected=%h",c,p,recv_data__rdy[p],gold_recv_data__rdy[p]);
      if(recv_from_controller_pkt__rdy !== gold_recv_from_controller_pkt__rdy) $fatal(1,"cycle=%0d port=recv_from_controller_pkt__rdy got=%h expected=%h",c,recv_from_controller_pkt__rdy,gold_recv_from_controller_pkt__rdy);
      for(int p=0;p<=3;p++) if(send_data__msg[p] !== gold_send_data__msg[p]) $fatal(1,"cycle=%0d port=send_data__msg p=%0d got=%h expected=%h",c,p,send_data__msg[p],gold_send_data__msg[p]);
      for(int p=0;p<=3;p++) if(send_data__val[p] !== gold_send_data__val[p]) $fatal(1,"cycle=%0d port=send_data__val p=%0d got=%h expected=%h",c,p,send_data__val[p],gold_send_data__val[p]);
      if(send_to_controller_pkt__msg !== gold_send_to_controller_pkt__msg) $fatal(1,"cycle=%0d port=send_to_controller_pkt__msg got=%h expected=%h",c,send_to_controller_pkt__msg,gold_send_to_controller_pkt__msg);
      if(send_to_controller_pkt__val !== gold_send_to_controller_pkt__val) $fatal(1,"cycle=%0d port=send_to_controller_pkt__val got=%h expected=%h",c,send_to_controller_pkt__val,gold_send_to_controller_pkt__val);
      if(to_mem_raddr__msg !== gold_to_mem_raddr__msg) $fatal(1,"cycle=%0d port=to_mem_raddr__msg got=%h expected=%h",c,to_mem_raddr__msg,gold_to_mem_raddr__msg);
      if(to_mem_raddr__val !== gold_to_mem_raddr__val) $fatal(1,"cycle=%0d port=to_mem_raddr__val got=%h expected=%h",c,to_mem_raddr__val,gold_to_mem_raddr__val);
      if(to_mem_waddr__msg !== gold_to_mem_waddr__msg) $fatal(1,"cycle=%0d port=to_mem_waddr__msg got=%h expected=%h",c,to_mem_waddr__msg,gold_to_mem_waddr__msg);
      if(to_mem_waddr__val !== gold_to_mem_waddr__val) $fatal(1,"cycle=%0d port=to_mem_waddr__val got=%h expected=%h",c,to_mem_waddr__val,gold_to_mem_waddr__val);
      if(to_mem_wdata__msg !== gold_to_mem_wdata__msg) $fatal(1,"cycle=%0d port=to_mem_wdata__msg got=%h expected=%h",c,to_mem_wdata__msg,gold_to_mem_wdata__msg);
      if(to_mem_wdata__val !== gold_to_mem_wdata__val) $fatal(1,"cycle=%0d port=to_mem_wdata__val got=%h expected=%h",c,to_mem_wdata__val,gold_to_mem_wdata__val);
    end
    $display("TILE_COMPARE_PASS cycles=2000");
    $finish;
  end
endmodule
