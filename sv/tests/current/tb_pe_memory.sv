`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`include "cgra_opcodes.svh"
module tb_pe_memory #(`CGRA_PROFILE_PARAMETERS, parameter int VARIANT=0, MEM_SLOT=0);
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

  localparam logic [23:0] KINDS=MEM_SLOT==0 ? {`CGRA_FU_NAH,`CGRA_FU_ADDER,`CGRA_FU_MEM} :
    {`CGRA_FU_MEM,`CGRA_FU_ADDER,`CGRA_FU_NAH};
`ifdef CURRENT_POST_SYNTH
  current_pe_synth_adapter #(
`else
  cgra_pe #(
`endif
    `CGRA_PROFILE_BIND,.VARIANT(VARIANT),.FU_COUNT(3),.FU_KINDS(KINDS)) dut(.*);
  int cycles=0,requests=0,responses=0,writes=0,outputs_seen=0,completed=0,injected=0,blocked=0;
  int request_cycle;
  localparam logic [DATA_W-1:0] WORD=DATA_W'(64'h1234567887654321);
  host_packet_t packet;
  ctrl_t control;
  data_t value;
  task automatic tick;
    #5;clk=1;#5;clk=0;cycles++;
    if(cycles>240) $fatal(1,"PE_MEMORY_TIMEOUT");
  endtask
  task automatic send_packet(input int cmd,input int data,input ctrl_t ctrl);
    packet='0;packet.payload.cmd=6'(cmd);packet.payload.data.payload=DATA_W'(data);
    packet.payload.data.predicate=1;packet.payload.ctrl=ctrl;
    recv_from_controller_pkt__msg=packet;recv_from_controller_pkt__val=1;
    #1;while(!recv_from_controller_pkt__rdy) begin tick();#1;end
    tick();recv_from_controller_pkt__val=0;
  endtask
  initial begin
    clk=0;reset=1;cgra_id=0;tile_id=0;
    recv_from_controller_pkt__msg=0;recv_from_controller_pkt__val=0;
    from_mem_rdata__msg=0;from_mem_rdata__val=0;
    to_mem_raddr__rdy=0;to_mem_waddr__rdy=0;to_mem_wdata__rdy=0;send_to_controller_pkt__rdy=1;
    for(int p=0;p<TILE_PORTS;p++)begin recv_data__msg[p]=0;recv_data__val[p]=0;send_data__rdy[p]=1;end
    for(int load=0;load<2;load++)begin
      reset=1;recv_data__val[0]=0;tick();tick();reset=0;tick();completed=0;
      control='0;control.operation=load ? `CGRA_OPT_LD_CONST : `CGRA_OPT_STR_CONST;
      if(load)control.fu_xbar_outport[0]=1;
      else begin control.fu_in[0]=1;control.routing_xbar_outport[TILE_PORTS]=1;end
      send_packet(13,9,'0);send_packet(3,0,control);
      send_packet(7,1,'0);send_packet(8,1,'0);send_packet(0,0,'0);
      begin
        int start_cycle;
        start_cycle=cycles;
        while(completed<1)begin
          recv_data__val[0]=!load && injected==0;value='0;value.payload=WORD;value.predicate=1;recv_data__msg[0]=value;
          to_mem_raddr__rdy=cycles>start_cycle+5;
          to_mem_waddr__rdy=cycles>start_cycle+8;to_mem_wdata__rdy=to_mem_waddr__rdy;
          from_mem_rdata__val=load && requests==1 && responses==0 && cycles>request_cycle+4;
          from_mem_rdata__msg=value;send_data__rdy[0]=cycles>start_cycle+18;
          send_to_controller_pkt__rdy=cycles>start_cycle+25;
          #2;
          if(recv_data__val[0] && recv_data__rdy[0])injected++;
          if(to_mem_waddr__val && !to_mem_waddr__rdy)blocked++;
          if(to_mem_waddr__val && to_mem_waddr__rdy)begin
            if(load || to_mem_waddr__msg!=9 || !to_mem_wdata__val || !to_mem_wdata__rdy || to_mem_wdata__msg!==value)
              $fatal(1,"PE_MEMORY_WRITE");
            writes++;
          end
          if(to_mem_raddr__val && to_mem_raddr__rdy)begin
            if(!load || to_mem_raddr__msg!=9 || requests!=0)$fatal(1,"PE_MEMORY_REQUEST");
            requests++;request_cycle=cycles;
          end
          if(from_mem_rdata__val && from_mem_rdata__rdy)responses++;
          if(send_data__val[0] && send_data__rdy[0])begin
            if(!load || send_data__msg[0] !== (value ^ DATA_BITS'($test$plusargs("EXPECT_FAILURE"))))$fatal(1,"PE_MEMORY_RESULT");
            outputs_seen++;
          end
          if(send_to_controller_pkt__val && send_to_controller_pkt__rdy)completed++;
          tick();
        end
      end
    end
    if(writes!=1 || requests!=1 || responses!=1 || outputs_seen!=1 || injected!=1 || blocked<5)$fatal(1,"PE_MEMORY_COUNTS writes=%0d req=%0d resp=%0d out=%0d in=%0d blocked=%0d",writes,requests,responses,outputs_seen,injected,blocked);
    $display("PE_MEMORY_PASS variant=%0d ports=%0d width=%0d slot=%0d cycles=%0d blocked=%0d",VARIANT,TILE_PORTS,DATA_W,MEM_SLOT,cycles,blocked);$finish;
  end
endmodule
