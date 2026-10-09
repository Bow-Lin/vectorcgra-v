"""One-time native vector outer-module authoring, not a build dependency."""
from pathlib import Path
from phase3_vector_port import load, shell, save

IDLE = '''
  assign to_mem_waddr__val = 0;
  assign to_mem_wdata__val = 0;
  assign to_mem_wdata__msg = '0;
  assign to_mem_waddr__msg = '0;
  assign to_mem_raddr__msg = '0;
  assign to_mem_raddr__val = 0;
  assign from_mem_rdata__rdy = 0;
'''
CTRL_IDLE = '''
  assign send_to_ctrl_mem__val = 0;
  assign send_to_ctrl_mem__msg = '0;
  assign recv_from_ctrl_mem__rdy = 0;
'''


def outer(case,body):
  raw=load(case).split('\n);',1)[0]+'\n);\n'+body+'\nendmodule'
  text=shell(raw,'tile_'+case,',\n  parameter int LANES = 4, VECTOR_FACTOR_POWER = 0')
  save(Path('vector')/('tile_'+case+'.sv'),text)


ADDER='''
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
    // The original connects these slices only. Extra operand/carry bits and
    // unused control fields are not silently zero-filled by this migration.
    assign operands[0][LANE_W-1:0] = recv_in__msg[0].payload[n*LANE_W+:LANE_W];
    assign operands[1][LANE_W-1:0] = recv_in__msg[1].payload[n*LANE_W+:LANE_W];
    assign constant[LANE_W-1:0] = recv_const__msg.payload[n*LANE_W+:LANE_W];
    assign operand_val[0] = recv_in__val[0];
    assign operand_val[1] = recv_in__val[1];
    assign send_out__msg[0].payload[n*LANE_W+:LANE_W] = lane_output[n][0][LANE_W-1:0];
    always_comb begin
      control.fu_in[0]=1;control.fu_in[1]=2;
      control.operation=7'd1;combine=0;
      case(recv_opt__msg.operation)
        51,71: begin control.operation=2;combine=(recv_opt__msg.operation==71);end
        53,73: begin control.operation=4;combine=(recv_opt__msg.operation==73);end
        // ac96 tests ADD_COMBINED here, not ADD_CONST_COMBINED; retain it.
        52,72: begin control.operation=25;combine=(recv_opt__msg.operation==71);end
        54,74: begin control.operation=36;combine=(recv_opt__msg.operation==74);end
        default: begin end
      endcase
    end
    cgra_vector_adder #(`CGRA_PROFILE_BIND,.LANE_W(LANE_W)) arithmetic (
      .clk,.reset,.carry_in(carry[n]),.carry_out(carry[n+1]),.combine_adder(combine),
      .recv_in__msg(operands),.recv_in__val(operand_val),.recv_in__rdy(lane_in_rdy[n]),
      .recv_const__msg(constant),.recv_const__val,.recv_const__rdy(lane_const_rdy[n]),
      .recv_opt__msg(control),.recv_opt__val,.recv_opt__rdy(lane_ctrl_rdy[n]),
      .send_out__msg(lane_output[n]),.send_out__val(lane_out_val[n]),.send_out__rdy);
  end
  assign recv_in__rdy[0]=lane_in_rdy[0][0];
  assign recv_in__rdy[1]=lane_in_rdy[0][1];
  assign recv_const__rdy=lane_const_rdy[0];
  assign recv_opt__rdy=lane_ctrl_rdy[0];
  always_comb begin
    send_out__val[0]=lane_out_val[0][0]&recv_opt__val;
    send_out__val[1]=0;
    send_out__msg[0].predicate=0;
    send_out__msg[1].predicate=0;
    case(recv_opt__msg.operation)
      51,71,53,73: send_out__msg[0].predicate=recv_in__msg[0].predicate & recv_in__msg[1].predicate;
      52,72,54,74: send_out__msg[0].predicate=recv_in__msg[0].predicate;
      default: send_out__val[0]=0;
    endcase
  end
'''+IDLE+CTRL_IDLE

