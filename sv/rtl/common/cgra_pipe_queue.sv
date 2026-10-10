// Standalone PipeQueueRTL: registered data path, combinational ready bypass.
// A full queue can dequeue its head and accept its replacement on the same edge.
module cgra_pipe_queue #(
  parameter integer DATA_BITS=35,DEPTH=2,
  parameter bit LEGACY_PYTHON=0,
  parameter integer COUNT_W=(DEPTH>0)?$clog2(DEPTH+1):1,
  parameter integer ADDR_W=(DEPTH>1)?$clog2(DEPTH):1
)(
  input logic clk,reset,
  input logic [DATA_BITS-1:0] recv__msg,
  input logic recv__val,
  output logic recv__rdy,
  output logic [DATA_BITS-1:0] send__msg,
  output logic send__val,
  input logic send__rdy,
  output logic [COUNT_W-1:0] count
);
  logic [COUNT_W-1:0] used;
  logic [ADDR_W-1:0] head,tail;
  logic [DATA_BITS-1:0] storage [0:DEPTH-1];
  logic push,pop;
  assign recv__rdy=(LEGACY_PYTHON || !reset) && ((used<DEPTH) || send__rdy);
  assign send__val=(LEGACY_PYTHON || !reset) && (used!=0);
  assign send__msg=(LEGACY_PYTHON || send__val) ? storage[head] : '0;
  assign count=(!LEGACY_PYTHON && reset) ? '0 : used;
  assign push=recv__val && recv__rdy;
  assign pop=send__val && send__rdy;
  generate if (LEGACY_PYTHON) begin : legacy_initial
    initial begin
      used='0;head='0;tail='0;
      for (integer i=0;i<DEPTH;i++) storage[i]='0;
    end
  end endgenerate
  always @(posedge clk) begin
    // Legacy Python writes data during reset even though occupancy is cleared.
    if (push) storage[tail]<=recv__msg;
    if (reset) begin used<='0;head<='0;tail<='0;end
    else begin
      if (push) tail<=(tail==DEPTH-1)?'0:tail+1'b1;
      if (pop) head<=(head==DEPTH-1)?'0:head+1'b1;
      case ({push,pop})
        2'b10: used<=used+1'b1;
        2'b01: used<=used-1'b1;
        default: ;
      endcase
    end
  end
`ifndef SYNTHESIS
  initial if (DATA_BITS<1 || DEPTH<1 || COUNT_W!=((DEPTH>0)?$clog2(DEPTH+1):1) ||
              ADDR_W!=((DEPTH>1)?$clog2(DEPTH):1)) $fatal(1,"PIPE_QUEUE_PARAMETER");
`endif
endmodule
