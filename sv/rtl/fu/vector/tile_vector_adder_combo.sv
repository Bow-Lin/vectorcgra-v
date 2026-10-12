`include "cgra_profile_defs.svh"
// Lane arithmetic with native combined-constant carry and explicit compatibility.
module tile_vector_adder_combo #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int LANES = 4, VECTOR_FACTOR_POWER = 0,
  parameter bit LEGACY_PYTHON = 0
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg  ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_const__msg  ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg  ,
  output logic [0:0] recv_from_ctrl_mem__rdy  ,
  input logic [0:0] recv_from_ctrl_mem__val  ,
  input logic [DATA_BITS-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg  ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg  ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg  ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val  
);
  `include "cgra_profile.svh"
  data_t p_from_mem_rdata__msg ;
  assign p_from_mem_rdata__msg = from_mem_rdata__msg;
  data_t p_recv_const__msg ;
  assign p_recv_const__msg = recv_const__msg;
  payload_t p_recv_from_ctrl_mem__msg ;
  assign p_recv_from_ctrl_mem__msg = recv_from_ctrl_mem__msg;
  data_t p_recv_in__msg [0:3];
  assign p_recv_in__msg = recv_in__msg;
  ctrl_t p_recv_opt__msg ;
  assign p_recv_opt__msg = recv_opt__msg;
  data_t p_send_out__msg [0:1];
  assign send_out__msg = p_send_out__msg;
  payload_t p_send_to_ctrl_mem__msg ;
  assign send_to_ctrl_mem__msg = p_send_to_ctrl_mem__msg;
  data_t p_to_mem_wdata__msg ;
  assign to_mem_wdata__msg = p_to_mem_wdata__msg;

  logic active_control;
  assign active_control=recv_opt__val && (LEGACY_PYTHON || (!reset && !clear));
  localparam int LANE_W = DATA_W / LANES;
  initial if (LANES < 1 || DATA_W % LANES != 0) $fatal(1,"VectorAdderCombo lane width must divide DATA_W");
  // VECTOR_FACTOR_POWER was unused in ac96. Do not add a replay counter.
  logic [LANES:0] carry;
  logic lane_in_rdy [0:LANES-1][0:3];
  logic lane_const_rdy [0:LANES-1], lane_ctrl_rdy [0:LANES-1];
  logic lane_out_val [0:LANES-1][0:1];
  logic [LANE_W:0] lane_output [0:LANES-1][0:1];
  assign carry[0] = 0;
  for(genvar n=0;n<LANES;n++) begin : lanes
    logic [LANE_W:0] operands [0:3], constant;
    logic operand_val [0:3];
    ctrl_t control;
    logic combine;
    // Explicit zero extension matches the source simulator's undriven zeros.
    assign operands[0] = {1'b0,p_recv_in__msg[0].payload[n*LANE_W+:LANE_W]};
    assign operands[1] = {1'b0,p_recv_in__msg[1].payload[n*LANE_W+:LANE_W]};
    assign operands[2] = '0; assign operands[3] = '0;
    assign constant = {1'b0,p_recv_const__msg.payload[n*LANE_W+:LANE_W]};
    assign operand_val[0] = recv_in__val[0];
    assign operand_val[1] = recv_in__val[1];
    assign operand_val[2] = 0; assign operand_val[3] = 0;
    assign p_send_out__msg[0].payload[n*LANE_W+:LANE_W] = lane_output[n][0][LANE_W-1:0];
    always_comb begin
      control='0;control.fu_in[0]=1;control.fu_in[1]=2;
      control.operation=7'd1;combine=0;
      case(p_recv_opt__msg.operation)
        51,71: begin control.operation=2;combine=(p_recv_opt__msg.operation==71);end
        53,73: begin control.operation=4;combine=(p_recv_opt__msg.operation==73);end
        // Source compares opcode 71 here, disabling carry for opcode 72.
        52,72: begin control.operation=25;combine=!LEGACY_PYTHON && (p_recv_opt__msg.operation==72);end
        54,74: begin control.operation=36;combine=(p_recv_opt__msg.operation==74);end
        default: begin end
      endcase
    end
    cgra_vector_adder #(`CGRA_PROFILE_BIND,.LANE_W(LANE_W)) arithmetic (
      .clk,.reset,.carry_in(carry[n]),.carry_out(carry[n+1]),.combine_adder(combine),
      .recv_in__msg(operands),.recv_in__val(operand_val),.recv_in__rdy(lane_in_rdy[n]),
      .recv_const__msg(constant),.recv_const__val,.recv_const__rdy(lane_const_rdy[n]),
      .recv_opt__msg(control),.recv_opt__val(active_control),.recv_opt__rdy(lane_ctrl_rdy[n]),
      .send_out__msg(lane_output[n]),.send_out__val(lane_out_val[n]),.send_out__rdy);
  end
  assign recv_in__rdy[0]=lane_in_rdy[0][0];
  assign recv_in__rdy[1]=lane_in_rdy[0][1];
  assign recv_const__rdy=lane_const_rdy[0];
  assign recv_opt__rdy=lane_ctrl_rdy[0];
  assign recv_in__rdy[2]=0;assign recv_in__rdy[3]=0;
  assign p_send_out__msg[0].bypass=0;assign p_send_out__msg[0].delay=0;
  assign p_send_out__msg[1].payload='0;
  assign p_send_out__msg[1].bypass=0;assign p_send_out__msg[1].delay=0;
  always_comb begin
    send_out__val[0]=lane_out_val[0][0]&recv_opt__val;
    send_out__val[1]=0;
    p_send_out__msg[0].predicate=0;
    p_send_out__msg[1].predicate=0;
    case(p_recv_opt__msg.operation)
      51,71,53,73: p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate & p_recv_in__msg[1].predicate;
      52,72,54,74: p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate;
      default: send_out__val[0]=0;
    endcase
  end

  assign to_mem_waddr__val = 0;
  assign to_mem_wdata__val = 0;
  assign p_to_mem_wdata__msg = '0;
  assign to_mem_waddr__msg = '0;
  assign to_mem_raddr__msg = '0;
  assign to_mem_raddr__val = 0;
  assign from_mem_rdata__rdy = 0;

  assign send_to_ctrl_mem__val = 0;
  assign p_send_to_ctrl_mem__msg = '0;
  assign recv_from_ctrl_mem__rdy = 0;

endmodule
