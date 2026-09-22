`include "cgra_profile_defs.svh"
// Synthesis-only profile for the same frozen heterogeneous architecture as the TB.
module phase4_template_synth #(`CGRA_PROFILE_PARAMETERS) (
  input logic clk, reset,
  input logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg,
  input logic recv_from_cpu_pkt__val,
  output logic recv_from_cpu_pkt__rdy,
  output logic [HOST_BITS-1:0] send_to_cpu_pkt__msg,
  output logic send_to_cpu_pkt__val,
  input logic send_to_cpu_pkt__rdy
);
  `include "heterogeneous/architecture.svh"
  cgra_multi_template #(`CGRA_PROFILE_BIND,.FU_COUNT(5),.CGRA_COLS(ARCH_SIZES),.CGRA_ROWS(ARCH_SIZES),
    .TILE_FU_COUNTS(ARCH_COUNTS),.TILE_FU_KINDS(ARCH_FUS),.CUSTOM_TOPOLOGY(4'hf),
    .LINK_COUNT(ARCH_LINKS),.LINK_ENABLED(ARCH_ENABLED),.LINK_SRC_TILE(ARCH_SRC_TILE),.LINK_SRC_PORT(ARCH_SRC_PORT),
    .LINK_DST_TILE(ARCH_DST_TILE),.LINK_DST_PORT(ARCH_DST_PORT),.READ_PORT_TILE(ARCH_READ),.WRITE_PORT_TILE(ARCH_WRITE),
    .BOUNDARY_IN_ENABLE(ARCH_BIN),.BOUNDARY_OUT_ENABLE(ARCH_BOUT)) dut(.*);
endmodule
