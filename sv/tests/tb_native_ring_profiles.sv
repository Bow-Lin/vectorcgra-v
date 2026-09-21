`timescale 1ns/1ps
// Each build uses one unchanged phase-2 reference to avoid generated-name
// collisions. See native_noc_README.md for module/source provenance.
`ifdef RING_17
  `define GOLD_RING RingNetworkRTL__20cebbcf8628020c
`else
  `define GOLD_RING RingNetworkRTL__0ef6fd6e3a72f330
`endif
module tb_native_ring_profiles;
`ifdef RING_17
  localparam int NODES = 17;
`else
  localparam int NODES = 7;
`endif
  localparam int ID_WIDTH = $clog2(NODES);
  localparam int WIDTH = 185 + 2*ID_WIDTH;
  logic clk=0, reset=1;
  always #5 clk=~clk;
  logic [WIDTH-1:0] input_msg [0:NODES-1], output_msg [0:NODES-1], gold_msg [0:NODES-1];
  logic input_val [0:NODES-1], input_rdy [0:NODES-1], gold_rdy [0:NODES-1];
  logic output_val [0:NODES-1], gold_val [0:NODES-1], output_rdy [0:NODES-1];
  logic accepted_previous [0:NODES-1];
  int source_count [0:NODES-1], sink_count [0:NODES-1];
  int accepted=0, delivered=0, blocked=0, cycle, packet_id=0;
  logic [31:0] random_state = 32'h27182818;
  function automatic logic [31:0] random_word();
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return random_state;
  endfunction
  cgra_credit_ring #(.WIDTH(WIDTH),.NODES(NODES),.DST_WIDTH(ID_WIDTH)) dut (
    .clk,.reset,.recv_msg(input_msg),.recv_val(input_val),.recv_rdy(input_rdy),
    .send_msg(output_msg),.send_val(output_val),.send_rdy(output_rdy));
  `GOLD_RING gold (
    .clk,.reset,.recv__msg(input_msg),.recv__val(input_val),.recv__rdy(gold_rdy),
    .send__msg(gold_msg),.send__val(gold_val),.send__rdy(output_rdy));
  initial begin
    for(int n=0;n<NODES;n++) begin
      input_msg[n]='0; input_val[n]=0; output_rdy[n]=0;
      accepted_previous[n]=0; source_count[n]=0; sink_count[n]=0;
    end
    for(cycle=0;cycle<800;cycle++) begin
      @(negedge clk);
      reset=(cycle<3)||((cycle>=250)&&(cycle<253));
      for(int n=0;n<NODES;n++) begin
        // Legal source: retain a pending valid packet until its handshake.
        if(reset) input_val[n]=0;
        else if(!input_val[n] || accepted_previous[n]) begin
          input_msg[n]=WIDTH'({random_word(),random_word(),random_word(),random_word(),random_word(),random_word(),random_word()});
          input_msg[n][185+:ID_WIDTH]=ID_WIDTH'(random_word()%NODES);
          input_msg[n][185+ID_WIDTH+:ID_WIDTH]=ID_WIDTH'(n);
          input_msg[n][170]=0;
          input_msg[n][31:0]=32'(packet_id++);
          input_val[n]=(cycle<600)&&1'(random_word());
        end
        // Directed all-destination stall exhausts credits; then random
        // backpressure and finally a long drain with all destinations ready.
        output_rdy[n]=(cycle>=600)||((cycle<300||cycle>=340)&&1'(random_word()));
      end
      @(posedge clk);
      if(reset) begin
        accepted=0; delivered=0; blocked=0;
        for(int n=0;n<NODES;n++) begin source_count[n]=0;sink_count[n]=0;end
      end
      for(int n=0;n<NODES;n++) begin
        if({input_rdy[n],output_val[n],output_msg[n]} !== {gold_rdy[n],gold_val[n],gold_msg[n]})
          $fatal(1,"NATIVE_RING_MISMATCH nodes=%0d cycle=%0d node=%0d actual=%h gold=%h",NODES,cycle,n,
            {input_rdy[n],output_val[n],output_msg[n]},{gold_rdy[n],gold_val[n],gold_msg[n]});
        accepted_previous[n]=input_val[n]&&input_rdy[n];
        if(!reset) begin
          if(accepted_previous[n]) begin accepted++;source_count[n]++;end
          if(input_val[n]&&!input_rdy[n]) blocked++;
          if(output_val[n]&&output_rdy[n]) begin
            delivered++;sink_count[n]++;
            if(output_msg[n][185+:ID_WIDTH] !== ID_WIDTH'(n))
              $fatal(1,"NATIVE_RING_WRONG_DEST nodes=%0d cycle=%0d node=%0d msg=%h",NODES,cycle,n,output_msg[n]);
          end
        end
      end
    end
    if(accepted!=delivered || accepted<200 || blocked<20)
      $fatal(1,"NATIVE_RING_CONSERVATION nodes=%0d accepted=%0d delivered=%0d blocked=%0d",NODES,accepted,delivered,blocked);
    for(int n=0;n<NODES;n++)
      if(source_count[n]==0||sink_count[n]==0)
        $fatal(1,"NATIVE_RING_NODE_NOT_COVERED node=%0d source=%0d sink=%0d",n,source_count[n],sink_count[n]);
    $display("NATIVE_RING_PASS nodes=%0d width=%0d cycles=800 seed=27182818 accepted=%0d delivered=%0d blocked=%0d full_invalid_msg_comparison=1",NODES,WIDTH,accepted,delivered,blocked);
    $finish;
  end
endmodule
`undef GOLD_RING
