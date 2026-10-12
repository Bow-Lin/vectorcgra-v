`timescale 1ns/1ps
`include "cgra_ring_ctrl_defs.svh"
`include "cgra_opcodes.svh"
module tb_ring_ctrl_memory #(`CGRA_RING_CTRL_PARAMETERS);
  `include "cgra_ring_ctrl_types.svh"
  logic clk=0,reset=0;
  logic [PACKET_BITS-1:0] recv_pkt_from_controller__msg='0,send_to_controller_pkt__msg;
  logic recv_pkt_from_controller__val=0,recv_pkt_from_controller__rdy;
  logic send_to_controller_pkt__val,send_to_controller_pkt__rdy=0;
  logic [CTRL_BITS-1:0] send_ctrl__msg [0:NUM_TILES-1];
  logic send_ctrl__val [0:NUM_TILES-1],send_ctrl__rdy [0:NUM_TILES-1];
`ifdef RING_CTRL_POST_SYNTH
  wire [NUM_TILES*CTRL_BITS-1:0] ctrl_msg_flat;
  wire [NUM_TILES-1:0] ctrl_val_flat,ctrl_rdy_flat;
  for (genvar n=0;n<NUM_TILES;n++) begin : flatten
    assign send_ctrl__msg[n]=ctrl_msg_flat[(NUM_TILES-1-n)*CTRL_BITS +: CTRL_BITS];
    assign send_ctrl__val[n]=ctrl_val_flat[NUM_TILES-1-n];
    assign ctrl_rdy_flat[NUM_TILES-1-n]=send_ctrl__rdy[n];
  end
  cgra_ring_multi_ctrl_mem_netlist dut (
    .clk,.reset,.recv_pkt_from_controller__msg,.recv_pkt_from_controller__val,
    .recv_pkt_from_controller__rdy,.send_to_controller_pkt__msg,
    .send_to_controller_pkt__val,.send_to_controller_pkt__rdy,
    .send_ctrl__msg(ctrl_msg_flat),.send_ctrl__val(ctrl_val_flat),.send_ctrl__rdy(ctrl_rdy_flat)
  );
`else
  cgra_ring_multi_ctrl_mem #(`CGRA_RING_CTRL_BIND) dut (.*);
