`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_native_global_reduce #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  logic clk=0,reset=0;
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg='0,send_to_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val=0,recv_from_cpu_pkt__rdy,send_to_cpu_pkt__val,send_to_cpu_pkt__rdy=0;
  cgra_multi #(`CGRA_PROFILE_BIND,.TILE_VARIANT(0),.FU_COUNT(4),
    .FU_KINDS({8'd3,8'd13,8'd21,8'd2}),.REDUCE_LEGACY_PYTHON(0)) dut (.*);
  logic [HOST_BITS-1:0] program_words[0:34];
  host_packet_t packet,completed;
  assign completed=send_to_cpu_pkt__msg;
  noc_packet_t network_packet[0:3];
  for (genvar i=0;i<4;i++) assign network_packet[i]=dut.noc_recv_msg[i];
  integer cycles /* verilator public_flat_rw */ =0;
  integer sent /* verilator public_flat_rw */ =0;
  integer completes /* verilator public_flat_rw */ =0;
  integer results /* verilator public_flat_rw */ =0;
  integer requests /* verilator public_flat_rw */ =0;
  integer replies /* verilator public_flat_rw */ =0;
  integer held_cycles /* verilator public_flat_rw */ =0;
  integer done_cycle /* verilator public_flat_rw */ =-1;
  bit [15:0] seen_completes /* verilator public_flat_rw */ =0;
  bit [3:0] seen_requests /* verilator public_flat_rw */ =0;
  bit [3:0] seen_replies /* verilator public_flat_rw */ =0;
  bit multiply,wrong,host_stalled=0;
  logic [DATA_W-1:0] global_value,expected,local_value;
  integer participant,tile,key;
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  initial begin
    if (DATA_W!=32 || COLS!=2 || ROWS!=2 || MULTI_COLS!=2 || MULTI_ROWS!=2 || HOST_BITS!=193)
      $fatal(1,"GLOBAL_REDUCE_TEST_PROFILE");
    multiply=$test$plusargs("MULTIPLY");wrong=$test$plusargs("EXPECT_FAILURE");
    $readmemh("tests/current/vector_reduce_program.mem",program_words);
    global_value=multiply?1:0;
    for (integer n=1;n<=8;n++) global_value=multiply?global_value*DATA_W'(n):global_value+DATA_W'(n);
    if (multiply) for (integer n=0;n<35;n++) begin
      packet=program_words[n];
      if (packet.payload.cmd==3 && packet.payload.ctrl.operation==78) packet.payload.ctrl.operation=79;
      program_words[n]=packet;
    end
    reset=1;repeat(3) tick();reset=0;
    for (cycles=0;cycles<2000;cycles++) begin
      if (!host_stalled) begin
        recv_from_cpu_pkt__val=(sent<35 && cycles%5!=1);
        recv_from_cpu_pkt__msg=recv_from_cpu_pkt__val?program_words[sent]:'0;
      end
      send_to_cpu_pkt__rdy=(held_cycles>=12 && cycles%29>=20);
      #2;
      host_stalled=recv_from_cpu_pkt__val && !recv_from_cpu_pkt__rdy;
      if (recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy) sent++;
      if (send_to_cpu_pkt__val && !send_to_cpu_pkt__rdy) held_cycles++;
      for (integer c=0;c<4;c++) if (dut.noc_recv_val[c] && dut.noc_recv_rdy[c]) begin
        if (network_packet[c].payload.cmd==18 || network_packet[c].payload.cmd==19) begin
          if (network_packet[c].payload.cmd!=(multiply?19:18) || (c!=0 && c!=3) || seen_requests[c])
            $fatal(1,"GLOBAL_REDUCE_REQUEST_DUPLICATE_OR_COMMAND");
          local_value=multiply?1:0;
          for (integer lane=1;lane<=4;lane++) local_value=multiply ?
            local_value*DATA_W'(lane+(c==3?4:0)) : local_value+DATA_W'(lane+(c==3?4:0));
          if (network_packet[c].payload.data.payload!=local_value || !network_packet[c].payload.data.predicate)
            $fatal(1,"GLOBAL_REDUCE_REQUEST_MATH");
          seen_requests[c]=1;requests++;
        end
        if (network_packet[c].payload.cmd==20 || network_packet[c].payload.cmd==21) begin
          participant=int'(network_packet[c].dst);
          if (network_packet[c].payload.cmd!=(multiply?21:20) || (participant!=0 && participant!=3) || seen_replies[participant])
            $fatal(1,"GLOBAL_REDUCE_RESPONSE_DUPLICATE_OR_COMMAND");
          if (network_packet[c].payload.data.payload!=global_value || !network_packet[c].payload.data.predicate)
            $fatal(1,"GLOBAL_REDUCE_RESPONSE_MATH");
          seen_replies[participant]=1;replies++;
        end
      end
      if (send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
        participant=int'(completed.src_cgra_id);tile=int'(completed.src);key=4*participant+tile;
        if (completed.payload.cmd!=14 || (participant!=0 && participant!=3) || tile>2 || seen_completes[key])
          $fatal(1,"GLOBAL_REDUCE_COMPLETION_DUPLICATE_OR_ROUTE");
        seen_completes[key]=1;completes++;
        if (tile==1) begin
          expected=multiply ? global_value*(participant==0?DATA_W'(17):DATA_W'(-5)) :
            global_value+(participant==0?DATA_W'(17):DATA_W'(-5));
          if (wrong) expected=expected^1;
          if (completed.payload.data.payload!=expected || !completed.payload.data.predicate)
            $fatal(1,"GLOBAL_REDUCE_FINAL_MATH got=%h expected=%h",completed.payload.data.payload,expected);
          results++;
        end
      end
      if (completes==6 && sent==35 && requests==2 && replies==2 && results==2) begin
        if (done_cycle<0) done_cycle=cycles;
        if (cycles>=done_cycle+30) begin
          if (held_cycles<12) $fatal(1,"GLOBAL_REDUCE_STALL_COVERAGE");
          $display("NATIVE_GLOBAL_REDUCE_PASS multiply=%0d cycles=%0d requests=%0d replies=%0d results=%0d completes=%0d held=%0d",
            multiply,cycles,requests,replies,results,completes,held_cycles);
          $finish;
        end
      end
      tick();
    end
    $fatal(1,"GLOBAL_REDUCE_TIMEOUT sent=%0d requests=%0d replies=%0d results=%0d completes=%0d",sent,requests,replies,results,completes);
  end
endmodule