MUL='''
  localparam int LANE_W = DATA_W / LANES;
  // ac96 RTLIR truncates multiplication in the shift-count expression.
  localparam int SHIFT_PRODUCT_W = ($clog2(LANE_W+1)>2)?$clog2(LANE_W+1):2;
  localparam logic [SHIFT_PRODUCT_W-1:0] SHIFT_TWO = LANE_W*2;
  localparam logic [SHIFT_PRODUCT_W-1:0] SHIFT_THREE = LANE_W*3;
  initial if (LANES < 4 || LANES % 4 != 0 || DATA_W % LANES != 0)
    $fatal(1,"VectorMulCombo requires LANES multiple of four dividing DATA_W");
  // ac96 allocates LANES but its data routing uses only lanes 0..3.
  logic lane_in_rdy [0:LANES-1][0:3];
  logic lane_const_rdy [0:LANES-1], lane_ctrl_rdy [0:LANES-1];
  logic lane_out_val [0:LANES-1][0:1];
  logic [2*LANE_W-1:0] lane_output [0:LANES-1][0:1];
  logic [DATA_W-1:0] product [0:LANES-1];
  for(genvar n=0;n<LANES;n++) begin : lanes
    logic [2*LANE_W-1:0] operands [0:3], constant;
    logic operand_val [0:3];
    ctrl_t control;
    always_comb begin
      operands[0]='0;operands[1]='0;
      if(n<4) begin
        if(recv_opt__msg.operation==55) begin
          operands[0][LANE_W-1:0]=recv_in__msg[0].payload[n*LANE_W+:LANE_W];
          operands[1][LANE_W-1:0]=recv_in__msg[1].payload[n*LANE_W+:LANE_W];
        end else if(recv_opt__msg.operation==75) begin
          operands[0][LANE_W-1:0]=recv_in__msg[0].payload[(n/2)*LANE_W+:LANE_W];
          operands[1][LANE_W-1:0]=recv_in__msg[1].payload[(n%2)*LANE_W+:LANE_W];
        end
      end
      control.fu_in[0]=1;control.fu_in[1]=2;
      control.operation=7'd1;
      if(recv_opt__msg.operation==55||recv_opt__msg.operation==75)control.operation=7'd7;
    end
    assign operand_val[0]=recv_in__val[0];
    assign operand_val[1]=recv_in__val[1];
    assign product[n]=DATA_W'(lane_output[n][0]);
    cgra_vector_mul #(`CGRA_PROFILE_BIND,.LANE_W(LANE_W)) arithmetic (
      .clk,.reset,.recv_in__msg(operands),.recv_in__val(operand_val),.recv_in__rdy(lane_in_rdy[n]),
      .recv_const__msg(constant),.recv_const__val,.recv_const__rdy(lane_const_rdy[n]),
      .recv_opt__msg(control),.recv_opt__val,.recv_opt__rdy(lane_ctrl_rdy[n]),
      .send_out__msg(lane_output[n]),.send_out__val(lane_out_val[n]),.send_out__rdy);
  end
  assign recv_in__rdy[0]=lane_in_rdy[0][0];
  assign recv_in__rdy[1]=lane_in_rdy[0][1];
  assign recv_const__rdy=lane_const_rdy[0];
  assign recv_opt__rdy=send_out__rdy[0];
  always_comb begin
    send_out__val[0]=lane_out_val[0][0]&recv_opt__val;
    send_out__val[1]=0;
    send_out__msg[0].payload='0;
    send_out__msg[0].predicate=0;
    case(recv_opt__msg.operation)
      55: send_out__msg[0].payload=(product[3]<<SHIFT_THREE)+(product[2]<<SHIFT_TWO)+(product[1]<<LANE_W)+product[0];
      75: send_out__msg[0].payload=product[0]+(product[1]<<LANE_W)+(product[2]<<LANE_W)+(product[3]<<SHIFT_TWO);
      default: send_out__val[0]=0;
    endcase
    if(recv_opt__msg.operation==55||recv_opt__msg.operation==75)
      send_out__msg[0].predicate=recv_in__msg[0].predicate&recv_in__msg[1].predicate;
  end
'''+IDLE+CTRL_IDLE

