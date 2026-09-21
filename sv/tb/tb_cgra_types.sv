`timescale 1ns/1ps
// Golden values come from the original PyMTL bitstruct packer, not SV helpers.
// See vectors/type_vectors.json. Samples check encoding, not executable ops.
module tb_cgra_types;
  import cgra_types_pkg::*;
  data_t data_word;
  ctrl_t control_word;
  payload_t payload;
  host_packet_t host_packet;

  initial begin
    if ($bits(data_t) != DATA_BITS || $bits(ctrl_t) != CTRL_BITS ||
        $bits(payload_t) != PAYLOAD_BITS ||
        $bits(host_packet_t) != HOST_PACKET_BITS ||
        $bits(noc_packet_t) != NOC_PACKET_BITS)
      $fatal(1, "TYPE_WIDTH_MISMATCH");

    data_word.payload = 32'h89abcdef;
    data_word.predicate = 1;
    data_word.bypass = 1;
    data_word.delay = 1;
    if (data_word !== 35'h44d5e6f7f)
      $fatal(1, "DATA_PACK_MISMATCH: %h", data_word);

    control_word = '0;
    control_word.operation = 85;
    for (int i = 0; i < 4; i++) control_word.fu_in[i] = 3'(i + 1);
    for (int i = 0; i < 8; i++) begin
      control_word.routing_xbar_outport[i] = 4'(i + 1);
      control_word.fu_xbar_outport[i] = 2'(i % 3 + 1);
    end
    control_word.vector_factor_power = 3;
    control_word.is_last_ctrl = 1;
    control_word.write_reg_from[0] = 1;
    control_word.write_reg_from[1] = 2;
    control_word.write_reg_from[2] = 3;
    control_word.write_reg_from[3] = 2;
    control_word.write_reg_idx[0] = 1;
    control_word.write_reg_idx[1] = 3;
    control_word.write_reg_idx[2] = 7;
    control_word.write_reg_idx[3] = 15;
    control_word.read_reg_towards[0] = 3;
    control_word.read_reg_towards[1] = 2;
    control_word.read_reg_towards[2] = 1;
    control_word.read_reg_towards[3] = 2;
    control_word.read_reg_idx[0] = 2;
    control_word.read_reg_idx[1] = 4;
    control_word.read_reg_idx[2] = 8;
    control_word.read_reg_idx[3] = 14;
    if (control_word !== 119'h558d1876543219e797b9f7319be842)
      $fatal(1, "CTRL_PACK_MISMATCH: %h", control_word);

    payload.cmd = 45;
    payload.data = data_word;
    payload.data_addr = 101;
    payload.ctrl = control_word;
    payload.ctrl_addr = 5;
    if (payload !== 170'h2d89abcdeff96ac68c3b2a190cf3cbdcfb98cdf4215)
      $fatal(1, "PAYLOAD_PACK_MISMATCH: %h", payload);

    host_packet = '0;
    host_packet.src = 3;
    host_packet.dst = 4;
    host_packet.src_cgra_id = 1;
    host_packet.dst_cgra_id = 1;
    host_packet.src_cgra_x = 1;
    host_packet.src_cgra_y = 1;
    host_packet.dst_cgra_x = 1;
    host_packet.dst_cgra_y = 1;
    host_packet.opaque = 8'ha5;
    host_packet.vc_id = 1;
    host_packet.payload = payload;
    if (host_packet !== 191'h39fd2ed89abcdeff96ac68c3b2a190cf3cbdcfb98cdf4215)
      $fatal(1, "HOST_PACK_MISMATCH: %h", host_packet);

    $display("CGRA_TYPES_PASS: widths and four independent packing samples");
    $finish;
  end
endmodule
