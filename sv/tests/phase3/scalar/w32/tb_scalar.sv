`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
// Frozen-input three-way test: native HDL, independently translated ac96 HDL,
// and original ac96 Python raw-cycle oracle. Daily execution uses only SV/tools.
module tb_scalar;
  localparam int DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16, GLOBAL_ADDR_W=7;
  localparam int CTRL_ADDR_W=$clog2(CTRL_DEPTH), REG_ADDR_W=$clog2(REG_DEPTH), ROUTING_OUTPUTS=8, ROUTING_SEL_W=4;
  localparam int DATA_BITS=DATA_W+3, CTRL_BITS=87+8*REG_ADDR_W, PAYLOAD_BITS=6+DATA_BITS+7+CTRL_BITS+CTRL_ADDR_W;
  localparam int TILE_ID_W=3, MEM_PORT_W=2, BANK_PORT_W=2;
  localparam int CGRA_ID_W=1, CGRA_X_W=1, CGRA_Y_W=1, XBAR_MEM_PORT_W=2, XBAR_WR_MEM_PORT_W=2;
  `include "cgra_profile.svh"
  localparam int CYCLES=2881, INPUT_BITS=518, OUTPUT_BITS=303;
  logic clk=0; integer cycle; integer math_checks=0; integer pipeline_checks=0;
  logic [0:0] clear;
  logic [0:0] reset;
  logic [2:0] ctrl_addr_inport;
  logic [34:0] from_mem_rdata__msg;
  logic [0:0] from_mem_rdata__val;
  logic [34:0] recv_const__msg;
  logic [0:0] recv_const__val;
  logic [169:0] recv_from_ctrl_mem__msg;
  logic [0:0] recv_from_ctrl_mem__val;
  logic [34:0] recv_in__msg [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [118:0] recv_opt__msg;
  logic [0:0] recv_opt__val;
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] send_to_ctrl_mem__rdy;
  logic [0:0] to_mem_raddr__rdy;
  logic [0:0] to_mem_waddr__rdy;
  logic [0:0] to_mem_wdata__rdy;
  ctrl_t ctrl_view; assign ctrl_view=recv_opt__msg;
  data_t operand[0:3]; assign operand=recv_in__msg;
  data_t constant_view; assign constant_view=recv_const__msg;
  logic [DATA_W-1:0] a,b,c; integer ia,ib,ic;
  always_comb begin
    ia=(ctrl_view.fu_in[0]==0)?0:((int'(ctrl_view.fu_in[0])-1)&3);
    ib=(ctrl_view.fu_in[1]==0)?0:((int'(ctrl_view.fu_in[1])-1)&3);
    ic=(ctrl_view.fu_in[2]==0)?0:((int'(ctrl_view.fu_in[2])-1)&3);
    a=operand[ia].payload; b=operand[ib].payload; c=constant_view.payload;
  end
  logic [INPUT_BITS-1:0] inputs[0:CYCLES-1];
  logic [0:0] Const_dut_from_mem_rdata__rdy;
  logic [0:0] Const_dut_recv_const__rdy;
  logic [0:0] Const_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Const_dut_recv_in__rdy [0:3];
  logic [0:0] Const_dut_recv_opt__rdy;
  logic [34:0] Const_dut_send_out__msg [0:1];
  logic [0:0] Const_dut_send_out__val [0:1];
  logic [169:0] Const_dut_send_to_ctrl_mem__msg;
  logic [0:0] Const_dut_send_to_ctrl_mem__val;
  logic [6:0] Const_dut_to_mem_raddr__msg;
  logic [0:0] Const_dut_to_mem_raddr__val;
  logic [6:0] Const_dut_to_mem_waddr__msg;
  logic [0:0] Const_dut_to_mem_waddr__val;
  logic [34:0] Const_dut_to_mem_wdata__msg;
  logic [0:0] Const_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Const_dut_bits;
  assign Const_dut_bits={Const_dut_from_mem_rdata__rdy,Const_dut_recv_const__rdy,Const_dut_recv_from_ctrl_mem__rdy,Const_dut_recv_in__rdy[0],Const_dut_recv_in__rdy[1],Const_dut_recv_in__rdy[2],Const_dut_recv_in__rdy[3],Const_dut_recv_opt__rdy,Const_dut_send_out__msg[0],Const_dut_send_out__msg[1],Const_dut_send_out__val[0],Const_dut_send_out__val[1],Const_dut_send_to_ctrl_mem__msg,Const_dut_send_to_ctrl_mem__val,Const_dut_to_mem_raddr__msg,Const_dut_to_mem_raddr__val,Const_dut_to_mem_waddr__msg,Const_dut_to_mem_waddr__val,Const_dut_to_mem_wdata__msg,Const_dut_to_mem_wdata__val};
  scalar_const #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Const_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Const_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Const_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Const_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Const_dut_recv_in__rdy),
    .recv_opt__rdy(Const_dut_recv_opt__rdy),
    .send_out__msg(Const_dut_send_out__msg),
    .send_out__val(Const_dut_send_out__val),
    .send_to_ctrl_mem__msg(Const_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Const_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Const_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Const_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Const_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Const_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Const_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Const_dut_to_mem_wdata__val)
  );
  logic [0:0] Const_gold_from_mem_rdata__rdy;
  logic [0:0] Const_gold_recv_const__rdy;
  logic [0:0] Const_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Const_gold_recv_in__rdy [0:3];
  logic [0:0] Const_gold_recv_opt__rdy;
  logic [34:0] Const_gold_send_out__msg [0:1];
  logic [0:0] Const_gold_send_out__val [0:1];
  logic [169:0] Const_gold_send_to_ctrl_mem__msg;
  logic [0:0] Const_gold_send_to_ctrl_mem__val;
  logic [6:0] Const_gold_to_mem_raddr__msg;
  logic [0:0] Const_gold_to_mem_raddr__val;
  logic [6:0] Const_gold_to_mem_waddr__msg;
  logic [0:0] Const_gold_to_mem_waddr__val;
  logic [34:0] Const_gold_to_mem_wdata__msg;
  logic [0:0] Const_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Const_gold_bits;
  assign Const_gold_bits={Const_gold_from_mem_rdata__rdy,Const_gold_recv_const__rdy,Const_gold_recv_from_ctrl_mem__rdy,Const_gold_recv_in__rdy[0],Const_gold_recv_in__rdy[1],Const_gold_recv_in__rdy[2],Const_gold_recv_in__rdy[3],Const_gold_recv_opt__rdy,Const_gold_send_out__msg[0],Const_gold_send_out__msg[1],Const_gold_send_out__val[0],Const_gold_send_out__val[1],Const_gold_send_to_ctrl_mem__msg,Const_gold_send_to_ctrl_mem__val,Const_gold_to_mem_raddr__msg,Const_gold_to_mem_raddr__val,Const_gold_to_mem_waddr__msg,Const_gold_to_mem_waddr__val,Const_gold_to_mem_wdata__msg,Const_gold_to_mem_wdata__val};
  ScalarRefConstw32 Const_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Const_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Const_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Const_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Const_gold_recv_in__rdy),
    .recv_opt__rdy(Const_gold_recv_opt__rdy),
    .send_out__msg(Const_gold_send_out__msg),
    .send_out__val(Const_gold_send_out__val),
    .send_to_ctrl_mem__msg(Const_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Const_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Const_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Const_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Const_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Const_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Const_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Const_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Const_python[0:CYCLES-1];
  logic [0:0] Comp_dut_from_mem_rdata__rdy;
  logic [0:0] Comp_dut_recv_const__rdy;
  logic [0:0] Comp_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Comp_dut_recv_in__rdy [0:3];
  logic [0:0] Comp_dut_recv_opt__rdy;
  logic [34:0] Comp_dut_send_out__msg [0:1];
  logic [0:0] Comp_dut_send_out__val [0:1];
  logic [169:0] Comp_dut_send_to_ctrl_mem__msg;
  logic [0:0] Comp_dut_send_to_ctrl_mem__val;
  logic [6:0] Comp_dut_to_mem_raddr__msg;
  logic [0:0] Comp_dut_to_mem_raddr__val;
  logic [6:0] Comp_dut_to_mem_waddr__msg;
  logic [0:0] Comp_dut_to_mem_waddr__val;
  logic [34:0] Comp_dut_to_mem_wdata__msg;
  logic [0:0] Comp_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Comp_dut_bits;
  assign Comp_dut_bits={Comp_dut_from_mem_rdata__rdy,Comp_dut_recv_const__rdy,Comp_dut_recv_from_ctrl_mem__rdy,Comp_dut_recv_in__rdy[0],Comp_dut_recv_in__rdy[1],Comp_dut_recv_in__rdy[2],Comp_dut_recv_in__rdy[3],Comp_dut_recv_opt__rdy,Comp_dut_send_out__msg[0],Comp_dut_send_out__msg[1],Comp_dut_send_out__val[0],Comp_dut_send_out__val[1],Comp_dut_send_to_ctrl_mem__msg,Comp_dut_send_to_ctrl_mem__val,Comp_dut_to_mem_raddr__msg,Comp_dut_to_mem_raddr__val,Comp_dut_to_mem_waddr__msg,Comp_dut_to_mem_waddr__val,Comp_dut_to_mem_wdata__msg,Comp_dut_to_mem_wdata__val};
  scalar_comp #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Comp_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Comp_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Comp_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Comp_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Comp_dut_recv_in__rdy),
    .recv_opt__rdy(Comp_dut_recv_opt__rdy),
    .send_out__msg(Comp_dut_send_out__msg),
    .send_out__val(Comp_dut_send_out__val),
    .send_to_ctrl_mem__msg(Comp_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Comp_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Comp_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Comp_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Comp_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Comp_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Comp_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Comp_dut_to_mem_wdata__val)
  );
  logic [0:0] Comp_gold_from_mem_rdata__rdy;
  logic [0:0] Comp_gold_recv_const__rdy;
  logic [0:0] Comp_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Comp_gold_recv_in__rdy [0:3];
  logic [0:0] Comp_gold_recv_opt__rdy;
  logic [34:0] Comp_gold_send_out__msg [0:1];
  logic [0:0] Comp_gold_send_out__val [0:1];
  logic [169:0] Comp_gold_send_to_ctrl_mem__msg;
  logic [0:0] Comp_gold_send_to_ctrl_mem__val;
  logic [6:0] Comp_gold_to_mem_raddr__msg;
  logic [0:0] Comp_gold_to_mem_raddr__val;
  logic [6:0] Comp_gold_to_mem_waddr__msg;
  logic [0:0] Comp_gold_to_mem_waddr__val;
  logic [34:0] Comp_gold_to_mem_wdata__msg;
  logic [0:0] Comp_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Comp_gold_bits;
  assign Comp_gold_bits={Comp_gold_from_mem_rdata__rdy,Comp_gold_recv_const__rdy,Comp_gold_recv_from_ctrl_mem__rdy,Comp_gold_recv_in__rdy[0],Comp_gold_recv_in__rdy[1],Comp_gold_recv_in__rdy[2],Comp_gold_recv_in__rdy[3],Comp_gold_recv_opt__rdy,Comp_gold_send_out__msg[0],Comp_gold_send_out__msg[1],Comp_gold_send_out__val[0],Comp_gold_send_out__val[1],Comp_gold_send_to_ctrl_mem__msg,Comp_gold_send_to_ctrl_mem__val,Comp_gold_to_mem_raddr__msg,Comp_gold_to_mem_raddr__val,Comp_gold_to_mem_waddr__msg,Comp_gold_to_mem_waddr__val,Comp_gold_to_mem_wdata__msg,Comp_gold_to_mem_wdata__val};
  ScalarRefCompw32 Comp_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Comp_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Comp_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Comp_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Comp_gold_recv_in__rdy),
    .recv_opt__rdy(Comp_gold_recv_opt__rdy),
    .send_out__msg(Comp_gold_send_out__msg),
    .send_out__val(Comp_gold_send_out__val),
    .send_to_ctrl_mem__msg(Comp_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Comp_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Comp_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Comp_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Comp_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Comp_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Comp_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Comp_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Comp_python[0:CYCLES-1];
  logic [0:0] Logic_dut_from_mem_rdata__rdy;
  logic [0:0] Logic_dut_recv_const__rdy;
  logic [0:0] Logic_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Logic_dut_recv_in__rdy [0:3];
  logic [0:0] Logic_dut_recv_opt__rdy;
  logic [34:0] Logic_dut_send_out__msg [0:1];
  logic [0:0] Logic_dut_send_out__val [0:1];
  logic [169:0] Logic_dut_send_to_ctrl_mem__msg;
  logic [0:0] Logic_dut_send_to_ctrl_mem__val;
  logic [6:0] Logic_dut_to_mem_raddr__msg;
  logic [0:0] Logic_dut_to_mem_raddr__val;
  logic [6:0] Logic_dut_to_mem_waddr__msg;
  logic [0:0] Logic_dut_to_mem_waddr__val;
  logic [34:0] Logic_dut_to_mem_wdata__msg;
  logic [0:0] Logic_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Logic_dut_bits;
  assign Logic_dut_bits={Logic_dut_from_mem_rdata__rdy,Logic_dut_recv_const__rdy,Logic_dut_recv_from_ctrl_mem__rdy,Logic_dut_recv_in__rdy[0],Logic_dut_recv_in__rdy[1],Logic_dut_recv_in__rdy[2],Logic_dut_recv_in__rdy[3],Logic_dut_recv_opt__rdy,Logic_dut_send_out__msg[0],Logic_dut_send_out__msg[1],Logic_dut_send_out__val[0],Logic_dut_send_out__val[1],Logic_dut_send_to_ctrl_mem__msg,Logic_dut_send_to_ctrl_mem__val,Logic_dut_to_mem_raddr__msg,Logic_dut_to_mem_raddr__val,Logic_dut_to_mem_waddr__msg,Logic_dut_to_mem_waddr__val,Logic_dut_to_mem_wdata__msg,Logic_dut_to_mem_wdata__val};
  scalar_logic #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Logic_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Logic_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Logic_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Logic_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Logic_dut_recv_in__rdy),
    .recv_opt__rdy(Logic_dut_recv_opt__rdy),
    .send_out__msg(Logic_dut_send_out__msg),
    .send_out__val(Logic_dut_send_out__val),
    .send_to_ctrl_mem__msg(Logic_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Logic_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Logic_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Logic_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Logic_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Logic_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Logic_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Logic_dut_to_mem_wdata__val)
  );
  logic [0:0] Logic_gold_from_mem_rdata__rdy;
  logic [0:0] Logic_gold_recv_const__rdy;
  logic [0:0] Logic_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Logic_gold_recv_in__rdy [0:3];
  logic [0:0] Logic_gold_recv_opt__rdy;
  logic [34:0] Logic_gold_send_out__msg [0:1];
  logic [0:0] Logic_gold_send_out__val [0:1];
  logic [169:0] Logic_gold_send_to_ctrl_mem__msg;
  logic [0:0] Logic_gold_send_to_ctrl_mem__val;
  logic [6:0] Logic_gold_to_mem_raddr__msg;
  logic [0:0] Logic_gold_to_mem_raddr__val;
  logic [6:0] Logic_gold_to_mem_waddr__msg;
  logic [0:0] Logic_gold_to_mem_waddr__val;
  logic [34:0] Logic_gold_to_mem_wdata__msg;
  logic [0:0] Logic_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Logic_gold_bits;
  assign Logic_gold_bits={Logic_gold_from_mem_rdata__rdy,Logic_gold_recv_const__rdy,Logic_gold_recv_from_ctrl_mem__rdy,Logic_gold_recv_in__rdy[0],Logic_gold_recv_in__rdy[1],Logic_gold_recv_in__rdy[2],Logic_gold_recv_in__rdy[3],Logic_gold_recv_opt__rdy,Logic_gold_send_out__msg[0],Logic_gold_send_out__msg[1],Logic_gold_send_out__val[0],Logic_gold_send_out__val[1],Logic_gold_send_to_ctrl_mem__msg,Logic_gold_send_to_ctrl_mem__val,Logic_gold_to_mem_raddr__msg,Logic_gold_to_mem_raddr__val,Logic_gold_to_mem_waddr__msg,Logic_gold_to_mem_waddr__val,Logic_gold_to_mem_wdata__msg,Logic_gold_to_mem_wdata__val};
  ScalarRefLogicw32 Logic_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Logic_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Logic_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Logic_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Logic_gold_recv_in__rdy),
    .recv_opt__rdy(Logic_gold_recv_opt__rdy),
    .send_out__msg(Logic_gold_send_out__msg),
    .send_out__val(Logic_gold_send_out__val),
    .send_to_ctrl_mem__msg(Logic_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Logic_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Logic_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Logic_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Logic_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Logic_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Logic_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Logic_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Logic_python[0:CYCLES-1];
  logic [0:0] Shifter_dut_from_mem_rdata__rdy;
  logic [0:0] Shifter_dut_recv_const__rdy;
  logic [0:0] Shifter_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Shifter_dut_recv_in__rdy [0:3];
  logic [0:0] Shifter_dut_recv_opt__rdy;
  logic [34:0] Shifter_dut_send_out__msg [0:1];
  logic [0:0] Shifter_dut_send_out__val [0:1];
  logic [169:0] Shifter_dut_send_to_ctrl_mem__msg;
  logic [0:0] Shifter_dut_send_to_ctrl_mem__val;
  logic [6:0] Shifter_dut_to_mem_raddr__msg;
  logic [0:0] Shifter_dut_to_mem_raddr__val;
  logic [6:0] Shifter_dut_to_mem_waddr__msg;
  logic [0:0] Shifter_dut_to_mem_waddr__val;
  logic [34:0] Shifter_dut_to_mem_wdata__msg;
  logic [0:0] Shifter_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Shifter_dut_bits;
  assign Shifter_dut_bits={Shifter_dut_from_mem_rdata__rdy,Shifter_dut_recv_const__rdy,Shifter_dut_recv_from_ctrl_mem__rdy,Shifter_dut_recv_in__rdy[0],Shifter_dut_recv_in__rdy[1],Shifter_dut_recv_in__rdy[2],Shifter_dut_recv_in__rdy[3],Shifter_dut_recv_opt__rdy,Shifter_dut_send_out__msg[0],Shifter_dut_send_out__msg[1],Shifter_dut_send_out__val[0],Shifter_dut_send_out__val[1],Shifter_dut_send_to_ctrl_mem__msg,Shifter_dut_send_to_ctrl_mem__val,Shifter_dut_to_mem_raddr__msg,Shifter_dut_to_mem_raddr__val,Shifter_dut_to_mem_waddr__msg,Shifter_dut_to_mem_waddr__val,Shifter_dut_to_mem_wdata__msg,Shifter_dut_to_mem_wdata__val};
  scalar_shifter #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Shifter_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Shifter_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Shifter_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Shifter_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Shifter_dut_recv_in__rdy),
    .recv_opt__rdy(Shifter_dut_recv_opt__rdy),
    .send_out__msg(Shifter_dut_send_out__msg),
    .send_out__val(Shifter_dut_send_out__val),
    .send_to_ctrl_mem__msg(Shifter_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Shifter_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Shifter_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Shifter_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Shifter_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Shifter_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Shifter_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Shifter_dut_to_mem_wdata__val)
  );
  logic [0:0] Shifter_gold_from_mem_rdata__rdy;
  logic [0:0] Shifter_gold_recv_const__rdy;
  logic [0:0] Shifter_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Shifter_gold_recv_in__rdy [0:3];
  logic [0:0] Shifter_gold_recv_opt__rdy;
  logic [34:0] Shifter_gold_send_out__msg [0:1];
  logic [0:0] Shifter_gold_send_out__val [0:1];
  logic [169:0] Shifter_gold_send_to_ctrl_mem__msg;
  logic [0:0] Shifter_gold_send_to_ctrl_mem__val;
  logic [6:0] Shifter_gold_to_mem_raddr__msg;
  logic [0:0] Shifter_gold_to_mem_raddr__val;
  logic [6:0] Shifter_gold_to_mem_waddr__msg;
  logic [0:0] Shifter_gold_to_mem_waddr__val;
  logic [34:0] Shifter_gold_to_mem_wdata__msg;
  logic [0:0] Shifter_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Shifter_gold_bits;
  assign Shifter_gold_bits={Shifter_gold_from_mem_rdata__rdy,Shifter_gold_recv_const__rdy,Shifter_gold_recv_from_ctrl_mem__rdy,Shifter_gold_recv_in__rdy[0],Shifter_gold_recv_in__rdy[1],Shifter_gold_recv_in__rdy[2],Shifter_gold_recv_in__rdy[3],Shifter_gold_recv_opt__rdy,Shifter_gold_send_out__msg[0],Shifter_gold_send_out__msg[1],Shifter_gold_send_out__val[0],Shifter_gold_send_out__val[1],Shifter_gold_send_to_ctrl_mem__msg,Shifter_gold_send_to_ctrl_mem__val,Shifter_gold_to_mem_raddr__msg,Shifter_gold_to_mem_raddr__val,Shifter_gold_to_mem_waddr__msg,Shifter_gold_to_mem_waddr__val,Shifter_gold_to_mem_wdata__msg,Shifter_gold_to_mem_wdata__val};
  ScalarRefShifterw32 Shifter_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Shifter_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Shifter_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Shifter_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Shifter_gold_recv_in__rdy),
    .recv_opt__rdy(Shifter_gold_recv_opt__rdy),
    .send_out__msg(Shifter_gold_send_out__msg),
    .send_out__val(Shifter_gold_send_out__val),
    .send_to_ctrl_mem__msg(Shifter_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Shifter_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Shifter_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Shifter_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Shifter_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Shifter_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Shifter_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Shifter_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Shifter_python[0:CYCLES-1];
  logic [0:0] Sel_dut_from_mem_rdata__rdy;
  logic [0:0] Sel_dut_recv_const__rdy;
  logic [0:0] Sel_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Sel_dut_recv_in__rdy [0:3];
  logic [0:0] Sel_dut_recv_opt__rdy;
  logic [34:0] Sel_dut_send_out__msg [0:1];
  logic [0:0] Sel_dut_send_out__val [0:1];
  logic [169:0] Sel_dut_send_to_ctrl_mem__msg;
  logic [0:0] Sel_dut_send_to_ctrl_mem__val;
  logic [6:0] Sel_dut_to_mem_raddr__msg;
  logic [0:0] Sel_dut_to_mem_raddr__val;
  logic [6:0] Sel_dut_to_mem_waddr__msg;
  logic [0:0] Sel_dut_to_mem_waddr__val;
  logic [34:0] Sel_dut_to_mem_wdata__msg;
  logic [0:0] Sel_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Sel_dut_bits;
  assign Sel_dut_bits={Sel_dut_from_mem_rdata__rdy,Sel_dut_recv_const__rdy,Sel_dut_recv_from_ctrl_mem__rdy,Sel_dut_recv_in__rdy[0],Sel_dut_recv_in__rdy[1],Sel_dut_recv_in__rdy[2],Sel_dut_recv_in__rdy[3],Sel_dut_recv_opt__rdy,Sel_dut_send_out__msg[0],Sel_dut_send_out__msg[1],Sel_dut_send_out__val[0],Sel_dut_send_out__val[1],Sel_dut_send_to_ctrl_mem__msg,Sel_dut_send_to_ctrl_mem__val,Sel_dut_to_mem_raddr__msg,Sel_dut_to_mem_raddr__val,Sel_dut_to_mem_waddr__msg,Sel_dut_to_mem_waddr__val,Sel_dut_to_mem_wdata__msg,Sel_dut_to_mem_wdata__val};
  scalar_sel #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Sel_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Sel_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Sel_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Sel_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Sel_dut_recv_in__rdy),
    .recv_opt__rdy(Sel_dut_recv_opt__rdy),
    .send_out__msg(Sel_dut_send_out__msg),
    .send_out__val(Sel_dut_send_out__val),
    .send_to_ctrl_mem__msg(Sel_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Sel_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Sel_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Sel_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Sel_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Sel_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Sel_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Sel_dut_to_mem_wdata__val)
  );
  logic [0:0] Sel_gold_from_mem_rdata__rdy;
  logic [0:0] Sel_gold_recv_const__rdy;
  logic [0:0] Sel_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Sel_gold_recv_in__rdy [0:3];
  logic [0:0] Sel_gold_recv_opt__rdy;
  logic [34:0] Sel_gold_send_out__msg [0:1];
  logic [0:0] Sel_gold_send_out__val [0:1];
  logic [169:0] Sel_gold_send_to_ctrl_mem__msg;
  logic [0:0] Sel_gold_send_to_ctrl_mem__val;
  logic [6:0] Sel_gold_to_mem_raddr__msg;
  logic [0:0] Sel_gold_to_mem_raddr__val;
  logic [6:0] Sel_gold_to_mem_waddr__msg;
  logic [0:0] Sel_gold_to_mem_waddr__val;
  logic [34:0] Sel_gold_to_mem_wdata__msg;
  logic [0:0] Sel_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Sel_gold_bits;
  assign Sel_gold_bits={Sel_gold_from_mem_rdata__rdy,Sel_gold_recv_const__rdy,Sel_gold_recv_from_ctrl_mem__rdy,Sel_gold_recv_in__rdy[0],Sel_gold_recv_in__rdy[1],Sel_gold_recv_in__rdy[2],Sel_gold_recv_in__rdy[3],Sel_gold_recv_opt__rdy,Sel_gold_send_out__msg[0],Sel_gold_send_out__msg[1],Sel_gold_send_out__val[0],Sel_gold_send_out__val[1],Sel_gold_send_to_ctrl_mem__msg,Sel_gold_send_to_ctrl_mem__val,Sel_gold_to_mem_raddr__msg,Sel_gold_to_mem_raddr__val,Sel_gold_to_mem_waddr__msg,Sel_gold_to_mem_waddr__val,Sel_gold_to_mem_wdata__msg,Sel_gold_to_mem_wdata__val};
  ScalarRefSelw32 Sel_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Sel_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Sel_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Sel_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Sel_gold_recv_in__rdy),
    .recv_opt__rdy(Sel_gold_recv_opt__rdy),
    .send_out__msg(Sel_gold_send_out__msg),
    .send_out__val(Sel_gold_send_out__val),
    .send_to_ctrl_mem__msg(Sel_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Sel_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Sel_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Sel_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Sel_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Sel_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Sel_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Sel_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Sel_python[0:CYCLES-1];
  logic [0:0] Phi_dut_from_mem_rdata__rdy;
  logic [0:0] Phi_dut_recv_const__rdy;
  logic [0:0] Phi_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Phi_dut_recv_in__rdy [0:3];
  logic [0:0] Phi_dut_recv_opt__rdy;
  logic [34:0] Phi_dut_send_out__msg [0:1];
  logic [0:0] Phi_dut_send_out__val [0:1];
  logic [169:0] Phi_dut_send_to_ctrl_mem__msg;
  logic [0:0] Phi_dut_send_to_ctrl_mem__val;
  logic [6:0] Phi_dut_to_mem_raddr__msg;
  logic [0:0] Phi_dut_to_mem_raddr__val;
  logic [6:0] Phi_dut_to_mem_waddr__msg;
  logic [0:0] Phi_dut_to_mem_waddr__val;
  logic [34:0] Phi_dut_to_mem_wdata__msg;
  logic [0:0] Phi_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Phi_dut_bits;
  assign Phi_dut_bits={Phi_dut_from_mem_rdata__rdy,Phi_dut_recv_const__rdy,Phi_dut_recv_from_ctrl_mem__rdy,Phi_dut_recv_in__rdy[0],Phi_dut_recv_in__rdy[1],Phi_dut_recv_in__rdy[2],Phi_dut_recv_in__rdy[3],Phi_dut_recv_opt__rdy,Phi_dut_send_out__msg[0],Phi_dut_send_out__msg[1],Phi_dut_send_out__val[0],Phi_dut_send_out__val[1],Phi_dut_send_to_ctrl_mem__msg,Phi_dut_send_to_ctrl_mem__val,Phi_dut_to_mem_raddr__msg,Phi_dut_to_mem_raddr__val,Phi_dut_to_mem_waddr__msg,Phi_dut_to_mem_waddr__val,Phi_dut_to_mem_wdata__msg,Phi_dut_to_mem_wdata__val};
  scalar_phi #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Phi_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Phi_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Phi_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Phi_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Phi_dut_recv_in__rdy),
    .recv_opt__rdy(Phi_dut_recv_opt__rdy),
    .send_out__msg(Phi_dut_send_out__msg),
    .send_out__val(Phi_dut_send_out__val),
    .send_to_ctrl_mem__msg(Phi_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Phi_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Phi_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Phi_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Phi_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Phi_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Phi_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Phi_dut_to_mem_wdata__val)
  );
  logic [0:0] Phi_gold_from_mem_rdata__rdy;
  logic [0:0] Phi_gold_recv_const__rdy;
  logic [0:0] Phi_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Phi_gold_recv_in__rdy [0:3];
  logic [0:0] Phi_gold_recv_opt__rdy;
  logic [34:0] Phi_gold_send_out__msg [0:1];
  logic [0:0] Phi_gold_send_out__val [0:1];
  logic [169:0] Phi_gold_send_to_ctrl_mem__msg;
  logic [0:0] Phi_gold_send_to_ctrl_mem__val;
  logic [6:0] Phi_gold_to_mem_raddr__msg;
  logic [0:0] Phi_gold_to_mem_raddr__val;
  logic [6:0] Phi_gold_to_mem_waddr__msg;
  logic [0:0] Phi_gold_to_mem_waddr__val;
  logic [34:0] Phi_gold_to_mem_wdata__msg;
  logic [0:0] Phi_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Phi_gold_bits;
  assign Phi_gold_bits={Phi_gold_from_mem_rdata__rdy,Phi_gold_recv_const__rdy,Phi_gold_recv_from_ctrl_mem__rdy,Phi_gold_recv_in__rdy[0],Phi_gold_recv_in__rdy[1],Phi_gold_recv_in__rdy[2],Phi_gold_recv_in__rdy[3],Phi_gold_recv_opt__rdy,Phi_gold_send_out__msg[0],Phi_gold_send_out__msg[1],Phi_gold_send_out__val[0],Phi_gold_send_out__val[1],Phi_gold_send_to_ctrl_mem__msg,Phi_gold_send_to_ctrl_mem__val,Phi_gold_to_mem_raddr__msg,Phi_gold_to_mem_raddr__val,Phi_gold_to_mem_waddr__msg,Phi_gold_to_mem_waddr__val,Phi_gold_to_mem_wdata__msg,Phi_gold_to_mem_wdata__val};
  ScalarRefPhiw32 Phi_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Phi_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Phi_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Phi_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Phi_gold_recv_in__rdy),
    .recv_opt__rdy(Phi_gold_recv_opt__rdy),
    .send_out__msg(Phi_gold_send_out__msg),
    .send_out__val(Phi_gold_send_out__val),
    .send_to_ctrl_mem__msg(Phi_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Phi_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Phi_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Phi_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Phi_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Phi_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Phi_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Phi_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Phi_python[0:CYCLES-1];
  logic [0:0] Grant_dut_from_mem_rdata__rdy;
  logic [0:0] Grant_dut_recv_const__rdy;
  logic [0:0] Grant_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Grant_dut_recv_in__rdy [0:3];
  logic [0:0] Grant_dut_recv_opt__rdy;
  logic [34:0] Grant_dut_send_out__msg [0:1];
  logic [0:0] Grant_dut_send_out__val [0:1];
  logic [169:0] Grant_dut_send_to_ctrl_mem__msg;
  logic [0:0] Grant_dut_send_to_ctrl_mem__val;
  logic [6:0] Grant_dut_to_mem_raddr__msg;
  logic [0:0] Grant_dut_to_mem_raddr__val;
  logic [6:0] Grant_dut_to_mem_waddr__msg;
  logic [0:0] Grant_dut_to_mem_waddr__val;
  logic [34:0] Grant_dut_to_mem_wdata__msg;
  logic [0:0] Grant_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Grant_dut_bits;
  assign Grant_dut_bits={Grant_dut_from_mem_rdata__rdy,Grant_dut_recv_const__rdy,Grant_dut_recv_from_ctrl_mem__rdy,Grant_dut_recv_in__rdy[0],Grant_dut_recv_in__rdy[1],Grant_dut_recv_in__rdy[2],Grant_dut_recv_in__rdy[3],Grant_dut_recv_opt__rdy,Grant_dut_send_out__msg[0],Grant_dut_send_out__msg[1],Grant_dut_send_out__val[0],Grant_dut_send_out__val[1],Grant_dut_send_to_ctrl_mem__msg,Grant_dut_send_to_ctrl_mem__val,Grant_dut_to_mem_raddr__msg,Grant_dut_to_mem_raddr__val,Grant_dut_to_mem_waddr__msg,Grant_dut_to_mem_waddr__val,Grant_dut_to_mem_wdata__msg,Grant_dut_to_mem_wdata__val};
  scalar_grant #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Grant_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Grant_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Grant_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Grant_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Grant_dut_recv_in__rdy),
    .recv_opt__rdy(Grant_dut_recv_opt__rdy),
    .send_out__msg(Grant_dut_send_out__msg),
    .send_out__val(Grant_dut_send_out__val),
    .send_to_ctrl_mem__msg(Grant_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Grant_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Grant_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Grant_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Grant_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Grant_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Grant_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Grant_dut_to_mem_wdata__val)
  );
  logic [0:0] Grant_gold_from_mem_rdata__rdy;
  logic [0:0] Grant_gold_recv_const__rdy;
  logic [0:0] Grant_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Grant_gold_recv_in__rdy [0:3];
  logic [0:0] Grant_gold_recv_opt__rdy;
  logic [34:0] Grant_gold_send_out__msg [0:1];
  logic [0:0] Grant_gold_send_out__val [0:1];
  logic [169:0] Grant_gold_send_to_ctrl_mem__msg;
  logic [0:0] Grant_gold_send_to_ctrl_mem__val;
  logic [6:0] Grant_gold_to_mem_raddr__msg;
  logic [0:0] Grant_gold_to_mem_raddr__val;
  logic [6:0] Grant_gold_to_mem_waddr__msg;
  logic [0:0] Grant_gold_to_mem_waddr__val;
  logic [34:0] Grant_gold_to_mem_wdata__msg;
  logic [0:0] Grant_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Grant_gold_bits;
  assign Grant_gold_bits={Grant_gold_from_mem_rdata__rdy,Grant_gold_recv_const__rdy,Grant_gold_recv_from_ctrl_mem__rdy,Grant_gold_recv_in__rdy[0],Grant_gold_recv_in__rdy[1],Grant_gold_recv_in__rdy[2],Grant_gold_recv_in__rdy[3],Grant_gold_recv_opt__rdy,Grant_gold_send_out__msg[0],Grant_gold_send_out__msg[1],Grant_gold_send_out__val[0],Grant_gold_send_out__val[1],Grant_gold_send_to_ctrl_mem__msg,Grant_gold_send_to_ctrl_mem__val,Grant_gold_to_mem_raddr__msg,Grant_gold_to_mem_raddr__val,Grant_gold_to_mem_waddr__msg,Grant_gold_to_mem_waddr__val,Grant_gold_to_mem_wdata__msg,Grant_gold_to_mem_wdata__val};
  ScalarRefGrantw32 Grant_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Grant_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Grant_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Grant_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Grant_gold_recv_in__rdy),
    .recv_opt__rdy(Grant_gold_recv_opt__rdy),
    .send_out__msg(Grant_gold_send_out__msg),
    .send_out__val(Grant_gold_send_out__val),
    .send_to_ctrl_mem__msg(Grant_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Grant_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Grant_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Grant_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Grant_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Grant_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Grant_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Grant_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Grant_python[0:CYCLES-1];
  logic [0:0] Gep_dut_from_mem_rdata__rdy;
  logic [0:0] Gep_dut_recv_const__rdy;
  logic [0:0] Gep_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Gep_dut_recv_in__rdy [0:3];
  logic [0:0] Gep_dut_recv_opt__rdy;
  logic [34:0] Gep_dut_send_out__msg [0:1];
  logic [0:0] Gep_dut_send_out__val [0:1];
  logic [169:0] Gep_dut_send_to_ctrl_mem__msg;
  logic [0:0] Gep_dut_send_to_ctrl_mem__val;
  logic [6:0] Gep_dut_to_mem_raddr__msg;
  logic [0:0] Gep_dut_to_mem_raddr__val;
  logic [6:0] Gep_dut_to_mem_waddr__msg;
  logic [0:0] Gep_dut_to_mem_waddr__val;
  logic [34:0] Gep_dut_to_mem_wdata__msg;
  logic [0:0] Gep_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Gep_dut_bits;
  assign Gep_dut_bits={Gep_dut_from_mem_rdata__rdy,Gep_dut_recv_const__rdy,Gep_dut_recv_from_ctrl_mem__rdy,Gep_dut_recv_in__rdy[0],Gep_dut_recv_in__rdy[1],Gep_dut_recv_in__rdy[2],Gep_dut_recv_in__rdy[3],Gep_dut_recv_opt__rdy,Gep_dut_send_out__msg[0],Gep_dut_send_out__msg[1],Gep_dut_send_out__val[0],Gep_dut_send_out__val[1],Gep_dut_send_to_ctrl_mem__msg,Gep_dut_send_to_ctrl_mem__val,Gep_dut_to_mem_raddr__msg,Gep_dut_to_mem_raddr__val,Gep_dut_to_mem_waddr__msg,Gep_dut_to_mem_waddr__val,Gep_dut_to_mem_wdata__msg,Gep_dut_to_mem_wdata__val};
  scalar_gep #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Gep_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Gep_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Gep_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Gep_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Gep_dut_recv_in__rdy),
    .recv_opt__rdy(Gep_dut_recv_opt__rdy),
    .send_out__msg(Gep_dut_send_out__msg),
    .send_out__val(Gep_dut_send_out__val),
    .send_to_ctrl_mem__msg(Gep_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Gep_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Gep_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Gep_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Gep_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Gep_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Gep_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Gep_dut_to_mem_wdata__val)
  );
  logic [0:0] Gep_gold_from_mem_rdata__rdy;
  logic [0:0] Gep_gold_recv_const__rdy;
  logic [0:0] Gep_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Gep_gold_recv_in__rdy [0:3];
  logic [0:0] Gep_gold_recv_opt__rdy;
  logic [34:0] Gep_gold_send_out__msg [0:1];
  logic [0:0] Gep_gold_send_out__val [0:1];
  logic [169:0] Gep_gold_send_to_ctrl_mem__msg;
  logic [0:0] Gep_gold_send_to_ctrl_mem__val;
  logic [6:0] Gep_gold_to_mem_raddr__msg;
  logic [0:0] Gep_gold_to_mem_raddr__val;
  logic [6:0] Gep_gold_to_mem_waddr__msg;
  logic [0:0] Gep_gold_to_mem_waddr__val;
  logic [34:0] Gep_gold_to_mem_wdata__msg;
  logic [0:0] Gep_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Gep_gold_bits;
  assign Gep_gold_bits={Gep_gold_from_mem_rdata__rdy,Gep_gold_recv_const__rdy,Gep_gold_recv_from_ctrl_mem__rdy,Gep_gold_recv_in__rdy[0],Gep_gold_recv_in__rdy[1],Gep_gold_recv_in__rdy[2],Gep_gold_recv_in__rdy[3],Gep_gold_recv_opt__rdy,Gep_gold_send_out__msg[0],Gep_gold_send_out__msg[1],Gep_gold_send_out__val[0],Gep_gold_send_out__val[1],Gep_gold_send_to_ctrl_mem__msg,Gep_gold_send_to_ctrl_mem__val,Gep_gold_to_mem_raddr__msg,Gep_gold_to_mem_raddr__val,Gep_gold_to_mem_waddr__msg,Gep_gold_to_mem_waddr__val,Gep_gold_to_mem_wdata__msg,Gep_gold_to_mem_wdata__val};
  ScalarRefGepw32 Gep_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Gep_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Gep_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Gep_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Gep_gold_recv_in__rdy),
    .recv_opt__rdy(Gep_gold_recv_opt__rdy),
    .send_out__msg(Gep_gold_send_out__msg),
    .send_out__val(Gep_gold_send_out__val),
    .send_to_ctrl_mem__msg(Gep_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Gep_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Gep_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Gep_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Gep_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Gep_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Gep_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Gep_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Gep_python[0:CYCLES-1];
  logic [0:0] ExtractPredicate_dut_from_mem_rdata__rdy;
  logic [0:0] ExtractPredicate_dut_recv_const__rdy;
  logic [0:0] ExtractPredicate_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] ExtractPredicate_dut_recv_in__rdy [0:3];
  logic [0:0] ExtractPredicate_dut_recv_opt__rdy;
  logic [34:0] ExtractPredicate_dut_send_out__msg [0:1];
  logic [0:0] ExtractPredicate_dut_send_out__val [0:1];
  logic [169:0] ExtractPredicate_dut_send_to_ctrl_mem__msg;
  logic [0:0] ExtractPredicate_dut_send_to_ctrl_mem__val;
  logic [6:0] ExtractPredicate_dut_to_mem_raddr__msg;
  logic [0:0] ExtractPredicate_dut_to_mem_raddr__val;
  logic [6:0] ExtractPredicate_dut_to_mem_waddr__msg;
  logic [0:0] ExtractPredicate_dut_to_mem_waddr__val;
  logic [34:0] ExtractPredicate_dut_to_mem_wdata__msg;
  logic [0:0] ExtractPredicate_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] ExtractPredicate_dut_bits;
  assign ExtractPredicate_dut_bits={ExtractPredicate_dut_from_mem_rdata__rdy,ExtractPredicate_dut_recv_const__rdy,ExtractPredicate_dut_recv_from_ctrl_mem__rdy,ExtractPredicate_dut_recv_in__rdy[0],ExtractPredicate_dut_recv_in__rdy[1],ExtractPredicate_dut_recv_in__rdy[2],ExtractPredicate_dut_recv_in__rdy[3],ExtractPredicate_dut_recv_opt__rdy,ExtractPredicate_dut_send_out__msg[0],ExtractPredicate_dut_send_out__msg[1],ExtractPredicate_dut_send_out__val[0],ExtractPredicate_dut_send_out__val[1],ExtractPredicate_dut_send_to_ctrl_mem__msg,ExtractPredicate_dut_send_to_ctrl_mem__val,ExtractPredicate_dut_to_mem_raddr__msg,ExtractPredicate_dut_to_mem_raddr__val,ExtractPredicate_dut_to_mem_waddr__msg,ExtractPredicate_dut_to_mem_waddr__val,ExtractPredicate_dut_to_mem_wdata__msg,ExtractPredicate_dut_to_mem_wdata__val};
  scalar_extract_predicate #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) ExtractPredicate_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(ExtractPredicate_dut_from_mem_rdata__rdy),
    .recv_const__rdy(ExtractPredicate_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(ExtractPredicate_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(ExtractPredicate_dut_recv_in__rdy),
    .recv_opt__rdy(ExtractPredicate_dut_recv_opt__rdy),
    .send_out__msg(ExtractPredicate_dut_send_out__msg),
    .send_out__val(ExtractPredicate_dut_send_out__val),
    .send_to_ctrl_mem__msg(ExtractPredicate_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(ExtractPredicate_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(ExtractPredicate_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(ExtractPredicate_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(ExtractPredicate_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(ExtractPredicate_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(ExtractPredicate_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(ExtractPredicate_dut_to_mem_wdata__val)
  );
  logic [0:0] ExtractPredicate_gold_from_mem_rdata__rdy;
  logic [0:0] ExtractPredicate_gold_recv_const__rdy;
  logic [0:0] ExtractPredicate_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] ExtractPredicate_gold_recv_in__rdy [0:3];
  logic [0:0] ExtractPredicate_gold_recv_opt__rdy;
  logic [34:0] ExtractPredicate_gold_send_out__msg [0:1];
  logic [0:0] ExtractPredicate_gold_send_out__val [0:1];
  logic [169:0] ExtractPredicate_gold_send_to_ctrl_mem__msg;
  logic [0:0] ExtractPredicate_gold_send_to_ctrl_mem__val;
  logic [6:0] ExtractPredicate_gold_to_mem_raddr__msg;
  logic [0:0] ExtractPredicate_gold_to_mem_raddr__val;
  logic [6:0] ExtractPredicate_gold_to_mem_waddr__msg;
  logic [0:0] ExtractPredicate_gold_to_mem_waddr__val;
  logic [34:0] ExtractPredicate_gold_to_mem_wdata__msg;
  logic [0:0] ExtractPredicate_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] ExtractPredicate_gold_bits;
  assign ExtractPredicate_gold_bits={ExtractPredicate_gold_from_mem_rdata__rdy,ExtractPredicate_gold_recv_const__rdy,ExtractPredicate_gold_recv_from_ctrl_mem__rdy,ExtractPredicate_gold_recv_in__rdy[0],ExtractPredicate_gold_recv_in__rdy[1],ExtractPredicate_gold_recv_in__rdy[2],ExtractPredicate_gold_recv_in__rdy[3],ExtractPredicate_gold_recv_opt__rdy,ExtractPredicate_gold_send_out__msg[0],ExtractPredicate_gold_send_out__msg[1],ExtractPredicate_gold_send_out__val[0],ExtractPredicate_gold_send_out__val[1],ExtractPredicate_gold_send_to_ctrl_mem__msg,ExtractPredicate_gold_send_to_ctrl_mem__val,ExtractPredicate_gold_to_mem_raddr__msg,ExtractPredicate_gold_to_mem_raddr__val,ExtractPredicate_gold_to_mem_waddr__msg,ExtractPredicate_gold_to_mem_waddr__val,ExtractPredicate_gold_to_mem_wdata__msg,ExtractPredicate_gold_to_mem_wdata__val};
  ScalarRefExtractPredicatew32 ExtractPredicate_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(ExtractPredicate_gold_from_mem_rdata__rdy),
    .recv_const__rdy(ExtractPredicate_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(ExtractPredicate_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(ExtractPredicate_gold_recv_in__rdy),
    .recv_opt__rdy(ExtractPredicate_gold_recv_opt__rdy),
    .send_out__msg(ExtractPredicate_gold_send_out__msg),
    .send_out__val(ExtractPredicate_gold_send_out__val),
    .send_to_ctrl_mem__msg(ExtractPredicate_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(ExtractPredicate_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(ExtractPredicate_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(ExtractPredicate_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(ExtractPredicate_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(ExtractPredicate_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(ExtractPredicate_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(ExtractPredicate_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] ExtractPredicate_python[0:CYCLES-1];
  logic [0:0] Ret_dut_from_mem_rdata__rdy;
  logic [0:0] Ret_dut_recv_const__rdy;
  logic [0:0] Ret_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Ret_dut_recv_in__rdy [0:3];
  logic [0:0] Ret_dut_recv_opt__rdy;
  logic [34:0] Ret_dut_send_out__msg [0:1];
  logic [0:0] Ret_dut_send_out__val [0:1];
  logic [169:0] Ret_dut_send_to_ctrl_mem__msg;
  logic [0:0] Ret_dut_send_to_ctrl_mem__val;
  logic [6:0] Ret_dut_to_mem_raddr__msg;
  logic [0:0] Ret_dut_to_mem_raddr__val;
  logic [6:0] Ret_dut_to_mem_waddr__msg;
  logic [0:0] Ret_dut_to_mem_waddr__val;
  logic [34:0] Ret_dut_to_mem_wdata__msg;
  logic [0:0] Ret_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Ret_dut_bits;
  assign Ret_dut_bits={Ret_dut_from_mem_rdata__rdy,Ret_dut_recv_const__rdy,Ret_dut_recv_from_ctrl_mem__rdy,Ret_dut_recv_in__rdy[0],Ret_dut_recv_in__rdy[1],Ret_dut_recv_in__rdy[2],Ret_dut_recv_in__rdy[3],Ret_dut_recv_opt__rdy,Ret_dut_send_out__msg[0],Ret_dut_send_out__msg[1],Ret_dut_send_out__val[0],Ret_dut_send_out__val[1],Ret_dut_send_to_ctrl_mem__msg,Ret_dut_send_to_ctrl_mem__val,Ret_dut_to_mem_raddr__msg,Ret_dut_to_mem_raddr__val,Ret_dut_to_mem_waddr__msg,Ret_dut_to_mem_waddr__val,Ret_dut_to_mem_wdata__msg,Ret_dut_to_mem_wdata__val};
  scalar_ret #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Ret_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Ret_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Ret_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Ret_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Ret_dut_recv_in__rdy),
    .recv_opt__rdy(Ret_dut_recv_opt__rdy),
    .send_out__msg(Ret_dut_send_out__msg),
    .send_out__val(Ret_dut_send_out__val),
    .send_to_ctrl_mem__msg(Ret_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Ret_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Ret_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Ret_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Ret_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Ret_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Ret_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Ret_dut_to_mem_wdata__val)
  );
  logic [0:0] Ret_gold_from_mem_rdata__rdy;
  logic [0:0] Ret_gold_recv_const__rdy;
  logic [0:0] Ret_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Ret_gold_recv_in__rdy [0:3];
  logic [0:0] Ret_gold_recv_opt__rdy;
  logic [34:0] Ret_gold_send_out__msg [0:1];
  logic [0:0] Ret_gold_send_out__val [0:1];
  logic [169:0] Ret_gold_send_to_ctrl_mem__msg;
  logic [0:0] Ret_gold_send_to_ctrl_mem__val;
  logic [6:0] Ret_gold_to_mem_raddr__msg;
  logic [0:0] Ret_gold_to_mem_raddr__val;
  logic [6:0] Ret_gold_to_mem_waddr__msg;
  logic [0:0] Ret_gold_to_mem_waddr__val;
  logic [34:0] Ret_gold_to_mem_wdata__msg;
  logic [0:0] Ret_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Ret_gold_bits;
  assign Ret_gold_bits={Ret_gold_from_mem_rdata__rdy,Ret_gold_recv_const__rdy,Ret_gold_recv_from_ctrl_mem__rdy,Ret_gold_recv_in__rdy[0],Ret_gold_recv_in__rdy[1],Ret_gold_recv_in__rdy[2],Ret_gold_recv_in__rdy[3],Ret_gold_recv_opt__rdy,Ret_gold_send_out__msg[0],Ret_gold_send_out__msg[1],Ret_gold_send_out__val[0],Ret_gold_send_out__val[1],Ret_gold_send_to_ctrl_mem__msg,Ret_gold_send_to_ctrl_mem__val,Ret_gold_to_mem_raddr__msg,Ret_gold_to_mem_raddr__val,Ret_gold_to_mem_waddr__msg,Ret_gold_to_mem_waddr__val,Ret_gold_to_mem_wdata__msg,Ret_gold_to_mem_wdata__val};
  ScalarRefRetw32 Ret_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Ret_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Ret_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Ret_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Ret_gold_recv_in__rdy),
    .recv_opt__rdy(Ret_gold_recv_opt__rdy),
    .send_out__msg(Ret_gold_send_out__msg),
    .send_out__val(Ret_gold_send_out__val),
    .send_to_ctrl_mem__msg(Ret_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Ret_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Ret_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Ret_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Ret_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Ret_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Ret_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Ret_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Ret_python[0:CYCLES-1];
  logic [0:0] LoopCounter_dut_from_mem_rdata__rdy;
  logic [0:0] LoopCounter_dut_recv_const__rdy;
  logic [0:0] LoopCounter_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] LoopCounter_dut_recv_in__rdy [0:3];
  logic [0:0] LoopCounter_dut_recv_opt__rdy;
  logic [34:0] LoopCounter_dut_send_out__msg [0:1];
  logic [0:0] LoopCounter_dut_send_out__val [0:1];
  logic [169:0] LoopCounter_dut_send_to_ctrl_mem__msg;
  logic [0:0] LoopCounter_dut_send_to_ctrl_mem__val;
  logic [6:0] LoopCounter_dut_to_mem_raddr__msg;
  logic [0:0] LoopCounter_dut_to_mem_raddr__val;
  logic [6:0] LoopCounter_dut_to_mem_waddr__msg;
  logic [0:0] LoopCounter_dut_to_mem_waddr__val;
  logic [34:0] LoopCounter_dut_to_mem_wdata__msg;
  logic [0:0] LoopCounter_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] LoopCounter_dut_bits;
  assign LoopCounter_dut_bits={LoopCounter_dut_from_mem_rdata__rdy,LoopCounter_dut_recv_const__rdy,LoopCounter_dut_recv_from_ctrl_mem__rdy,LoopCounter_dut_recv_in__rdy[0],LoopCounter_dut_recv_in__rdy[1],LoopCounter_dut_recv_in__rdy[2],LoopCounter_dut_recv_in__rdy[3],LoopCounter_dut_recv_opt__rdy,LoopCounter_dut_send_out__msg[0],LoopCounter_dut_send_out__msg[1],LoopCounter_dut_send_out__val[0],LoopCounter_dut_send_out__val[1],LoopCounter_dut_send_to_ctrl_mem__msg,LoopCounter_dut_send_to_ctrl_mem__val,LoopCounter_dut_to_mem_raddr__msg,LoopCounter_dut_to_mem_raddr__val,LoopCounter_dut_to_mem_waddr__msg,LoopCounter_dut_to_mem_waddr__val,LoopCounter_dut_to_mem_wdata__msg,LoopCounter_dut_to_mem_wdata__val};
  scalar_loop_counter #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) LoopCounter_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(LoopCounter_dut_from_mem_rdata__rdy),
    .recv_const__rdy(LoopCounter_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(LoopCounter_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(LoopCounter_dut_recv_in__rdy),
    .recv_opt__rdy(LoopCounter_dut_recv_opt__rdy),
    .send_out__msg(LoopCounter_dut_send_out__msg),
    .send_out__val(LoopCounter_dut_send_out__val),
    .send_to_ctrl_mem__msg(LoopCounter_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(LoopCounter_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(LoopCounter_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(LoopCounter_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(LoopCounter_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(LoopCounter_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(LoopCounter_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(LoopCounter_dut_to_mem_wdata__val)
  );
  logic [0:0] LoopCounter_gold_from_mem_rdata__rdy;
  logic [0:0] LoopCounter_gold_recv_const__rdy;
  logic [0:0] LoopCounter_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] LoopCounter_gold_recv_in__rdy [0:3];
  logic [0:0] LoopCounter_gold_recv_opt__rdy;
  logic [34:0] LoopCounter_gold_send_out__msg [0:1];
  logic [0:0] LoopCounter_gold_send_out__val [0:1];
  logic [169:0] LoopCounter_gold_send_to_ctrl_mem__msg;
  logic [0:0] LoopCounter_gold_send_to_ctrl_mem__val;
  logic [6:0] LoopCounter_gold_to_mem_raddr__msg;
  logic [0:0] LoopCounter_gold_to_mem_raddr__val;
  logic [6:0] LoopCounter_gold_to_mem_waddr__msg;
  logic [0:0] LoopCounter_gold_to_mem_waddr__val;
  logic [34:0] LoopCounter_gold_to_mem_wdata__msg;
  logic [0:0] LoopCounter_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] LoopCounter_gold_bits;
  assign LoopCounter_gold_bits={LoopCounter_gold_from_mem_rdata__rdy,LoopCounter_gold_recv_const__rdy,LoopCounter_gold_recv_from_ctrl_mem__rdy,LoopCounter_gold_recv_in__rdy[0],LoopCounter_gold_recv_in__rdy[1],LoopCounter_gold_recv_in__rdy[2],LoopCounter_gold_recv_in__rdy[3],LoopCounter_gold_recv_opt__rdy,LoopCounter_gold_send_out__msg[0],LoopCounter_gold_send_out__msg[1],LoopCounter_gold_send_out__val[0],LoopCounter_gold_send_out__val[1],LoopCounter_gold_send_to_ctrl_mem__msg,LoopCounter_gold_send_to_ctrl_mem__val,LoopCounter_gold_to_mem_raddr__msg,LoopCounter_gold_to_mem_raddr__val,LoopCounter_gold_to_mem_waddr__msg,LoopCounter_gold_to_mem_waddr__val,LoopCounter_gold_to_mem_wdata__msg,LoopCounter_gold_to_mem_wdata__val};
  ScalarRefLoopCounterw32 LoopCounter_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(LoopCounter_gold_from_mem_rdata__rdy),
    .recv_const__rdy(LoopCounter_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(LoopCounter_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(LoopCounter_gold_recv_in__rdy),
    .recv_opt__rdy(LoopCounter_gold_recv_opt__rdy),
    .send_out__msg(LoopCounter_gold_send_out__msg),
    .send_out__val(LoopCounter_gold_send_out__val),
    .send_to_ctrl_mem__msg(LoopCounter_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(LoopCounter_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(LoopCounter_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(LoopCounter_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(LoopCounter_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(LoopCounter_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(LoopCounter_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(LoopCounter_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] LoopCounter_python[0:CYCLES-1];
  logic [0:0] LoopControl_dut_from_mem_rdata__rdy;
  logic [0:0] LoopControl_dut_recv_const__rdy;
  logic [0:0] LoopControl_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] LoopControl_dut_recv_in__rdy [0:3];
  logic [0:0] LoopControl_dut_recv_opt__rdy;
  logic [34:0] LoopControl_dut_send_out__msg [0:1];
  logic [0:0] LoopControl_dut_send_out__val [0:1];
  logic [169:0] LoopControl_dut_send_to_ctrl_mem__msg;
  logic [0:0] LoopControl_dut_send_to_ctrl_mem__val;
  logic [6:0] LoopControl_dut_to_mem_raddr__msg;
  logic [0:0] LoopControl_dut_to_mem_raddr__val;
  logic [6:0] LoopControl_dut_to_mem_waddr__msg;
  logic [0:0] LoopControl_dut_to_mem_waddr__val;
  logic [34:0] LoopControl_dut_to_mem_wdata__msg;
  logic [0:0] LoopControl_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] LoopControl_dut_bits;
  assign LoopControl_dut_bits={LoopControl_dut_from_mem_rdata__rdy,LoopControl_dut_recv_const__rdy,LoopControl_dut_recv_from_ctrl_mem__rdy,LoopControl_dut_recv_in__rdy[0],LoopControl_dut_recv_in__rdy[1],LoopControl_dut_recv_in__rdy[2],LoopControl_dut_recv_in__rdy[3],LoopControl_dut_recv_opt__rdy,LoopControl_dut_send_out__msg[0],LoopControl_dut_send_out__msg[1],LoopControl_dut_send_out__val[0],LoopControl_dut_send_out__val[1],LoopControl_dut_send_to_ctrl_mem__msg,LoopControl_dut_send_to_ctrl_mem__val,LoopControl_dut_to_mem_raddr__msg,LoopControl_dut_to_mem_raddr__val,LoopControl_dut_to_mem_waddr__msg,LoopControl_dut_to_mem_waddr__val,LoopControl_dut_to_mem_wdata__msg,LoopControl_dut_to_mem_wdata__val};
  scalar_loop_control #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) LoopControl_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(LoopControl_dut_from_mem_rdata__rdy),
    .recv_const__rdy(LoopControl_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(LoopControl_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(LoopControl_dut_recv_in__rdy),
    .recv_opt__rdy(LoopControl_dut_recv_opt__rdy),
    .send_out__msg(LoopControl_dut_send_out__msg),
    .send_out__val(LoopControl_dut_send_out__val),
    .send_to_ctrl_mem__msg(LoopControl_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(LoopControl_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(LoopControl_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(LoopControl_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(LoopControl_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(LoopControl_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(LoopControl_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(LoopControl_dut_to_mem_wdata__val)
  );
  logic [0:0] LoopControl_gold_from_mem_rdata__rdy;
  logic [0:0] LoopControl_gold_recv_const__rdy;
  logic [0:0] LoopControl_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] LoopControl_gold_recv_in__rdy [0:3];
  logic [0:0] LoopControl_gold_recv_opt__rdy;
  logic [34:0] LoopControl_gold_send_out__msg [0:1];
  logic [0:0] LoopControl_gold_send_out__val [0:1];
  logic [169:0] LoopControl_gold_send_to_ctrl_mem__msg;
  logic [0:0] LoopControl_gold_send_to_ctrl_mem__val;
  logic [6:0] LoopControl_gold_to_mem_raddr__msg;
  logic [0:0] LoopControl_gold_to_mem_raddr__val;
  logic [6:0] LoopControl_gold_to_mem_waddr__msg;
  logic [0:0] LoopControl_gold_to_mem_waddr__val;
  logic [34:0] LoopControl_gold_to_mem_wdata__msg;
  logic [0:0] LoopControl_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] LoopControl_gold_bits;
  assign LoopControl_gold_bits={LoopControl_gold_from_mem_rdata__rdy,LoopControl_gold_recv_const__rdy,LoopControl_gold_recv_from_ctrl_mem__rdy,LoopControl_gold_recv_in__rdy[0],LoopControl_gold_recv_in__rdy[1],LoopControl_gold_recv_in__rdy[2],LoopControl_gold_recv_in__rdy[3],LoopControl_gold_recv_opt__rdy,LoopControl_gold_send_out__msg[0],LoopControl_gold_send_out__msg[1],LoopControl_gold_send_out__val[0],LoopControl_gold_send_out__val[1],LoopControl_gold_send_to_ctrl_mem__msg,LoopControl_gold_send_to_ctrl_mem__val,LoopControl_gold_to_mem_raddr__msg,LoopControl_gold_to_mem_raddr__val,LoopControl_gold_to_mem_waddr__msg,LoopControl_gold_to_mem_waddr__val,LoopControl_gold_to_mem_wdata__msg,LoopControl_gold_to_mem_wdata__val};
  ScalarRefLoopControlw32 LoopControl_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(LoopControl_gold_from_mem_rdata__rdy),
    .recv_const__rdy(LoopControl_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(LoopControl_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(LoopControl_gold_recv_in__rdy),
    .recv_opt__rdy(LoopControl_gold_recv_opt__rdy),
    .send_out__msg(LoopControl_gold_send_out__msg),
    .send_out__val(LoopControl_gold_send_out__val),
    .send_to_ctrl_mem__msg(LoopControl_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(LoopControl_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(LoopControl_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(LoopControl_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(LoopControl_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(LoopControl_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(LoopControl_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(LoopControl_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] LoopControl_python[0:CYCLES-1];
  logic [0:0] Div_dut_from_mem_rdata__rdy;
  logic [0:0] Div_dut_recv_const__rdy;
  logic [0:0] Div_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] Div_dut_recv_in__rdy [0:3];
  logic [0:0] Div_dut_recv_opt__rdy;
  logic [34:0] Div_dut_send_out__msg [0:1];
  logic [0:0] Div_dut_send_out__val [0:1];
  logic [169:0] Div_dut_send_to_ctrl_mem__msg;
  logic [0:0] Div_dut_send_to_ctrl_mem__val;
  logic [6:0] Div_dut_to_mem_raddr__msg;
  logic [0:0] Div_dut_to_mem_raddr__val;
  logic [6:0] Div_dut_to_mem_waddr__msg;
  logic [0:0] Div_dut_to_mem_waddr__val;
  logic [34:0] Div_dut_to_mem_wdata__msg;
  logic [0:0] Div_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Div_dut_bits;
  assign Div_dut_bits={Div_dut_from_mem_rdata__rdy,Div_dut_recv_const__rdy,Div_dut_recv_from_ctrl_mem__rdy,Div_dut_recv_in__rdy[0],Div_dut_recv_in__rdy[1],Div_dut_recv_in__rdy[2],Div_dut_recv_in__rdy[3],Div_dut_recv_opt__rdy,Div_dut_send_out__msg[0],Div_dut_send_out__msg[1],Div_dut_send_out__val[0],Div_dut_send_out__val[1],Div_dut_send_to_ctrl_mem__msg,Div_dut_send_to_ctrl_mem__val,Div_dut_to_mem_raddr__msg,Div_dut_to_mem_raddr__val,Div_dut_to_mem_waddr__msg,Div_dut_to_mem_waddr__val,Div_dut_to_mem_wdata__msg,Div_dut_to_mem_wdata__val};
  scalar_div #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) Div_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Div_dut_from_mem_rdata__rdy),
    .recv_const__rdy(Div_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Div_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Div_dut_recv_in__rdy),
    .recv_opt__rdy(Div_dut_recv_opt__rdy),
    .send_out__msg(Div_dut_send_out__msg),
    .send_out__val(Div_dut_send_out__val),
    .send_to_ctrl_mem__msg(Div_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Div_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Div_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(Div_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(Div_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(Div_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(Div_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(Div_dut_to_mem_wdata__val)
  );
  logic [0:0] Div_gold_from_mem_rdata__rdy;
  logic [0:0] Div_gold_recv_const__rdy;
  logic [0:0] Div_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] Div_gold_recv_in__rdy [0:3];
  logic [0:0] Div_gold_recv_opt__rdy;
  logic [34:0] Div_gold_send_out__msg [0:1];
  logic [0:0] Div_gold_send_out__val [0:1];
  logic [169:0] Div_gold_send_to_ctrl_mem__msg;
  logic [0:0] Div_gold_send_to_ctrl_mem__val;
  logic [6:0] Div_gold_to_mem_raddr__msg;
  logic [0:0] Div_gold_to_mem_raddr__val;
  logic [6:0] Div_gold_to_mem_waddr__msg;
  logic [0:0] Div_gold_to_mem_waddr__val;
  logic [34:0] Div_gold_to_mem_wdata__msg;
  logic [0:0] Div_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] Div_gold_bits;
  assign Div_gold_bits={Div_gold_from_mem_rdata__rdy,Div_gold_recv_const__rdy,Div_gold_recv_from_ctrl_mem__rdy,Div_gold_recv_in__rdy[0],Div_gold_recv_in__rdy[1],Div_gold_recv_in__rdy[2],Div_gold_recv_in__rdy[3],Div_gold_recv_opt__rdy,Div_gold_send_out__msg[0],Div_gold_send_out__msg[1],Div_gold_send_out__val[0],Div_gold_send_out__val[1],Div_gold_send_to_ctrl_mem__msg,Div_gold_send_to_ctrl_mem__val,Div_gold_to_mem_raddr__msg,Div_gold_to_mem_raddr__val,Div_gold_to_mem_waddr__msg,Div_gold_to_mem_waddr__val,Div_gold_to_mem_wdata__msg,Div_gold_to_mem_wdata__val};
  ScalarRefDivw32 Div_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(Div_gold_from_mem_rdata__rdy),
    .recv_const__rdy(Div_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(Div_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(Div_gold_recv_in__rdy),
    .recv_opt__rdy(Div_gold_recv_opt__rdy),
    .send_out__msg(Div_gold_send_out__msg),
    .send_out__val(Div_gold_send_out__val),
    .send_to_ctrl_mem__msg(Div_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(Div_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(Div_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(Div_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(Div_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(Div_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(Div_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(Div_gold_to_mem_wdata__val)
  );
  logic [OUTPUT_BITS-1:0] Div_python[0:CYCLES-1];
  logic [0:0] InclusiveDiv_dut_from_mem_rdata__rdy;
  logic [0:0] InclusiveDiv_dut_recv_const__rdy;
  logic [0:0] InclusiveDiv_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] InclusiveDiv_dut_recv_in__rdy [0:3];
  logic [0:0] InclusiveDiv_dut_recv_opt__rdy;
  logic [34:0] InclusiveDiv_dut_send_out__msg [0:1];
  logic [0:0] InclusiveDiv_dut_send_out__val [0:1];
  logic [169:0] InclusiveDiv_dut_send_to_ctrl_mem__msg;
  logic [0:0] InclusiveDiv_dut_send_to_ctrl_mem__val;
  logic [6:0] InclusiveDiv_dut_to_mem_raddr__msg;
  logic [0:0] InclusiveDiv_dut_to_mem_raddr__val;
  logic [6:0] InclusiveDiv_dut_to_mem_waddr__msg;
  logic [0:0] InclusiveDiv_dut_to_mem_waddr__val;
  logic [34:0] InclusiveDiv_dut_to_mem_wdata__msg;
  logic [0:0] InclusiveDiv_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] InclusiveDiv_dut_bits;
  assign InclusiveDiv_dut_bits={InclusiveDiv_dut_from_mem_rdata__rdy,InclusiveDiv_dut_recv_const__rdy,InclusiveDiv_dut_recv_from_ctrl_mem__rdy,InclusiveDiv_dut_recv_in__rdy[0],InclusiveDiv_dut_recv_in__rdy[1],InclusiveDiv_dut_recv_in__rdy[2],InclusiveDiv_dut_recv_in__rdy[3],InclusiveDiv_dut_recv_opt__rdy,InclusiveDiv_dut_send_out__msg[0],InclusiveDiv_dut_send_out__msg[1],InclusiveDiv_dut_send_out__val[0],InclusiveDiv_dut_send_out__val[1],InclusiveDiv_dut_send_to_ctrl_mem__msg,InclusiveDiv_dut_send_to_ctrl_mem__val,InclusiveDiv_dut_to_mem_raddr__msg,InclusiveDiv_dut_to_mem_raddr__val,InclusiveDiv_dut_to_mem_waddr__msg,InclusiveDiv_dut_to_mem_waddr__val,InclusiveDiv_dut_to_mem_wdata__msg,InclusiveDiv_dut_to_mem_wdata__val};
  scalar_inclusive_div #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) InclusiveDiv_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(InclusiveDiv_dut_from_mem_rdata__rdy),
    .recv_const__rdy(InclusiveDiv_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(InclusiveDiv_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(InclusiveDiv_dut_recv_in__rdy),
    .recv_opt__rdy(InclusiveDiv_dut_recv_opt__rdy),
    .send_out__msg(InclusiveDiv_dut_send_out__msg),
    .send_out__val(InclusiveDiv_dut_send_out__val),
    .send_to_ctrl_mem__msg(InclusiveDiv_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(InclusiveDiv_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(InclusiveDiv_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(InclusiveDiv_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(InclusiveDiv_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(InclusiveDiv_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(InclusiveDiv_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(InclusiveDiv_dut_to_mem_wdata__val)
  );
  logic [0:0] InclusiveDiv_gold_from_mem_rdata__rdy;
  logic [0:0] InclusiveDiv_gold_recv_const__rdy;
  logic [0:0] InclusiveDiv_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] InclusiveDiv_gold_recv_in__rdy [0:3];
  logic [0:0] InclusiveDiv_gold_recv_opt__rdy;
  logic [34:0] InclusiveDiv_gold_send_out__msg [0:1];
  logic [0:0] InclusiveDiv_gold_send_out__val [0:1];
  logic [169:0] InclusiveDiv_gold_send_to_ctrl_mem__msg;
  logic [0:0] InclusiveDiv_gold_send_to_ctrl_mem__val;
  logic [6:0] InclusiveDiv_gold_to_mem_raddr__msg;
  logic [0:0] InclusiveDiv_gold_to_mem_raddr__val;
  logic [6:0] InclusiveDiv_gold_to_mem_waddr__msg;
  logic [0:0] InclusiveDiv_gold_to_mem_waddr__val;
  logic [34:0] InclusiveDiv_gold_to_mem_wdata__msg;
  logic [0:0] InclusiveDiv_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] InclusiveDiv_gold_bits;
  assign InclusiveDiv_gold_bits={InclusiveDiv_gold_from_mem_rdata__rdy,InclusiveDiv_gold_recv_const__rdy,InclusiveDiv_gold_recv_from_ctrl_mem__rdy,InclusiveDiv_gold_recv_in__rdy[0],InclusiveDiv_gold_recv_in__rdy[1],InclusiveDiv_gold_recv_in__rdy[2],InclusiveDiv_gold_recv_in__rdy[3],InclusiveDiv_gold_recv_opt__rdy,InclusiveDiv_gold_send_out__msg[0],InclusiveDiv_gold_send_out__msg[1],InclusiveDiv_gold_send_out__val[0],InclusiveDiv_gold_send_out__val[1],InclusiveDiv_gold_send_to_ctrl_mem__msg,InclusiveDiv_gold_send_to_ctrl_mem__val,InclusiveDiv_gold_to_mem_raddr__msg,InclusiveDiv_gold_to_mem_raddr__val,InclusiveDiv_gold_to_mem_waddr__msg,InclusiveDiv_gold_to_mem_waddr__val,InclusiveDiv_gold_to_mem_wdata__msg,InclusiveDiv_gold_to_mem_wdata__val};
  ScalarRefInclusiveDivw32 InclusiveDiv_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(InclusiveDiv_gold_from_mem_rdata__rdy),
    .recv_const__rdy(InclusiveDiv_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(InclusiveDiv_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(InclusiveDiv_gold_recv_in__rdy),
    .recv_opt__rdy(InclusiveDiv_gold_recv_opt__rdy),
    .send_out__msg(InclusiveDiv_gold_send_out__msg),
    .send_out__val(InclusiveDiv_gold_send_out__val),
    .send_to_ctrl_mem__msg(InclusiveDiv_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(InclusiveDiv_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(InclusiveDiv_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(InclusiveDiv_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(InclusiveDiv_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(InclusiveDiv_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(InclusiveDiv_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(InclusiveDiv_gold_to_mem_wdata__val)
  );
  logic [0:0] ExclusiveDiv_dut_from_mem_rdata__rdy;
  logic [0:0] ExclusiveDiv_dut_recv_const__rdy;
  logic [0:0] ExclusiveDiv_dut_recv_from_ctrl_mem__rdy;
  logic [0:0] ExclusiveDiv_dut_recv_in__rdy [0:3];
  logic [0:0] ExclusiveDiv_dut_recv_opt__rdy;
  logic [34:0] ExclusiveDiv_dut_send_out__msg [0:1];
  logic [0:0] ExclusiveDiv_dut_send_out__val [0:1];
  logic [169:0] ExclusiveDiv_dut_send_to_ctrl_mem__msg;
  logic [0:0] ExclusiveDiv_dut_send_to_ctrl_mem__val;
  logic [6:0] ExclusiveDiv_dut_to_mem_raddr__msg;
  logic [0:0] ExclusiveDiv_dut_to_mem_raddr__val;
  logic [6:0] ExclusiveDiv_dut_to_mem_waddr__msg;
  logic [0:0] ExclusiveDiv_dut_to_mem_waddr__val;
  logic [34:0] ExclusiveDiv_dut_to_mem_wdata__msg;
  logic [0:0] ExclusiveDiv_dut_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] ExclusiveDiv_dut_bits;
  assign ExclusiveDiv_dut_bits={ExclusiveDiv_dut_from_mem_rdata__rdy,ExclusiveDiv_dut_recv_const__rdy,ExclusiveDiv_dut_recv_from_ctrl_mem__rdy,ExclusiveDiv_dut_recv_in__rdy[0],ExclusiveDiv_dut_recv_in__rdy[1],ExclusiveDiv_dut_recv_in__rdy[2],ExclusiveDiv_dut_recv_in__rdy[3],ExclusiveDiv_dut_recv_opt__rdy,ExclusiveDiv_dut_send_out__msg[0],ExclusiveDiv_dut_send_out__msg[1],ExclusiveDiv_dut_send_out__val[0],ExclusiveDiv_dut_send_out__val[1],ExclusiveDiv_dut_send_to_ctrl_mem__msg,ExclusiveDiv_dut_send_to_ctrl_mem__val,ExclusiveDiv_dut_to_mem_raddr__msg,ExclusiveDiv_dut_to_mem_raddr__val,ExclusiveDiv_dut_to_mem_waddr__msg,ExclusiveDiv_dut_to_mem_waddr__val,ExclusiveDiv_dut_to_mem_wdata__msg,ExclusiveDiv_dut_to_mem_wdata__val};
  scalar_exclusive_div #(.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16)) ExclusiveDiv_dut (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(ExclusiveDiv_dut_from_mem_rdata__rdy),
    .recv_const__rdy(ExclusiveDiv_dut_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(ExclusiveDiv_dut_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(ExclusiveDiv_dut_recv_in__rdy),
    .recv_opt__rdy(ExclusiveDiv_dut_recv_opt__rdy),
    .send_out__msg(ExclusiveDiv_dut_send_out__msg),
    .send_out__val(ExclusiveDiv_dut_send_out__val),
    .send_to_ctrl_mem__msg(ExclusiveDiv_dut_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(ExclusiveDiv_dut_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(ExclusiveDiv_dut_to_mem_raddr__msg),
    .to_mem_raddr__val(ExclusiveDiv_dut_to_mem_raddr__val),
    .to_mem_waddr__msg(ExclusiveDiv_dut_to_mem_waddr__msg),
    .to_mem_waddr__val(ExclusiveDiv_dut_to_mem_waddr__val),
    .to_mem_wdata__msg(ExclusiveDiv_dut_to_mem_wdata__msg),
    .to_mem_wdata__val(ExclusiveDiv_dut_to_mem_wdata__val)
  );
  logic [0:0] ExclusiveDiv_gold_from_mem_rdata__rdy;
  logic [0:0] ExclusiveDiv_gold_recv_const__rdy;
  logic [0:0] ExclusiveDiv_gold_recv_from_ctrl_mem__rdy;
  logic [0:0] ExclusiveDiv_gold_recv_in__rdy [0:3];
  logic [0:0] ExclusiveDiv_gold_recv_opt__rdy;
  logic [34:0] ExclusiveDiv_gold_send_out__msg [0:1];
  logic [0:0] ExclusiveDiv_gold_send_out__val [0:1];
  logic [169:0] ExclusiveDiv_gold_send_to_ctrl_mem__msg;
  logic [0:0] ExclusiveDiv_gold_send_to_ctrl_mem__val;
  logic [6:0] ExclusiveDiv_gold_to_mem_raddr__msg;
  logic [0:0] ExclusiveDiv_gold_to_mem_raddr__val;
  logic [6:0] ExclusiveDiv_gold_to_mem_waddr__msg;
  logic [0:0] ExclusiveDiv_gold_to_mem_waddr__val;
  logic [34:0] ExclusiveDiv_gold_to_mem_wdata__msg;
  logic [0:0] ExclusiveDiv_gold_to_mem_wdata__val;
  logic [OUTPUT_BITS-1:0] ExclusiveDiv_gold_bits;
  assign ExclusiveDiv_gold_bits={ExclusiveDiv_gold_from_mem_rdata__rdy,ExclusiveDiv_gold_recv_const__rdy,ExclusiveDiv_gold_recv_from_ctrl_mem__rdy,ExclusiveDiv_gold_recv_in__rdy[0],ExclusiveDiv_gold_recv_in__rdy[1],ExclusiveDiv_gold_recv_in__rdy[2],ExclusiveDiv_gold_recv_in__rdy[3],ExclusiveDiv_gold_recv_opt__rdy,ExclusiveDiv_gold_send_out__msg[0],ExclusiveDiv_gold_send_out__msg[1],ExclusiveDiv_gold_send_out__val[0],ExclusiveDiv_gold_send_out__val[1],ExclusiveDiv_gold_send_to_ctrl_mem__msg,ExclusiveDiv_gold_send_to_ctrl_mem__val,ExclusiveDiv_gold_to_mem_raddr__msg,ExclusiveDiv_gold_to_mem_raddr__val,ExclusiveDiv_gold_to_mem_waddr__msg,ExclusiveDiv_gold_to_mem_waddr__val,ExclusiveDiv_gold_to_mem_wdata__msg,ExclusiveDiv_gold_to_mem_wdata__val};
  ScalarRefExclusiveDivw32 ExclusiveDiv_gold (
    .clk(clk),
    .clear(clear),
    .reset(reset),
    .ctrl_addr_inport(ctrl_addr_inport),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__val(recv_opt__val),
    .send_out__rdy(send_out__rdy),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .from_mem_rdata__rdy(ExclusiveDiv_gold_from_mem_rdata__rdy),
    .recv_const__rdy(ExclusiveDiv_gold_recv_const__rdy),
    .recv_from_ctrl_mem__rdy(ExclusiveDiv_gold_recv_from_ctrl_mem__rdy),
    .recv_in__rdy(ExclusiveDiv_gold_recv_in__rdy),
    .recv_opt__rdy(ExclusiveDiv_gold_recv_opt__rdy),
    .send_out__msg(ExclusiveDiv_gold_send_out__msg),
    .send_out__val(ExclusiveDiv_gold_send_out__val),
    .send_to_ctrl_mem__msg(ExclusiveDiv_gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__val(ExclusiveDiv_gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(ExclusiveDiv_gold_to_mem_raddr__msg),
    .to_mem_raddr__val(ExclusiveDiv_gold_to_mem_raddr__val),
    .to_mem_waddr__msg(ExclusiveDiv_gold_to_mem_waddr__msg),
    .to_mem_waddr__val(ExclusiveDiv_gold_to_mem_waddr__val),
    .to_mem_wdata__msg(ExclusiveDiv_gold_to_mem_wdata__msg),
    .to_mem_wdata__val(ExclusiveDiv_gold_to_mem_wdata__val)
  );
  task automatic expect_math(input logic [DATA_W-1:0] got,expected,input string operation);
    if (got !== expected) $fatal(1,"SCALAR_MATH_MISMATCH %s cycle=%0d got=%h expected=%h",operation,cycle,got,expected);
    math_checks++;
  endtask
  initial begin
    $readmemh("reference/phase3/scalar/w32/vectors/inputs.hex",inputs);
    $readmemh("reference/phase3/scalar/w32/vectors/Const.hex",Const_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Comp.hex",Comp_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Logic.hex",Logic_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Shifter.hex",Shifter_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Sel.hex",Sel_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Phi.hex",Phi_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Grant.hex",Grant_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Gep.hex",Gep_python);
    $readmemh("reference/phase3/scalar/w32/vectors/ExtractPredicate.hex",ExtractPredicate_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Ret.hex",Ret_python);
    $readmemh("reference/phase3/scalar/w32/vectors/LoopCounter.hex",LoopCounter_python);
    $readmemh("reference/phase3/scalar/w32/vectors/LoopControl.hex",LoopControl_python);
    $readmemh("reference/phase3/scalar/w32/vectors/Div.hex",Div_python);
    for(cycle=0;cycle<CYCLES;cycle++) begin
      {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}=inputs[cycle];
      #2;
      if ($test$plusargs("NEGATIVE") && cycle==7) begin
        $display("SCALAR_NEGATIVE_CONTROL injecting one oracle output bit");
        Const_python[cycle][0]=~Const_python[cycle][0];
      end
      if (Const_dut_bits !== Const_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Const cycle=%0d dut=%h gold=%h",cycle,Const_dut_bits,Const_gold_bits);
      if (Const_dut_bits !== Const_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Const cycle=%0d dut=%h python=%h",cycle,Const_dut_bits,Const_python[cycle]);
      if (Comp_dut_bits !== Comp_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Comp cycle=%0d dut=%h gold=%h",cycle,Comp_dut_bits,Comp_gold_bits);
      if (Comp_dut_bits !== Comp_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Comp cycle=%0d dut=%h python=%h",cycle,Comp_dut_bits,Comp_python[cycle]);
      if (Logic_dut_bits !== Logic_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Logic cycle=%0d dut=%h gold=%h",cycle,Logic_dut_bits,Logic_gold_bits);
      if (Logic_dut_bits !== Logic_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Logic cycle=%0d dut=%h python=%h",cycle,Logic_dut_bits,Logic_python[cycle]);
      if (Shifter_dut_bits !== Shifter_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Shifter cycle=%0d dut=%h gold=%h",cycle,Shifter_dut_bits,Shifter_gold_bits);
      if (Shifter_dut_bits !== Shifter_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Shifter cycle=%0d dut=%h python=%h",cycle,Shifter_dut_bits,Shifter_python[cycle]);
      if (Sel_dut_bits !== Sel_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Sel cycle=%0d dut=%h gold=%h",cycle,Sel_dut_bits,Sel_gold_bits);
      if (Sel_dut_bits !== Sel_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Sel cycle=%0d dut=%h python=%h",cycle,Sel_dut_bits,Sel_python[cycle]);
      if (Phi_dut_bits !== Phi_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Phi cycle=%0d dut=%h gold=%h",cycle,Phi_dut_bits,Phi_gold_bits);
      if (Phi_dut_bits !== Phi_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Phi cycle=%0d dut=%h python=%h",cycle,Phi_dut_bits,Phi_python[cycle]);
      if (Grant_dut_bits !== Grant_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Grant cycle=%0d dut=%h gold=%h",cycle,Grant_dut_bits,Grant_gold_bits);
      if (Grant_dut_bits !== Grant_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Grant cycle=%0d dut=%h python=%h",cycle,Grant_dut_bits,Grant_python[cycle]);
      if (Gep_dut_bits !== Gep_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Gep cycle=%0d dut=%h gold=%h",cycle,Gep_dut_bits,Gep_gold_bits);
      if (Gep_dut_bits !== Gep_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Gep cycle=%0d dut=%h python=%h",cycle,Gep_dut_bits,Gep_python[cycle]);
      if (ExtractPredicate_dut_bits !== ExtractPredicate_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH ExtractPredicate cycle=%0d dut=%h gold=%h",cycle,ExtractPredicate_dut_bits,ExtractPredicate_gold_bits);
      if (ExtractPredicate_dut_bits !== ExtractPredicate_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH ExtractPredicate cycle=%0d dut=%h python=%h",cycle,ExtractPredicate_dut_bits,ExtractPredicate_python[cycle]);
      if (Ret_dut_bits !== Ret_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Ret cycle=%0d dut=%h gold=%h",cycle,Ret_dut_bits,Ret_gold_bits);
      if (Ret_dut_bits !== Ret_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Ret cycle=%0d dut=%h python=%h",cycle,Ret_dut_bits,Ret_python[cycle]);
      if (LoopCounter_dut_bits !== LoopCounter_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH LoopCounter cycle=%0d dut=%h gold=%h",cycle,LoopCounter_dut_bits,LoopCounter_gold_bits);
      if (LoopCounter_dut_bits !== LoopCounter_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH LoopCounter cycle=%0d dut=%h python=%h",cycle,LoopCounter_dut_bits,LoopCounter_python[cycle]);
      if (LoopControl_dut_bits !== LoopControl_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH LoopControl cycle=%0d dut=%h gold=%h",cycle,LoopControl_dut_bits,LoopControl_gold_bits);
      if (LoopControl_dut_bits !== LoopControl_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH LoopControl cycle=%0d dut=%h python=%h",cycle,LoopControl_dut_bits,LoopControl_python[cycle]);
      if (Div_dut_bits !== Div_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH Div cycle=%0d dut=%h gold=%h",cycle,Div_dut_bits,Div_gold_bits);
      if (Div_dut_bits !== Div_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH Div cycle=%0d dut=%h python=%h",cycle,Div_dut_bits,Div_python[cycle]);
      if (InclusiveDiv_dut_bits !== InclusiveDiv_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH InclusiveDiv cycle=%0d dut=%h gold=%h",cycle,InclusiveDiv_dut_bits,InclusiveDiv_gold_bits);
      if (ExclusiveDiv_dut_bits !== ExclusiveDiv_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH ExclusiveDiv cycle=%0d dut=%h gold=%h",cycle,ExclusiveDiv_dut_bits,ExclusiveDiv_gold_bits);
      if (recv_opt__val) begin
        case(ctrl_view.operation)
          7'd80: begin
            expect_math(Const_dut_send_out__msg[0][DATA_BITS-1:3],c,"OPT_CONST");
            if (Const_dut_recv_opt__rdy !== (Const_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Const cycle=%0d",cycle);
          end
          7'd8: begin
            expect_math(Logic_dut_send_out__msg[0][DATA_BITS-1:3],a|b,"OPT_OR");
            if (Logic_dut_recv_opt__rdy !== (Logic_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Logic cycle=%0d",cycle);
          end
          7'd10: begin
            expect_math(Logic_dut_send_out__msg[0][DATA_BITS-1:3],a&b,"OPT_AND");
            if (Logic_dut_recv_opt__rdy !== (Logic_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Logic cycle=%0d",cycle);
          end
          7'd9: begin
            expect_math(Logic_dut_send_out__msg[0][DATA_BITS-1:3],a^b,"OPT_XOR");
            if (Logic_dut_recv_opt__rdy !== (Logic_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Logic cycle=%0d",cycle);
          end
          7'd43: begin
            expect_math(Logic_dut_send_out__msg[0][DATA_BITS-1:3],~a,"OPT_BIT_NOT");
            if (Logic_dut_recv_opt__rdy !== (Logic_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Logic cycle=%0d",cycle);
          end
          7'd11: begin
            expect_math(Logic_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(!a),"OPT_NOT");
            if (Logic_dut_recv_opt__rdy !== (Logic_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Logic cycle=%0d",cycle);
          end
          7'd5: begin
            expect_math(Shifter_dut_send_out__msg[0][DATA_BITS-1:3],a<<b,"OPT_LLS");
            if (Shifter_dut_recv_opt__rdy !== (Shifter_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Shifter cycle=%0d",cycle);
          end
          7'd6: begin
            expect_math(Shifter_dut_send_out__msg[0][DATA_BITS-1:3],a>>b,"OPT_LRS");
            if (Shifter_dut_recv_opt__rdy !== (Shifter_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Shifter cycle=%0d",cycle);
          end
          7'd26: begin
            expect_math(Div_dut_send_out__msg[0][DATA_BITS-1:3],a/b,"OPT_DIV");
            if (Div_dut_recv_opt__rdy !== (Div_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Div cycle=%0d",cycle);
          end
          7'd65: begin
            expect_math(Div_dut_send_out__msg[0][DATA_BITS-1:3],a/c,"OPT_DIV_CONST");
            if (Div_dut_recv_opt__rdy !== (Div_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Div cycle=%0d",cycle);
          end
          7'd14: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(a==b),"OPT_EQ");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd45: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(a!=b),"OPT_NE");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd33: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(a==c),"OPT_EQ_CONST");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd46: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(a!=c),"OPT_NE_CONST");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd60: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'($signed(a)<$signed(b)),"OPT_LT");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd94: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'($signed(a)<$signed(c)),"OPT_LT_CONST");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd95: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'($signed(a)>$signed(c)),"OPT_GT_CONST");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          7'd93: begin
            expect_math(Comp_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'($signed(a)>=$signed(c)),"OPT_GTE_CONST");
            if (Comp_dut_recv_opt__rdy !== (Comp_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH Comp cycle=%0d",cycle);
          end
          default: ;
        endcase
      end
      if(cycle>=1755 && cycle<=1762) begin
        expect_math(InclusiveDiv_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(7),"pipeline InclusiveDiv 49"); pipeline_checks++;
      end
      if(cycle>=1787 && cycle<=1794) begin
        expect_math(InclusiveDiv_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(1),"pipeline InclusiveDiv 15"); pipeline_checks++;
      end
      if(cycle>=1803 && cycle<=1810) begin
        expect_math(ExclusiveDiv_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(7),"pipeline ExclusiveDiv 26"); pipeline_checks++;
      end
      if(cycle>=1819 && cycle<=1826) begin
        expect_math(ExclusiveDiv_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W'(1),"pipeline ExclusiveDiv 44"); pipeline_checks++;
      end
      #3; clk=1; #5; clk=0;
    end
    if(math_checks<100) $fatal(1,"SCALAR_CHECKER_COVERAGE math_checks=%0d",math_checks);
    if($test$plusargs("TIMEOUT_TEST")) wait(1'b0);
    $display("SCALAR_PASS profile=w32 cycles=%0d modules=15 python_modules=13 raw_output_bits=%0d math_checks=%0d pipeline_checks=%0d",CYCLES,OUTPUT_BITS,math_checks,pipeline_checks);
    $finish;
  end
  initial begin #1000000; $fatal(1,"SCALAR_TIMEOUT"); end
endmodule