REDUCE='''
  localparam int LANE_W=DATA_W/LANES;
  initial if(LANES<4||LANES%4!=0||DATA_W%LANES!=0)
    $fatal(1,"VectorAllReduce requires LANES multiple of four dividing DATA_W");
  logic already_sent_to_controller;
  logic [DATA_W-1:0] reduced_add, reduced_mul;
  logic add_op, mul_op, local_plain, local_base, global_plain, global_base, global_op;
  assign add_op=recv_opt__msg.operation==56||recv_opt__msg.operation==68||recv_opt__msg.operation==76||recv_opt__msg.operation==78;
  assign mul_op=recv_opt__msg.operation==57||recv_opt__msg.operation==69||recv_opt__msg.operation==77||recv_opt__msg.operation==79;
  assign local_plain=recv_opt__msg.operation==56||recv_opt__msg.operation==57;
  assign local_base=recv_opt__msg.operation==68||recv_opt__msg.operation==69;
  assign global_plain=recv_opt__msg.operation==76||recv_opt__msg.operation==77;
  assign global_base=recv_opt__msg.operation==78||recv_opt__msg.operation==79;
  assign global_op=global_plain||global_base;
  always_comb begin
    reduced_add='0;reduced_mul=DATA_W'(1);
    for(int lane=0;lane<LANES;lane++) begin
      reduced_add=reduced_add+(add_op ? DATA_W'(recv_in__msg[0].payload[lane*LANE_W+:LANE_W]) : DATA_W'(0));
      reduced_mul=reduced_mul*(mul_op ? DATA_W'(recv_in__msg[0].payload[lane*LANE_W+:LANE_W]) : DATA_W'(0));
    end
  end
  always_comb begin
    send_out__msg[0].payload='0;
    case(recv_opt__msg.operation)
      56:send_out__msg[0].payload=reduced_add;
      68:send_out__msg[0].payload=reduced_add+recv_in__msg[1].payload;
      57:send_out__msg[0].payload=reduced_mul;
      69:send_out__msg[0].payload=reduced_mul*recv_in__msg[1].payload;
      76,77:send_out__msg[0].payload=recv_from_ctrl_mem__msg.data.payload;
      78:send_out__msg[0].payload=recv_from_ctrl_mem__msg.data.payload+recv_in__msg[1].payload;
      79:send_out__msg[0].payload=recv_from_ctrl_mem__msg.data.payload*recv_in__msg[1].payload;
      default:begin end
    endcase
    send_out__msg[0].predicate=0;
    if(local_plain)send_out__msg[0].predicate=recv_in__msg[0].predicate;
    else if(local_base)send_out__msg[0].predicate=recv_in__msg[0].predicate&recv_in__msg[1].predicate;
    else if(global_base)send_out__msg[0].predicate=recv_from_ctrl_mem__msg.data.predicate&recv_in__msg[1].predicate;
  end
  always_comb begin
    for(int n=0;n<4;n++)recv_in__rdy[n]=0;
    send_to_ctrl_mem__val=0;send_to_ctrl_mem__msg='0;recv_from_ctrl_mem__rdy=0;
    recv_in__rdy[0]=((local_plain||local_base)&send_out__rdy[0])|(global_op&send_to_ctrl_mem__rdy);
    recv_opt__rdy=send_out__rdy[0];
    // Original duplicate MUL_BASE_GLOBAL comparison excludes ADD_BASE_GLOBAL.
    recv_in__rdy[1]=(local_base&send_out__rdy[0])|((recv_opt__msg.operation==79)&send_to_ctrl_mem__rdy);
    send_out__val[0]=(recv_in__val[0]&recv_opt__val&local_plain)|
      (recv_in__val[0]&recv_in__val[1]&recv_opt__val&local_base)|
      (recv_opt__val&recv_from_ctrl_mem__val&global_plain)|
      (recv_opt__val&recv_from_ctrl_mem__val&recv_in__val[1]&global_base);
    // Parentheses intentionally preserve ac96's precedence: the base branch
    // bypasses recv_opt.val and already_sent_to_controller gating.
    if((recv_opt__val&~already_sent_to_controller&recv_in__val[0]&global_plain)|
       (recv_in__val[0]&recv_in__val[1]&global_base)) begin
      send_to_ctrl_mem__val=1;
      send_to_ctrl_mem__msg.cmd=add_op ? 6'd18 : 6'd19;
      // ac96 also uses reduced_add for global MUL (therefore zero there).
      send_to_ctrl_mem__msg.data.payload=reduced_add;
      send_to_ctrl_mem__msg.data.predicate=recv_in__msg[0].predicate;
      send_to_ctrl_mem__msg.ctrl=recv_opt__msg;
    end
    if(recv_opt__val&already_sent_to_controller)recv_from_ctrl_mem__rdy=1;
  end
  always_ff @(posedge clk) begin
    if(reset)already_sent_to_controller<=0;
    else if(recv_opt__val&global_op&~already_sent_to_controller&send_to_ctrl_mem__val&send_to_ctrl_mem__rdy)
      already_sent_to_controller<=1;
    else if(recv_opt__val&global_op&already_sent_to_controller&recv_opt__rdy)
      already_sent_to_controller<=0;
  end
  // recv_const.rdy, output1, output0 bypass/delay remain undriven as in ac96.
'''+IDLE


if __name__=='__main__':
  outer('vector_adder_combo',ADDER)
  outer('vector_mul_combo',MUL)
  outer('vector_all_reduce',REDUCE)
