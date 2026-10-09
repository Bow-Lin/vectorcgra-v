`include "cgra_profile_defs.svh"
// Native parameterized cgra_global_reduce; control flow derived from ac96 cgra_global_reduce.
// Disabled DMA/im2col declarations and undriven inputs retain baseline semantics.
module cgra_global_reduce #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input logic [NOC_BITS-1:0] recv_count__msg  ,
  output logic [0:0] recv_count__rdy  ,
  input logic [0:0] recv_count__val  ,
  input logic [NOC_BITS-1:0] recv_data__msg  ,
  output logic [0:0] recv_data__rdy  ,
  input logic [0:0] recv_data__val  ,
  output logic [(NOC_BITS+1)-1:0] send__msg  ,
  input logic [0:0] send__rdy  ,
  output logic [0:0] send__val  
);
  `include "cgra_profile.svh"
  noc_packet_t p_recv_count__msg ;
  assign p_recv_count__msg = recv_count__msg;
  noc_packet_t p_recv_data__msg ;
  assign p_recv_data__msg = recv_data__msg;
  controller_xbar_t p_send__msg ;
  assign send__msg = p_send__msg;

  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD  = 5'd18;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_ADD_RESPONSE  = 5'd20;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_MUL  = 5'd19;
  localparam logic [4:0] CMD_GLOBAL_REDUCE_MUL_RESPONSE  = 5'd21;
  data_t receiving_count;
  data_t reduce_add_value;
  data_t reduce_mul_value;
  data_t sending_count;
  data_t target_count;

  logic [0:0] queue__clk;
  logic [4:0] queue__count;
  logic [0:0] queue__reset;
  noc_packet_t queue__recv__msg;
  logic [0:0] queue__recv__rdy;
  logic [0:0] queue__recv__val;
  noc_packet_t queue__send__msg;
  logic [0:0] queue__send__rdy;
  logic [0:0] queue__send__val;

  cgra_queue #(.WIDTH(NOC_BITS), .DEPTH(16)) queue (
    .clk(queue__clk),
    .count(queue__count),
    .reset(queue__reset),
    .recv_msg(queue__recv__msg),
    .recv_rdy(queue__recv__rdy),
    .recv_val(queue__recv__val),
    .send_msg(queue__send__msg),
    .send_rdy(queue__send__rdy),
    .send_val(queue__send__val),
    .clear(1'b0)
  );

  always_comb begin : set_recv_rdy
    recv_data__rdy = 1'd0;
    queue__recv__val = 1'd0;
    queue__recv__msg = '0;
    if ( target_count.payload > receiving_count.payload ) begin
      recv_data__rdy = queue__recv__rdy;
      queue__recv__msg = p_recv_data__msg;
      queue__recv__val = recv_data__val;
    end
  end

  always_comb begin : update_send
    p_send__msg = '0;
    send__val = 1'd0;
    queue__send__rdy = 1'd0;
    if ( ( target_count.payload > DATA_W'(0) ) & ( receiving_count.payload == target_count.payload ) ) begin
      if ( queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD ) ) begin
        p_send__msg.inter_cgra_pkt.payload.cmd = 6'( CMD_GLOBAL_REDUCE_ADD_RESPONSE );
        p_send__msg.inter_cgra_pkt.payload.data = reduce_add_value;
      end
      else if ( queue__send__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL ) ) begin
        p_send__msg.inter_cgra_pkt.payload.cmd = 6'( CMD_GLOBAL_REDUCE_MUL_RESPONSE );
        p_send__msg.inter_cgra_pkt.payload.data = reduce_mul_value;
      end
      p_send__msg.inter_cgra_pkt.src = queue__send__msg.dst;
      p_send__msg.inter_cgra_pkt.dst = queue__send__msg.src;
      p_send__msg.inter_cgra_pkt.src_x = queue__send__msg.dst_x;
      p_send__msg.inter_cgra_pkt.src_y = queue__send__msg.dst_y;
      p_send__msg.inter_cgra_pkt.dst_x = queue__send__msg.src_x;
      p_send__msg.inter_cgra_pkt.dst_y = queue__send__msg.src_y;
      p_send__msg.inter_cgra_pkt.src_tile_id = queue__send__msg.dst_tile_id;
      p_send__msg.inter_cgra_pkt.dst_tile_id = queue__send__msg.src_tile_id;
      queue__send__rdy = send__rdy;
      send__val = queue__send__val;
    end
  end

  always_ff @(posedge clk) begin : accumulate_value
    if ( reset | ( sending_count == target_count ) ) begin
      reduce_add_value <= '0;
      reduce_mul_value <= { DATA_W'(1), 1'd0, 1'd0, 1'd0 };
    end
    else if ( recv_data__val & recv_data__rdy ) begin
      if ( p_recv_data__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_ADD ) ) begin
        reduce_add_value <= { reduce_add_value.payload + p_recv_data__msg.payload.data.payload, p_recv_data__msg.payload.data.predicate, 1'd0, 1'd0 };
      end
      else if ( p_recv_data__msg.payload.cmd == 6'( CMD_GLOBAL_REDUCE_MUL ) ) begin
        reduce_mul_value <= { reduce_mul_value.payload * p_recv_data__msg.payload.data.payload, p_recv_data__msg.payload.data.predicate, 1'd0, 1'd0 };
      end
    end
  end

  always_ff @(posedge clk) begin : update_count
    if ( reset ) begin
      target_count <= '0;
      receiving_count <= '0;
      sending_count <= '0;
    end
    else begin
      if ( recv_count__val & recv_count__rdy ) begin
        target_count <= { p_recv_count__msg.payload.data.payload, 1'd0, 1'd0, 1'd0 };
      end
      if ( recv_data__val & recv_data__rdy ) begin
        receiving_count <= { receiving_count.payload + DATA_W'(1), 1'd0, 1'd0, 1'd0 };
      end
      if ( send__rdy & send__val ) begin
        sending_count <= { sending_count.payload + DATA_W'(1), 1'd0, 1'd0, 1'd0 };
      end
      else if ( ( ( sending_count == receiving_count ) & ( sending_count == target_count ) ) & ( target_count.payload > DATA_W'(0) ) ) begin
        sending_count <= '0;
        receiving_count <= '0;
      end
    end
  end

  assign queue__clk = clk;
  assign queue__reset = reset;
  assign recv_count__rdy = 1'd1;

endmodule
