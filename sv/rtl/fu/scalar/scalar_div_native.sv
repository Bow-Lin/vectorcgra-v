`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// Defined unsigned division, valid-tracked pipeline results and explicit reset cancellation.
module scalar_div_native #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int VECTOR_FACTOR_POWER = 0,
  parameter int MODE = 0, LATENCY = 1
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
  ctrl_t control;
  data_t inputs[0:3],constant_data,outputs[0:1];
  logic [1:0] sel0,sel1;
  logic selection_valid,flush,reached,operand_valid,predicate;
  logic [7:0] vector_count;
  logic [8:0] vector_next,vector_limit;
  logic [DATA_W-1:0] a,b;
  assign control=recv_opt__msg;
  assign inputs=recv_in__msg;
  assign constant_data=recv_const__msg;
  assign send_out__msg=outputs;
  assign sel0=control.fu_in[0]==0 ? 2'd0 : 2'(control.fu_in[0]-1);
  assign sel1=control.fu_in[1]==0 ? 2'd0 : 2'(control.fu_in[1]-1);
  assign selection_valid=control.fu_in[0]<=4 && (MODE==0 && control.operation==65 || control.fu_in[1]<=4);
  assign a=inputs[sel0].payload;
  assign b=MODE==0 && control.operation==65 ? constant_data.payload : inputs[sel1].payload;
  assign operand_valid=recv_in__val[sel0] && (MODE==0 && control.operation==65 ? recv_const__val : recv_in__val[sel1]);
  assign predicate=inputs[sel0].predicate && (MODE==0 && control.operation==65 || inputs[sel1].predicate) && reached;
  assign flush=reset || clear;
  assign vector_next={1'b0,vector_count}+(9'd1<<VECTOR_FACTOR_POWER);
  assign vector_limit=9'd1<<control.vector_factor_power;
  assign reached=vector_next>=vector_limit;
  initial begin
    if (MODE<0 || MODE>2 || DATA_W<1 || VECTOR_FACTOR_POWER<0 || VECTOR_FACTOR_POWER>7)
      $fatal(1,"DIV_NATIVE_PARAMETERS");
    if (MODE!=0 && (DATA_W!=32 || LATENCY<1 || LATENCY>DATA_W))
      $fatal(1,"DIV_NATIVE_PIPELINE_PARAMETERS: DATA_W=32 and 1 <= LATENCY <= DATA_W");
  end
  // A vector replay completes when this FU retires its control transaction.
  always_ff @(posedge clk) begin
    if (flush) vector_count<=0;
    else if (recv_opt__val && recv_opt__rdy && control.is_last_ctrl)
      vector_count<=reached ? 8'd0 : vector_next[7:0];
  end
  assign recv_from_ctrl_mem__rdy=0;
  assign send_to_ctrl_mem__msg='0;
  assign send_to_ctrl_mem__val=0;
  assign from_mem_rdata__rdy=0;
  assign to_mem_raddr__msg='0;
  assign to_mem_raddr__val=0;
  assign to_mem_waddr__msg='0;
  assign to_mem_waddr__val=0;
  assign to_mem_wdata__msg='0;
  assign to_mem_wdata__val=0;

  if (MODE==0 || MODE==1 && LATENCY==1) begin : combinational_division
    always_comb begin
      outputs[0]='0;outputs[1]='0;
      send_out__val[0]=0;send_out__val[1]=0;
      for(integer i=0;i<4;i++) recv_in__rdy[i]=0;
      recv_opt__rdy=0;recv_const__rdy=0;
      if (!flush && recv_opt__val && selection_valid &&
          (control.operation==26 || MODE==0 && control.operation==65 || MODE==1 && control.operation==44)) begin
        if (control.operation==44) outputs[0].payload=b==0 ? a : a%b;
        else outputs[0].payload=b==0 ? {DATA_W{1'b1}} : a/b;
        outputs[0].predicate=predicate;
        send_out__val[0]=operand_valid;
        recv_opt__rdy=operand_valid && send_out__rdy[0];
        recv_in__rdy[sel0]=recv_opt__rdy;
        if (control.operation==65) recv_const__rdy=recv_opt__rdy;
        else recv_in__rdy[sel1]=recv_opt__rdy;
      end
    end
  end else if (MODE==1) begin : exclusive_division
    localparam int COUNT_W=$clog2(LATENCY+1);
    logic busy,held_predicate,held_remainder,launch;
    logic [1:0] held_sel0,held_sel1;
    logic [COUNT_W-1:0] remaining;
    logic [DATA_W-1:0] held_a,held_b,pipe_a,pipe_b,quotient,remainder;
    assign launch=!flush && !busy && recv_opt__val && selection_valid && operand_valid &&
      (control.operation==26 || control.operation==44);
    assign pipe_a=busy ? held_a : a;
    assign pipe_b=busy ? held_b : b;
    scalar_div_pipeline #(.WIDTH(DATA_W),.CYCLE(LATENCY)) pipeline(
      .clk,.reset(flush),.dividend(pipe_a),.divisor(pipe_b),.quotient,.remainder);
    always_comb begin
      outputs[0]='0;outputs[1]='0;send_out__val[0]=0;send_out__val[1]=0;
      for(integer i=0;i<4;i++) recv_in__rdy[i]=0;
      recv_opt__rdy=0;recv_const__rdy=0;
      if (!flush && busy && remaining==0) begin
        outputs[0].payload=held_remainder ? remainder : quotient;
        outputs[0].predicate=held_predicate;
        send_out__val[0]=1;
        recv_opt__rdy=send_out__rdy[0];
        recv_in__rdy[held_sel0]=send_out__rdy[0];
        recv_in__rdy[held_sel1]=send_out__rdy[0];
      end
    end
    always_ff @(posedge clk) begin
      if (flush) begin
        busy<=0;remaining<=0;held_a<=0;held_b<=0;
        held_predicate<=0;held_remainder<=0;held_sel0<=0;held_sel1<=0;
      end else if (launch) begin
        busy<=1;remaining<=COUNT_W'(LATENCY-2);held_a<=a;held_b<=b;
        held_predicate<=predicate;held_remainder<=control.operation==44;
        held_sel0<=sel0;held_sel1<=sel1;
      end else if (busy) begin
        if (remaining!=0) remaining<=remaining-1'b1;
        else if (send_out__rdy[0]) busy<=0;
      end
    end
  end else begin : inclusive_division
    // START/END retain the source's input0 token and input1 snooping contract.
    // Capacity counts both in-flight and returned results, preventing overwrite.
    localparam int CAPACITY=LATENCY,COUNT_W=$clog2(CAPACITY+1),PTR_W=CAPACITY>1 ? $clog2(CAPACITY) : 1;
    logic [COUNT_W-1:0] outstanding,available;
    logic [PTR_W-1:0] rdptr,wrptr;
    logic [DATA_W-1:0] quotient,remainder,q_fifo[CAPACITY],r_fifo[CAPACITY];
    logic pred_fifo[CAPACITY];
    logic start_op,end_op,take_start,take_end,arrival,arrived_predicate;
    assign start_op=control.operation==48 || control.operation==59;
    assign end_op=control.operation==49 || control.operation==15;
    scalar_div_pipeline #(.WIDTH(DATA_W),.CYCLE(LATENCY)) pipeline(
      .clk,.reset(flush),.dividend(a),.divisor(b),.quotient,.remainder);
    if (LATENCY==1) begin : direct_arrival
      assign arrival=take_start;
      assign arrived_predicate=predicate;
    end else begin : delayed_arrival
      logic [LATENCY-2:0] valid_pipe,pred_pipe;
      assign arrival=valid_pipe[LATENCY-2];
      assign arrived_predicate=pred_pipe[LATENCY-2];
      always_ff @(posedge clk) begin
        if (flush) begin valid_pipe<=0;pred_pipe<=0;end
        else begin
          valid_pipe[0]<=take_start;pred_pipe[0]<=predicate;
          for(integer i=1;i<LATENCY-1;i++) begin
            valid_pipe[i]<=valid_pipe[i-1];pred_pipe[i]<=pred_pipe[i-1];
          end
        end
      end
    end
    always_comb begin
      outputs[0]='0;outputs[1]='0;send_out__val[0]=0;send_out__val[1]=0;
      for(integer i=0;i<4;i++) recv_in__rdy[i]=0;
      recv_opt__rdy=0;recv_const__rdy=0;take_start=0;take_end=0;
      if (!flush && recv_opt__val && selection_valid && operand_valid) begin
        if (start_op && outstanding<COUNT_W'(CAPACITY)) begin
          outputs[0].predicate=predicate;send_out__val[0]=1;
          take_start=send_out__rdy[0];
        end else if (end_op && available!=0) begin
          outputs[0].payload=control.operation==49 ? q_fifo[rdptr] : r_fifo[rdptr];
          outputs[0].predicate=pred_fifo[rdptr];send_out__val[0]=1;
          take_end=send_out__rdy[0];
        end
        recv_in__rdy[sel0]=take_start || take_end;
        recv_opt__rdy=take_start || take_end;
      end
    end
    always_ff @(posedge clk) begin
      if (flush) begin
        outstanding<=0;available<=0;rdptr<=0;wrptr<=0;
        for(integer i=0;i<CAPACITY;i++) begin q_fifo[i]<=0;r_fifo[i]<=0;pred_fifo[i]<=0;end
      end else begin
        case ({take_start,take_end})
          2'b10:outstanding<=outstanding+1'b1;
          2'b01:outstanding<=outstanding-1'b1;
          default:begin end
        endcase
        case ({arrival,take_end})
          2'b10:available<=available+1'b1;
          2'b01:available<=available-1'b1;
          default:begin end
        endcase
        if (arrival) begin
          q_fifo[wrptr]<=quotient;r_fifo[wrptr]<=remainder;pred_fifo[wrptr]<=arrived_predicate;
          wrptr<=wrptr==PTR_W'(CAPACITY-1) ? PTR_W'(0) : wrptr+1'b1;
        end
        if (take_end) rdptr<=rdptr==PTR_W'(CAPACITY-1) ? PTR_W'(0) : rdptr+1'b1;
      end
    end
  end
endmodule
