`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`include "cgra_opcodes.svh"
module tb_arithmetic_boundaries_pe #(`CGRA_PROFILE_PARAMETERS, parameter int VARIANT=0, parameter int KIND=0, parameter bit LEGACY_VECTOR=0);
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
  localparam logic [7:0] FU=KIND==0?`CGRA_FU_DIV:KIND==1?`CGRA_FU_INCLUSIVE_DIV:KIND==2?`CGRA_FU_EXCLUSIVE_DIV:KIND==3 || KIND==6?`CGRA_FU_ALU_GEN_MAC:KIND==4?`CGRA_FU_LOOP_CONTROL:`CGRA_FU_VECTOR_MUL;
  localparam int STEPS=KIND==0 || KIND==4 || KIND==6 ? 4 : 2;
  localparam int ENTRIES=KIND==1 || KIND==2 || KIND==3 ? 2 : 1;
  localparam int INPUTS=KIND==3 || KIND==6?3:KIND==4?4:2,OUTPUTS=KIND==4?2:1;
  cgra_pe #(`CGRA_PROFILE_BIND,.VARIANT(VARIANT),.VECTOR_LEGACY_PYTHON(LEGACY_VECTOR),
    .FU_COUNT(2),.FU_KINDS({`CGRA_FU_NAH,FU})) dut(.*);
  int cycles=0,completed=0;
  int injected[TILE_PORTS],seen[2],held_cycles[2];
  logic [DATA_BITS-1:0] held_message[2];
  host_packet_t packet;
  ctrl_t control;
  data_t value;
  task automatic tick;
    #5; clk=1; #5; clk=0; cycles++;
    if(cycles>1000) $fatal(1,"ARITHMETIC_PE_TIMEOUT kind=%0d variant=%0d outputs=%0d/%0d complete=%0d",KIND,VARIANT,seen[0],seen[1],completed);
  endtask
  task automatic send_packet(input int cmd, input int addr, input int data, input ctrl_t ctrl);
    packet='0; packet.payload.cmd=6'(cmd); packet.payload.ctrl_addr=CTRL_ADDR_W'(addr);
    packet.payload.data.payload=DATA_W'(data); packet.payload.data.predicate=1;
    packet.payload.ctrl=ctrl; recv_from_controller_pkt__msg=packet; recv_from_controller_pkt__val=1;
    #1; while(!recv_from_controller_pkt__rdy) begin tick(); #1; end
    tick();recv_from_controller_pkt__val=0;
  endtask
  function automatic data_t source_data(input integer port_id,token_id);
    data_t d;
    d='0;d.predicate=1;
    case(KIND)
      0:d.payload=port_id==0?42:3;
      1:d.payload=port_id==0?(token_id==0?13:999):3;
      2:d.payload=port_id==0?43:3;
      3,6:d.payload=port_id==0?16'h8000:port_id==1?1:9;
      4:d.payload=port_id==0?0:port_id==1?3:port_id==2?8:2;
      5:d.payload=port_id==0?65535:3;
    endcase
    return d;
  endfunction
  function automatic data_t expected_data(input integer port_id,token_id);
    data_t d;
    d='0;d.predicate=1;
    case(KIND)
      0:begin d.payload=14;d.predicate=token_id==3;end
      1:d.payload=token_id==0?0:4;
      2:d.payload=token_id==0?14:1;
      3:d.payload=token_id==0?1:16'h8009;
      4:begin d.payload=port_id==0?DATA_W'(3+2*token_id):DATA_W'(token_id<3);d.predicate=port_id==1 || token_id<3;end
      5:d.payload=196605;
      6:d.payload=16'h8009;
    endcase
    return d;
  endfunction
  bit wrong;
  int launched_at;
  data_t expected;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    clk=0;reset=1;cgra_id=0;tile_id=0;from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_controller_pkt__msg=0;recv_from_controller_pkt__val=0;
    send_to_controller_pkt__rdy=1;to_mem_raddr__rdy=1;to_mem_waddr__rdy=1;to_mem_wdata__rdy=1;
    for(integer p=0;p<TILE_PORTS;p++) begin recv_data__msg[p]=0;recv_data__val[p]=0;send_data__rdy[p]=0;injected[p]=0;end
    for(integer p=0;p<2;p++) begin seen[p]=0;held_cycles[p]=0;held_message[p]=0;end
    tick();tick();reset=0;tick();
    for(integer step_id=0;step_id<ENTRIES;step_id++) begin
      control='0;
      case(KIND)
        0:begin control.operation=26;control.vector_factor_power=2;control.is_last_ctrl=1;end
        1:control.operation=step_id==0?48:49;
        2:control.operation=step_id==0?26:44;
        3:control.operation=step_id==0?60:18;
        4:control.operation=83;
        5:control.operation=75;
        6:begin control.operation=18;control.vector_factor_power=2;control.is_last_ctrl=1;end
      endcase
      for(integer p=0;p<INPUTS;p++) begin control.fu_in[p]=3'(p+1);control.routing_xbar_outport[TILE_PORTS+p]=ROUTING_SEL_W'(p+1);end
      for(integer p=0;p<OUTPUTS;p++) control.fu_xbar_outport[p]=2'(p+1);
      send_packet(3,step_id,0,control);
    end
    send_packet(7,0,STEPS,'0);send_packet(8,0,ENTRIES,'0);send_packet(0,0,0,'0);launched_at=cycles;
    while(seen[0]<STEPS || (OUTPUTS==2 && seen[1]<STEPS) || completed<1) begin
      for(integer p=0;p<INPUTS;p++) begin
        recv_data__val[p]=injected[p]<STEPS && (p==0 || cycles>=launched_at+12);
        recv_data__msg[p]=source_data(p,injected[p]);
      end
      for(integer p=0;p<OUTPUTS;p++) send_data__rdy[p]=held_cycles[p]>=(p==0?8:3);
      #2;
      for(integer p=0;p<INPUTS;p++) if(recv_data__val[p] && recv_data__rdy[p]) injected[p]++;
      for(integer p=0;p<OUTPUTS;p++) if(send_data__val[p]) begin
        expected=expected_data(p,seen[p]);if(wrong && p==0 && seen[p]==0) expected.payload^=1;
        if(seen[p]>=STEPS || send_data__msg[p]!==expected) $fatal(1,"ARITHMETIC_PE_RESULT kind=%0d variant=%0d port=%0d index=%0d got=%h expected=%h",KIND,VARIANT,p,seen[p],send_data__msg[p],expected);
        if(!send_data__rdy[p]) begin
          if(held_cycles[p] && send_data__msg[p]!==held_message[p]) $fatal(1,"ARITHMETIC_PE_HOLD");
          held_message[p]=send_data__msg[p];held_cycles[p]++;
        end else begin seen[p]++;held_cycles[p]=0;end
      end
      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completed++;
      tick();
    end
    if(completed!=1) $fatal(1,"ARITHMETIC_PE_COMPLETE_COUNT");
    for(integer p=0;p<INPUTS;p++) begin
      if(injected[p]!=STEPS) $fatal(1,"ARITHMETIC_PE_INPUT_COUNT port=%0d count=%0d expected=%0d",p,injected[p],STEPS);
      recv_data__val[p]=0;
    end
    for(integer p=0;p<TILE_PORTS;p++) send_data__rdy[p]=1;
    repeat(12) begin
      #1;for(integer p=0;p<TILE_PORTS;p++) if(send_data__val[p]) $fatal(1,"ARITHMETIC_PE_DUPLICATE");
      if(send_to_controller_pkt__val) $fatal(1,"ARITHMETIC_PE_DUPLICATE_COMPLETE");tick();
    end
    $display("ARITHMETIC_PE_PASS kind=%0d variant=%0d width=%0d cycles=%0d outputs=%0d/%0d completion=%0d",KIND,VARIANT,DATA_W,cycles,seen[0],seen[1],completed);$finish;
  end
endmodule
