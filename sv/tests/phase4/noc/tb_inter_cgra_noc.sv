`timescale 1ns/1ps
module tb_inter_cgra_noc #(parameter bit LEGACY=1, parameter bit RAW_INVALID_MESSAGES=1);
  `include "profile.svh"
  localparam int PACKETS=64,TOTAL=NODES*PACKETS,SCENARIO_CYCLES=1024;
  logic clk=0;
  always #5 clk=~clk;
  logic reset;
  logic [WIDTH-1:0] recv_msg [0:NODES-1],send_msg [0:NODES-1],gold_msg [0:NODES-1];
  logic recv_val [0:NODES-1],recv_rdy [0:NODES-1],gold_rdy [0:NODES-1];
  logic send_val [0:NODES-1],send_rdy [0:NODES-1],gold_val [0:NODES-1];
`ifdef NOC_POST_SYNTH
  logic [NODES*WIDTH-1:0] recv_flat,send_flat;
  logic [NODES-1:0] recv_val_flat,recv_rdy_flat,send_val_flat,send_rdy_flat;
  for(genvar n=0;n<NODES;n++)begin : flat_ports
    assign recv_flat[(NODES-n)*WIDTH-1-:WIDTH]=recv_msg[n];
    assign send_msg[n]=send_flat[(NODES-n)*WIDTH-1-:WIDTH];
    assign recv_val_flat[NODES-1-n]=recv_val[n];
    assign recv_rdy[n]=recv_rdy_flat[NODES-1-n];
    assign send_val[n]=send_val_flat[NODES-1-n];
    assign send_rdy_flat[NODES-1-n]=send_rdy[n];
  end
  noc_network_netlist dut(.clk,.reset,.recv_msg(recv_flat),.recv_val(recv_val_flat),.recv_rdy(recv_rdy_flat),
    .send_msg(send_flat),.send_val(send_val_flat),.send_rdy(send_rdy_flat));
`else
  if(IS_RING)begin : ring_dut
    cgra_inter_ring #(.LEGACY_PYTHON(LEGACY),.WIDTH(WIDTH),.NODES(NODES),.DST_LSB(DST_LSB),.DST_WIDTH(DST_WIDTH),
      .VC_LSB(VC_LSB),.VC_WIDTH(VC_WIDTH),.CHANNEL_LATENCY(CHANNEL_LATENCY)) dut (
      .clk,.reset,.recv_msg,.recv_val,.recv_rdy,.send_msg,.send_val,.send_rdy);
  end else begin : mesh_dut
    cgra_inter_mesh #(.LEGACY_PYTHON(LEGACY),.WIDTH(WIDTH),.COLS(COLS),.ROWS(ROWS),.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),
      .DST_X_LSB(DST_X_LSB),.DST_Y_LSB(DST_Y_LSB),.CHANNEL_LATENCY(CHANNEL_LATENCY)) dut (
      .clk,.reset,.recv_msg,.recv_val,.recv_rdy,.send_msg,.send_val,.send_rdy);
  end
