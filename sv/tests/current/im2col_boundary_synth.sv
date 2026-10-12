module im2col_boundary_synth #(parameter int DATA_W=32,SCRATCH_DEPTH=64,parameter bit LEGACY_PYTHON=0)(
 input logic clk,reset,
 input logic [158+DATA_W:0] recv_cmd_pkt__msg,
 input logic recv_cmd_pkt__val,
 output logic recv_cmd_pkt__rdy,
 output logic [158+DATA_W:0] send_pkt__msg,
 output logic send_pkt__val,
 input logic send_pkt__rdy,
 output logic done
);
 `include "im2col_boundary_fixture.svh"
 cgra_im2col_engine #(.DATA_W(DATA_W),.SCRATCH_DEPTH(SCRATCH_DEPTH),.PRELOAD_IMAGE(IMAGE),.LEGACY_PYTHON(LEGACY_PYTHON)) dut(.*);
endmodule
