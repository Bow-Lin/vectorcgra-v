`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_streaming_memory;
  localparam COLS=2, ROWS=2, DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16, BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8, TOTAL_STEPS=8, TILE_PORTS=8;
  localparam DATA_BITS=35, CTRL_ADDR_W=3, REG_ADDR_W=4, TILE_ID_W=3, ROUTING_OUTPUTS=12, ROUTING_SEL_W=4, CTRL_BITS=143, PAYLOAD_BITS=194, HOST_BITS=215, MEM_PORT_W=2, BANK_PORT_W=2, NOC_BITS=218;
  `include "cgra_profile.svh"
  logic [0:0] clear ;
  logic [0:0] clk ;
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [0:0] reset ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg ;
  logic [0:0] d_from_mem_rdata__rdy ;
  logic [0:0] g_from_mem_rdata__rdy ;
  logic [0:0] from_mem_rdata__val ;
  logic [DATA_BITS-1:0] recv_const__msg ;
  logic [0:0] d_recv_const__rdy ;
  logic [0:0] g_recv_const__rdy ;
  logic [0:0] recv_const__val ;
  logic [HOST_BITS-1:0] recv_from_controller_pkt__msg ;
  logic  recv_from_controller_pkt__val ;
  logic  d_recv_from_controller_pkt__rdy ;
  logic  g_recv_from_controller_pkt__rdy ;
  logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ;
  logic [0:0] d_recv_from_ctrl_mem__rdy ;
  logic [0:0] g_recv_from_ctrl_mem__rdy ;
  logic [0:0] recv_from_ctrl_mem__val ;
  logic [DATA_BITS-1:0] recv_in__msg [0:3];
  logic [0:0] d_recv_in__rdy [0:3];
  logic [0:0] g_recv_in__rdy [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] d_recv_opt__rdy ;
  logic [0:0] g_recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [DATA_BITS-1:0] d_send_out__msg [0:1];
  logic [DATA_BITS-1:0] g_send_out__msg [0:1];
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] d_send_out__val [0:1];
  logic [0:0] g_send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] d_send_to_ctrl_mem__msg ;
  logic [PAYLOAD_BITS-1:0] g_send_to_ctrl_mem__msg ;
  logic [0:0] send_to_ctrl_mem__rdy ;
  logic [0:0] d_send_to_ctrl_mem__val ;
  logic [0:0] g_send_to_ctrl_mem__val ;
  logic [GLOBAL_ADDR_W-1:0] d_to_mem_raddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] g_to_mem_raddr__msg ;
  logic [0:0] to_mem_raddr__rdy ;
  logic [0:0] d_to_mem_raddr__val ;
  logic [0:0] g_to_mem_raddr__val ;
  logic [GLOBAL_ADDR_W-1:0] d_to_mem_waddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] g_to_mem_waddr__msg ;
  logic [0:0] to_mem_waddr__rdy ;
  logic [0:0] d_to_mem_waddr__val ;
  logic [0:0] g_to_mem_waddr__val ;
  logic [DATA_BITS-1:0] d_to_mem_wdata__msg ;
  logic [DATA_BITS-1:0] g_to_mem_wdata__msg ;
  logic [0:0] to_mem_wdata__rdy ;
  logic [0:0] d_to_mem_wdata__val ;
  logic [0:0] g_to_mem_wdata__val ;
  tile_streaming_memory_fu #(.TILE_PORTS(8)) dut (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .reset(reset),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(d_from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(d_recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_controller_pkt__msg(recv_from_controller_pkt__msg),
    .recv_from_controller_pkt__val(recv_from_controller_pkt__val),
    .recv_from_controller_pkt__rdy(d_recv_from_controller_pkt__rdy),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(d_recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(d_recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(d_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_out__msg(d_send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(d_send_out__val),
    .send_to_ctrl_mem__msg(d_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(d_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(d_to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(d_to_mem_raddr__val),
    .to_mem_waddr__msg(d_to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(d_to_mem_waddr__val),
    .to_mem_wdata__msg(d_to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(d_to_mem_wdata__val)
  );
  Phase3StreamingW32C8R16 gold (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .reset(reset),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(g_from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(g_recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_controller_pkt__msg(recv_from_controller_pkt__msg),
    .recv_from_controller_pkt__val(recv_from_controller_pkt__val),
    .recv_from_controller_pkt__rdy(g_recv_from_controller_pkt__rdy),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(g_recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(g_recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(g_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_out__msg(g_send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(g_send_out__val),
    .send_to_ctrl_mem__msg(g_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(g_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(g_to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(g_to_mem_raddr__val),
    .to_mem_waddr__msg(g_to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(g_to_mem_waddr__val),
    .to_mem_wdata__msg(g_to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(g_to_mem_wdata__val)
  );
  ctrl_t control; host_packet_t packet; data_t response;
  assign recv_opt__msg=control; assign recv_from_controller_pkt__msg=packet; assign from_mem_rdata__msg=response;
  integer cycle=0, requests=0, responses=0, completions=0, head=0, tail=0;
  integer request_time[0:31], request_address[0:31];
  bit finished=0; integer random_seed=31415926;
  task automatic tick;
    #4;
    if(d_from_mem_rdata__rdy !== (g_from_mem_rdata__rdy ^ ($test$plusargs("EXPECT_FAILURE") && cycle==20))) $fatal(1,"stream mismatch from_mem_rdata__rdy cycle=%0d actual=%h expected=%h",cycle,d_from_mem_rdata__rdy,g_from_mem_rdata__rdy);
    if(d_recv_const__rdy !== g_recv_const__rdy) $fatal(1,"stream mismatch recv_const__rdy cycle=%0d actual=%h expected=%h",cycle,d_recv_const__rdy,g_recv_const__rdy);
    if(d_recv_from_controller_pkt__rdy !== g_recv_from_controller_pkt__rdy) $fatal(1,"stream mismatch recv_from_controller_pkt__rdy cycle=%0d actual=%h expected=%h",cycle,d_recv_from_controller_pkt__rdy,g_recv_from_controller_pkt__rdy);
    if(d_recv_from_ctrl_mem__rdy !== g_recv_from_ctrl_mem__rdy) $fatal(1,"stream mismatch recv_from_ctrl_mem__rdy cycle=%0d actual=%h expected=%h",cycle,d_recv_from_ctrl_mem__rdy,g_recv_from_ctrl_mem__rdy);
    for(int i=0;i<4;i++) if(d_recv_in__rdy[i] !== g_recv_in__rdy[i]) $fatal(1,"stream mismatch recv_in__rdy cycle=%0d index=%0d",cycle,i);
    if(d_recv_opt__rdy !== g_recv_opt__rdy) $fatal(1,"stream mismatch recv_opt__rdy cycle=%0d actual=%h expected=%h",cycle,d_recv_opt__rdy,g_recv_opt__rdy);
    for(int i=0;i<2;i++) if(d_send_out__msg[i] !== g_send_out__msg[i]) $fatal(1,"stream mismatch send_out__msg cycle=%0d index=%0d",cycle,i);
    for(int i=0;i<2;i++) if(d_send_out__val[i] !== g_send_out__val[i]) $fatal(1,"stream mismatch send_out__val cycle=%0d index=%0d",cycle,i);
    if(d_send_to_ctrl_mem__msg !== g_send_to_ctrl_mem__msg) $fatal(1,"stream mismatch send_to_ctrl_mem__msg cycle=%0d actual=%h expected=%h",cycle,d_send_to_ctrl_mem__msg,g_send_to_ctrl_mem__msg);
    if(d_send_to_ctrl_mem__val !== g_send_to_ctrl_mem__val) $fatal(1,"stream mismatch send_to_ctrl_mem__val cycle=%0d actual=%h expected=%h",cycle,d_send_to_ctrl_mem__val,g_send_to_ctrl_mem__val);
    if(d_to_mem_raddr__msg !== g_to_mem_raddr__msg) $fatal(1,"stream mismatch to_mem_raddr__msg cycle=%0d actual=%h expected=%h",cycle,d_to_mem_raddr__msg,g_to_mem_raddr__msg);
    if(d_to_mem_raddr__val !== g_to_mem_raddr__val) $fatal(1,"stream mismatch to_mem_raddr__val cycle=%0d actual=%h expected=%h",cycle,d_to_mem_raddr__val,g_to_mem_raddr__val);
    if(d_to_mem_waddr__msg !== g_to_mem_waddr__msg) $fatal(1,"stream mismatch to_mem_waddr__msg cycle=%0d actual=%h expected=%h",cycle,d_to_mem_waddr__msg,g_to_mem_waddr__msg);
    if(d_to_mem_waddr__val !== g_to_mem_waddr__val) $fatal(1,"stream mismatch to_mem_waddr__val cycle=%0d actual=%h expected=%h",cycle,d_to_mem_waddr__val,g_to_mem_waddr__val);
    if(d_to_mem_wdata__msg !== g_to_mem_wdata__msg) $fatal(1,"stream mismatch to_mem_wdata__msg cycle=%0d actual=%h expected=%h",cycle,d_to_mem_wdata__msg,g_to_mem_wdata__msg);
    if(d_to_mem_wdata__val !== g_to_mem_wdata__val) $fatal(1,"stream mismatch to_mem_wdata__val cycle=%0d actual=%h expected=%h",cycle,d_to_mem_wdata__val,g_to_mem_wdata__val);
    clk=1; #1; clk=0; #1; cycle++;
  endtask
  initial begin
    clk=0; reset=1; clear=0; ctrl_addr_inport=0; control='0; packet='0; response='0;
    from_mem_rdata__val='0;
    recv_const__msg='0;
    recv_const__val='0;
    recv_from_controller_pkt__val='0;
    recv_from_ctrl_mem__msg='0;
    recv_from_ctrl_mem__val='0;
    for(int i=0;i<4;i++) recv_in__msg[i]='0;
    for(int i=0;i<4;i++) recv_in__val[i]='0;
    recv_opt__val='0;
    for(int i=0;i<2;i++) send_out__rdy[i]='0;
    send_to_ctrl_mem__rdy='0;
    to_mem_raddr__rdy='0;
    to_mem_waddr__rdy='0;
    to_mem_wdata__rdy='0;
    repeat(3) tick(); reset=0;
    recv_from_controller_pkt__val=1;
    packet.payload.cmd=23; packet.payload.data.payload=10; tick();
    packet.payload.cmd=24; packet.payload.data.payload=2; tick();
    packet.payload.cmd=25; packet.payload.data.payload=18; tick();
    recv_from_controller_pkt__val=0; tick();
    control.operation=88; recv_opt__val=1; ctrl_addr_inport=1; tick();
    for(int t=0;t<50;t++) begin
      to_mem_raddr__rdy=(t%3!=0); send_out__rdy[0]=(t%5!=1 && t%5!=2);
      clear=(t==5); reset=(t==9); // Neither clears the streaming cursors/config.
      recv_opt__val=!finished;
      from_mem_rdata__val=(head<tail && t>=request_time[head]+4);
      response='0;
      if(from_mem_rdata__val) begin
        response.payload=32'(request_address[head]*7+1); response.predicate=1;
        response.bypass=1; response.delay=1;
      end
      #1;
      if(d_to_mem_raddr__val && to_mem_raddr__rdy) begin
        if(d_to_mem_raddr__msg !== 7'(10+2*requests) || requests>=5)
          $fatal(1,"stream independent request ordering");
        request_time[tail]=t; request_address[tail]=int'(d_to_mem_raddr__msg); tail++; requests++;
      end
      if(d_send_out__val[0] && send_out__rdy[0]) begin
        if(d_send_out__msg[0] !== response || responses>=5)
          $fatal(1,"stream independent response payload");
        head++; responses++;
      end
      if(d_recv_opt__rdy && recv_opt__val) begin
        if(responses!=5) $fatal(1,"stream early completion");
        completions++; finished=1;
      end
      tick();
    end
    if(requests!=5 || responses!=5 || completions!=1 || !finished)
      $fatal(1,"stream missing events req=%0d rsp=%0d done=%0d",requests,responses,completions);
    // Randomized raw inputs exercise idle messages, operation changes, reset,
    // clear, malformed/non-stream opcodes and vector-factor state against HDL.
    for(int t=0;t<300;t++) begin
      reset=(t%79==0); clear=$random(random_seed)&1; ctrl_addr_inport=3'($random(random_seed));
      control='0; control.operation=(t%4==0)?7'd88:7'($random(random_seed));
      control.vector_factor_power=3'($random(random_seed)); control.is_last_ctrl=$random(random_seed)&1;
      recv_opt__val=$random(random_seed)&1; send_out__rdy[0]=$random(random_seed)&1;
      from_mem_rdata__val=$random(random_seed)&1;
      response={32'($random(random_seed)),3'($random(random_seed))};
      to_mem_raddr__rdy=$random(random_seed)&1;
      recv_from_controller_pkt__val=$random(random_seed)&1;
      packet.payload.cmd=6'(23+(t%3)); packet.payload.data.payload=32'($random(random_seed));
      tick();
    end
    $display("STREAMING_MEMORY_PASS cycles=%0d requests=%0d responses=%0d completions=%0d",cycle,requests,responses,completions);
    $finish;
  end
endmodule