`endif
  if(LEGACY) begin : reference_model
  `PHASE4_NOC_GOLD gold (.clk,.reset,.recv__msg(recv_msg),.recv__val(recv_val),.recv__rdy(gold_rdy),
    .send__msg(gold_msg),.send__val(gold_val),.send__rdy(send_rdy));
  end else begin : no_reference
    for(genvar i=0;i<NODES;i++)begin
      assign gold_msg[i]='0;assign gold_val[i]=0;assign gold_rdy[i]=0;
    end
  end
  logic [WIDTH-1:0] held_msg[0:NODES-1];
  bit held[0:NODES-1];
  int stable_samples=0;
  int invalid_message_differences=0;


  logic [31:0] rng=32'h4c03a271;
  function automatic logic [31:0] random_word();
    rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;
  endfunction
  function automatic logic [WIDTH-1:0] random_packet();
    logic [WIDTH-1:0] packet;
    packet='0;
    for(int bit_index=0;bit_index<WIDTH;bit_index+=32)begin
      packet=(packet<<32)|WIDTH'(random_word());
    end
    return packet;
  endfunction
  function automatic logic [WIDTH-1:0] packet_for(input int source,destination,serial,vc);
    logic [WIDTH-1:0] packet;
    packet=random_packet();
    packet[SRC_LSB+:DST_WIDTH]=DST_WIDTH'(source);
    packet[DST_LSB+:DST_WIDTH]=DST_WIDTH'(destination);
    packet[SRC_X_LSB+:X_WIDTH]=X_WIDTH'(source%COLS);
    packet[SRC_Y_LSB+:Y_WIDTH]=Y_WIDTH'(source/COLS);
    packet[DST_X_LSB+:X_WIDTH]=X_WIDTH'(destination%COLS);
    packet[DST_Y_LSB+:Y_WIDTH]=Y_WIDTH'(destination/COLS);
    packet[VC_LSB+:VC_WIDTH]=VC_WIDTH'(vc);
    packet[ID_LSB+:32]=32'(source*PACKETS+serial);
    return packet;
  endfunction
  function automatic bit crosses_dateline(input int source,destination);
    int left_distance,right_distance;
    left_distance=(NODES+source-destination)%NODES;
    right_distance=(NODES+destination-source)%NODES;
    if(source==destination)return 0;
    return left_distance<right_distance ? destination>source : destination<source;
  endfunction

  logic [WIDTH-1:0] expected [0:TOTAL-1];
  bit accepted [0:TOTAL-1],delivered [0:TOTAL-1];
  int order_rank [0:TOTAL-1],initial_vc [0:TOTAL-1];
  int flow_sent [0:NODES-1][0:NODES-1][0:3],flow_received [0:NODES-1][0:NODES-1][0:3];
  int seq_count [0:NODES-1],node_received [0:NODES-1];
  int scenario,cycle,all_cycles=0,accepted_count,delivered_count,blocked_count,stall_count;
  int dateline_count,invalid_vc_checks,all_accepted=0,all_delivered=0,all_blocked=0,all_stalled=0;
  int all_datelines=0,all_invalid_vc=0;
  bit input_fire [0:NODES-1];
  string result_path;
  integer result_fd;

  task automatic compare_raw;
    if(LEGACY) for(int node=0;node<NODES;node++)begin
      if(recv_rdy[node]!==gold_rdy[node])$fatal(1,"NOC_DIFF cycle=%0d recv_rdy node=%0d native=%b gold=%b",all_cycles,node,recv_rdy[node],gold_rdy[node]);
      if(send_val[node]!==gold_val[node])$fatal(1,"NOC_DIFF cycle=%0d send_val node=%0d",all_cycles,node);
      if(send_msg[node]!==gold_msg[node])begin
        // Unreset empty-queue storage is unspecified hardware state. Synthesis
        // may optimize it; RTL compatibility still compares every raw bit.
        if(RAW_INVALID_MESSAGES || send_val[node])
          $fatal(1,"NOC_DIFF cycle=%0d msg node=%0d val=%b native=%h gold=%h",all_cycles,node,send_val[node],send_msg[node],gold_msg[node]);
        invalid_message_differences++;
      end
    end
    all_cycles++;
  endtask
  task automatic check_packets;
    // Register all same-cycle injections before considering ejection.
    for(int source=0;source<NODES;source++)begin
      int id,destination,vc;
      input_fire[source]=recv_val[source]&&recv_rdy[source];
      if(recv_val[source]&&!recv_rdy[source])blocked_count++;
      if(input_fire[source])begin
        id=int'(recv_msg[source][ID_LSB+:32]);
        destination=int'(recv_msg[source][DST_LSB+:DST_WIDTH]);
        vc=int'(recv_msg[source][VC_LSB+:VC_WIDTH]);
        if(id<0||id>=TOTAL||accepted[id]||destination>=NODES)$fatal(1,"Invalid/duplicate injection id=%0d destination=%0d",id,destination);
        accepted[id]=1;
        expected[id]=recv_msg[source];
        initial_vc[id]=vc;
        order_rank[id]=flow_sent[source][destination][vc];
        flow_sent[source][destination][vc]+=1;
        if(IS_RING&&crosses_dateline(source,destination))begin
          expected[id][VC_LSB+:VC_WIDTH]=1;
          dateline_count++;
        end
        accepted_count++;
        seq_count[source]++;
      end
    end
    for(int destination=0;destination<NODES;destination++)begin
      int id,source,vc;
      logic [WIDTH-1:0] expectation;
      if(send_val[destination]&&!send_rdy[destination])stall_count++;
      if(send_val[destination]&&send_rdy[destination])begin
        id=int'(send_msg[destination][ID_LSB+:32]);
        if(id<0||id>=TOTAL||!accepted[id]||delivered[id])$fatal(1,"Lost/duplicate/unexpected output id=%0d",id);
        source=id/PACKETS;
        vc=initial_vc[id];
        expectation=expected[id];
        if($test$plusargs("EXPECT_FAILURE")&&delivered_count==0)begin
          expectation[0]=~expectation[0];
          $display("intentional negative control: corrupt packet scoreboard expectation");
        end
        if(send_msg[destination]!==expectation)$fatal(1,"NOC_PACKET_MISMATCH scenario=%0d id=%0d expected=%h actual=%h",scenario,id,expectation,send_msg[destination]);
        if(int'(send_msg[destination][DST_LSB+:DST_WIDTH])!=destination)$fatal(1,"Wrong destination id=%0d port=%0d",id,destination);
        if(order_rank[id]!=flow_received[source][destination][vc])$fatal(1,"NOC_ORDER_MISMATCH source=%0d dst=%0d initial_vc=%0d rank=%0d expected_rank=%0d",source,destination,vc,order_rank[id],flow_received[source][destination][vc]);
        flow_received[source][destination][vc]++;
        delivered[id]=1;
        delivered_count++;
        node_received[destination]++;
      end
    end
  endtask
  task automatic tick(input bit scoreboard=0);
    @(posedge clk);
    compare_raw();
    if(!LEGACY)for(int n=0;n<NODES;n++)begin
      if(reset)begin
        held[n]=0;
        if(recv_rdy[n] || send_val[n])$fatal(1,"NOC_RESET_HANDSHAKE node=%0d",n);
      end else begin
        if(held[n])begin
          if(!send_val[n] || send_msg[n]!==held_msg[n])$fatal(1,"NOC_OUTPUT_CHANGED_UNDER_STALL node=%0d",n);
          stable_samples++;
        end
        held[n]=send_val[n] && !send_rdy[n];held_msg[n]=send_msg[n];
      end
    end
    if(scoreboard)check_packets();
    @(negedge clk);
  endtask
  task automatic reset_network;
    reset=1;
    for(int node=0;node<NODES;node++)begin recv_val[node]=0;recv_msg[node]=random_packet();send_rdy[node]=0;end
    repeat(3)tick();
    reset=0;
  endtask
  task automatic run_scenario(input int index);
    scenario=index;
    reset_network();
    foreach(accepted[id])begin accepted[id]=0;delivered[id]=0;expected[id]='0;end
    foreach(flow_sent[source,destination,vc])begin flow_sent[source][destination][vc]=0;flow_received[source][destination][vc]=0;end
    foreach(seq_count[node])begin seq_count[node]=0;node_received[node]=0;end
    accepted_count=0;delivered_count=0;blocked_count=0;stall_count=0;dateline_count=0;invalid_vc_checks=0;
    for(cycle=0;cycle<SCENARIO_CYCLES;cycle++)begin
      for(int node=0;node<NODES;node++)begin
        int destination,vc;
        send_rdy[node]=(cycle>=90)&&(cycle>=700||(random_word()%5>=2));
        if($test$plusargs("STALL_FOREVER"))send_rdy[node]=0;
        if(!recv_val[node])begin
          recv_msg[node]=random_packet();
          if(seq_count[node]<PACKETS && cycle<700)begin
            destination=seq_count[node]<8 ? node : seq_count[node]<24 ? 0 : (node+seq_count[node])%NODES;
            vc=IS_RING?seq_count[node]%2:seq_count[node]%4;
            recv_msg[node]=packet_for(node,destination,seq_count[node],vc);
            recv_val[node]=1;
          end
        end
        if(IS_RING&&cycle>=900&&cycle<932)begin
          if(accepted_count!=TOTAL||delivered_count!=TOTAL)$fatal(1,"Traffic did not drain before invalid-VC phase accepted=%0d delivered=%0d total=%0d",accepted_count,delivered_count,TOTAL);
          recv_msg[node]=packet_for(node,node,0,2+(cycle%2));
          recv_val[node]=1;
        end
      end
      tick(1);
      for(int node=0;node<NODES;node++)begin
        if(IS_RING&&cycle>=900&&cycle<932)begin
          if(input_fire[node])$fatal(1,"Invalid VC2/3 was accepted");
          invalid_vc_checks++;
          recv_val[node]=0;
        end else if(input_fire[node])recv_val[node]=0;
      end
    end
    if(accepted_count!=TOTAL||delivered_count!=TOTAL)$fatal(1,"NOC_TIMEOUT scenario=%0d accepted=%0d delivered=%0d expected=%0d",scenario,accepted_count,delivered_count,TOTAL);
    if(blocked_count==0||stall_count==0)$fatal(1,"Backpressure not exercised");
    if(IS_RING&&(dateline_count==0||invalid_vc_checks!=32*NODES))$fatal(1,"Ring VC/dateline coverage missing");
    foreach(seq_count[node])if(seq_count[node]!=PACKETS||node_received[node]==0)$fatal(1,"Node coverage missing node=%0d",node);
    foreach(accepted[id])if(!accepted[id]||!delivered[id])$fatal(1,"Packet identity missing id=%0d",id);
    $display("NOC_SCENARIO_PASS scenario=%0d accepted=%0d delivered=%0d blocked=%0d output_stalls=%0d datelines=%0d invalid_vc_checks=%0d",scenario,accepted_count,delivered_count,blocked_count,stall_count,dateline_count,invalid_vc_checks);
    all_accepted+=accepted_count;all_delivered+=delivered_count;all_blocked+=blocked_count;all_stalled+=stall_count;
    all_datelines+=dateline_count;all_invalid_vc+=invalid_vc_checks;
  endtask
  initial begin
    reset_network();
    // Fill with in-flight traffic, then reset without draining. The following
    // scenarios start fresh while comparing preserved, unreset storage bits.
    for(int warmup=0;warmup<24;warmup++)begin
      for(int node=0;node<NODES;node++)begin
        if(LEGACY || !recv_val[node])begin recv_val[node]=1;recv_msg[node]=packet_for(node,(node+1)%NODES,warmup,0);end
        send_rdy[node]=0;
      end
      #1;
      for(int node=0;node<NODES;node++)input_fire[node]=recv_val[node]&&recv_rdy[node];
      tick();
      if(!LEGACY)for(int node=0;node<NODES;node++)if(input_fire[node])recv_val[node]=0;
    end
    run_scenario(0);
    run_scenario(1);
    if(all_cycles!=27+2*(3+SCENARIO_CYCLES))$fatal(1,"Incomplete raw cycle coverage");
    if(!$value$plusargs("RESULT=%s",result_path))result_path="result.json";
    result_fd=$fopen(result_path,"w");if(result_fd==0)$fatal(1,"Cannot write result JSON");
    $fwrite(result_fd,"{\"status\":\"pass\",\"cycles\":%0d,\"scenarios\":2,\"width\":%0d,\"nodes\":%0d,\"raw_bits_per_cycle\":%0d,\"accepted\":%0d,\"delivered\":%0d,\"blocked_samples\":%0d,\"output_stalls\":%0d,\"dateline_packets\":%0d,\"invalid_vc_checks\":%0d,\"seed\":\"4c03a271\"}\n",all_cycles,WIDTH,NODES,NODES*(WIDTH+2),all_accepted,all_delivered,all_blocked,all_stalled,all_datelines,all_invalid_vc);
    $fclose(result_fd);
    if(!LEGACY && stable_samples==0)$fatal(1,"NOC_STABILITY_NOT_EXERCISED");
    $display("NOC_MODE_PASS legacy=%0d stable_samples=%0d",LEGACY,stable_samples);
    $display("NOC_RAW_POLICY legacy=%0d compare_invalid_messages=%0d invalid_message_differences=%0d",LEGACY,RAW_INVALID_MESSAGES,invalid_message_differences);
    $display("PHASE4_NOC_PASS label=%s cycles=%0d packets=%0d raw_bits=%0d",PROFILE_LABEL,all_cycles,all_delivered,NODES*(WIDTH+2));
    $finish;
  end
  initial begin #100000;$fatal(1,"NOC_WALL_TIMEOUT");end
endmodule
