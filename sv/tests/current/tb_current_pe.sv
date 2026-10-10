`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`include "cgra_opcodes.svh"
module tb_current_pe #(`CGRA_PROFILE_PARAMETERS, parameter int VARIANT=0);
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
`ifdef CURRENT_POST_SYNTH
  current_pe_synth_adapter #(`CGRA_PROFILE_BIND, .VARIANT(VARIANT),
`else
  cgra_pe #(`CGRA_PROFILE_BIND, .VARIANT(VARIANT),
`endif
    .FU_COUNT(5), .FU_KINDS({`CGRA_FU_NAH,`CGRA_FU_ADDER,`CGRA_FU_GEP,`CGRA_FU_SHIFTER,`CGRA_FU_GRANT})) dut(.*);
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
  initial begin
    clk=0; reset=1; cgra_id=0;tile_id=0;
    from_mem_rdata__msg=0;from_mem_rdata__val=0;
    recv_from_controller_pkt__msg=0;recv_from_controller_pkt__val=0;
    send_to_controller_pkt__rdy=1;to_mem_raddr__rdy=1;to_mem_waddr__rdy=1;to_mem_wdata__rdy=1;
    for(int p=0;p<TILE_PORTS;p++) begin recv_data__msg[p]=0;recv_data__val[p]=0;send_data__rdy[p]=1;end
    tick();tick();reset=0;tick();
    for(int run=0;run<(VARIANT==1 ? 2 : 1);run++) begin
    if(run>0) begin
      recv_data__val[0]=0;
      send_packet(2,0,0,'0); // Context task switch must clear per-slot grants.
      tick();tick();
      outputs_seen=0;forwarded=0;injected=0;completed=0;
    end
    // A FU result finishes while the independent routing output is stalled.
    // The constant must advance only when this whole control step retires.
    control='0;control.operation=`CGRA_OPT_GRT_ONCE_CONST;
    control.fu_xbar_outport[0]=1;control.routing_xbar_outport[1]=1;
    send_packet(13,0,10,'0);send_packet(13,0,20,'0);
    send_packet(3,0,0,control);send_packet(3,1,0,control);
    send_packet(7,0,4,'0);send_packet(8,0,2,'0);
    send_data__rdy[1]=0;
    send_packet(0,0,0,'0);
    while(completed<1 || outputs_seen<4 || forwarded<4) begin
      recv_data__val[0]=(injected<4);
      value='0;value.payload=DATA_W'(101+injected);value.predicate=1;recv_data__msg[0]=value;
      // Keep the routing side blocked for many cycles after the first FU result.
      send_data__rdy[0]=cycles%5!=0;
      send_data__rdy[1]=cycles>45 && cycles%4!=0;
      send_to_controller_pkt__rdy=cycles%3!=0;
      #2;
      if(recv_data__val[0] && recv_data__rdy[0]) injected++;
      if(send_data__val[0] && send_data__rdy[0]) begin
        value=send_data__msg[0];
        if(value.payload != DATA_W'(outputs_seen%2==0 ? 10 : 20) || value.predicate != (outputs_seen<2))
          $fatal(1,"PE_RESULT variant=%0d index=%0d got=%h",VARIANT,outputs_seen,value);
        outputs_seen++;
        if(outputs_seen>4) $fatal(1,"PE duplicate FU output");
      end
      if(send_data__val[1] && send_data__rdy[1]) begin
        value=send_data__msg[1];
        if(value.payload != DATA_W'(101+forwarded) || !value.predicate) $fatal(1,"PE routing order");
        forwarded++;
      end
      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completed++;
      tick();
    end
    if(injected!=4 || outputs_seen!=4 || forwarded!=4 || completed!=1) $fatal(1,"PE incomplete counts");
    $display("CURRENT_PE_GRANT_PASS variant=%0d cycles=%0d outputs=%0d forwarded=%0d",VARIANT,cycles,outputs_seen,forwarded);
    end
    // Reconfigure the complete PE through its public packet interface. This
    // checks command 43 actually reaches GEP through Tile and control memory.
    reset=1;recv_data__val[0]=0;tick();reset=0;tick();
    outputs_seen=0;completed=0;injected=0;forwarded=0;
    control='0;control.operation=`CGRA_OPT_GEP_2D_CONST;
    control.fu_in[0]=1;control.fu_in[1]=2;
    control.routing_xbar_outport[TILE_PORTS]=1;
    control.routing_xbar_outport[TILE_PORTS+1]=2;
    control.fu_xbar_outport[0]=1;
    send_packet(43,0,13,'0);send_packet(13,0,7,'0);
    send_packet(3,0,0,control);send_packet(7,0,1,'0);send_packet(8,0,1,'0);
    send_packet(0,0,0,'0);
    while(completed<1 || outputs_seen<1) begin
      recv_data__val[0]=injected<1;recv_data__msg[0]=DATA_BITS'((3<<3)|4);
      recv_data__val[1]=forwarded<1;recv_data__msg[1]=DATA_BITS'((2<<3)|4);
      send_data__rdy[0]=cycles%4!=0;send_to_controller_pkt__rdy=1;
      #2;
      if(recv_data__val[0] && recv_data__rdy[0]) injected++;
      if(recv_data__val[1] && recv_data__rdy[1]) forwarded++;
      if(send_data__val[0] && send_data__rdy[0]) begin
        value=send_data__msg[0];
        if(value.payload!=48 || !value.predicate) $fatal(1,"PE GEP stride/result");
        outputs_seen++;
      end
      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completed++;
      tick();
    end
    if(outputs_seen!=1 || injected!=1 || forwarded!=1 || completed!=1) $fatal(1,"PE GEP counts");
    $display("CURRENT_PE_PASS variant=%0d ports=%0d data=%0d ctrl=%0d reg=%0d cycles=%0d",VARIANT,TILE_PORTS,DATA_W,CTRL_DEPTH,REG_DEPTH,cycles);
    $finish;
  end
endmodule
