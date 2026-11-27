`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_ctrl_commands.svh"
module tb_control_network #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int BACKEND=0,
  parameter int DOWN_PACKETS=160,
  parameter int UP_PACKETS=40
);
  `include "cgra_profile.svh"
  logic clk=0,reset=0;
  logic [HOST_BITS-1:0] recv_msg [0:MAX_TILES],send_msg [0:MAX_TILES];
  logic recv_val [0:MAX_TILES],recv_rdy [0:MAX_TILES];
  logic send_val [0:MAX_TILES],send_rdy [0:MAX_TILES];
  if(BACKEND==0) begin : original
    cgra_credit_ring #(.WIDTH(HOST_BITS),.NODES(MAX_TILES+1),.DST_LSB(HOST_DST_LSB),
      .DST_WIDTH(TILE_ID_W),.VC_LSB(PAYLOAD_BITS),.LEGACY_PYTHON(0)) dut(.*);
  end else begin : dedicated
    cgra_ctrl_network #(.WIDTH(HOST_BITS),.TILES(NUM_TILES),.MAX_TILES(MAX_TILES),
      .COLS(COLS),.LAYOUT(BACKEND),.DST_LSB(HOST_DST_LSB),.DST_WIDTH(TILE_ID_W),.VC_LSB(PAYLOAD_BITS),
      .MULTICAST(CTRL_MULTICAST),.CMD_LSB(PAYLOAD_BITS-6),
      .DATA_LSB(CTRL_ADDR_W+CTRL_BITS+GLOBAL_ADDR_W+3),.DATA_WIDTH(DATA_W),
      .MASK_ADDR_LSB(CTRL_ADDR_W+CTRL_BITS),.MASK_ADDR_WIDTH(GLOBAL_ADDR_W),
      .CTRL_ADDR_WIDTH(CTRL_ADDR_W),.CTRL_DEPTH(CTRL_DEPTH)) dut(.*);
  end
  int cycle=0,epoch=0,down_sent=0,down_received=0,up_received=0;
  int down_expected=0;
  logic [HOST_BITS-1:0] root_program[$];
  logic [NUM_TILES-1:0] reference_mask;
  int down_count [0:NUM_TILES-1],down_head [0:NUM_TILES-1];
  int up_sent [0:NUM_TILES-1],up_head [0:NUM_TILES-1],wait_cycles [0:NUM_TILES-1];
  logic [HOST_BITS-1:0] expected_down [0:NUM_TILES-1][0:DOWN_PACKETS-1];
  logic blocked [0:MAX_TILES];
  logic [HOST_BITS-1:0] held [0:MAX_TILES];
  logic root_active=0,up_active [0:NUM_TILES-1];
  int first_accept=-1,last_delivery=-1,last_up=-1;
  int fd; string result;
  bit pressure=0;
  bit fairness_mode=0,negative_injected=0;
  function automatic bit crossing(input int src,input int dst);
    int ld,rd;
    ld=(src-dst+MAX_TILES+1)%(MAX_TILES+1);
    rd=(dst-src+MAX_TILES+1)%(MAX_TILES+1);
    if(src==dst)return 0;
    return ld<rd ? dst>src : dst<src;
  endfunction
  function automatic logic [HOST_BITS-1:0] packet(input int src,input int dst,input int seq);
    host_packet_t p;
    for(int b=0;b<HOST_BITS;b++) p[b]=((b*13+seq*17+epoch*29+src*7)%(23+b%5))%2;
    p.src=TILE_ID_W'(src);p.dst=TILE_ID_W'(dst);
    p.vc_id=1'(seq%2);p.payload.cmd=6'(seq%59);
    p.payload.data.payload=DATA_W'(seq+epoch*10000+src*1000);
    return p;
  endfunction
  task automatic prepare_program;
    host_packet_t p;
    logic [NUM_TILES-1:0] mask;
    root_program.delete();
    for(int seq=0;seq<DOWN_PACKETS;seq++)begin
      if(CTRL_MULTICAST && seq%4==0)begin
        mask='0;
        for(int t=0;t<NUM_TILES;t++)
          if(seq%3==0 || (seq%3==1 && t%2==0) || (seq%3==2 && t==NUM_TILES-1))mask[t]=1;
        if($test$plusargs("ZERO_MASK") && seq==0)mask='0;
        for(int w=0;w<(NUM_TILES+DATA_W-1)/DATA_W;w++)begin
          p=packet(NUM_TILES,0,seq);p.payload.cmd=`CGRA_CMD_CTRL_MASK_WORD;
          p.payload.data_addr=GLOBAL_ADDR_W'(w);p.payload.data.payload=DATA_W'(mask>>(w*DATA_W));
          if($test$plusargs("BAD_MASK_PADDING") && seq==0 && w==(NUM_TILES+DATA_W-1)/DATA_W-1)
            p.payload.data.payload[NUM_TILES%DATA_W]=1;
          if($test$plusargs("INVALID_MASK_WORD") && seq==0)p.payload.data_addr=GLOBAL_ADDR_W'((NUM_TILES+DATA_W-1)/DATA_W+1);
          if(!$test$plusargs("UNLOADED_MASK") || seq!=0)root_program.push_back(p);
        end
        p=packet(NUM_TILES,0,seq);p.payload.cmd=`CGRA_CMD_CONFIG_MULTICAST;
        p.payload.ctrl_addr=CTRL_ADDR_W'(seq%CTRL_DEPTH);root_program.push_back(p);
      end else root_program.push_back(packet(NUM_TILES,(seq*7+3)%NUM_TILES,seq));
    end
    if($test$plusargs("INVALID_TARGET"))begin
      p=root_program[0];p.payload.cmd=6'd3;p.dst=TILE_ID_W'(NUM_TILES);root_program[0]=p;
    end
    if($test$plusargs("DISABLED_MULTICAST"))begin
      p=root_program[0];p.payload.cmd=`CGRA_CMD_CONFIG_MULTICAST;root_program[0]=p;
    end
  endtask
  task automatic expect_delivery(input host_packet_t p,input integer dst);
    host_packet_t want;
    want=p;want.dst=TILE_ID_W'(dst);want.vc_id=p.vc_id|crossing(NUM_TILES,dst);
    if($test$plusargs("BAD_EXPECTED") && !negative_injected)begin want[0]=~want[0];negative_injected=1;end
    expected_down[dst][down_count[dst]]=want;down_count[dst]++;down_expected++;
  endtask
  task automatic tick;
    host_packet_t p,want;
    int src,dst;
    #5;
    if(!reset) begin
      if(recv_val[NUM_TILES] && recv_rdy[NUM_TILES]) begin
        p=recv_msg[NUM_TILES];dst=int'(p.dst);
        if(CTRL_MULTICAST && p.payload.cmd==`CGRA_CMD_CTRL_MASK_WORD)begin
          for(int b=0;b<NUM_TILES;b++)
            if(b/DATA_W==int'(p.payload.data_addr))reference_mask[b]=p.payload.data.payload[b%DATA_W];
        end else if(CTRL_MULTICAST && p.payload.cmd==`CGRA_CMD_CONFIG_MULTICAST)begin
          p.payload.cmd=6'd3;
          for(int t=0;t<NUM_TILES;t++)if(reference_mask[t])expect_delivery(p,t);
        end else expect_delivery(p,dst);
        down_sent++;root_active=0;
        if(first_accept<0)first_accept=cycle;
      end
      for(int t=0;t<NUM_TILES;t++) begin
        if(recv_val[t] && recv_rdy[t]) begin up_sent[t]++;up_active[t]=0;end
        if(send_val[t] && send_rdy[t]) begin
          if(down_head[t]>=down_count[t] || send_msg[t]!==expected_down[t][down_head[t]])
            $fatal(1,"CTRL_NETWORK_DOWN_MISMATCH tile=%0d index=%0d",t,down_head[t]);
          down_head[t]++;down_received++;last_delivery=cycle;
        end
      end
      if(send_val[NUM_TILES] && send_rdy[NUM_TILES]) begin
        p=send_msg[NUM_TILES];src=int'(p.src);
        if(src>=NUM_TILES || up_head[src]>=up_sent[src]) $fatal(1,"CTRL_NETWORK_UNEXPECTED_RETURN");
        want=packet(src,NUM_TILES,up_head[src]);want.vc_id=want.vc_id|crossing(src,NUM_TILES);
        if(p!==want)$fatal(1,"CTRL_NETWORK_UP_MISMATCH tile=%0d index=%0d",src,up_head[src]);
        up_head[src]++;up_received++;last_up=cycle;
      end
      for(int t=0;t<=MAX_TILES;t++) begin
        if(blocked[t] && (!send_val[t] || send_msg[t]!==held[t]))
          $fatal(1,"CTRL_NETWORK_STALL_STABILITY node=%0d",t);
        blocked[t]=send_val[t]&&!send_rdy[t];held[t]=send_msg[t];
      end
    end
    clk=1;#5;clk=0;cycle++;
    if(cycle>20000)$fatal(1,"CTRL_NETWORK_TIMEOUT");
  endtask
  task automatic initialize;
    for(int t=0;t<=MAX_TILES;t++) begin recv_val[t]=0;recv_msg[t]='0;send_rdy[t]=0;blocked[t]=0;held[t]='0;end
    reset=1;repeat(3)tick();reset=0;
    down_sent=0;down_received=0;down_expected=0;up_received=0;root_active=0;reference_mask='0;negative_injected=0;
    first_accept=-1;last_delivery=-1;last_up=-1;
    for(int t=0;t<NUM_TILES;t++) begin
      down_count[t]=0;down_head[t]=0;up_sent[t]=0;up_head[t]=0;up_active[t]=0;wait_cycles[t]=0;
    end
    prepare_program();
  endtask
  task automatic drive;
    int dst;
    if(down_sent<root_program.size() && (!pressure || cycle%5!=0))root_active=1;
    recv_val[NUM_TILES]=root_active;recv_msg[NUM_TILES]=down_sent<root_program.size() ? root_program[down_sent]:'0;
    send_rdy[NUM_TILES]=!pressure || (cycle%17>=6 && cycle%7!=0);
    for(int t=0;t<NUM_TILES;t++) begin
      if((fairness_mode || up_sent[t]<UP_PACKETS) && (!pressure || (cycle+t)%5!=0))up_active[t]=1;
      recv_val[t]=up_active[t];recv_msg[t]=packet(t,NUM_TILES,up_sent[t]);
      send_rdy[t]=!pressure || ((cycle+t*3)%13>=4 && (cycle+t)%7!=0);
    end
  endtask
  initial begin
    pressure=$test$plusargs("BACKPRESSURE");
    // Reset with both directions blocked and outstanding data, then reject any
    // late packet by starting a distinct epoch. No internal state is written.
    epoch=8;initialize();fairness_mode=1;down_sent=root_program.size();
    repeat(600)begin drive();tick();end
    for(int t=0;t<NUM_TILES;t++)if(up_head[t]==0)$fatal(1,"CTRL_NETWORK_FAIRNESS tile=%0d",t);
    $display("CTRL_NETWORK_FAIRNESS_PASS backend=%0d leaves=%0d",BACKEND,NUM_TILES);
    fairness_mode=0;epoch=7;initialize();
    for(int i=0;i<35;i++) begin drive();send_rdy[0]=0;send_rdy[NUM_TILES]=0;tick();end
    if(CTRL_MULTICAST && down_received==0)$fatal(1,"CTRL_MULTICAST_NO_PARTIAL_RESET_COVERAGE");
    epoch=0;initialize();
    for(int run=0;run<2;run++) begin
      epoch=run;
      if(run!=0)initialize();
      while(down_sent<root_program.size() || down_received<down_expected || up_received<NUM_TILES*UP_PACKETS)begin drive();tick();end
      for(int t=0;t<=MAX_TILES;t++)begin recv_val[t]=0;send_rdy[t]=1;end
      repeat(20)tick();
      if(down_received!=down_expected || up_received!=NUM_TILES*UP_PACKETS)$fatal(1,"CTRL_NETWORK_COUNTS");
      $display("CTRL_NETWORK_PASS backend=%0d shape=%0dx%0d max=%0d epoch=%0d down=%0d up=%0d first=%0d last_down=%0d last_up=%0d",BACKEND,COLS,ROWS,MAX_TILES,epoch,down_received,up_received,first_accept,last_delivery,last_up);
    end
    if($value$plusargs("RESULT=%s",result))begin
      fd=$fopen(result,"w");if(!fd)$fatal(1,"CTRL_NETWORK_RESULT");
      $fdisplay(fd,"{\"backend\":%0d,\"multicast\":%0d,\"cols\":%0d,\"rows\":%0d,\"max_tiles\":%0d,\"pressure\":%0d,\"first_accept\":%0d,\"last_delivery\":%0d,\"last_return\":%0d,\"host_packets\":%0d,\"target_deliveries\":%0d,\"up_packets\":%0d}",BACKEND,CTRL_MULTICAST,COLS,ROWS,MAX_TILES,pressure,first_accept,last_delivery,last_up,down_sent,down_received,up_received);
      $fclose(fd);
    end
    $finish;
  end
endmodule
