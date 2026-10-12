`include "cgra_profile_defs.svh"
// Native reduction transactions, with explicit compatibility for pinned Python defects.
module tile_vector_all_reduce #(
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

  localparam int LANE_W=DATA_W/LANES;
  `ifndef SYNTHESIS
  initial if(LANES<4||LANES%4!=0||DATA_W%LANES!=0)
    $fatal(1,"VectorAllReduce requires LANES multiple of four dividing DATA_W");
  `endif
  logic already_sent_to_controller;
  logic [DATA_W-1:0] reduced_add, reduced_mul;
  logic add_op, mul_op, local_plain, local_base, global_plain, global_base, global_op;
  assign add_op=p_recv_opt__msg.operation==56||p_recv_opt__msg.operation==68||p_recv_opt__msg.operation==76||p_recv_opt__msg.operation==78;
  assign mul_op=p_recv_opt__msg.operation==57||p_recv_opt__msg.operation==69||p_recv_opt__msg.operation==77||p_recv_opt__msg.operation==79;
  assign local_plain=p_recv_opt__msg.operation==56||p_recv_opt__msg.operation==57;
  assign local_base=p_recv_opt__msg.operation==68||p_recv_opt__msg.operation==69;
  assign global_plain=p_recv_opt__msg.operation==76||p_recv_opt__msg.operation==77;
  assign global_base=p_recv_opt__msg.operation==78||p_recv_opt__msg.operation==79;
  assign global_op=global_plain||global_base;
  always_comb begin
    reduced_add='0;reduced_mul=DATA_W'(1);
    for(int lane=0;lane<LANES;lane++) begin
      reduced_add=reduced_add+(add_op ? DATA_W'(p_recv_in__msg[0].payload[lane*LANE_W+:LANE_W]) : DATA_W'(0));
      reduced_mul=reduced_mul*(mul_op ? DATA_W'(p_recv_in__msg[0].payload[lane*LANE_W+:LANE_W]) : DATA_W'(0));
    end
  end
  generate if (LEGACY_PYTHON) begin : legacy
    initial already_sent_to_controller=0;
  always_comb begin
    p_send_out__msg[0].payload='0;
    case(p_recv_opt__msg.operation)
      56:p_send_out__msg[0].payload=reduced_add;
      68:p_send_out__msg[0].payload=reduced_add+p_recv_in__msg[1].payload;
      57:p_send_out__msg[0].payload=reduced_mul;
      69:p_send_out__msg[0].payload=reduced_mul*p_recv_in__msg[1].payload;
      76,77:p_send_out__msg[0].payload=p_recv_from_ctrl_mem__msg.data.payload;
      78:p_send_out__msg[0].payload=p_recv_from_ctrl_mem__msg.data.payload+p_recv_in__msg[1].payload;
      79:p_send_out__msg[0].payload=p_recv_from_ctrl_mem__msg.data.payload*p_recv_in__msg[1].payload;
      default:begin end
    endcase
    p_send_out__msg[0].predicate=0;
    if(local_plain)p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate;
    else if(local_base)p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate&p_recv_in__msg[1].predicate;
    else if(global_base)p_send_out__msg[0].predicate=p_recv_from_ctrl_mem__msg.data.predicate&p_recv_in__msg[1].predicate;
  end
  always_comb begin
    for(int n=0;n<4;n++)recv_in__rdy[n]=0;
    send_to_ctrl_mem__val=0;p_send_to_ctrl_mem__msg='0;recv_from_ctrl_mem__rdy=0;
    recv_in__rdy[0]=((local_plain||local_base)&send_out__rdy[0])|(global_op&send_to_ctrl_mem__rdy);
    recv_opt__rdy=send_out__rdy[0];
    // Original duplicate MUL_BASE_GLOBAL comparison excludes ADD_BASE_GLOBAL.
    recv_in__rdy[1]=(local_base&send_out__rdy[0])|((p_recv_opt__msg.operation==79)&send_to_ctrl_mem__rdy);
    send_out__val[0]=(recv_in__val[0]&recv_opt__val&local_plain)|
      (recv_in__val[0]&recv_in__val[1]&recv_opt__val&local_base)|
      (recv_opt__val&recv_from_ctrl_mem__val&global_plain)|
      (recv_opt__val&recv_from_ctrl_mem__val&recv_in__val[1]&global_base);
    // Parentheses intentionally preserve ac96's precedence: the base branch
    // bypasses recv_opt.val and already_sent_to_controller gating.
    if((recv_opt__val&~already_sent_to_controller&recv_in__val[0]&global_plain)|
       (recv_in__val[0]&recv_in__val[1]&global_base)) begin
      send_to_ctrl_mem__val=1;
      p_send_to_ctrl_mem__msg.cmd=add_op ? 6'd18 : 6'd19;
      // ac96 also uses reduced_add for global MUL (therefore zero there).
      p_send_to_ctrl_mem__msg.data.payload=reduced_add;
      p_send_to_ctrl_mem__msg.data.predicate=p_recv_in__msg[0].predicate;
      p_send_to_ctrl_mem__msg.ctrl=p_recv_opt__msg;
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
  end else begin : native_mode
    logic pending,draining,pending_is_mul,pending_has_base;
    data_t pending_base;
    always_comb begin
      for (integer i=0;i<4;i++) recv_in__rdy[i]=0;
      recv_opt__rdy=0;recv_from_ctrl_mem__rdy=0;
      send_out__val[0]=0;p_send_out__msg[0].payload='0;p_send_out__msg[0].predicate=0;
      send_to_ctrl_mem__val=0;p_send_to_ctrl_mem__msg='0;
      if (!reset && !clear) begin
        if (draining) begin
          // A per-FU clear cannot retract a request already accepted remotely.
          // Discard that response before allowing another reduction transaction.
          recv_from_ctrl_mem__rdy=1;
        end else if (pending) begin
          recv_from_ctrl_mem__rdy=recv_opt__val && send_out__rdy[0];
          send_out__val[0]=recv_opt__val && recv_from_ctrl_mem__val;
          recv_opt__rdy=send_out__val[0] && send_out__rdy[0];
          if (send_out__val[0]) begin
            p_send_out__msg[0].payload=p_recv_from_ctrl_mem__msg.data.payload;
            p_send_out__msg[0].predicate=p_recv_from_ctrl_mem__msg.data.predicate;
            if (pending_has_base) begin
              p_send_out__msg[0].payload=pending_is_mul
                ? p_recv_from_ctrl_mem__msg.data.payload*pending_base.payload
                : p_recv_from_ctrl_mem__msg.data.payload+pending_base.payload;
              p_send_out__msg[0].predicate=p_recv_from_ctrl_mem__msg.data.predicate && pending_base.predicate;
            end
          end
        end else if (recv_opt__val && (local_plain || local_base)) begin
          send_out__val[0]=recv_in__val[0] && (!local_base || recv_in__val[1]);
          recv_in__rdy[0]=send_out__rdy[0] && (!local_base || recv_in__val[1]);
          recv_in__rdy[1]=local_base && send_out__rdy[0] && recv_in__val[0];
          recv_opt__rdy=send_out__val[0] && send_out__rdy[0];
          if (send_out__val[0]) begin
            p_send_out__msg[0].payload=mul_op ? reduced_mul : reduced_add;
            p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate;
            if (local_base) begin
              p_send_out__msg[0].payload=mul_op
                ? reduced_mul*p_recv_in__msg[1].payload
                : reduced_add+p_recv_in__msg[1].payload;
              p_send_out__msg[0].predicate=p_recv_in__msg[0].predicate && p_recv_in__msg[1].predicate;
            end
          end
        end else if (recv_opt__val && global_op) begin
          send_to_ctrl_mem__val=recv_in__val[0] && (!global_base || recv_in__val[1]);
          recv_in__rdy[0]=send_to_ctrl_mem__rdy && (!global_base || recv_in__val[1]);
          recv_in__rdy[1]=global_base && send_to_ctrl_mem__rdy && recv_in__val[0];
          if (send_to_ctrl_mem__val) begin
            p_send_to_ctrl_mem__msg.cmd=mul_op ? 6'd19 : 6'd18;
            p_send_to_ctrl_mem__msg.data.payload=mul_op ? reduced_mul : reduced_add;
            p_send_to_ctrl_mem__msg.data.predicate=p_recv_in__msg[0].predicate;
            p_send_to_ctrl_mem__msg.ctrl=p_recv_opt__msg;
          end
        end
      end
    end
    always @(posedge clk) begin
      if (reset) begin
        pending<=0;draining<=0;pending_is_mul<=0;pending_has_base<=0;pending_base<='0;
      end else if (clear) begin
        draining<=draining || pending;pending<=0;
        pending_is_mul<=0;pending_has_base<=0;pending_base<='0;
      end else begin
        if (draining && recv_from_ctrl_mem__val && recv_from_ctrl_mem__rdy) draining<=0;
        if (send_to_ctrl_mem__val && send_to_ctrl_mem__rdy) begin
          pending<=1;pending_is_mul<=mul_op;pending_has_base<=global_base;
          pending_base<=p_recv_in__msg[1];
        end else if (pending && send_out__val[0] && send_out__rdy[0]) pending<=0;
      end
    end
  end endgenerate
  // The source leaves these fields undriven (zero in PyMTL simulation).
  assign recv_const__rdy=0;
  assign send_out__val[1]=0;
  assign p_send_out__msg[1]='0;
  assign p_send_out__msg[0].bypass=0;
  assign p_send_out__msg[0].delay=0;


  assign to_mem_waddr__val = 0;
  assign to_mem_wdata__val = 0;
  assign p_to_mem_wdata__msg = '0;
  assign to_mem_waddr__msg = '0;
  assign to_mem_raddr__msg = '0;
  assign to_mem_raddr__val = 0;
  assign from_mem_rdata__rdy = 0;

endmodule
