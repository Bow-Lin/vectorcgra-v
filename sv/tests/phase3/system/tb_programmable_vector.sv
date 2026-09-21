`timescale 1ns/1ps
// ac96-derived whole-array scalar tests for the three explicitly validated geometries.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
`ifndef PHASE2_REFERENCE_MODULE
`define PHASE2_REFERENCE_MODULE Phase3VectorReference2x2
`endif
module tb_programmable_vector #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  typedef data_t tb_data_t;
  typedef ctrl_t tb_ctrl_t;
  typedef host_packet_t tb_packet_t;
  typedef payload_t tb_payload_t;
  localparam int REPLAY_IN_BITS = 4 + 2*GLOBAL_ADDR_W + HOST_BITS + 2*(COLS+ROWS)*(DATA_BITS+2);
  localparam int REPLAY_OUT_BITS = 2 + HOST_BITS + 2*(COLS+ROWS)*(DATA_BITS+2);
  localparam int PACKET_COUNT = 5*NUM_TILES+6;
  int chain [0:NUM_TILES-1];
  int expected_cycles, expected_samples;
  localparam int CMD_LAUNCH=0, CMD_CONFIG=3, CMD_CONFIG_TOTAL_CTRL_COUNT=7,
    CMD_CONFIG_COUNT_PER_ITER=8, CMD_LOAD_REQUEST=10, CMD_LOAD_RESPONSE=11,
    CMD_STORE_REQUEST=12, CMD_CONST=13, CMD_COMPLETE=14;

  function automatic tb_data_t data_word(input logic [DATA_W-1:0] value, input logic predicate=1);
    return {value,predicate,2'b00};
  endfunction
  // Independent per-lane arithmetic; no native FU/reference internal signals.
  function automatic logic [31:0] lane_add(input logic [31:0] value);
    logic [31:0] result,constant_word;
    constant_word=32'h05040302;
    for(int i=0;i<4;i++) result[8*i+:8]=value[8*i+:8]+constant_word[8*i+:8];
    return result;
  endfunction
  function automatic logic [31:0] lane_sub(input logic [31:0] value);
    logic [31:0] result,constant_word;
    constant_word=32'h08070605;
    for(int i=0;i<4;i++) result[8*i+:8]=value[8*i+:8]-constant_word[8*i+:8];
    return result;
  endfunction
  function automatic logic [DATA_W-1:0] result_for(input logic [DATA_W-1:0] value);
    return lane_sub(lane_add(value)*32'd3);
  endfunction
  function automatic int dir(input int src, input int dst);
    if (dst==src+COLS) return 0;
    if (dst==src-COLS) return 1;
    if (dst==src-1) return 2;
    if (dst==src+1) return 3;
    $fatal(1,"Nonadjacent chain edge %0d -> %0d",src,dst);
    return -1;
  endfunction
  function automatic tb_ctrl_t workload_ctrl(input int tile_id, input int step_id=0);
    tb_ctrl_t c;
    int position;
    c='0;
    for(int i=0;i<4;i++) c.fu_in[i]=3'(i+1);
    if(tile_id==0) begin
      c.operation=step_id==0 ? 7'd28 : 7'd58;
      if(step_id==0) c.fu_xbar_outport[3]=1;
      else c.routing_xbar_outport[4]=1;
    end else begin
      position=0;
      for(int i=1;i<NUM_TILES;i++) if(chain[i]==tile_id) position=i;
      if(position==0) $fatal(1,"Tile missing from chain");
      c.operation=position==1 ? 7'd52 : position==2 ? 7'd29 : 7'd54;
      c.routing_xbar_outport[4]=4'(dir(tile_id,chain[position-1])+1);
      c.fu_xbar_outport[dir(tile_id,chain[(position+1)%NUM_TILES])]=1;
      if(position==NUM_TILES-1) c.fu_xbar_outport[2]=1;
    end
    return c;
  endfunction
  function automatic tb_packet_t packet(input int command, input int destination,
      input logic [DATA_W-1:0] value='0, input logic predicate=0,
      input logic [GLOBAL_ADDR_W-1:0] address='0, input tb_ctrl_t control_word='0,
      input logic [CTRL_ADDR_W-1:0] control_address='0, input logic [TILE_ID_W-1:0] source='0);
    tb_packet_t p;
    p='0; p.src=source; p.dst=TILE_ID_W'(destination);
    p.payload.cmd=6'(command); p.payload.data=data_word(value,predicate);
    p.payload.data_addr=address; p.payload.ctrl=control_word; p.payload.ctrl_addr=control_address;
    return p;
  endfunction
  initial if(COLS!=2 || ROWS!=2 || DATA_W!=32 || CTRL_DEPTH!=8 || REG_DEPTH!=16) $fatal(1,"VECTOR_SYSTEM_PROFILE requires 2x2/32/8/16");
  logic clk = 0;
  always #5 clk = ~clk;
  logic reset;
  logic [GLOBAL_ADDR_W-1:0] address_lower, address_upper;
  logic cgra_id;
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val, recv_from_cpu_pkt__rdy;
  logic [HOST_BITS-1:0] send_to_cpu_pkt__msg;
  logic send_to_cpu_pkt__val, send_to_cpu_pkt__rdy;
  logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg, send_to_inter_cgra_noc__msg;
  logic recv_from_inter_cgra_noc__val, recv_from_inter_cgra_noc__rdy;
  logic send_to_inter_cgra_noc__val, send_to_inter_cgra_noc__rdy;
  logic gold_recv_from_cpu_pkt__rdy;
  logic [HOST_BITS-1:0] gold_send_to_cpu_pkt__msg;
  logic gold_send_to_cpu_pkt__val;
  logic [NOC_BITS-1:0] gold_send_to_inter_cgra_noc__msg;
  logic gold_recv_from_inter_cgra_noc__rdy, gold_send_to_inter_cgra_noc__val;
  logic [DATA_BITS-1:0] recv_data_on_boundary_east__msg [0:ROWS-1];
  logic recv_data_on_boundary_east__val [0:ROWS-1];
  logic recv_data_on_boundary_east__rdy [0:ROWS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_east__msg [0:ROWS-1];
  logic send_data_on_boundary_east__val [0:ROWS-1];
  logic send_data_on_boundary_east__rdy [0:ROWS-1];
  logic gold_recv_data_on_boundary_east__rdy [0:ROWS-1];
  logic [DATA_BITS-1:0] gold_send_data_on_boundary_east__msg [0:ROWS-1];
  logic gold_send_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_north__msg [0:COLS-1];
  logic recv_data_on_boundary_north__val [0:COLS-1];
  logic recv_data_on_boundary_north__rdy [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_north__msg [0:COLS-1];
  logic send_data_on_boundary_north__val [0:COLS-1];
  logic send_data_on_boundary_north__rdy [0:COLS-1];
  logic gold_recv_data_on_boundary_north__rdy [0:COLS-1];
  logic [DATA_BITS-1:0] gold_send_data_on_boundary_north__msg [0:COLS-1];
  logic gold_send_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_south__msg [0:COLS-1];
  logic recv_data_on_boundary_south__val [0:COLS-1];
  logic recv_data_on_boundary_south__rdy [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_south__msg [0:COLS-1];
  logic send_data_on_boundary_south__val [0:COLS-1];
  logic send_data_on_boundary_south__rdy [0:COLS-1];
  logic gold_recv_data_on_boundary_south__rdy [0:COLS-1];
  logic [DATA_BITS-1:0] gold_send_data_on_boundary_south__msg [0:COLS-1];
  logic gold_send_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_west__msg [0:ROWS-1];
  logic recv_data_on_boundary_west__val [0:ROWS-1];
  logic recv_data_on_boundary_west__rdy [0:ROWS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_west__msg [0:ROWS-1];
  logic send_data_on_boundary_west__val [0:ROWS-1];
  logic send_data_on_boundary_west__rdy [0:ROWS-1];
  logic gold_recv_data_on_boundary_west__rdy [0:ROWS-1];
  logic [DATA_BITS-1:0] gold_send_data_on_boundary_west__msg [0:ROWS-1];
  logic gold_send_data_on_boundary_west__val [0:ROWS-1];

`ifdef PHASE2_REFERENCE_ONLY
  `PHASE2_REFERENCE_MODULE dut (.*);
`else
  cgra_programmable #(`CGRA_PROFILE_BIND, .FU_COUNT(4), .VECTOR_LANES(4),
    .FU_KINDS({`CGRA_FU_NAH,`CGRA_FU_MEM,`CGRA_FU_MUL,`CGRA_FU_VECTOR_ADDER})) dut (.*);
`endif
  `PHASE2_REFERENCE_MODULE gold (
    .clk(clk), .reset(reset), .cgra_id(cgra_id),
    .address_lower(address_lower), .address_upper(address_upper),
    .recv_from_cpu_pkt__msg(recv_from_cpu_pkt__msg),
    .recv_from_cpu_pkt__val(recv_from_cpu_pkt__val),
    .recv_from_cpu_pkt__rdy(gold_recv_from_cpu_pkt__rdy),
    .send_to_cpu_pkt__msg(gold_send_to_cpu_pkt__msg),
    .send_to_cpu_pkt__val(gold_send_to_cpu_pkt__val),
    .send_to_cpu_pkt__rdy(send_to_cpu_pkt__rdy),
    .recv_from_inter_cgra_noc__msg(recv_from_inter_cgra_noc__msg),
    .recv_from_inter_cgra_noc__val(recv_from_inter_cgra_noc__val),
    .recv_from_inter_cgra_noc__rdy(gold_recv_from_inter_cgra_noc__rdy),
    .send_to_inter_cgra_noc__msg(gold_send_to_inter_cgra_noc__msg),
    .send_to_inter_cgra_noc__val(gold_send_to_inter_cgra_noc__val),
    .send_to_inter_cgra_noc__rdy(send_to_inter_cgra_noc__rdy),
    .recv_data_on_boundary_east__msg(recv_data_on_boundary_east__msg),
    .recv_data_on_boundary_east__val(recv_data_on_boundary_east__val),
    .recv_data_on_boundary_east__rdy(gold_recv_data_on_boundary_east__rdy),
    .send_data_on_boundary_east__msg(gold_send_data_on_boundary_east__msg),
    .send_data_on_boundary_east__val(gold_send_data_on_boundary_east__val),
    .send_data_on_boundary_east__rdy(send_data_on_boundary_east__rdy),
    .recv_data_on_boundary_north__msg(recv_data_on_boundary_north__msg),
    .recv_data_on_boundary_north__val(recv_data_on_boundary_north__val),
    .recv_data_on_boundary_north__rdy(gold_recv_data_on_boundary_north__rdy),
    .send_data_on_boundary_north__msg(gold_send_data_on_boundary_north__msg),
    .send_data_on_boundary_north__val(gold_send_data_on_boundary_north__val),
    .send_data_on_boundary_north__rdy(send_data_on_boundary_north__rdy),
    .recv_data_on_boundary_south__msg(recv_data_on_boundary_south__msg),
    .recv_data_on_boundary_south__val(recv_data_on_boundary_south__val),
    .recv_data_on_boundary_south__rdy(gold_recv_data_on_boundary_south__rdy),
    .send_data_on_boundary_south__msg(gold_send_data_on_boundary_south__msg),
    .send_data_on_boundary_south__val(gold_send_data_on_boundary_south__val),
    .send_data_on_boundary_south__rdy(send_data_on_boundary_south__rdy),
    .recv_data_on_boundary_west__msg(recv_data_on_boundary_west__msg),
    .recv_data_on_boundary_west__val(recv_data_on_boundary_west__val),
    .recv_data_on_boundary_west__rdy(gold_recv_data_on_boundary_west__rdy),
    .send_data_on_boundary_west__msg(gold_send_data_on_boundary_west__msg),
    .send_data_on_boundary_west__val(gold_send_data_on_boundary_west__val),
    .send_data_on_boundary_west__rdy(send_data_on_boundary_west__rdy)
  );

  int scenario_id, cycle_count, max_cycles = 2000;
  int input_packets, completion_count, read_response_count, west_count;
  int mesh_link_count [0:NUM_TILES-1];
  int native_mesh_link_count [0:NUM_TILES-1];
  int host_stall_cycles, west_stall_cycles;
  int all_compared_cycles = 0;
  int pymtl_compared_cycles = 0;
  int trace_fd = 0;
  int packet_fd = 0;
  string trace_path, packet_path, vector_dir = "sv/vectors/phase3/system/vector/2x2";
  logic [HOST_BITS-1:0] golden_packets [0:PACKET_COUNT-1];
  logic [NUM_TILES-1:0] completed_tiles;
  logic [DATA_W-1:0] scenario_input, scenario_result;
  bit last_input_fire;
  bit queries_started;
  bit inject_bad_expectation, stall_forever;
  bit host_was_stalled;
  logic [HOST_BITS-1:0] stalled_host_msg;

  // Frozen PyMTL samples, including idle messages: no dynamic valid mask.
  // Bit positions are documented in vectors/replay_layout.json.
  logic [REPLAY_IN_BITS-1:0] pymtl_inputs [0:8191];
  logic [REPLAY_OUT_BITS-1:0] pymtl_outputs [0:8191];

  task automatic compare_pymtl();
    logic [REPLAY_IN_BITS-1:0] actual_inputs;
    logic [REPLAY_OUT_BITS-1:0] actual_outputs;
    int sample_index, a, b;
    sample_index=scenario_id*(expected_cycles+3)+cycle_count+3;
    actual_inputs='0; actual_outputs='0; a=0; b=0;
    actual_inputs[a +: 1]=reset; a+=1;
    actual_inputs[a +: 1]=cgra_id; a+=1;
    actual_inputs[a +: GLOBAL_ADDR_W]=address_lower; a+=GLOBAL_ADDR_W;
    actual_inputs[a +: GLOBAL_ADDR_W]=address_upper; a+=GLOBAL_ADDR_W;
    actual_inputs[a +: 1]=recv_from_cpu_pkt__val; a+=1;
    actual_inputs[a +: HOST_BITS]=recv_from_cpu_pkt__msg; a+=HOST_BITS;
    actual_inputs[a +: 1]=send_to_cpu_pkt__rdy; a+=1;
    actual_outputs[b +: 1]=recv_from_cpu_pkt__rdy; b+=1;
    actual_outputs[b +: 1]=send_to_cpu_pkt__val; b+=1;
    actual_outputs[b +: HOST_BITS]=send_to_cpu_pkt__msg; b+=HOST_BITS;
    for(int i=0;i<COLS;i++) begin
      actual_inputs[a +: 1]=recv_data_on_boundary_north__val[i]; a+=1;
      actual_outputs[b +: 1]=send_data_on_boundary_north__val[i]; b+=1;
      actual_inputs[a +: DATA_BITS]=recv_data_on_boundary_north__msg[i]; a+=DATA_BITS;
      actual_outputs[b +: DATA_BITS]=send_data_on_boundary_north__msg[i]; b+=DATA_BITS;
      actual_outputs[b]=recv_data_on_boundary_north__rdy[i]; b++;
      actual_inputs[a]=send_data_on_boundary_north__rdy[i]; a++;
    end
    for(int i=0;i<COLS;i++) begin
      actual_inputs[a +: 1]=recv_data_on_boundary_south__val[i]; a+=1;
      actual_outputs[b +: 1]=send_data_on_boundary_south__val[i]; b+=1;
      actual_inputs[a +: DATA_BITS]=recv_data_on_boundary_south__msg[i]; a+=DATA_BITS;
      actual_outputs[b +: DATA_BITS]=send_data_on_boundary_south__msg[i]; b+=DATA_BITS;
      actual_outputs[b]=recv_data_on_boundary_south__rdy[i]; b++;
      actual_inputs[a]=send_data_on_boundary_south__rdy[i]; a++;
    end
    for(int i=0;i<ROWS;i++) begin
      actual_inputs[a +: 1]=recv_data_on_boundary_west__val[i]; a+=1;
      actual_outputs[b +: 1]=send_data_on_boundary_west__val[i]; b+=1;
      actual_inputs[a +: DATA_BITS]=recv_data_on_boundary_west__msg[i]; a+=DATA_BITS;
      actual_outputs[b +: DATA_BITS]=send_data_on_boundary_west__msg[i]; b+=DATA_BITS;
      actual_outputs[b]=recv_data_on_boundary_west__rdy[i]; b++;
      actual_inputs[a]=send_data_on_boundary_west__rdy[i]; a++;
    end
    for(int i=0;i<ROWS;i++) begin
      actual_inputs[a +: 1]=recv_data_on_boundary_east__val[i]; a+=1;
      actual_outputs[b +: 1]=send_data_on_boundary_east__val[i]; b+=1;
      actual_inputs[a +: DATA_BITS]=recv_data_on_boundary_east__msg[i]; a+=DATA_BITS;
      actual_outputs[b +: DATA_BITS]=send_data_on_boundary_east__msg[i]; b+=DATA_BITS;
      actual_outputs[b]=recv_data_on_boundary_east__rdy[i]; b++;
      actual_inputs[a]=send_data_on_boundary_east__rdy[i]; a++;
    end
    if(a!=REPLAY_IN_BITS || b!=REPLAY_OUT_BITS) $fatal(1,"Replay layout width mismatch");
    if(!stall_forever) begin
      if(sample_index<0 || sample_index>=expected_samples) $fatal(1,"Replay length mismatch");
      if(actual_inputs !== pymtl_inputs[sample_index]) $fatal(1,"PYMTL_INPUT_MISMATCH scenario=%0d cycle=%0d expected=%h actual=%h",scenario_id,cycle_count,pymtl_inputs[sample_index],actual_inputs);
      if(actual_outputs !== pymtl_outputs[sample_index]) $fatal(1,"PYMTL_OUTPUT_MISMATCH scenario=%0d cycle=%0d xor=%h",scenario_id,cycle_count,actual_outputs^pymtl_outputs[sample_index]);
      pymtl_compared_cycles++;
    end
  endtask

  task automatic compare_signal(input string name,
                                input logic [HOST_BITS-1:0] actual,
                                input logic [HOST_BITS-1:0] reference);
    if (actual !== reference)
      $fatal(1, "CYCLE_MISMATCH scenario=%0d cycle=%0d signal=%s actual=%h reference=%h",
             scenario_id, cycle_count, name, actual, reference);
  endtask

  task automatic compare_outputs();
    compare_signal("recv_from_cpu_pkt.rdy", HOST_BITS'(recv_from_cpu_pkt__rdy),
                   HOST_BITS'(gold_recv_from_cpu_pkt__rdy));
    compare_signal("send_to_cpu_pkt.val", HOST_BITS'(send_to_cpu_pkt__val),
                   HOST_BITS'(gold_send_to_cpu_pkt__val));
    compare_signal("send_to_cpu_pkt.msg", send_to_cpu_pkt__msg, gold_send_to_cpu_pkt__msg);
    // Narrow static exclusion, independent of val: these three output ports
    // have no driver when the original CgraRTL is_multi_cgra=False.
    // recv_from_inter_cgra_noc.rdy, send_to_inter_cgra_noc.val/msg.
    for(int i=0;i<COLS;i++) begin
      compare_signal($sformatf("recv.north.%0d.rdy",i), HOST_BITS'(recv_data_on_boundary_north__rdy[i]), HOST_BITS'(gold_recv_data_on_boundary_north__rdy[i]));
      compare_signal($sformatf("send.north.%0d.val",i), HOST_BITS'(send_data_on_boundary_north__val[i]), HOST_BITS'(gold_send_data_on_boundary_north__val[i]));
      compare_signal($sformatf("send.north.%0d.msg",i), HOST_BITS'(send_data_on_boundary_north__msg[i]), HOST_BITS'(gold_send_data_on_boundary_north__msg[i]));
    end
    for(int i=0;i<COLS;i++) begin
      compare_signal($sformatf("recv.south.%0d.rdy",i), HOST_BITS'(recv_data_on_boundary_south__rdy[i]), HOST_BITS'(gold_recv_data_on_boundary_south__rdy[i]));
      compare_signal($sformatf("send.south.%0d.val",i), HOST_BITS'(send_data_on_boundary_south__val[i]), HOST_BITS'(gold_send_data_on_boundary_south__val[i]));
      compare_signal($sformatf("send.south.%0d.msg",i), HOST_BITS'(send_data_on_boundary_south__msg[i]), HOST_BITS'(gold_send_data_on_boundary_south__msg[i]));
    end
    for(int i=0;i<ROWS;i++) begin
      compare_signal($sformatf("recv.west.%0d.rdy",i), HOST_BITS'(recv_data_on_boundary_west__rdy[i]), HOST_BITS'(gold_recv_data_on_boundary_west__rdy[i]));
      compare_signal($sformatf("send.west.%0d.val",i), HOST_BITS'(send_data_on_boundary_west__val[i]), HOST_BITS'(gold_send_data_on_boundary_west__val[i]));
      compare_signal($sformatf("send.west.%0d.msg",i), HOST_BITS'(send_data_on_boundary_west__msg[i]), HOST_BITS'(gold_send_data_on_boundary_west__msg[i]));
    end
    for(int i=0;i<ROWS;i++) begin
      compare_signal($sformatf("recv.east.%0d.rdy",i), HOST_BITS'(recv_data_on_boundary_east__rdy[i]), HOST_BITS'(gold_recv_data_on_boundary_east__rdy[i]));
      compare_signal($sformatf("send.east.%0d.val",i), HOST_BITS'(send_data_on_boundary_east__val[i]), HOST_BITS'(gold_send_data_on_boundary_east__val[i]));
      compare_signal($sformatf("send.east.%0d.msg",i), HOST_BITS'(send_data_on_boundary_east__msg[i]), HOST_BITS'(gold_send_data_on_boundary_east__msg[i]));
    end
    all_compared_cycles++;
  endtask

  task automatic record_cycle();
    if(trace_fd) $fwrite(trace_fd,"%0d,%0d,%0d,%h,%h\n",scenario_id,cycle_count,reset,recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg);
  endtask

  task automatic check_transactions();
    tb_packet_t received, expected;
    logic [DATA_W-1:0] expected_value;
    logic [6:0] expected_address;
    if (host_was_stalled &&
        ((send_to_cpu_pkt__val !== 1'b1) || (send_to_cpu_pkt__msg !== stalled_host_msg)))
      $fatal(1, "Host response queue changed its stalled output");
    host_was_stalled = send_to_cpu_pkt__val && !send_to_cpu_pkt__rdy;
    stalled_host_msg = send_to_cpu_pkt__msg;
    if (host_was_stalled) host_stall_cycles++;
    if (send_data_on_boundary_west__val[1] && !send_data_on_boundary_west__rdy[1])
      west_stall_cycles++;

    // Check payload/predicate/bypass/delay whenever this output is valid.
    // No invalid-message masking is used in the independent cycle comparison.
    if (send_data_on_boundary_west__val[1]) begin
      if (send_data_on_boundary_west__msg[1] !== data_word(scenario_result)) begin
        if (inject_bad_expectation)
          $fatal(1, "intentional negative control: West result mismatch expected=%h actual=%h",
                 data_word(scenario_result), send_data_on_boundary_west__msg[1]);
        else
          $fatal(1, "West result mismatch scenario=%0d expected=%h actual=%h",
                 scenario_id, data_word(scenario_result), send_data_on_boundary_west__msg[1]);
      end
      if (send_data_on_boundary_west__rdy[1]) begin
        west_count++;
        if (west_count != 1) $fatal(1, "Duplicate West multicast result");
      end
    end
    for(int i=0;i<COLS;i++) if(send_data_on_boundary_north__val[i] !== 1'b0) $fatal(1,"Unexpected north boundary output %0d",i);
    for(int i=0;i<COLS;i++) if(send_data_on_boundary_south__val[i] !== 1'b0) $fatal(1,"Unexpected south boundary output %0d",i);
    for(int i=0;i<ROWS;i++) if(send_data_on_boundary_east__val[i] !== 1'b0) $fatal(1,"Unexpected east boundary output %0d",i);
    for(int i=0;i<ROWS;i++) if(i!=1) if(send_data_on_boundary_west__val[i] !== 1'b0) $fatal(1,"Unexpected west boundary output %0d",i);
    last_input_fire = recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy;
    if (last_input_fire) input_packets++;
    if (send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
      received = tb_packet_t'(send_to_cpu_pkt__msg);
      case (received.payload.cmd)
        CMD_COMPLETE: begin
          if (received.src >= NUM_TILES || completed_tiles[received.src])
            $fatal(1, "Invalid or duplicate completion src=%0d", received.src);
          expected = packet(CMD_COMPLETE, NUM_TILES, '0, 0, '0, '0, '0, received.src);
          if (received !== expected)
            $fatal(1, "Completion packet mismatch expected=%h actual=%h", expected, received);
          completed_tiles[received.src] = 1'b1;
          completion_count++;
        end
        CMD_LOAD_RESPONSE: begin
          if (!queries_started || read_response_count >= 2)
            $fatal(1, "Unexpected load response");
          expected_value = (read_response_count == 0) ? scenario_result : scenario_input;
          expected_address = (read_response_count == 0) ? 7'd16 : 7'd15;
          expected = packet(CMD_LOAD_RESPONSE, NUM_TILES, expected_value, 1, expected_address);
          if (received !== expected)
            $fatal(1, "Load response mismatch index=%0d expected=%h actual=%h",
                   read_response_count, expected, received);
          read_response_count++;
        end
        default: $fatal(1, "Unexpected host command %0d", received.payload.cmd);
      endcase
    end
  endtask

  task automatic check_mesh_link(input int index, input logic valid,
                                 input logic ready, input logic [DATA_BITS-1:0] message,
                                 input logic [DATA_W-1:0] expected_value);
    if (valid && ready) begin
      mesh_link_count[index]++;
      if (mesh_link_count[index] != 1 || message !== data_word(expected_value))
        $fatal(1, "Mesh link mismatch scenario=%0d link=%0d count=%0d expected=%h actual=%h",
               scenario_id, index, mesh_link_count[index], data_word(expected_value), message);
      $display("MESH_LINK scenario=%0d cycle=%0d link=%0d data=%h",
               scenario_id, cycle_count, index, expected_value);
    end
  endtask

  task automatic check_native_mesh_link(input int index, input logic valid,
                                 input logic ready, input logic [DATA_BITS-1:0] message,
                                 input logic [DATA_W-1:0] expected_value);
    if (valid && ready) begin
      native_mesh_link_count[index]++;
      if (native_mesh_link_count[index] != 1 || message !== data_word(expected_value))
        $fatal(1, "Mesh link mismatch scenario=%0d link=%0d count=%0d expected=%h actual=%h",
               scenario_id, index, native_mesh_link_count[index], data_word(expected_value), message);
      $display("NATIVE_MESH_LINK scenario=%0d cycle=%0d link=%0d data=%h",
               scenario_id, cycle_count, index, expected_value);
    end
  endtask

  task automatic tick();
    @(posedge clk);
    compare_outputs();
    compare_pymtl();
    record_cycle();
    last_input_fire = 0;
    if (!reset) begin
      check_transactions();
      // Full-array links are checked on the independently generated gold hierarchy.
      // Native implementation hierarchy is intentionally not part of this TB contract.
      for(int i=0;i<NUM_TILES;i++) begin
        logic [DATA_W-1:0] expected_value;
        expected_value=i==0 ? scenario_input : i==1 ? lane_add(scenario_input) :
          i==2 ? lane_add(scenario_input)*32'd3 : result_for(scenario_input);
        check_mesh_link(i,gold.tile__send_data__val[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          gold.tile__send_data__rdy[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          gold.tile__send_data__msg[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],expected_value);
`ifndef PHASE2_REFERENCE_ONLY
        check_native_mesh_link(i,dut.tile_send_val[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          dut.tile_send_rdy[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          dut.tile_send_msg[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],expected_value);
`endif
      end
      if (cycle_count >= max_cycles)
        $fatal(1, "TIMEOUT scenario=%0d cycles=%0d inputs=%0d completions=%0d reads=%0d west=%0d",
               scenario_id, cycle_count, input_packets, completion_count, read_response_count, west_count);
    end
    cycle_count++;
    @(negedge clk);
    if (!reset) begin
      send_to_cpu_pkt__rdy = (host_stall_cycles >= 6) && ((cycle_count % 7) >= 2);
      send_data_on_boundary_west__rdy[1] = (west_stall_cycles >= 8) && !stall_forever;
    end
  endtask

  task automatic send_packet(input tb_packet_t request);
    if (input_packets >= PACKET_COUNT || request !== golden_packets[input_packets])
      $fatal(1, "Configuration encoding mismatch scenario=%0d packet=%0d expected=%h actual=%h",
             scenario_id, input_packets, golden_packets[input_packets], request);
    if (packet_fd) $fwrite(packet_fd, "%0d,%0d,%h\n", scenario_id, input_packets, request);
    recv_from_cpu_pkt__val = 1;
    recv_from_cpu_pkt__msg = request;
    do tick(); while (!last_input_fire);
    recv_from_cpu_pkt__val = 0;
    recv_from_cpu_pkt__msg = '0;
  endtask

  task automatic program_tile(input int tile_id);
    int steps;
    steps = (tile_id == 0) ? 2 : 1;
    if(tile_id==0) begin
      send_packet(packet(CMD_CONST,0,15,1));
      send_packet(packet(CMD_CONST,0,16,1));
    end else begin
      int position;
      position=0;
      for(int i=1;i<NUM_TILES;i++) if(chain[i]==tile_id) position=i;
      send_packet(packet(CMD_CONST,tile_id,position==1 ? 32'h05040302 : position==2 ? 32'd3 : 32'h08070605,1));
    end
    send_packet(packet(CMD_CONFIG_COUNT_PER_ITER, tile_id, 32'(steps), 0));
    send_packet(packet(CMD_CONFIG_TOTAL_CTRL_COUNT, tile_id, 32'(steps), 0));
    for (int step_id = 0; step_id < steps; step_id++)
      send_packet(packet(CMD_CONFIG, tile_id, '0, 0, '0, workload_ctrl(tile_id, step_id), CTRL_ADDR_W'(step_id)));
  endtask

  task automatic run_scenario(input int index, input logic [DATA_W-1:0] value);
    string vectors_path;
    int vectors_fd;
    scenario_id = index;
    if (index == 0) vectors_path = {vector_dir, "/positive_packets.hex"};
    else vectors_path = {vector_dir, "/negative_after_reset_packets.hex"};
    vectors_fd = $fopen(vectors_path, "r");
    if (!vectors_fd) $fatal(1, "Cannot read canonical packets %s", vectors_path);
    $fclose(vectors_fd);
    $readmemh(vectors_path, golden_packets);
    scenario_input = value;
    scenario_result = result_for(value);
    if (inject_bad_expectation) scenario_result ^= 32'b1;
    reset = 1;
    recv_from_cpu_pkt__val = 0;
    recv_from_cpu_pkt__msg = '0;
    send_to_cpu_pkt__rdy = 0;
    send_data_on_boundary_west__rdy[1] = 0;
    cycle_count = -3;
    input_packets = 0;
    completion_count = 0;
    read_response_count = 0;
    west_count = 0;
    host_stall_cycles = 0;
    west_stall_cycles = 0;
    foreach (mesh_link_count[i]) mesh_link_count[i] = 0;
    foreach (native_mesh_link_count[i]) native_mesh_link_count[i] = 0;
    completed_tiles = '0;
    queries_started = 0;
    host_was_stalled = 0;
    repeat (3) tick();
    reset = 0;
    send_packet(packet(CMD_STORE_REQUEST, 0, value, 1, 7'd15));
    send_packet(packet(CMD_STORE_REQUEST, 0, 32'hdead_beef, 1, 7'd16));
    for (int tile_id = 0; tile_id < NUM_TILES; tile_id++) program_tile(tile_id);
    // Downstream tiles are launched first; data production starts last.
    for(int i=NUM_TILES-1;i>=0;i--) send_packet(packet(CMD_LAUNCH,chain[i]));
    while(completed_tiles != {NUM_TILES{1'b1}} || west_count != 1) tick();
    queries_started = 1;
    send_packet(packet(CMD_LOAD_REQUEST, 0, '0, 0, 7'd16));
    send_packet(packet(CMD_LOAD_REQUEST, 0, '0, 0, 7'd15));
    while (read_response_count != 2) tick();
    repeat (8) tick();  // Reject late duplicates and unexpected traffic.
    if (cycle_count != expected_cycles)
      $fatal(1, "Incomplete scenario replay: expected %0d post-reset cycles, got %0d", expected_cycles, cycle_count);
    if (input_packets != PACKET_COUNT || completion_count != NUM_TILES || west_count != 1 ||
        read_response_count != 2 || host_stall_cycles < 6 || west_stall_cycles < 8)
      $fatal(1, "Missing coverage scenario=%0d", scenario_id);
    foreach (mesh_link_count[i])
      if (mesh_link_count[i] != 1) $fatal(1, "Missing mesh link %0d", i);
`ifndef PHASE2_REFERENCE_ONLY
    foreach(native_mesh_link_count[i])
      if(native_mesh_link_count[i]!=1) $fatal(1,"Missing native mesh link %0d",i);
`endif
    $display("SCENARIO_PASS id=%0d input=%h result=%h cycles=%0d inputs=%0d completions=%0d reads=%0d west=%0d host_stalls=%0d west_stalls=%0d",
             scenario_id, scenario_input, scenario_result, cycle_count, input_packets,
             completion_count, read_response_count, west_count, host_stall_cycles, west_stall_cycles);
  endtask

  initial begin
    if ($bits(tb_data_t) != DATA_BITS || $bits(tb_ctrl_t) != CTRL_BITS ||
        $bits(tb_payload_t) != PAYLOAD_BITS || $bits(tb_packet_t) != HOST_BITS)
      $fatal(1, "Independent test packet encoding has the wrong width");
    address_lower = 0;
    address_upper = 31;
    cgra_id = 0;
    recv_from_inter_cgra_noc__msg = '0;
    recv_from_inter_cgra_noc__val = 0;
    send_to_inter_cgra_noc__rdy = 0;
    inject_bad_expectation = $test$plusargs("EXPECT_FAILURE");
    stall_forever = $test$plusargs("STALL_FOREVER");
    if ($value$plusargs("VECTORS=%s", vector_dir)) begin end
    begin
      int n,meta_fd,got;
      n=0; chain[n++]=0;
      for(int y=0;y<ROWS;y++) begin
        if(y%2==0) for(int x=1;x<COLS;x++) chain[n++]=y*COLS+x;
        else for(int x=COLS-1;x>=1;x--) chain[n++]=y*COLS+x;
      end
      for(int y=ROWS-1;y>=1;y--) chain[n++]=y*COLS;
      if(n!=NUM_TILES || ROWS%2!=0 || COLS<2) $fatal(1,"Unsupported Hamiltonian test geometry");
      meta_fd=$fopen({vector_dir,"/replay_meta.txt"},"r");
      if(!meta_fd) $fatal(1,"Cannot read replay metadata");
      got=$fscanf(meta_fd,"%d %d",expected_cycles,expected_samples); $fclose(meta_fd);
      if(got!=2 || expected_samples!=2*(expected_cycles+3) || expected_samples>8192) $fatal(1,"Invalid replay metadata");
    end
    begin
      int replay_fd;
      replay_fd = $fopen({vector_dir, "/replay_inputs.hex"}, "r");
      if (!replay_fd) $fatal(1, "Cannot read PyMTL input replay");
      $fclose(replay_fd);
      replay_fd = $fopen({vector_dir, "/replay_outputs.hex"}, "r");
      if (!replay_fd) $fatal(1, "Cannot read PyMTL output replay");
      $fclose(replay_fd);
      $readmemh({vector_dir, "/replay_inputs.hex"}, pymtl_inputs,0,expected_samples-1);
      $readmemh({vector_dir, "/replay_outputs.hex"}, pymtl_outputs,0,expected_samples-1);
    end
    if ($value$plusargs("MAX_CYCLES=%d", max_cycles) && max_cycles < 1)
      $fatal(1, "MAX_CYCLES must be positive");
    if ($value$plusargs("TRACE=%s", trace_path)) begin
      trace_fd = $fopen(trace_path, "w");
      if (!trace_fd) $fatal(1, "Cannot open trace output %s", trace_path);
    end
    if ($value$plusargs("PACKETS=%s", packet_path)) begin
      packet_fd = $fopen(packet_path, "w");
      if (!packet_fd) $fatal(1, "Cannot open packet output %s", packet_path);
    end
    for(int i=0;i<COLS;i++) begin
      recv_data_on_boundary_north__msg[i]='0;
      recv_data_on_boundary_north__val[i]=0;
      send_data_on_boundary_north__rdy[i]=1;
    end
    for(int i=0;i<COLS;i++) begin
      recv_data_on_boundary_south__msg[i]='0;
      recv_data_on_boundary_south__val[i]=0;
      send_data_on_boundary_south__rdy[i]=1;
    end
    for(int i=0;i<ROWS;i++) begin
      recv_data_on_boundary_west__msg[i]='0;
      recv_data_on_boundary_west__val[i]=0;
      send_data_on_boundary_west__rdy[i]=1;
    end
    for(int i=0;i<ROWS;i++) begin
      recv_data_on_boundary_east__msg[i]='0;
      recv_data_on_boundary_east__val[i]=0;
      send_data_on_boundary_east__rdy[i]=1;
    end
    run_scenario(0, 32'h7ffeff01);
    run_scenario(1, 32'hff01027f);
    if (all_compared_cycles != expected_samples || pymtl_compared_cycles != expected_samples)
      $fatal(1, "Incomplete replay: gold/dut cycles=%0d PyMTL cycles=%0d expected=%0d",
             all_compared_cycles, pymtl_compared_cycles,expected_samples);
    if (trace_fd) $fclose(trace_fd);
    if (packet_fd) $fclose(packet_fd);
`ifdef PHASE2_REFERENCE_ONLY
    $display("PHASE2_REFERENCE_TEST_PASS geometry=%0dx%0d cycles=%0d pymtl_cycles=%0d bits=%0d",COLS,ROWS,all_compared_cycles,pymtl_compared_cycles,REPLAY_OUT_BITS);
`else
    $display("PHASE3_PROGRAMMABLE_VECTOR_PASS geometry=%0dx%0d cycles=%0d pymtl_cycles=%0d bits=%0d",COLS,ROWS,all_compared_cycles,pymtl_compared_cycles,REPLAY_OUT_BITS);
`endif
    $finish;
  end
endmodule
