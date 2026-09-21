// Fixed, single-CGRA 2x2 public top. No extra state or handshake gates.
// Phase 1 uses a frozen ac96 core; see MIGRATION_PLAN.md for parameterization.
module cgra_2x2 (
  input logic [6:0] address_lower,
  input logic [6:0] address_upper,
  input logic cgra_id,
  input logic clk,
  input logic reset,

  input logic [34:0] recv_data_on_boundary_east__msg [0:1],
  output logic recv_data_on_boundary_east__rdy [0:1],
  input logic recv_data_on_boundary_east__val [0:1],
  input logic [34:0] recv_data_on_boundary_north__msg [0:1],
  output logic recv_data_on_boundary_north__rdy [0:1],
  input logic recv_data_on_boundary_north__val [0:1],
  input logic [34:0] recv_data_on_boundary_south__msg [0:1],
  output logic recv_data_on_boundary_south__rdy [0:1],
  input logic recv_data_on_boundary_south__val [0:1],
  input logic [34:0] recv_data_on_boundary_west__msg [0:1],
  output logic recv_data_on_boundary_west__rdy [0:1],
  input logic recv_data_on_boundary_west__val [0:1],

  input logic [190:0] recv_from_cpu_pkt__msg,
  output logic recv_from_cpu_pkt__rdy,
  input logic recv_from_cpu_pkt__val,
  input logic [193:0] recv_from_inter_cgra_noc__msg,
  output logic recv_from_inter_cgra_noc__rdy,
  input logic recv_from_inter_cgra_noc__val,

  output logic [34:0] send_data_on_boundary_east__msg [0:1],
  input logic send_data_on_boundary_east__rdy [0:1],
  output logic send_data_on_boundary_east__val [0:1],
  output logic [34:0] send_data_on_boundary_north__msg [0:1],
  input logic send_data_on_boundary_north__rdy [0:1],
  output logic send_data_on_boundary_north__val [0:1],
  output logic [34:0] send_data_on_boundary_south__msg [0:1],
  input logic send_data_on_boundary_south__rdy [0:1],
  output logic send_data_on_boundary_south__val [0:1],
  output logic [34:0] send_data_on_boundary_west__msg [0:1],
  input logic send_data_on_boundary_west__rdy [0:1],
  output logic send_data_on_boundary_west__val [0:1],

  output logic [190:0] send_to_cpu_pkt__msg,
  input logic send_to_cpu_pkt__rdy,
  output logic send_to_cpu_pkt__val,
  output logic [193:0] send_to_inter_cgra_noc__msg,
  input logic send_to_inter_cgra_noc__rdy,
  output logic send_to_inter_cgra_noc__val
);
  cgra_2x2_fixed core (.*);
endmodule
