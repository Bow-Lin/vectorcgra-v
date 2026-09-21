// Native parameterized scalar profile; migrated from ac96 MemUnitRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_memory_fu #(
  `CGRA_PROFILE_PARAMETERS
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
  data_t from_mem_rdata__msg_typed ;
  assign from_mem_rdata__msg_typed = from_mem_rdata__msg;
  data_t recv_const__msg_typed ;
  assign recv_const__msg_typed = recv_const__msg;
  data_t recv_in__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_recv_in__msg
    assign recv_in__msg_typed[p] = recv_in__msg[p];
  end
  data_t send_out__msg_typed [0:1];
  for (genvar p=0; p<=1; p++) begin : port_send_out__msg
    assign send_out__msg[p] = send_out__msg_typed[p];
  end
  data_t to_mem_wdata__msg_typed ;
  assign to_mem_wdata__msg = to_mem_wdata__msg_typed;
  ctrl_t recv_opt__msg_typed ;
  assign recv_opt__msg_typed = recv_opt__msg;
  payload_t recv_from_ctrl_mem__msg_typed ;
  assign recv_from_ctrl_mem__msg_typed = recv_from_ctrl_mem__msg;
  payload_t send_to_ctrl_mem__msg_typed ;
  assign send_to_ctrl_mem__msg = send_to_ctrl_mem__msg_typed;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_LD  = 7'd12;
  localparam logic [6:0] OPT_ADD_CONST_LD  = 7'd81;
  localparam logic [6:0] OPT_LD_CONST  = 7'd28;
  localparam logic [6:0] OPT_STR  = 7'd13;
  localparam logic [6:0] OPT_STR_CONST  = 7'd58;
  logic [0:0] already_sent_raddr;
  logic [2:0] in0;
  logic [1:0] in0_idx;
  logic [2:0] in1;
  logic [1:0] in1_idx;
  logic [0:0] reached_vector_factor;
  logic [0:0] recv_all_val;
  logic [3:0] recv_in_val_vector;
  logic [7:0] vector_factor_counter;
  logic [2:0] vector_factor_power;
  always_comb begin : comb_logic
    recv_all_val = 1'd0;
    in0 = 3'd0;
    in1 = 3'd0;
    for ( int unsigned i = 0; i < 3'( num_inports_at_comb_logic ); i++ )
      recv_in__rdy[2'(i)] = 1'd0;
    for ( int unsigned i = 0; i < 2'( num_outports_at_comb_logic ); i++ ) begin
      send_out__val[1'(i)] = 1'd0;
      send_out__msg_typed[1'(i)] = '0;
    end
    recv_const__rdy = 1'd0;
    recv_opt__rdy = 1'd0;
    send_to_ctrl_mem__val = 1'd0;
    send_to_ctrl_mem__msg_typed = '0;
    recv_from_ctrl_mem__rdy = 1'd0;
    if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.fu_in[2'd0] != 3'd0 ) begin
        in0 = recv_opt__msg_typed.fu_in[2'd0] - 3'd1;
      end
      if ( recv_opt__msg_typed.fu_in[2'd1] != 3'd0 ) begin
        in1 = recv_opt__msg_typed.fu_in[2'd1] - 3'd1;
      end
    end
    to_mem_waddr__val = 1'd0;
    to_mem_waddr__msg = 7'd0;
    to_mem_wdata__val = 1'd0;
    to_mem_wdata__msg_typed = '0;
    to_mem_raddr__val = 1'd0;
    to_mem_raddr__msg = 7'd0;
    from_mem_rdata__rdy = 1'd0;
    if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.operation == 7'( OPT_LD ) ) begin
        recv_all_val = recv_in__val[in0_idx];
        recv_in__rdy[in0_idx] = recv_all_val & to_mem_raddr__rdy;
        to_mem_raddr__msg = GLOBAL_ADDR_W'( recv_in__msg_typed[in0_idx].payload[GLOBAL_ADDR_W-1:0] );
        if ( recv_all_val & ( recv_in__msg_typed[in0_idx].predicate == 1'd0 ) ) begin
          to_mem_raddr__val = 1'd0;
        end
        else
          to_mem_raddr__val = recv_all_val & ( ~already_sent_raddr );
        from_mem_rdata__rdy = send_out__rdy[1'd0];
        if ( recv_all_val & ( recv_in__msg_typed[in0_idx].predicate == 1'd0 ) ) begin
          send_out__val[1'd0] = recv_all_val;
          send_out__msg_typed[1'd0].predicate = 1'd0;
          recv_opt__rdy = send_out__rdy[1'd0];
        end
        else begin
          send_out__val[1'd0] = from_mem_rdata__val;
          send_out__msg_typed[1'd0] = from_mem_rdata__msg_typed;
          send_out__msg_typed[1'd0].predicate = from_mem_rdata__msg_typed.predicate & reached_vector_factor;
          recv_opt__rdy = send_out__rdy[1'd0] & from_mem_rdata__val;
        end
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_ADD_CONST_LD ) ) begin
        recv_all_val = recv_in__val[in0_idx] & recv_const__val;
        recv_in__rdy[in0_idx] = recv_all_val & to_mem_raddr__rdy;
        recv_const__rdy = 1'd1;
        to_mem_raddr__msg = GLOBAL_ADDR_W'( recv_in__msg_typed[in0_idx].payload[GLOBAL_ADDR_W-1:0] + recv_const__msg_typed.payload[GLOBAL_ADDR_W-1:0] );
        if ( recv_all_val & ( recv_in__msg_typed[in0_idx].predicate == 1'd0 ) ) begin
          to_mem_raddr__val = 1'd0;
        end
        else
          to_mem_raddr__val = recv_all_val & ( ~already_sent_raddr );
        from_mem_rdata__rdy = send_out__rdy[1'd0];
        if ( recv_all_val & ( recv_in__msg_typed[in0_idx].predicate == 1'd0 ) ) begin
          send_out__val[1'd0] = recv_all_val;
          send_out__msg_typed[1'd0].predicate = 1'd0;
          recv_opt__rdy = send_out__rdy[1'd0];
        end
        else begin
          send_out__val[1'd0] = from_mem_rdata__val;
          send_out__msg_typed[1'd0] = from_mem_rdata__msg_typed;
          send_out__msg_typed[1'd0].predicate = from_mem_rdata__msg_typed.predicate & reached_vector_factor;
          recv_opt__rdy = send_out__rdy[1'd0] & from_mem_rdata__val;
        end
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_LD_CONST ) ) begin
        recv_all_val = recv_const__val;
        recv_const__rdy = 1'd1;
        to_mem_raddr__msg = GLOBAL_ADDR_W'( recv_const__msg_typed.payload[GLOBAL_ADDR_W-1:0] );
        to_mem_raddr__val = recv_all_val & ( ~already_sent_raddr );
        from_mem_rdata__rdy = send_out__rdy[1'd0];
        send_out__val[1'd0] = from_mem_rdata__val;
        send_out__msg_typed[1'd0] = from_mem_rdata__msg_typed;
        send_out__msg_typed[1'd0].predicate = ( recv_const__msg_typed.predicate & from_mem_rdata__msg_typed.predicate ) & reached_vector_factor;
        recv_opt__rdy = send_out__rdy[1'd0] & from_mem_rdata__val;
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_STR ) ) begin
        recv_all_val = recv_in__val[in0_idx] & recv_in__val[in1_idx];
        recv_in__rdy[in0_idx] = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
        recv_in__rdy[in1_idx] = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
        to_mem_waddr__msg = GLOBAL_ADDR_W'( recv_in__msg_typed[in0_idx].payload[GLOBAL_ADDR_W-1:0] );
        to_mem_waddr__val = recv_all_val;
        to_mem_wdata__msg_typed = recv_in__msg_typed[in1_idx];
        to_mem_wdata__msg_typed.predicate = ( recv_in__msg_typed[in0_idx].predicate & recv_in__msg_typed[in1_idx].predicate ) & reached_vector_factor;
        to_mem_wdata__val = recv_all_val;
        send_out__val[1'd0] = 1'd0;
        recv_opt__rdy = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
      end
      else if ( recv_opt__msg_typed.operation == 7'( OPT_STR_CONST ) ) begin
        recv_all_val = recv_in__val[in0_idx] & recv_const__val;
        recv_const__rdy = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
        recv_in__rdy[in0_idx] = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
        to_mem_waddr__msg = GLOBAL_ADDR_W'( recv_const__msg_typed.payload[GLOBAL_ADDR_W-1:0] );
        to_mem_waddr__val = ( recv_all_val & recv_in__msg_typed[in0_idx].predicate ) & recv_const__msg_typed.predicate;
        to_mem_wdata__msg_typed = recv_in__msg_typed[in0_idx];
        to_mem_wdata__msg_typed.predicate = ( recv_in__msg_typed[in0_idx].predicate & recv_const__msg_typed.predicate ) & reached_vector_factor;
        to_mem_wdata__val = ( recv_all_val & recv_in__msg_typed[in0_idx].predicate ) & recv_const__msg_typed.predicate;
        send_out__val[1'd0] = 1'd0;
        recv_opt__rdy = ( recv_all_val & to_mem_waddr__rdy ) & to_mem_wdata__rdy;
      end
      else begin
        for ( int unsigned j = 0; j < 2'( num_outports_at_comb_logic ); j++ )
          send_out__val[1'(j)] = 1'd0;
        recv_opt__rdy = 1'd0;
        recv_in__rdy[in0_idx] = 1'd0;
        recv_in__rdy[in1_idx] = 1'd0;
      end
    end
  end
  always_comb begin : update_reached_vector_factor
    reached_vector_factor = 1'd0;
    if ( recv_opt__val & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) >= ( 8'd1 << { { 5 { 1'b0 } }, recv_opt__msg_typed.vector_factor_power } ) ) ) begin
      reached_vector_factor = 1'd1;
    end
  end
  always_ff @(posedge clk) begin : update_already_sent_raddr
    if ( reset ) begin
      already_sent_raddr <= 1'd0;
    end
    else if ( ~recv_opt__val ) begin
      already_sent_raddr <= 1'd0;
    end
    else if ( from_mem_rdata__val & from_mem_rdata__rdy ) begin
      already_sent_raddr <= 1'd0;
    end
    else if ( ( to_mem_raddr__val & to_mem_raddr__rdy ) & ( ~already_sent_raddr ) ) begin
      already_sent_raddr <= 1'd1;
    end
    else
      already_sent_raddr <= already_sent_raddr;
  end
  always_ff @(posedge clk) begin : update_vector_factor_counter
    if ( reset ) begin
      vector_factor_counter <= 8'd0;
    end
    else if ( recv_opt__val ) begin
      if ( recv_opt__msg_typed.is_last_ctrl & ( ( vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } ) ) < ( 8'd1 << { { 5 { 1'b0 } }, recv_opt__msg_typed.vector_factor_power } ) ) ) begin
        vector_factor_counter <= vector_factor_counter + ( 8'd1 << { { 5 { 1'b0 } }, vector_factor_power } );
      end
      else if ( recv_opt__msg_typed.is_last_ctrl & reached_vector_factor ) begin
        vector_factor_counter <= 8'd0;
      end
    end
  end
  assign in0_idx = in0[1:0];
  assign in1_idx = in1[1:0];
  assign vector_factor_power = 3'd0;
endmodule
