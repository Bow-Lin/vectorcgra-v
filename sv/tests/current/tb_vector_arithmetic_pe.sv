`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`include "cgra_opcodes.svh"
module tb_vector_arithmetic_pe #(`CGRA_PROFILE_PARAMETERS, parameter int VARIANT=0, parameter bit LEGACY_PYTHON=0);
  `include "cgra_profile.svh"
  logic [CGRA_ID_W-1:0] cgra_id;
  logic [0:0] clk;
  logic [0:0] reset;
  logic [TILE_ID_W-1:0] tile_id;
  logic [DATA_BITS-1:0] from_mem_rdata__msg;
  logic [0:0] from_mem_rdata__rdy;
  logic [0:0] from_mem_rdata__val;
  logic [DATA_BITS-1:0] recv_data__msg [0:TILE_PORTS-1];
  logic [0:0] recv_data__rdy [0:TILE_PORTS-1];
  logic [0:0] recv_data__val [0:TILE_PORTS-1];
  logic [HOST_BITS-1:0] recv_from_controller_pkt__msg;
  logic [0:0] recv_from_controller_pkt__rdy;
  logic [0:0] recv_from_controller_pkt__val;
  logic [DATA_BITS-1:0] send_data__msg [0:TILE_PORTS-1];
  logic [0:0] send_data__rdy [0:TILE_PORTS-1];
  logic [0:0] send_data__val [0:TILE_PORTS-1];
  logic [HOST_BITS-1:0] send_to_controller_pkt__msg;
  logic [0:0] send_to_controller_pkt__rdy;
  logic [0:0] send_to_controller_pkt__val;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg;
  logic [0:0] to_mem_raddr__rdy;
  logic [0:0] to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg;
  logic [0:0] to_mem_waddr__rdy;
  logic [0:0] to_mem_waddr__val;
  logic [DATA_BITS-1:0] to_mem_wdata__msg;
  logic [0:0] to_mem_wdata__rdy;
  logic [0:0] to_mem_wdata__val;
  cgra_pe #(`CGRA_PROFILE_BIND, .VARIANT(VARIANT),.VECTOR_LEGACY_PYTHON(LEGACY_PYTHON),
    .FU_COUNT(2),.FU_KINDS({`CGRA_FU_NAH,`CGRA_FU_VECTOR_ADDER})) dut(.*);
  int cycles=0, outputs_seen=0, forwarded=0, injected=0, completed=0;
  host_packet_t packet;
  ctrl_t control;
  data_t value;
  task automatic tick;
    #5; clk=1; #5; clk=0; cycles++;
    if(cycles>400) $fatal(1,"PE_TIMEOUT variant=%0d outputs=%0d forwarded=%0d complete=%0d",VARIANT,outputs_seen,forwarded,completed);
  endtask
  task automatic send_packet(input int cmd, input int addr, input int data, input ctrl_t ctrl);
    packet='0; packet.payload.cmd=6'(cmd); packet.payload.ctrl_addr=CTRL_ADDR_W'(addr);
    packet.payload.data.payload=DATA_W'(data); packet.payload.data.predicate=1;
    packet.payload.ctrl=ctrl; recv_from_controller_pkt__msg=packet; recv_from_controller_pkt__val=1;
    #1; while(!recv_from_controller_pkt__rdy) begin tick(); #1; end
    tick();recv_from_controller_pkt__val=0;
  endtask
  integer held_cycles=0;
  logic [DATA_BITS-1:0] held;
  logic [DATA_W-1:0] expected;
  bit wrong;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    clk=0;reset=1;cgra_id=0;tile_id=0;from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_controller_pkt__msg=0;recv_from_controller_pkt__val=0;
    send_to_controller_pkt__rdy=1;to_mem_raddr__rdy=1;to_mem_waddr__rdy=1;to_mem_wdata__rdy=1;
    for (integer p=0;p<TILE_PORTS;p++) begin recv_data__msg[p]=0;recv_data__val[p]=0;send_data__rdy[p]=0;end
    tick();tick();reset=0;tick();
    expected=LEGACY_PYTHON ? ({DATA_W{1'b1}} << (DATA_W/4)) : DATA_W'(0);
    if (wrong) expected=expected^1;
    control='0;control.operation=72;control.fu_in[0]=1;
    control.routing_xbar_outport[TILE_PORTS]=1;control.fu_xbar_outport[0]=1;
    send_packet(13,0,1,'0);send_packet(3,0,0,control);send_packet(7,0,1,'0);send_packet(8,0,1,'0);
    send_packet(0,0,0,'0);
    while (outputs_seen<1 || completed<1) begin
      recv_data__val[0]=injected<1;value='0;value.payload='1;value.predicate=1;recv_data__msg[0]=value;
      send_data__rdy[0]=held_cycles>=8;#2;
      if (recv_data__val[0] && recv_data__rdy[0]) injected++;
      if (send_data__val[0]) begin
        value=send_data__msg[0];
        if (value.payload!==expected || !value.predicate) $fatal(1,"VECTOR_ARITHMETIC_PE_RESULT variant=%0d legacy=%0d got=%h expected=%h",VARIANT,LEGACY_PYTHON,value.payload,expected);
        if (!send_data__rdy[0]) begin
          if (held_cycles && send_data__msg[0]!==held) $fatal(1,"VECTOR_ARITHMETIC_PE_HOLD");
          held=send_data__msg[0];held_cycles++;
        end else outputs_seen++;
      end
      if (send_to_controller_pkt__val && send_to_controller_pkt__rdy) completed++;
      tick();
    end
    if (injected!=1 || outputs_seen!=1 || completed!=1 || held_cycles<8) $fatal(1,"VECTOR_ARITHMETIC_PE_COUNTS");
    recv_data__val[0]=0;
    repeat(12) begin
      #1;if(send_data__val[0] || send_to_controller_pkt__val) $fatal(1,"VECTOR_ARITHMETIC_PE_DUPLICATE");tick();
    end
    $display("VECTOR_ARITHMETIC_PE_PASS variant=%0d legacy=%0d cycles=%0d held=%0d",VARIANT,LEGACY_PYTHON,cycles,held_cycles);
    $finish;
  end
endmodule
