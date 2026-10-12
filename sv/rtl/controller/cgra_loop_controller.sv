// Standalone payload controller. Native counted barriers and stable dispatch;
// LEGACY_PYTHON preserves the pinned source contract (see LOOP_CONTROLLER_API.md).
module cgra_loop_controller #(
  parameter int DATA_W = 32,
  parameter int CTRL_BITS = 107,
  parameter int NUM_CCUS = 8,
  parameter int MAX_TARGETS = 4,
  parameter int DATA_ADDR_W = 3,
  parameter int CTRL_ADDR_W = 3,
  parameter bit LEGACY_DISPATCH_WRAP = 0,
  parameter bit LEGACY_PYTHON = 0,
  localparam int DATA_BITS = DATA_W + 3,
  localparam int PAYLOAD_BITS = 6 + DATA_BITS + DATA_ADDR_W + CTRL_BITS + CTRL_ADDR_W,
  localparam int CCU_ID_W = NUM_CCUS > 1 ? $clog2(NUM_CCUS) : 1,
  localparam int TARGET_IDX_W = MAX_TARGETS > 1 ? $clog2(MAX_TARGETS) : 1
) (
  input logic clk, reset,
  input logic [PAYLOAD_BITS-1:0] recv_config__msg,
  input logic recv_config__val,
  output logic recv_config__rdy,
  input logic [PAYLOAD_BITS-1:0] recv_from_tile__msg,
  input logic recv_from_tile__val,
  output logic recv_from_tile__rdy,
  input logic [PAYLOAD_BITS-1:0] recv_from_remote__msg,
  input logic recv_from_remote__val,
  output logic recv_from_remote__rdy,
  output logic [PAYLOAD_BITS-1:0] send_to_tile__msg,
  output logic send_to_tile__val,
  input logic send_to_tile__rdy,
  output logic [PAYLOAD_BITS-1:0] send_to_remote__msg,
  output logic send_to_remote__val,
  input logic send_to_remote__rdy,
  output logic all_loops_complete
);
  if (LEGACY_PYTHON) begin : legacy
    cgra_loop_controller_legacy #(.DATA_W(DATA_W),.CTRL_BITS(CTRL_BITS),.NUM_CCUS(NUM_CCUS),.MAX_TARGETS(MAX_TARGETS),
      .DATA_ADDR_W(DATA_ADDR_W),.CTRL_ADDR_W(CTRL_ADDR_W),
      .LEGACY_DISPATCH_WRAP(LEGACY_DISPATCH_WRAP)) core(.*);
  end else begin : native_mode
    cgra_loop_controller_native #(.DATA_W(DATA_W),.CTRL_BITS(CTRL_BITS),.NUM_CCUS(NUM_CCUS),.MAX_TARGETS(MAX_TARGETS),
      .DATA_ADDR_W(DATA_ADDR_W),.CTRL_ADDR_W(CTRL_ADDR_W)) core(.*);
  end
endmodule
