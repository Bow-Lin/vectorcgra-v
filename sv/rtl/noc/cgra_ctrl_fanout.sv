// A buffered, acyclic fork. Each FIFO head is delivered once per selected child.
// LAYOUT=1 balances leaf count; LAYOUT=2 splits complete rows before columns.
module cgra_ctrl_fanout #(
  parameter int WIDTH=32, LEAVES=4, COLS=2, LAYOUT=1, DEPTH=2
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg,
  input logic [LEAVES-1:0] recv_mask,
  input logic recv_val,
  output logic recv_rdy,
  output logic [WIDTH-1:0] send_msg [0:LEAVES-1],
  output logic send_val [0:LEAVES-1],
  input logic send_rdy [0:LEAVES-1]
);
  logic [WIDTH+LEAVES-1:0] head;
  logic head_val, head_rdy;
  cgra_queue #(.WIDTH(WIDTH+LEAVES),.DEPTH(DEPTH)) input_fifo (
    .clk,.reset,.clear(1'b0),.recv_msg({recv_mask,recv_msg}),.recv_val,
    .recv_rdy,.send_msg(head),.send_val(head_val),.send_rdy(head_rdy),.count());
  if(LEAVES==1) begin : leaf
    assign send_msg[0]=head[WIDTH-1:0];
    assign send_val[0]=head_val && head[WIDTH];
    assign head_rdy=!head[WIDTH] || send_rdy[0];
  end else begin : split
    localparam int LEFT=(LAYOUT==2 && LEAVES>COLS) ?
      ((LEAVES/COLS+1)/2)*COLS : (LEAVES+1)/2;
    localparam int RIGHT=LEAVES-LEFT;
    logic [1:0] delivered, needed, child_valid, child_ready;
    logic [WIDTH-1:0] left_msg [0:LEFT-1], right_msg [0:RIGHT-1];
    logic left_val [0:LEFT-1], left_rdy [0:LEFT-1];
    logic right_val [0:RIGHT-1], right_rdy [0:RIGHT-1];
    assign needed[0]=|head[WIDTH+:LEFT];
    assign needed[1]=|head[WIDTH+LEFT+:RIGHT];
    assign child_valid={2{head_val}} & needed & ~delivered;
    assign head_rdy=(&(~needed | delivered | (child_valid & child_ready)));
    always_ff @(posedge clk) begin
      if(reset || (head_val && head_rdy)) delivered<='0;
      else delivered<=delivered | (child_valid & child_ready);
    end
    cgra_ctrl_fanout #(.WIDTH(WIDTH),.LEAVES(LEFT),.COLS(COLS),.LAYOUT(LAYOUT),.DEPTH(DEPTH)) left (
      .clk,.reset,.recv_msg(head[WIDTH-1:0]),.recv_mask(head[WIDTH+:LEFT]),
      .recv_val(child_valid[0]),.recv_rdy(child_ready[0]),
      .send_msg(left_msg),.send_val(left_val),.send_rdy(left_rdy));
    cgra_ctrl_fanout #(.WIDTH(WIDTH),.LEAVES(RIGHT),.COLS(COLS),.LAYOUT(LAYOUT),.DEPTH(DEPTH)) right (
      .clk,.reset,.recv_msg(head[WIDTH-1:0]),.recv_mask(head[WIDTH+LEFT+:RIGHT]),
      .recv_val(child_valid[1]),.recv_rdy(child_ready[1]),
      .send_msg(right_msg),.send_val(right_val),.send_rdy(right_rdy));
    for(genvar i=0;i<LEFT;i++) begin : left_ports
      assign send_msg[i]=left_msg[i]; assign send_val[i]=left_val[i];
      assign left_rdy[i]=send_rdy[i];
    end
    for(genvar i=0;i<RIGHT;i++) begin : right_ports
      assign send_msg[LEFT+i]=right_msg[i]; assign send_val[LEFT+i]=right_val[i];
      assign right_rdy[i]=send_rdy[LEFT+i];
    end
  end
endmodule
