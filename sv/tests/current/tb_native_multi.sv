`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`ifndef PHASE4_REFERENCE
`define PHASE4_REFERENCE Phase4Mesh4Tiles2
`endif
// Independent host-program and arithmetic checks on the current native RTL.
// Derived from the historical system workload; no old HDL/cycle oracle is used.
module tb_native_multi #(`CGRA_PROFILE_PARAMETERS, parameter int TOPOLOGY=0);
  `include "cgra_profile.svh"
  logic clk=0,reset=0;
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val,recv_from_cpu_pkt__rdy,send_to_cpu_pkt__val,send_to_cpu_pkt__rdy;
  cgra_multi #(`CGRA_PROFILE_BIND,.TOPOLOGY(TOPOLOGY)) dut(.*);
  host_packet_t program_packets[$],query_packets[$],p;
  int chain[0:NUM_TILES-1];
  bit completed[0:NUM_CGRAS-1][0:NUM_TILES-1];
  int owner_reads[0:NUM_CGRAS-1];
  int sample_count=0,cycle_count=0,expected_samples,fd,negative,timeout_negative;
  int total_reads=0,total_completions=0,host_stalls=0,remote_requests=0,remote_responses=0;
  string vectors;
  function automatic int direction(input int src,dst);
    if(dst==src+COLS) return 0;
    if(dst==src-COLS) return 1;
    if(dst==src-1) return 2;
    if(dst==src+1) return 3;
    $fatal(1,"Nonadjacent program edge");return 0;
  endfunction
  function automatic ctrl_t control_word(input int tile,pc=0);
    ctrl_t c;int ix;
    c='0;for(int i=0;i<4;i++) c.fu_in[i]=3'(i+1);
    if(tile==0) begin
      c.operation=pc==0 ? 28:58;
      if(pc==0) c.fu_xbar_outport[3]=1;else c.routing_xbar_outport[4]=1;
    end else begin
      ix=0;for(int i=1;i<NUM_TILES;i++) if(chain[i]==tile) ix=i;
      c.operation=ix==2 ? 29:25;
      c.routing_xbar_outport[4]=ROUTING_SEL_W'(direction(tile,chain[ix-1])+1);
      c.fu_xbar_outport[direction(tile,chain[(ix+1)%NUM_TILES])]=1;
    end
    return c;
  endfunction
  function automatic host_packet_t packet(input int cmd,cgra=0,tile=0,
      input logic [DATA_W-1:0] value=0,input bit pred=0,
      input int addr=0,input ctrl_t control='0,input int pc=0);
    host_packet_t h;h='0;h.dst=TILE_ID_W'(tile);h.dst_cgra_id=CGRA_ID_W'(cgra);
    h.payload.cmd=6'(cmd);h.payload.data={value,pred,2'b00};h.payload.data_addr=GLOBAL_ADDR_W'(addr);
    h.payload.ctrl=control;h.payload.ctrl_addr=CTRL_ADDR_W'(pc);return h;
  endfunction
  function automatic logic [DATA_W-1:0] value_for(input int scenario,owner);
    return DATA_W'(scenario==0 ? 7+7*owner : -6-3*owner);
  endfunction
  task automatic sample();
    #1;
    sample_count++;
  endtask
  task automatic tick();
    #4;clk=1;#5;clk=0;
  endtask
  for(genvar i=0;i<NUM_CGRAS;i++) begin : network_monitors
    noc_packet_t outgoing;
    assign outgoing=dut.noc_recv_msg[i];
    always @(posedge clk) if(!reset && dut.noc_recv_val[i] && dut.noc_recv_rdy[i] && outgoing.src!=outgoing.dst) begin
      if(outgoing.payload.cmd==10 || outgoing.payload.cmd==12) remote_requests++;
      if(outgoing.payload.cmd==11) remote_responses++;
    end
  end
  initial begin
    int k,pi,qi,hold,count,reads,done_cycle,owner,tile,addr;
    bit querying,active;
    logic [DATA_W-1:0] expected,value;
    negative=$test$plusargs("NEGATIVE");timeout_negative=$test$plusargs("STALL_FOREVER");
    k=0;chain[k++]=0;
    for(int y=0;y<ROWS;y++) begin
      if(y%2==0) for(int x=1;x<COLS;x++) chain[k++]=y*COLS+x;
      else for(int x=COLS-1;x>=1;x--) chain[k++]=y*COLS+x;
    end
    for(int y=ROWS-1;y>=1;y--) chain[k++]=y*COLS;
    if(k!=NUM_TILES) $fatal(1,"Invalid program chain");
    for(int scenario=0;scenario<2;scenario++) begin
      program_packets.delete();query_packets.delete();
      for(int c=0;c<NUM_CGRAS;c++) begin
        owner_reads[c]=0;
        program_packets.push_back(packet(12,0,0,value_for(scenario,c),1,c*32+15));
        program_packets.push_back(packet(12,0,0,32'hdeadbeef,1,c*32+16));
        for(int t=0;t<NUM_TILES;t++) completed[c][t]=0;
      end
      for(int c=0;c<NUM_CGRAS;c++) for(int t=0;t<NUM_TILES;t++) begin
        if(t==0) begin
          program_packets.push_back(packet(13,c,t,((c+1)%NUM_CGRAS)*32+15,1));
          program_packets.push_back(packet(13,c,t,((c+1)%NUM_CGRAS)*32+16,1));
        end else begin
          k=0;for(int i=1;i<NUM_TILES;i++) if(chain[i]==t) k=i;
          program_packets.push_back(packet(13,c,t,DATA_W'(k==1 ? 5 : k==2 ? 3 : -8),1));
        end
        program_packets.push_back(packet(8,c,t,t==0 ? 2:1));
        program_packets.push_back(packet(7,c,t,t==0 ? 2:1));
        program_packets.push_back(packet(3,c,t,0,0,0,control_word(t,0),0));
        if(t==0) program_packets.push_back(packet(3,c,t,0,0,0,control_word(t,1),1));
      end
      for(int c=0;c<NUM_CGRAS;c++) for(int i=NUM_TILES-1;i>=0;i--)
        program_packets.push_back(packet(0,c,chain[i]));
      for(int c=0;c<NUM_CGRAS;c++) begin
        query_packets.push_back(packet(10,0,0,0,0,c*32+16));
        query_packets.push_back(packet(10,0,0,0,0,c*32+15));
      end
      recv_from_cpu_pkt__val=0;recv_from_cpu_pkt__msg='0;send_to_cpu_pkt__rdy=0;reset=1;
      repeat(3) begin sample();tick();end
      reset=0;pi=0;qi=0;hold=0;count=0;reads=0;done_cycle=-1;
      for(cycle_count=0;cycle_count<1500;cycle_count++) begin
        querying=pi==program_packets.size() && count==NUM_CGRAS*NUM_TILES;
        active=pi<program_packets.size() || (querying && qi<query_packets.size());
        recv_from_cpu_pkt__val=active;
        recv_from_cpu_pkt__msg=pi<program_packets.size() ? program_packets[pi] : querying && qi<query_packets.size() ? query_packets[qi] : HOST_BITS'(0);
        send_to_cpu_pkt__rdy=!timeout_negative && hold>=8 && cycle_count%7>=2;
        sample();
        if(active && recv_from_cpu_pkt__rdy) begin if(querying) qi++;else pi++;end
        if(send_to_cpu_pkt__val) begin
          if(hold<8) hold++;
          if(!send_to_cpu_pkt__rdy) host_stalls++;
          else begin
            p=send_to_cpu_pkt__msg;
            if(p.payload.cmd==14) begin
              owner=int'(p.src_cgra_id);tile=int'(p.src);
              if(owner>=NUM_CGRAS || tile>=NUM_TILES || completed[owner][tile]) $fatal(1,"Invalid/duplicate completion");
              completed[owner][tile]=1;count++;total_completions++;
            end else begin
              addr=int'(p.payload.data_addr);owner=addr/32;value=value_for(scenario,owner);
              expected=addr%32==16 ? ((value+DATA_W'(5))*DATA_W'(3)-DATA_W'(8*(NUM_TILES-3))) : value;
              if(negative && total_reads==0) expected^=1;
              if(p.payload.cmd!=11 || p.src_cgra_id!=CGRA_ID_W'(owner) || p.dst_cgra_id!=0 ||
                 p.payload.data.payload!=expected || !p.payload.data.predicate) $fatal(1,"Independent result/owner failure addr=%0d value=%h expected=%h",addr,p.payload.data.payload,expected);
              // Independent destinations can overtake in the inter-CGRA NoC.
              // Each owner's two reads must remain ordered and occur once.
              if(owner>=NUM_CGRAS || owner_reads[owner]>=2 ||
                 addr!=owner*32+(owner_reads[owner]==0 ? 16:15))
                $fatal(1,"Duplicate/address/per-owner response order mismatch");
              owner_reads[owner]++;
              reads++;total_reads++;
            end
          end
        end
        if(count==NUM_CGRAS*NUM_TILES && reads==2*NUM_CGRAS) begin
          if(done_cycle<0) done_cycle=cycle_count;
          if(cycle_count>=done_cycle+10) begin tick();break;end
        end
        tick();
      end
      if(cycle_count>=1500) $fatal(1,"TIMEOUT multi-CGRA");
      $display("MULTI_SCENARIO_PASS id=%0d cycles=%0d completions=%0d reads=%0d",scenario,cycle_count+1,count,reads);
    end
    if(host_stalls<16 || remote_requests<8 || remote_responses<8)
      $fatal(1,"Missing cycle/backpressure/remote coverage");
    $display("NATIVE_MULTI_PASS samples=%0d bits=%0d completions=%0d reads=%0d remote_requests=%0d remote_responses=%0d host_stalls=%0d",sample_count,HOST_BITS+2,total_completions,total_reads,remote_requests,remote_responses,host_stalls);
    $display("NATIVE_MULTI_ORACLE independent_math=1");
    $finish;
  end
endmodule