`endif
  integer cycles /* verilator public_flat_rw */ = 0;
  integer checks /* verilator public_flat_rw */ = 0;
  integer samples /* verilator public_flat_rw */ = 0;
  integer input_stalls /* verilator public_flat_rw */ = 0;
  integer output_stalls /* verilator public_flat_rw */ = 0;
  integer loopbacks /* verilator public_flat_rw */ = 0;
  integer completed /* verilator public_flat_rw */ = 0;
  integer seen [0:NUM_TILES-1];
  bit done_seen [0:NUM_TILES-1];
  bit returned [0:19];
  bit wrong,monitor=0,check_controls=0,held_valid=0;
  bit ready_controls=0;
  integer budget=5,prologue=2,host_block_until=0;
  logic [PACKET_BITS-1:0] held_msg;
  task automatic require(input bit condition,input string label);
    checks++;
    if (!condition) $fatal(1,"RING_CTRL_CHECK %s cycle=%0d checks=%0d",label,cycles,checks);
  endtask
  function automatic ring_ctrl_t program_word(input integer node,input integer slot);
    ring_ctrl_t result;
    result='1;
    result.operation=7'(2+slot);
    result.vector_factor_power=3'(node+slot);
    result.is_last_ctrl=1'(slot);
    for (integer i=0;i<FU_INPUTS;i++) begin
      result.fu_in[i]=FU_SEL_W'(i+1);
      result.write_reg_from[i]=2'(node+i);
      result.write_reg_idx[i]=REG_W'(REG_DEPTH-1-i);
      result.read_reg_towards[i]=2'(slot+i);
      result.read_reg_idx[i]=REG_W'(node+slot+i);
    end
    for (integer i=0;i<ROUTES;i++) begin
      result.routing_xbar_outport[i]=ROUTE_W'(i%(TILE_INPUTS+FU_INPUTS+1));
      result.fu_xbar_outport[i]=FU_OUT_W'(i%3);
    end
    return result;
  endfunction
  function automatic ring_packet_t config_packet(input integer node,input integer cmd,
    input integer addr,input logic [DATA_W-1:0] data,input ring_ctrl_t control);
    ring_packet_t result;
    result='0;result.src=ID_W'(NUM_TILES);result.dst=ID_W'(node);
    result.payload.cmd=6'(cmd);result.payload.ctrl_addr=ADDR_W'(addr);
    result.payload.data={data,3'b111};result.payload.ctrl=control;
    return result;
  endfunction
  function automatic ring_packet_t loop_packet(input integer token);
    ring_packet_t result;
    result=config_packet(NUM_TILES,12,2,(DATA_W'(1)<<(DATA_W-1))|DATA_W'(token+123),program_word(0,1));
    result.opaque=8'(token);result.vc_id=1'(token);
    result.src_cgra_id=1;result.src_cgra_x=1;result.dst_cgra_y=1;
    result.payload.data_addr='1;
    return result;
  endfunction
  task automatic observe;
    ring_ctrl_t expected;
    ring_packet_t returned_packet,expected_packet;
    if (reset) held_valid=0;
    else if (monitor) begin
      if (held_valid)
        require(send_to_controller_pkt__val && send_to_controller_pkt__msg==held_msg,"held return stable");
      held_valid=send_to_controller_pkt__val && !send_to_controller_pkt__rdy;
      held_msg=send_to_controller_pkt__msg;
      if (held_valid) output_stalls++;
      if (recv_pkt_from_controller__val && !recv_pkt_from_controller__rdy) input_stalls++;
      for (integer n=0;n<NUM_TILES;n++) begin
        if (send_ctrl__val[n] && check_controls) begin
          require(budget==0 || seen[n]<budget,"no extra control after budget");
          expected=program_word(n,1+seen[n]%2);
          if (seen[n]%2==0 && seen[n]/2<prologue) expected.operation=`CGRA_OPT_NAH;
          if (wrong && n==0 && seen[n]==0) expected=expected^CTRL_BITS'(1);
          require(send_ctrl__msg[n]==expected,"complete control word / FU prologue / bounds");
          if (send_ctrl__rdy[n]) seen[n]++;
        end
      end
      if (send_to_controller_pkt__val && send_to_controller_pkt__rdy) begin
        returned_packet=send_to_controller_pkt__msg;
        if (returned_packet.payload.cmd==14) begin
          require(int'(returned_packet.src)<NUM_TILES,"completion source");
          require(!done_seen[returned_packet.src] && budget>0 && seen[returned_packet.src]==budget,
                  "unique completion only after all retired controls");
          expected_packet='0;expected_packet.src=returned_packet.src;expected_packet.dst=ID_W'(NUM_TILES);
          expected_packet.vc_id=(int'(returned_packet.src)+1 < NUM_TILES-int'(returned_packet.src));
          expected_packet.payload.cmd=14;
          require(returned_packet==expected_packet,"complete packet fields");
          done_seen[returned_packet.src]=1;completed++;
        end else if (returned_packet.payload.cmd==12) begin
          require(returned_packet.opaque<20,"loopback token range");
          require(!returned[returned_packet.opaque],"no duplicate loopback");
          require(returned_packet==loop_packet(int'(returned_packet.opaque)),"loopback all fields including wide payload");
          returned[returned_packet.opaque]=1;loopbacks++;
        end else $fatal(1,"RING_CTRL_UNEXPECTED_RETURN cmd=%0d cycle=%0d",returned_packet.payload.cmd,cycles);
      end
    end
  endtask
  task automatic tick;
    #1; observe(); #2;clk=1;#2;clk=0;#1;cycles++;
    if (cycles>5000) $fatal(1,"RING_CTRL_TIMEOUT");
  endtask
  task automatic step;
    send_to_controller_pkt__rdy=(cycles>=host_block_until && cycles%4!=1);
    for (integer n=0;n<NUM_TILES;n++) send_ctrl__rdy[n]=ready_controls && cycles%5!=n%5;
    tick();
  endtask
  task automatic send_packet(input ring_packet_t packet);
    integer waited;
    waited=0;recv_pkt_from_controller__msg=packet;recv_pkt_from_controller__val=1;
    #1;
    while (!recv_pkt_from_controller__rdy) begin
      step();#1;waited++;
      if (waited>600) $fatal(1,"RING_CTRL_SOURCE_TIMEOUT");
    end
    step();recv_pkt_from_controller__val=0;
  endtask
  task automatic reset_all;
    reset=1;recv_pkt_from_controller__val=0;ready_controls=0;
    repeat (3) step();reset=0;
    completed=0;held_valid=0;
    for (integer n=0;n<NUM_TILES;n++) begin seen[n]=0;done_seen[n]=0;end
    for (integer i=0;i<20;i++) returned[i]=0;
  endtask
  task automatic launch_all(input bit resume_run);
    for (integer n=0;n<NUM_TILES;n++) begin
      send_packet(config_packet(n,8,0,DATA_W'(2),'0));
      send_packet(config_packet(n,9,0,DATA_W'(1),'0));
      send_packet(config_packet(n,7,0,DATA_W'(budget),'0));
      send_packet(config_packet(n,resume_run?15:0,0,'0,'0));
    end
  endtask
  task automatic wait_complete;
    integer waited;
    waited=0;
    while (completed<NUM_TILES && waited<500) begin step();waited++;end
    require(completed==NUM_TILES,"all nodes complete before timeout");
    repeat (30) step();
    for (integer n=0;n<NUM_TILES;n++) require(seen[n]==budget,"exact retirement count per node");
  endtask
  task automatic native_checks;
    reset_all();monitor=1;
    if ($test$plusargs("INVALID_DEST")) begin
      send_packet(config_packet(NUM_TILES+1,3,0,'0,'0));$fatal(1,"DEST_ASSERTION_MISSING");
    end
    if ($test$plusargs("INVALID_ADDRESS")) begin
      send_packet(config_packet(0,3,CTRL_DEPTH,'0,'0));$fatal(1,"ADDRESS_ASSERTION_MISSING");
    end
    for (integer n=0;n<NUM_TILES;n++) begin
      for (integer slot=0;slot<3;slot++) send_packet(config_packet(n,3,slot,'0,program_word(n,slot)));
      send_packet(config_packet(n,4,1,DATA_W'(prologue),'0));
    end
    check_controls=1;launch_all(0);
    // Long output stalls do not consume control budget.
    repeat (35) step();
    for (integer n=0;n<NUM_TILES;n++) require(seen[n]==0,"no retire under control stall");
    ready_controls=1;host_block_until=cycles+65;
    wait_complete();
    // Relaunch without terminate does not reset the inherited execution budget.
    check_controls=0;
    for (integer n=0;n<NUM_TILES;n++) send_packet(config_packet(n,2,0,'0,'0));
    repeat (20) step();
    completed=0;budget=3;prologue=0;ready_controls=0;
    for (integer n=0;n<NUM_TILES;n++) begin seen[n]=0;done_seen[n]=0;end
    check_controls=1;launch_all(1);ready_controls=1;wait_complete();
    // Reset keeps program storage but clears metadata and outstanding traffic.
    reset_all();budget=0;prologue=0;check_controls=1;launch_all(0);ready_controls=1;
    repeat (90) step();
    require(completed==0,"unlimited mode has no completion");
    for (integer n=0;n<NUM_TILES;n++) require(seen[n]>20,"unlimited progress on every node");
    // PAUSE/PRESERVE are accepted no-ops in this base-memory wrapper.
    for (integer n=0;n<NUM_TILES;n++) begin
      send_packet(config_packet(n,1,0,'0,'0));send_packet(config_packet(n,22,0,'0,'0));
    end
    repeat (20) step();
    for (integer n=0;n<NUM_TILES;n++) send_packet(config_packet(n,2,0,'0,'0));
    repeat (30) step();check_controls=0;
    for (integer n=0;n<NUM_TILES;n++) require(!send_ctrl__val[n],"terminate quiesces control output");
    // START is a sentinel, not an instruction or an implicit completion.
    reset_all();budget=5;prologue=0;
    for (integer n=0;n<NUM_TILES;n++) send_packet(config_packet(n,3,2,'0,'0));
    check_controls=1;launch_all(0);ready_controls=1;repeat (45) step();
    for (integer n=0;n<NUM_TILES;n++)
      require(seen[n]==1 && !send_ctrl__val[n] && send_ctrl__msg[n]=='0,"START stops before budget");
    require(completed==0,"START does not fabricate COMPLETE");
    for (integer n=0;n<NUM_TILES;n++) send_packet(config_packet(n,2,0,'0,'0));
    repeat (25) step();check_controls=0;
    // Saturate the controller ejection path, then drain both VCs exactly once.
    host_block_until=cycles+100;
    for (integer i=0;i<20;i++) send_packet(loop_packet(i));
    repeat (200) step();require(loopbacks==20,"all loopbacks delivered");
    require(input_stalls>5 && output_stalls>20,"credit and output backpressure coverage");
    // Cancel a buffered controller packet with reset.
    host_block_until=cycles+100;send_packet(loop_packet(0));repeat (8) step();
    reset_all();host_block_until=0;repeat (30) step();
    require(loopbacks==20,"reset flushed pending packet");
    $display("RING_CTRL_NATIVE_PASS tiles=%0d ctrl_bits=%0d packet_bits=%0d cycles=%0d checks=%0d input_stalls=%0d output_stalls=%0d loopbacks=%0d",
      NUM_TILES,CTRL_BITS,PACKET_BITS,cycles,checks,input_stalls,output_stalls,loopbacks);
  endtask
  task automatic replay(input string path);
    localparam integer IN_W=PACKET_BITS+NUM_TILES+3;
    localparam integer OUT_W=PACKET_BITS+2+NUM_TILES*(CTRL_BITS+1);
    logic [IN_W-1:0] ins;
    logic [OUT_W-1:0] expected,actual;
    logic [NUM_TILES-1:0] ready_flat;
    integer fd,scan,expected_samples;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    if (!$value$plusargs("SAMPLES=%d",expected_samples)) $fatal(1,"RING_CTRL_SAMPLE_COUNT_REQUIRED");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"RING_CTRL_VECTOR_FORMAT");
      {reset,recv_pkt_from_controller__val,recv_pkt_from_controller__msg,send_to_controller_pkt__rdy,ready_flat}=ins;
      for (integer n=0;n<NUM_TILES;n++) send_ctrl__rdy[n]=ready_flat[NUM_TILES-1-n];
      #1;
      actual[OUT_W-1 -: PACKET_BITS+2]={recv_pkt_from_controller__rdy,send_to_controller_pkt__val,send_to_controller_pkt__msg};
      for (integer n=0;n<NUM_TILES;n++)
        actual[(NUM_TILES-1-n)*(CTRL_BITS+1) +: CTRL_BITS+1]={send_ctrl__val[n],send_ctrl__msg[n]};
      if (wrong && samples==8) expected=expected^OUT_W'(1);
      if (actual !== expected) $fatal(1,"RING_CTRL_REPLAY_MISMATCH cycle=%0d got=%h expected=%h",samples,actual,expected);
      samples++;tick();
    end
    $fclose(fd);require(samples==expected_samples && samples>20,"exact sample count");
    $display("RING_CTRL_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_W);
  endtask
  string path;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    for (integer n=0;n<NUM_TILES;n++) send_ctrl__rdy[n]=0;
    if ($value$plusargs("VECTORS=%s",path)) replay(path);else native_checks();
    $finish;
  end
endmodule
