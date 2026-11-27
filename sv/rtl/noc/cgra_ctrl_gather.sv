// Independent upward tree. Registered FIFO capacity breaks ready paths.
// Arbitration is stable under stalls and advances only on an actual transfer.
module cgra_ctrl_gather #(
  parameter int WIDTH=32, LEAVES=4, COLS=2, LAYOUT=1, DEPTH=2
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg [0:LEAVES-1],
  input logic recv_val [0:LEAVES-1],
  output logic recv_rdy [0:LEAVES-1],
  output logic [WIDTH-1:0] send_msg,
  output logic send_val,
  input logic send_rdy
);
  logic [WIDTH-1:0] selected_msg;
  logic selected_val, selected_rdy;
  if(LEAVES==1) begin : leaf
    assign selected_msg=recv_msg[0];
    assign selected_val=recv_val[0];
    assign recv_rdy[0]=selected_rdy;
  end else begin : merge
    localparam int LEFT=(LAYOUT==2 && LEAVES>COLS) ?
      ((LEAVES/COLS+1)/2)*COLS : (LEAVES+1)/2;
    localparam int RIGHT=LEAVES-LEFT;
    logic [WIDTH-1:0] messages [0:1];
    logic valid [0:1], ready [0:1];
    logic [WIDTH-1:0] left_msg [0:LEFT-1], right_msg [0:RIGHT-1];
    logic left_val [0:LEFT-1], left_rdy [0:LEFT-1];
    logic right_val [0:RIGHT-1], right_rdy [0:RIGHT-1];
    for(genvar i=0;i<LEFT;i++) begin : left_ports
      assign left_msg[i]=recv_msg[i]; assign left_val[i]=recv_val[i];
      assign recv_rdy[i]=left_rdy[i];
    end
    for(genvar i=0;i<RIGHT;i++) begin : right_ports
      assign right_msg[i]=recv_msg[LEFT+i]; assign right_val[i]=recv_val[LEFT+i];
      assign recv_rdy[LEFT+i]=right_rdy[i];
    end
    cgra_ctrl_gather #(.WIDTH(WIDTH),.LEAVES(LEFT),.COLS(COLS),.LAYOUT(LAYOUT),.DEPTH(DEPTH)) left (
      .clk,.reset,.recv_msg(left_msg),.recv_val(left_val),.recv_rdy(left_rdy),
      .send_msg(messages[0]),.send_val(valid[0]),.send_rdy(ready[0]));
    cgra_ctrl_gather #(.WIDTH(WIDTH),.LEAVES(RIGHT),.COLS(COLS),.LAYOUT(LAYOUT),.DEPTH(DEPTH)) right (
      .clk,.reset,.recv_msg(right_msg),.recv_val(right_val),.recv_rdy(right_rdy),
      .send_msg(messages[1]),.send_val(valid[1]),.send_rdy(ready[1]));
    cgra_switch #(.WIDTH(WIDTH),.INPUTS(2),.LEGACY_PYTHON(0)) select_source (
      .clk,.reset,.recv_msg(messages),.recv_val(valid),.recv_rdy(ready),
      .send_msg(selected_msg),.send_val(selected_val),.send_rdy(selected_rdy));
  end
  logic input_ready, output_valid;
  assign selected_rdy=!reset && input_ready;
  assign send_val=!reset && output_valid;
  cgra_queue #(.WIDTH(WIDTH),.DEPTH(DEPTH)) output_fifo (
    .clk,.reset,.clear(1'b0),.recv_msg(selected_msg),.recv_val(!reset && selected_val),
    .recv_rdy(input_ready),.send_msg,.send_val(output_valid),.send_rdy(!reset && send_rdy),.count());
endmodule
