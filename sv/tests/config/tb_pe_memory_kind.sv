`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tb_pe_memory_kind #(`CGRA_PROFILE_PARAMETERS, parameter int VARIANT=1, KIND=32);
  logic clk=0,reset=1;
  logic [DATA_BITS-1:0] recv_data__msg[0:TILE_PORTS-1],send_data__msg[0:TILE_PORTS-1];
  logic recv_data__val[0:TILE_PORTS-1],recv_data__rdy[0:TILE_PORTS-1];
  logic send_data__val[0:TILE_PORTS-1],send_data__rdy[0:TILE_PORTS-1];
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg,to_mem_waddr__msg;
  logic to_mem_raddr__val,to_mem_waddr__val,to_mem_wdata__val,from_mem_rdata__rdy;
  logic [DATA_BITS-1:0] to_mem_wdata__msg;
  // KIND=ADDER is a legal no-memory catalog; both memory kinds are also tested.
  cgra_pe #(`CGRA_PROFILE_BIND,.VARIANT(VARIANT),.FU_COUNT(2),.FU_KINDS({`CGRA_FU_NAH,8'(KIND)})) dut(
    .clk,.reset,.cgra_id(CGRA_ID_W'(0)),.tile_id(TILE_ID_W'(0)),
    .recv_data__msg,.recv_data__val,.recv_data__rdy,.send_data__msg,.send_data__val,.send_data__rdy,
    .recv_from_controller_pkt__msg(HOST_BITS'(0)),.recv_from_controller_pkt__val(1'b0),.recv_from_controller_pkt__rdy(),
    .send_to_controller_pkt__msg(),.send_to_controller_pkt__val(),.send_to_controller_pkt__rdy(1'b0),
    .to_mem_raddr__msg,.to_mem_raddr__val,.to_mem_raddr__rdy(1'b0),
    .to_mem_waddr__msg,.to_mem_waddr__val,.to_mem_waddr__rdy(1'b0),
    .to_mem_wdata__msg,.to_mem_wdata__val,.to_mem_wdata__rdy(1'b0),
    .from_mem_rdata__msg(DATA_BITS'(0)),.from_mem_rdata__val(1'b0),.from_mem_rdata__rdy);
  initial begin
    for(int i=0;i<TILE_PORTS;i++)begin recv_data__msg[i]=0;recv_data__val[i]=0;send_data__rdy[i]=0;end
    repeat(3)begin #5;clk=1;#5;clk=0;end
    reset=0;
    repeat(3)begin #5;clk=1;#5;clk=0;end
    if(KIND==0 && (to_mem_raddr__msg!='0 || to_mem_waddr__msg!='0 || to_mem_wdata__msg!='0 ||
       to_mem_raddr__val || to_mem_waddr__val || to_mem_wdata__val || from_mem_rdata__rdy))
      $fatal(1,"CONFIG_NO_MEMORY_OUTPUT");
    $display("CONFIG_PE_MEMORY_KIND_PASS variant=%0d kind=%0d",VARIANT,KIND);$finish;
  end
endmodule
