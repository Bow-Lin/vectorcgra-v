`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
module tile_streaming_memory_fu #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int VECTOR_FACTOR_POWER = 0
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
  input logic [HOST_BITS-1:0] recv_from_controller_pkt__msg,
  input logic recv_from_controller_pkt__val,
  output logic recv_from_controller_pkt__rdy,
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
  ctrl_t control;
  host_packet_t packet;
  data_t response, output_data;
  logic [GLOBAL_ADDR_W-1:0] single_request_addr;
  logic [GLOBAL_ADDR_W-1:0] single_response_of_which_request_addr;
  logic [GLOBAL_ADDR_W-1:0] streaming_start_raddr, streaming_stride, streaming_end_raddr;
  logic [CTRL_ADDR_W-1:0] ctrl_addr_reg;
  logic streaming_status, streaming_done, reached_vector_factor;
  logic already_sent_raddr;
  logic [7:0] vector_factor_counter, vector_next;
  localparam logic [2:0] VECTOR_POWER = 3'(VECTOR_FACTOR_POWER);
  assign control = recv_opt__msg;
  assign packet = recv_from_controller_pkt__msg;
  assign response = from_mem_rdata__msg;
  assign vector_next = vector_factor_counter + (8'd1 << VECTOR_POWER);
  assign reached_vector_factor = recv_opt__val &&
    (vector_next >= (8'd1 << control.vector_factor_power));
  assign streaming_done = !(recv_opt__val && control.operation == `CGRA_OPT_STREAM_LD) ||
    (single_response_of_which_request_addr == streaming_end_raddr &&
     from_mem_rdata__val && from_mem_rdata__rdy);
  assign recv_from_controller_pkt__rdy = 1'b1;
  always_comb begin
    for (int i=0; i<4; i++) recv_in__rdy[i] = 1'b0;
    for (int i=0; i<2; i++) begin
      send_out__msg[i] = '0;
      send_out__val[i] = 1'b0;
    end
    recv_const__rdy = 1'b0;
    recv_opt__rdy = 1'b0;
    recv_from_ctrl_mem__rdy = 1'b0;
    send_to_ctrl_mem__msg = '0;
    send_to_ctrl_mem__val = 1'b0;
    to_mem_waddr__msg = '0;
    to_mem_waddr__val = 1'b0;
    to_mem_wdata__msg = '0;
    to_mem_wdata__val = 1'b0;
    to_mem_raddr__msg = '0;
    to_mem_raddr__val = 1'b0;
    from_mem_rdata__rdy = 1'b0;
    output_data = '0;
    if (recv_opt__val && control.operation == `CGRA_OPT_STREAM_LD) begin
      to_mem_raddr__val = streaming_status && single_request_addr <= streaming_end_raddr;
      to_mem_raddr__msg = single_request_addr;
      from_mem_rdata__rdy = send_out__rdy[0];
      send_out__val[0] = from_mem_rdata__val;
      output_data = response;
      output_data.predicate = response.predicate && reached_vector_factor;
      send_out__msg[0] = output_data;
      recv_opt__rdy = send_out__rdy[0] && streaming_done;
    end
  end
  always_ff @(posedge clk) begin
    if (reset) vector_factor_counter <= '0;
    else if (recv_opt__val && control.is_last_ctrl) begin
      if (vector_next < (8'd1 << control.vector_factor_power))
        vector_factor_counter <= vector_next;
      else if (reached_vector_factor) vector_factor_counter <= '0;
    end
    if (reset || !recv_opt__val || (from_mem_rdata__val && from_mem_rdata__rdy))
      already_sent_raddr <= 1'b0;
    else if (to_mem_raddr__val && to_mem_raddr__rdy && !already_sent_raddr)
      already_sent_raddr <= 1'b1;
    // ac96 deliberately tests operation/address even when recv_opt.val is low.
    // These cursors, configuration registers and ctrl_addr_reg have no reset.
    if (control.operation == `CGRA_OPT_STREAM_LD && ctrl_addr_reg != ctrl_addr_inport) begin
      single_request_addr <= streaming_start_raddr;
      single_response_of_which_request_addr <= streaming_start_raddr;
      streaming_status <= 1'b1;
    end else if (streaming_done) begin
      single_request_addr <= '0;
      single_response_of_which_request_addr <= '0;
      streaming_status <= 1'b0;
    end else begin
      if (to_mem_raddr__val && to_mem_raddr__rdy)
        single_request_addr <= single_request_addr + streaming_stride;
      if (from_mem_rdata__val && from_mem_rdata__rdy)
        single_response_of_which_request_addr <= single_response_of_which_request_addr + streaming_stride;
    end
    ctrl_addr_reg <= ctrl_addr_inport;
    if (recv_from_controller_pkt__val && packet.payload.cmd == 6'd23)
      streaming_start_raddr <= GLOBAL_ADDR_W'(packet.payload.data.payload);
    if (recv_from_controller_pkt__val && packet.payload.cmd == 6'd24)
      streaming_stride <= GLOBAL_ADDR_W'(packet.payload.data.payload);
    if (recv_from_controller_pkt__val && packet.payload.cmd == 6'd25)
      streaming_end_raddr <= GLOBAL_ADDR_W'(packet.payload.data.payload);
  end
  // clear and operand channels are unused by the original streaming unit.
endmodule
