// Independent fixed-profile test encoding, reviewed against master@ac96a7.
// Arrays put element zero in the least-significant part of each field.
// These helpers deliberately do not use the DUT's pack/unpack functions.
package scalar_workload_pkg;
  typedef logic [34:0] tb_data_t;
  typedef struct packed {
    logic [6:0] operation;
    logic [3:0][2:0] fu_in;
    logic [7:0][3:0] routing_xbar_outport;
    logic [7:0][1:0] fu_xbar_outport;
    logic [2:0] vector_factor_power;
    logic is_last_ctrl;
    logic [3:0][1:0] write_reg_from;
    logic [3:0][3:0] write_reg_idx;
    logic [3:0][1:0] read_reg_towards;
    logic [3:0][3:0] read_reg_idx;
  } tb_ctrl_t;
  typedef struct packed {
    logic [5:0] cmd;
    tb_data_t data;
    logic [6:0] data_addr;
    tb_ctrl_t ctrl;
    logic [2:0] ctrl_addr;
  } tb_payload_t;
  typedef struct packed {
    logic [2:0] src;
    logic [2:0] dst;
    logic src_cgra_id, dst_cgra_id;
    logic src_cgra_x, src_cgra_y, dst_cgra_x, dst_cgra_y;
    logic [7:0] opaque;
    logic vc_id;
    tb_payload_t payload;
  } tb_packet_t;

  localparam int CMD_LAUNCH = 0;
  localparam int CMD_CONFIG = 3;
  localparam int CMD_CONFIG_TOTAL_CTRL_COUNT = 7;
  localparam int CMD_CONFIG_COUNT_PER_ITER = 8;
  localparam int CMD_LOAD_REQUEST = 10;
  localparam int CMD_LOAD_RESPONSE = 11;
  localparam int CMD_STORE_REQUEST = 12;
  localparam int CMD_CONST = 13;
  localparam int CMD_COMPLETE = 14;

  function automatic tb_data_t data_word(input logic [31:0] value,
                                         input logic predicate = 1'b1);
    return {value, predicate, 2'b00};
  endfunction

  function automatic tb_ctrl_t workload_ctrl(input int tile_id,
                                             input int step_id = 0);
    tb_ctrl_t ctrl;
    ctrl = '0;
    ctrl.fu_in[0] = 1;
    ctrl.fu_in[1] = 2;
    ctrl.fu_in[2] = 3;
    ctrl.fu_in[3] = 4;
    case (tile_id)
      0: if (step_id == 0) begin
        ctrl.operation = 28;  // LD_CONST: address 15 -> east.
        ctrl.fu_xbar_outport[3] = 1;
      end else begin
        ctrl.operation = 58;  // STR_CONST: north -> address 16.
        ctrl.routing_xbar_outport[4] = 1;
      end
      1: begin
        ctrl.operation = 25;  // ADD_CONST: west + 5 -> north.
        ctrl.routing_xbar_outport[4] = 3;
        ctrl.fu_xbar_outport[0] = 1;
      end
      2: begin
        ctrl.operation = 25;  // ADD_CONST: east + (-8) -> south + west.
        ctrl.routing_xbar_outport[4] = 4;
        ctrl.fu_xbar_outport[1] = 1;
        ctrl.fu_xbar_outport[2] = 1;
      end
      3: begin
        ctrl.operation = 29;  // MUL_CONST: south * 3 -> west.
        ctrl.routing_xbar_outport[4] = 2;
        ctrl.fu_xbar_outport[2] = 1;
      end
      default: $fatal(1, "Invalid workload tile %0d", tile_id);
    endcase
    return ctrl;
  endfunction

  function automatic tb_packet_t packet(
    input int command,
    input int destination,
    input logic [31:0] value = '0,
    input logic predicate = 1'b0,
    input logic [6:0] address = '0,
    input tb_ctrl_t control_word = '0,
    input logic [2:0] control_address = '0,
    input logic [2:0] source = '0
  );
    tb_packet_t result;
    result = '0;
    result.src = source;
    result.dst = 3'(destination);
    result.payload.cmd = 6'(command);
    result.payload.data = data_word(value, predicate);
    result.payload.data_addr = address;
    result.payload.ctrl = control_word;
    result.payload.ctrl_addr = control_address;
    return result;
  endfunction

  // Arithmetic expectation is derived from the algorithm, not a DUT trace.
  function automatic logic [31:0] result_for(input logic [31:0] value);
    return ((value + 32'd5) * 32'd3) - 32'd8;
  endfunction
endpackage
