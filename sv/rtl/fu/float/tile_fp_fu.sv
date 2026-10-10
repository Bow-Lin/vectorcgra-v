// IEEE field widths by default; explicit compatibility for frozen Python traces.
`include "cgra_profile_defs.svh"
module tile_fp_fu #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int FP_EXP_W = 8, FP_SIG_W = 23,
  parameter bit MULTIPLY = 0, FP_LEGACY_PYTHON = 0
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_const__msg ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ,
  output logic [0:0] recv_from_ctrl_mem__rdy  ,
  input logic [0:0] recv_from_ctrl_mem__val  ,
  input logic [DATA_BITS-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val  
);


  `include "cgra_profile.svh"
  localparam logic [6:0] FADD=37, FSUB=38, FADD_CONST=39, FINC=40, FMUL=41, FMUL_CONST=42;
  localparam logic [DATA_W-1:0] FLOATING_ONE = {1'b0, FP_EXP_W'((1 << (FP_EXP_W-1))-1), {FP_SIG_W{1'b0}}};
  ctrl_t control;
  data_t inputs [0:3], constant_data, result;
  logic [1:0] in0, in1;
  logic [DATA_W-1:0] a, b, arithmetic_result;
  logic all_valid;
  assign control = recv_opt__msg;
  assign constant_data = recv_const__msg;
  for (genvar i=0; i<4; i++) assign inputs[i] = recv_in__msg[i];
  assign send_out__msg[0] = result;
  assign send_out__msg[1] = '0;
  assign send_out__val[1] = 1'b0;
  assign send_to_ctrl_mem__msg = '0;
  assign send_to_ctrl_mem__val = 1'b0;
  assign recv_from_ctrl_mem__rdy = 1'b0;
  assign to_mem_raddr__msg = '0;
  assign to_mem_raddr__val = 1'b0;
  assign to_mem_waddr__msg = '0;
  assign to_mem_waddr__val = 1'b0;
  assign to_mem_wdata__msg = '0;
  assign to_mem_wdata__val = 1'b0;
  assign from_mem_rdata__rdy = 1'b0;
  initial begin
    if (DATA_W != FP_EXP_W + FP_SIG_W + 1) $fatal(1, "FP payload width must match sign+exponent+fraction");
    if (FP_EXP_W < 2 || FP_SIG_W < 3) $fatal(1, "Unsupported HardFloat format");
  end
  // HardFloat SIG_W includes the hidden bit, while FP_SIG_W is the stored fraction.
  cgra_hardfloat_fn #(.EXP_W(FP_EXP_W + (FP_LEGACY_PYTHON ? 1 : 0)),
    .SIG_W(FP_SIG_W + (FP_LEGACY_PYTHON ? 0 : 1)), .MULTIPLY(MULTIPLY)) arithmetic (
    .a(a), .b(b), .sub_op(control.operation==FSUB), .result(arithmetic_result)
  );
  always_comb begin
    in0 = 0;
    in1 = 0;
    for (int i=0; i<4; i++) recv_in__rdy[i] = 0;
    recv_const__rdy = 0;
    recv_opt__rdy = 0;
    send_out__val[0] = 0;
    result = '0;
    a = 0;
    b = 0;
    all_valid = 0;
    if (recv_opt__val) begin
      if (control.fu_in[0] != 0) in0 = 2'(control.fu_in[0]-1);
      if (control.fu_in[1] != 0) in1 = 2'(control.fu_in[1]-1);
      if ((!MULTIPLY && (control.operation==FADD || control.operation==FSUB)) ||
          (MULTIPLY && control.operation==FMUL)) begin
        a = inputs[in0].payload;
        b = inputs[in1].payload;
        result.predicate = inputs[in0].predicate & inputs[in1].predicate;
        all_valid = recv_in__val[in0] & recv_in__val[in1];
        send_out__val[0] = all_valid;
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_in__rdy[in1] = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end else if ((!MULTIPLY && control.operation==FADD_CONST) ||
                   (MULTIPLY && control.operation==FMUL_CONST)) begin
        a = inputs[in0].payload;
        b = constant_data.payload;
        result.predicate = inputs[in0].predicate & (FP_LEGACY_PYTHON || constant_data.predicate);
        all_valid = recv_in__val[in0] & ((FP_LEGACY_PYTHON && MULTIPLY) || recv_const__val);
        send_out__val[0] = all_valid;
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_const__rdy = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end else if (!MULTIPLY && control.operation==FINC) begin
        a = inputs[in0].payload;
        b = FLOATING_ONE;
        result.predicate = inputs[in0].predicate;
        all_valid = recv_in__val[in0];
        send_out__val[0] = all_valid & (!FP_LEGACY_PYTHON || send_out__rdy[0]);
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end
      result.payload = arithmetic_result;
    end
  end
endmodule
