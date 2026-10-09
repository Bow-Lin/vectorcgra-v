`timescale 1ns/1ps
// Fixed ac96a7 2x2 scalar acceptance test. This is not a parameterization claim.
module tb_cgra_2x2_scalar;
  import scalar_workload_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  logic reset;
  logic [6:0] address_lower, address_upper;
  logic cgra_id;
  logic [190:0] recv_from_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val, recv_from_cpu_pkt__rdy;
  logic [190:0] send_to_cpu_pkt__msg;
  logic send_to_cpu_pkt__val, send_to_cpu_pkt__rdy;
  logic [193:0] recv_from_inter_cgra_noc__msg, send_to_inter_cgra_noc__msg;
  logic recv_from_inter_cgra_noc__val, recv_from_inter_cgra_noc__rdy;
  logic send_to_inter_cgra_noc__val, send_to_inter_cgra_noc__rdy;
  logic gold_recv_from_cpu_pkt__rdy;
  logic [190:0] gold_send_to_cpu_pkt__msg;
  logic gold_send_to_cpu_pkt__val;
  logic [193:0] gold_send_to_inter_cgra_noc__msg;
  logic gold_recv_from_inter_cgra_noc__rdy, gold_send_to_inter_cgra_noc__val;
  logic [34:0] recv_data_on_boundary_east__msg [0:1];
  logic recv_data_on_boundary_east__val [0:1];
  logic recv_data_on_boundary_east__rdy [0:1];
  logic [34:0] send_data_on_boundary_east__msg [0:1];
  logic send_data_on_boundary_east__val [0:1];
  logic send_data_on_boundary_east__rdy [0:1];
  logic gold_recv_data_on_boundary_east__rdy [0:1];
  logic [34:0] gold_send_data_on_boundary_east__msg [0:1];
  logic gold_send_data_on_boundary_east__val [0:1];
  logic [34:0] recv_data_on_boundary_north__msg [0:1];
  logic recv_data_on_boundary_north__val [0:1];
  logic recv_data_on_boundary_north__rdy [0:1];
  logic [34:0] send_data_on_boundary_north__msg [0:1];
  logic send_data_on_boundary_north__val [0:1];
  logic send_data_on_boundary_north__rdy [0:1];
  logic gold_recv_data_on_boundary_north__rdy [0:1];
  logic [34:0] gold_send_data_on_boundary_north__msg [0:1];
  logic gold_send_data_on_boundary_north__val [0:1];
  logic [34:0] recv_data_on_boundary_south__msg [0:1];
  logic recv_data_on_boundary_south__val [0:1];
  logic recv_data_on_boundary_south__rdy [0:1];
  logic [34:0] send_data_on_boundary_south__msg [0:1];
  logic send_data_on_boundary_south__val [0:1];
  logic send_data_on_boundary_south__rdy [0:1];
  logic gold_recv_data_on_boundary_south__rdy [0:1];
  logic [34:0] gold_send_data_on_boundary_south__msg [0:1];
  logic gold_send_data_on_boundary_south__val [0:1];
  logic [34:0] recv_data_on_boundary_west__msg [0:1];
  logic recv_data_on_boundary_west__val [0:1];
  logic recv_data_on_boundary_west__rdy [0:1];
  logic [34:0] send_data_on_boundary_west__msg [0:1];
  logic send_data_on_boundary_west__val [0:1];
  logic send_data_on_boundary_west__rdy [0:1];
  logic gold_recv_data_on_boundary_west__rdy [0:1];
  logic [34:0] gold_send_data_on_boundary_west__msg [0:1];
  logic gold_send_data_on_boundary_west__val [0:1];

  cgra_2x2 dut (.*);
  VectorCGRA2x2Reference gold (
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
  int mesh_link_count [0:3];
  int host_stall_cycles, west_stall_cycles;
  int all_compared_cycles = 0;
  int pymtl_compared_cycles = 0;
  int trace_fd = 0;
  int packet_fd = 0;
  string trace_path, packet_path, vector_dir = "sv/vectors";
  logic [190:0] golden_packets [0:25];
  logic [3:0] completed_tiles;
  logic [31:0] scenario_input, scenario_result;
  bit last_input_fire;
  bit queries_started;
  bit inject_bad_expectation, stall_forever;
  bit host_was_stalled;
  logic [190:0] stalled_host_msg;

  // Frozen PyMTL samples, including idle messages: no dynamic valid mask.
  // Bit positions are documented in vectors/replay_layout.json.
  logic [504:0] pymtl_inputs [0:133];
  logic [488:0] pymtl_outputs [0:133];

  task automatic compare_pymtl();
    logic [504:0] actual_inputs;
    logic [488:0] actual_outputs;
    int sample_index;
    sample_index = scenario_id * 67 + cycle_count + 3;
    actual_inputs = '0;
    actual_outputs = '0;
    actual_inputs[0:0] = reset;
    actual_inputs[1:1] = cgra_id;
    actual_inputs[8:2] = address_lower;
    actual_inputs[15:9] = address_upper;
    actual_inputs[16:16] = recv_from_cpu_pkt__val;
    actual_inputs[207:17] = recv_from_cpu_pkt__msg;
    actual_inputs[208:208] = send_to_cpu_pkt__rdy;
    actual_inputs[209:209] = recv_data_on_boundary_north__val[0];
    actual_inputs[244:210] = recv_data_on_boundary_north__msg[0];
    actual_inputs[245:245] = send_data_on_boundary_north__rdy[0];
    actual_inputs[246:246] = recv_data_on_boundary_north__val[1];
    actual_inputs[281:247] = recv_data_on_boundary_north__msg[1];
    actual_inputs[282:282] = send_data_on_boundary_north__rdy[1];
    actual_inputs[283:283] = recv_data_on_boundary_south__val[0];
    actual_inputs[318:284] = recv_data_on_boundary_south__msg[0];
    actual_inputs[319:319] = send_data_on_boundary_south__rdy[0];
    actual_inputs[320:320] = recv_data_on_boundary_south__val[1];
    actual_inputs[355:321] = recv_data_on_boundary_south__msg[1];
    actual_inputs[356:356] = send_data_on_boundary_south__rdy[1];
    actual_inputs[357:357] = recv_data_on_boundary_west__val[0];
    actual_inputs[392:358] = recv_data_on_boundary_west__msg[0];
    actual_inputs[393:393] = send_data_on_boundary_west__rdy[0];
    actual_inputs[394:394] = recv_data_on_boundary_west__val[1];
    actual_inputs[429:395] = recv_data_on_boundary_west__msg[1];
    actual_inputs[430:430] = send_data_on_boundary_west__rdy[1];
    actual_inputs[431:431] = recv_data_on_boundary_east__val[0];
    actual_inputs[466:432] = recv_data_on_boundary_east__msg[0];
    actual_inputs[467:467] = send_data_on_boundary_east__rdy[0];
    actual_inputs[468:468] = recv_data_on_boundary_east__val[1];
    actual_inputs[503:469] = recv_data_on_boundary_east__msg[1];
    actual_inputs[504:504] = send_data_on_boundary_east__rdy[1];
    actual_outputs[0:0] = recv_from_cpu_pkt__rdy;
    actual_outputs[1:1] = send_to_cpu_pkt__val;
    actual_outputs[192:2] = send_to_cpu_pkt__msg;
    actual_outputs[193:193] = recv_data_on_boundary_north__rdy[0];
    actual_outputs[194:194] = send_data_on_boundary_north__val[0];
    actual_outputs[229:195] = send_data_on_boundary_north__msg[0];
    actual_outputs[230:230] = recv_data_on_boundary_north__rdy[1];
    actual_outputs[231:231] = send_data_on_boundary_north__val[1];
    actual_outputs[266:232] = send_data_on_boundary_north__msg[1];
    actual_outputs[267:267] = recv_data_on_boundary_south__rdy[0];
    actual_outputs[268:268] = send_data_on_boundary_south__val[0];
    actual_outputs[303:269] = send_data_on_boundary_south__msg[0];
    actual_outputs[304:304] = recv_data_on_boundary_south__rdy[1];
    actual_outputs[305:305] = send_data_on_boundary_south__val[1];
    actual_outputs[340:306] = send_data_on_boundary_south__msg[1];
    actual_outputs[341:341] = recv_data_on_boundary_west__rdy[0];
    actual_outputs[342:342] = send_data_on_boundary_west__val[0];
    actual_outputs[377:343] = send_data_on_boundary_west__msg[0];
    actual_outputs[378:378] = recv_data_on_boundary_west__rdy[1];
    actual_outputs[379:379] = send_data_on_boundary_west__val[1];
    actual_outputs[414:380] = send_data_on_boundary_west__msg[1];
    actual_outputs[415:415] = recv_data_on_boundary_east__rdy[0];
    actual_outputs[416:416] = send_data_on_boundary_east__val[0];
    actual_outputs[451:417] = send_data_on_boundary_east__msg[0];
    actual_outputs[452:452] = recv_data_on_boundary_east__rdy[1];
    actual_outputs[453:453] = send_data_on_boundary_east__val[1];
    actual_outputs[488:454] = send_data_on_boundary_east__msg[1];
    // The timeout negative control intentionally changes the sink readiness.
    if (!stall_forever) begin
      if (sample_index < 0 || sample_index >= 134)
        $fatal(1, "Unexpected PyMTL replay length scenario=%0d cycle=%0d", scenario_id, cycle_count);
      if (actual_inputs !== pymtl_inputs[sample_index])
        $fatal(1, "PYMTL_INPUT_MISMATCH scenario=%0d cycle=%0d expected=%h actual=%h",
               scenario_id, cycle_count, pymtl_inputs[sample_index], actual_inputs);
      if (actual_outputs !== pymtl_outputs[sample_index])
        $fatal(1, "PYMTL_OUTPUT_MISMATCH scenario=%0d cycle=%0d expected=%h actual=%h xor=%h",
               scenario_id, cycle_count, pymtl_outputs[sample_index], actual_outputs,
               actual_outputs ^ pymtl_outputs[sample_index]);
      pymtl_compared_cycles++;
    end
  endtask


  task automatic compare_signal(input string name,
                                input logic [190:0] actual,
                                input logic [190:0] reference);
    if (actual !== reference)
      $fatal(1, "CYCLE_MISMATCH scenario=%0d cycle=%0d signal=%s actual=%h reference=%h",
             scenario_id, cycle_count, name, actual, reference);
  endtask

  task automatic compare_outputs();
    compare_signal("recv_from_cpu_pkt.rdy", 191'(recv_from_cpu_pkt__rdy),
                   191'(gold_recv_from_cpu_pkt__rdy));
    compare_signal("send_to_cpu_pkt.val", 191'(send_to_cpu_pkt__val),
                   191'(gold_send_to_cpu_pkt__val));
    compare_signal("send_to_cpu_pkt.msg", send_to_cpu_pkt__msg, gold_send_to_cpu_pkt__msg);
    // Narrow static exclusion, independent of val: these three output ports
    // have no driver when the original CgraRTL is_multi_cgra=False.
    // recv_from_inter_cgra_noc.rdy, send_to_inter_cgra_noc.val/msg.
    for (int i = 0; i < 2; i++) begin
      compare_signal($sformatf("recv_data_on_boundary_east[%0d].rdy", i),
                     191'(recv_data_on_boundary_east__rdy[i]), 191'(gold_recv_data_on_boundary_east__rdy[i]));
      compare_signal($sformatf("send_data_on_boundary_east[%0d].val", i),
                     191'(send_data_on_boundary_east__val[i]), 191'(gold_send_data_on_boundary_east__val[i]));
      compare_signal($sformatf("send_data_on_boundary_east[%0d].msg", i),
                     191'(send_data_on_boundary_east__msg[i]), 191'(gold_send_data_on_boundary_east__msg[i]));
      compare_signal($sformatf("recv_data_on_boundary_north[%0d].rdy", i),
                     191'(recv_data_on_boundary_north__rdy[i]), 191'(gold_recv_data_on_boundary_north__rdy[i]));
      compare_signal($sformatf("send_data_on_boundary_north[%0d].val", i),
                     191'(send_data_on_boundary_north__val[i]), 191'(gold_send_data_on_boundary_north__val[i]));
      compare_signal($sformatf("send_data_on_boundary_north[%0d].msg", i),
                     191'(send_data_on_boundary_north__msg[i]), 191'(gold_send_data_on_boundary_north__msg[i]));
      compare_signal($sformatf("recv_data_on_boundary_south[%0d].rdy", i),
                     191'(recv_data_on_boundary_south__rdy[i]), 191'(gold_recv_data_on_boundary_south__rdy[i]));
      compare_signal($sformatf("send_data_on_boundary_south[%0d].val", i),
                     191'(send_data_on_boundary_south__val[i]), 191'(gold_send_data_on_boundary_south__val[i]));
      compare_signal($sformatf("send_data_on_boundary_south[%0d].msg", i),
                     191'(send_data_on_boundary_south__msg[i]), 191'(gold_send_data_on_boundary_south__msg[i]));
      compare_signal($sformatf("recv_data_on_boundary_west[%0d].rdy", i),
                     191'(recv_data_on_boundary_west__rdy[i]), 191'(gold_recv_data_on_boundary_west__rdy[i]));
      compare_signal($sformatf("send_data_on_boundary_west[%0d].val", i),
                     191'(send_data_on_boundary_west__val[i]), 191'(gold_send_data_on_boundary_west__val[i]));
      compare_signal($sformatf("send_data_on_boundary_west[%0d].msg", i),
                     191'(send_data_on_boundary_west__msg[i]), 191'(gold_send_data_on_boundary_west__msg[i]));
    end
    all_compared_cycles++;
  endtask

  task automatic record_cycle();
    if (trace_fd) begin
      $fwrite(trace_fd, "%0d,%0d,%0d,%0d,%h,%0d,%0d,%0d,%h",
              scenario_id, cycle_count, reset, recv_from_cpu_pkt__val,
              recv_from_cpu_pkt__msg, recv_from_cpu_pkt__rdy,
              send_to_cpu_pkt__val, send_to_cpu_pkt__rdy, send_to_cpu_pkt__msg);
      for (int i = 0; i < 2; i++)
        $fwrite(trace_fd, ",%0d,%h,%0d,%0d,%0d,%h",
                recv_data_on_boundary_east__val[i], recv_data_on_boundary_east__msg[i],
                recv_data_on_boundary_east__rdy[i], send_data_on_boundary_east__val[i],
                send_data_on_boundary_east__rdy[i], send_data_on_boundary_east__msg[i]);
      for (int i = 0; i < 2; i++)
        $fwrite(trace_fd, ",%0d,%h,%0d,%0d,%0d,%h",
                recv_data_on_boundary_north__val[i], recv_data_on_boundary_north__msg[i],
                recv_data_on_boundary_north__rdy[i], send_data_on_boundary_north__val[i],
                send_data_on_boundary_north__rdy[i], send_data_on_boundary_north__msg[i]);
      for (int i = 0; i < 2; i++)
        $fwrite(trace_fd, ",%0d,%h,%0d,%0d,%0d,%h",
                recv_data_on_boundary_south__val[i], recv_data_on_boundary_south__msg[i],
                recv_data_on_boundary_south__rdy[i], send_data_on_boundary_south__val[i],
                send_data_on_boundary_south__rdy[i], send_data_on_boundary_south__msg[i]);
      for (int i = 0; i < 2; i++)
        $fwrite(trace_fd, ",%0d,%h,%0d,%0d,%0d,%h",
                recv_data_on_boundary_west__val[i], recv_data_on_boundary_west__msg[i],
                recv_data_on_boundary_west__rdy[i], send_data_on_boundary_west__val[i],
                send_data_on_boundary_west__rdy[i], send_data_on_boundary_west__msg[i]);
      $fwrite(trace_fd, "\n");
    end
  endtask

  task automatic check_transactions();
    tb_packet_t received, expected;
    logic [31:0] expected_value;
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
    for (int i = 0; i < 2; i++) begin
      if (send_data_on_boundary_east__val[i] !== 1'b0)
        $fatal(1, "Unexpected east boundary output at port %0d", i);
      if (send_data_on_boundary_north__val[i] !== 1'b0)
        $fatal(1, "Unexpected north boundary output at port %0d", i);
      if (send_data_on_boundary_south__val[i] !== 1'b0)
        $fatal(1, "Unexpected south boundary output at port %0d", i);
    end
    if (send_data_on_boundary_west__val[0] !== 1'b0)
      $fatal(1, "Unexpected west boundary output at port 0");
    last_input_fire = recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy;
    if (last_input_fire) input_packets++;
    if (send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
      received = tb_packet_t'(send_to_cpu_pkt__msg);
      case (received.payload.cmd)
        CMD_COMPLETE: begin
          if (received.src >= 4 || completed_tiles[received.src])
            $fatal(1, "Invalid or duplicate completion src=%0d", received.src);
          expected = packet(CMD_COMPLETE, 4, '0, 0, '0, '0, '0, received.src);
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
          expected = packet(CMD_LOAD_RESPONSE, 4, expected_value, 1, expected_address);
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
                                 input logic ready, input logic [34:0] message,
                                 input logic [31:0] expected_value);
    if (valid && ready) begin
      mesh_link_count[index]++;
      if (mesh_link_count[index] != 1 || message !== data_word(expected_value))
        $fatal(1, "Mesh link mismatch scenario=%0d link=%0d count=%0d expected=%h actual=%h",
               scenario_id, index, mesh_link_count[index], data_word(expected_value), message);
      $display("MESH_LINK scenario=%0d cycle=%0d link=%0d data=%h",
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
      // Fixed-profile coverage of all four directional internal links.
      check_mesh_link(0, dut.core.tile_send_val[0][3],
                      dut.core.tile_send_rdy[0][3],
                      dut.core.tile_send_msg[0][3], scenario_input);
      check_mesh_link(1, dut.core.tile_send_val[1][0],
                      dut.core.tile_send_rdy[1][0],
                      dut.core.tile_send_msg[1][0], scenario_input + 32'd5);
      check_mesh_link(2, dut.core.tile_send_val[3][2],
                      dut.core.tile_send_rdy[3][2],
                      dut.core.tile_send_msg[3][2], (scenario_input + 32'd5) * 32'd3);
      check_mesh_link(3, dut.core.tile_send_val[2][1],
                      dut.core.tile_send_rdy[2][1],
                      dut.core.tile_send_msg[2][1], result_for(scenario_input));
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
    if (input_packets >= 26 || request !== golden_packets[input_packets])
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
    case (tile_id)
      0: begin
        send_packet(packet(CMD_CONST, 0, 15, 1));
        send_packet(packet(CMD_CONST, 0, 16, 1));
      end
      1: send_packet(packet(CMD_CONST, 1, 5, 1));
      2: send_packet(packet(CMD_CONST, 2, 32'hffff_fff8, 1));
      3: send_packet(packet(CMD_CONST, 3, 3, 1));
    endcase
    send_packet(packet(CMD_CONFIG_COUNT_PER_ITER, tile_id, 32'(steps), 0));
    send_packet(packet(CMD_CONFIG_TOTAL_CTRL_COUNT, tile_id, 32'(steps), 0));
    for (int step_id = 0; step_id < steps; step_id++)
      send_packet(packet(CMD_CONFIG, tile_id, '0, 0, '0, workload_ctrl(tile_id, step_id), 3'(step_id)));
  endtask

  task automatic run_scenario(input int index, input logic [31:0] value);
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
    completed_tiles = '0;
    queries_started = 0;
    host_was_stalled = 0;
    repeat (3) tick();
    reset = 0;
    send_packet(packet(CMD_STORE_REQUEST, 0, value, 1, 7'd15));
    send_packet(packet(CMD_STORE_REQUEST, 0, 32'hdead_beef, 1, 7'd16));
    for (int tile_id = 0; tile_id < 4; tile_id++) program_tile(tile_id);
    // Downstream tiles are launched first; data production starts last.
    send_packet(packet(CMD_LAUNCH, 2));
    send_packet(packet(CMD_LAUNCH, 3));
    send_packet(packet(CMD_LAUNCH, 1));
    send_packet(packet(CMD_LAUNCH, 0));
    while (completed_tiles != 4'b1111 || west_count != 1) tick();
    queries_started = 1;
    send_packet(packet(CMD_LOAD_REQUEST, 0, '0, 0, 7'd16));
    send_packet(packet(CMD_LOAD_REQUEST, 0, '0, 0, 7'd15));
    while (read_response_count != 2) tick();
    repeat (8) tick();  // Reject late duplicates and unexpected traffic.
    if (cycle_count != 64)
      $fatal(1, "Incomplete scenario replay: expected 64 post-reset cycles, got %0d", cycle_count);
    if (input_packets != 26 || completion_count != 4 || west_count != 1 ||
        read_response_count != 2 || host_stall_cycles < 6 || west_stall_cycles < 8)
      $fatal(1, "Missing coverage scenario=%0d", scenario_id);
    foreach (mesh_link_count[i])
      if (mesh_link_count[i] != 1) $fatal(1, "Missing mesh link %0d", i);
    $display("SCENARIO_PASS id=%0d input=%h result=%h cycles=%0d inputs=%0d completions=%0d reads=%0d west=%0d host_stalls=%0d west_stalls=%0d",
             scenario_id, scenario_input, scenario_result, cycle_count, input_packets,
             completion_count, read_response_count, west_count, host_stall_cycles, west_stall_cycles);
  endtask

  initial begin
    if ($bits(tb_data_t) != 35 || $bits(tb_ctrl_t) != 119 ||
        $bits(tb_payload_t) != 170 || $bits(tb_packet_t) != 191)
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
      int replay_fd;
      replay_fd = $fopen({vector_dir, "/replay_inputs.hex"}, "r");
      if (!replay_fd) $fatal(1, "Cannot read PyMTL input replay");
      $fclose(replay_fd);
      replay_fd = $fopen({vector_dir, "/replay_outputs.hex"}, "r");
      if (!replay_fd) $fatal(1, "Cannot read PyMTL output replay");
      $fclose(replay_fd);
      $readmemh({vector_dir, "/replay_inputs.hex"}, pymtl_inputs);
      $readmemh({vector_dir, "/replay_outputs.hex"}, pymtl_outputs);
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
    for (int i = 0; i < 2; i++) begin
      recv_data_on_boundary_east__msg[i] = '0;
      recv_data_on_boundary_east__val[i] = 0;
      send_data_on_boundary_east__rdy[i] = 1;
      recv_data_on_boundary_north__msg[i] = '0;
      recv_data_on_boundary_north__val[i] = 0;
      send_data_on_boundary_north__rdy[i] = 1;
      recv_data_on_boundary_south__msg[i] = '0;
      recv_data_on_boundary_south__val[i] = 0;
      send_data_on_boundary_south__rdy[i] = 1;
      recv_data_on_boundary_west__msg[i] = '0;
      recv_data_on_boundary_west__val[i] = 0;
      send_data_on_boundary_west__rdy[i] = 1;
    end
    run_scenario(0, 32'd7);
    run_scenario(1, 32'hffff_fffa);
    if (all_compared_cycles != 134 || pymtl_compared_cycles != 134)
      $fatal(1, "Incomplete replay: gold/dut cycles=%0d PyMTL cycles=%0d expected=134",
             all_compared_cycles, pymtl_compared_cycles);
    if (trace_fd) $fclose(trace_fd);
    if (packet_fd) $fclose(packet_fd);
    $display("CGRA_2X2_PASS scenarios=2 compared_cycles=%0d pymtl_cycles=%0d compared_bits_per_cycle=489",
             all_compared_cycles, pymtl_compared_cycles);
    $finish;
  end
endmodule
