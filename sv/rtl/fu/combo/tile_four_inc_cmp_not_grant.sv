`include "cgra_profile_defs.svh"
// ac96 behavior preserved, including undriven fields and original handshake rules.
module tile_four_inc_cmp_not_grant #(
  `CGRA_PROFILE_PARAMETERS
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

  localparam data_t const_zero  = '0;
  localparam logic [6:0] OPT_INC_NE_CONST_NOT_GRT  = 7'd82;
  localparam logic [6:0] OPT_INC  = 7'd3;
  localparam logic [6:0] OPT_NE_CONST  = 7'd46;
  localparam logic [6:0] OPT_NOT  = 7'd11;
  localparam logic [6:0] OPT_GRT_PRED  = 7'd16;
  localparam logic [6:0] OPT_START  = GLOBAL_ADDR_W'(0);

  logic [0:0] Fu0__clear;
  logic [0:0] Fu0__clk;
  logic [CTRL_ADDR_W-1:0] Fu0__ctrl_addr_inport;
  logic [0:0] Fu0__reset;
  data_t Fu0__from_mem_rdata__msg;
  logic [0:0] Fu0__from_mem_rdata__rdy;
  logic [0:0] Fu0__from_mem_rdata__val;
  data_t Fu0__recv_const__msg;
  logic [0:0] Fu0__recv_const__rdy;
  logic [0:0] Fu0__recv_const__val;
  payload_t Fu0__recv_from_ctrl_mem__msg;
  logic [0:0] Fu0__recv_from_ctrl_mem__rdy;
  logic [0:0] Fu0__recv_from_ctrl_mem__val;
  data_t Fu0__recv_in__msg [0:3];
  logic [0:0] Fu0__recv_in__rdy [0:3];
  logic [0:0] Fu0__recv_in__val [0:3];
  ctrl_t Fu0__recv_opt__msg;
  logic [0:0] Fu0__recv_opt__rdy;
  logic [0:0] Fu0__recv_opt__val;
  data_t Fu0__send_out__msg [0:1];
  logic [0:0] Fu0__send_out__rdy [0:1];
  logic [0:0] Fu0__send_out__val [0:1];
  payload_t Fu0__send_to_ctrl_mem__msg;
  logic [0:0] Fu0__send_to_ctrl_mem__rdy;
  logic [0:0] Fu0__send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] Fu0__to_mem_raddr__msg;
  logic [0:0] Fu0__to_mem_raddr__rdy;
  logic [0:0] Fu0__to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] Fu0__to_mem_waddr__msg;
  logic [0:0] Fu0__to_mem_waddr__rdy;
  logic [0:0] Fu0__to_mem_waddr__val;
  data_t Fu0__to_mem_wdata__msg;
  logic [0:0] Fu0__to_mem_wdata__rdy;
  logic [0:0] Fu0__to_mem_wdata__val;

  tile_adder #(`CGRA_PROFILE_BIND) Fu0 (
    .clear( Fu0__clear ),
    .clk( Fu0__clk ),
    .ctrl_addr_inport( Fu0__ctrl_addr_inport ),
    .reset( Fu0__reset ),
    .from_mem_rdata__msg( Fu0__from_mem_rdata__msg ),
    .from_mem_rdata__rdy( Fu0__from_mem_rdata__rdy ),
    .from_mem_rdata__val( Fu0__from_mem_rdata__val ),
    .recv_const__msg( Fu0__recv_const__msg ),
    .recv_const__rdy( Fu0__recv_const__rdy ),
    .recv_const__val( Fu0__recv_const__val ),
    .recv_from_ctrl_mem__msg( Fu0__recv_from_ctrl_mem__msg ),
    .recv_from_ctrl_mem__rdy( Fu0__recv_from_ctrl_mem__rdy ),
    .recv_from_ctrl_mem__val( Fu0__recv_from_ctrl_mem__val ),
    .recv_in__msg( Fu0__recv_in__msg ),
    .recv_in__rdy( Fu0__recv_in__rdy ),
    .recv_in__val( Fu0__recv_in__val ),
    .recv_opt__msg( Fu0__recv_opt__msg ),
    .recv_opt__rdy( Fu0__recv_opt__rdy ),
    .recv_opt__val( Fu0__recv_opt__val ),
    .send_out__msg( Fu0__send_out__msg ),
    .send_out__rdy( Fu0__send_out__rdy ),
    .send_out__val( Fu0__send_out__val ),
    .send_to_ctrl_mem__msg( Fu0__send_to_ctrl_mem__msg ),
    .send_to_ctrl_mem__rdy( Fu0__send_to_ctrl_mem__rdy ),
    .send_to_ctrl_mem__val( Fu0__send_to_ctrl_mem__val ),
    .to_mem_raddr__msg( Fu0__to_mem_raddr__msg ),
    .to_mem_raddr__rdy( Fu0__to_mem_raddr__rdy ),
    .to_mem_raddr__val( Fu0__to_mem_raddr__val ),
    .to_mem_waddr__msg( Fu0__to_mem_waddr__msg ),
    .to_mem_waddr__rdy( Fu0__to_mem_waddr__rdy ),
    .to_mem_waddr__val( Fu0__to_mem_waddr__val ),
    .to_mem_wdata__msg( Fu0__to_mem_wdata__msg ),
    .to_mem_wdata__rdy( Fu0__to_mem_wdata__rdy ),
    .to_mem_wdata__val( Fu0__to_mem_wdata__val )
  );

  logic [0:0] Fu1__clear;
  logic [0:0] Fu1__clk;
  logic [CTRL_ADDR_W-1:0] Fu1__ctrl_addr_inport;
  logic [0:0] Fu1__reset;
  data_t Fu1__from_mem_rdata__msg;
  logic [0:0] Fu1__from_mem_rdata__rdy;
  logic [0:0] Fu1__from_mem_rdata__val;
  data_t Fu1__recv_const__msg;
  logic [0:0] Fu1__recv_const__rdy;
  logic [0:0] Fu1__recv_const__val;
  payload_t Fu1__recv_from_ctrl_mem__msg;
  logic [0:0] Fu1__recv_from_ctrl_mem__rdy;
  logic [0:0] Fu1__recv_from_ctrl_mem__val;
  data_t Fu1__recv_in__msg [0:3];
  logic [0:0] Fu1__recv_in__rdy [0:3];
  logic [0:0] Fu1__recv_in__val [0:3];
  ctrl_t Fu1__recv_opt__msg;
  logic [0:0] Fu1__recv_opt__rdy;
  logic [0:0] Fu1__recv_opt__val;
  data_t Fu1__send_out__msg [0:1];
  logic [0:0] Fu1__send_out__rdy [0:1];
  logic [0:0] Fu1__send_out__val [0:1];
  payload_t Fu1__send_to_ctrl_mem__msg;
  logic [0:0] Fu1__send_to_ctrl_mem__rdy;
  logic [0:0] Fu1__send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] Fu1__to_mem_raddr__msg;
  logic [0:0] Fu1__to_mem_raddr__rdy;
  logic [0:0] Fu1__to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] Fu1__to_mem_waddr__msg;
  logic [0:0] Fu1__to_mem_waddr__rdy;
  logic [0:0] Fu1__to_mem_waddr__val;
  data_t Fu1__to_mem_wdata__msg;
  logic [0:0] Fu1__to_mem_wdata__rdy;
  logic [0:0] Fu1__to_mem_wdata__val;

  scalar_comp #(`CGRA_PROFILE_BIND) Fu1 (
    .clear( Fu1__clear ),
    .clk( Fu1__clk ),
    .ctrl_addr_inport( Fu1__ctrl_addr_inport ),
    .reset( Fu1__reset ),
    .from_mem_rdata__msg( Fu1__from_mem_rdata__msg ),
    .from_mem_rdata__rdy( Fu1__from_mem_rdata__rdy ),
    .from_mem_rdata__val( Fu1__from_mem_rdata__val ),
    .recv_const__msg( Fu1__recv_const__msg ),
    .recv_const__rdy( Fu1__recv_const__rdy ),
    .recv_const__val( Fu1__recv_const__val ),
    .recv_from_ctrl_mem__msg( Fu1__recv_from_ctrl_mem__msg ),
    .recv_from_ctrl_mem__rdy( Fu1__recv_from_ctrl_mem__rdy ),
    .recv_from_ctrl_mem__val( Fu1__recv_from_ctrl_mem__val ),
    .recv_in__msg( Fu1__recv_in__msg ),
    .recv_in__rdy( Fu1__recv_in__rdy ),
    .recv_in__val( Fu1__recv_in__val ),
    .recv_opt__msg( Fu1__recv_opt__msg ),
    .recv_opt__rdy( Fu1__recv_opt__rdy ),
    .recv_opt__val( Fu1__recv_opt__val ),
    .send_out__msg( Fu1__send_out__msg ),
    .send_out__rdy( Fu1__send_out__rdy ),
    .send_out__val( Fu1__send_out__val ),
    .send_to_ctrl_mem__msg( Fu1__send_to_ctrl_mem__msg ),
    .send_to_ctrl_mem__rdy( Fu1__send_to_ctrl_mem__rdy ),
    .send_to_ctrl_mem__val( Fu1__send_to_ctrl_mem__val ),
    .to_mem_raddr__msg( Fu1__to_mem_raddr__msg ),
    .to_mem_raddr__rdy( Fu1__to_mem_raddr__rdy ),
    .to_mem_raddr__val( Fu1__to_mem_raddr__val ),
    .to_mem_waddr__msg( Fu1__to_mem_waddr__msg ),
    .to_mem_waddr__rdy( Fu1__to_mem_waddr__rdy ),
    .to_mem_waddr__val( Fu1__to_mem_waddr__val ),
    .to_mem_wdata__msg( Fu1__to_mem_wdata__msg ),
    .to_mem_wdata__rdy( Fu1__to_mem_wdata__rdy ),
    .to_mem_wdata__val( Fu1__to_mem_wdata__val )
  );

  logic [0:0] Fu2__clear;
  logic [0:0] Fu2__clk;
  logic [CTRL_ADDR_W-1:0] Fu2__ctrl_addr_inport;
  logic [0:0] Fu2__reset;
  data_t Fu2__from_mem_rdata__msg;
  logic [0:0] Fu2__from_mem_rdata__rdy;
  logic [0:0] Fu2__from_mem_rdata__val;
  data_t Fu2__recv_const__msg;
  logic [0:0] Fu2__recv_const__rdy;
  logic [0:0] Fu2__recv_const__val;
  payload_t Fu2__recv_from_ctrl_mem__msg;
  logic [0:0] Fu2__recv_from_ctrl_mem__rdy;
  logic [0:0] Fu2__recv_from_ctrl_mem__val;
  data_t Fu2__recv_in__msg [0:3];
  logic [0:0] Fu2__recv_in__rdy [0:3];
  logic [0:0] Fu2__recv_in__val [0:3];
  ctrl_t Fu2__recv_opt__msg;
  logic [0:0] Fu2__recv_opt__rdy;
  logic [0:0] Fu2__recv_opt__val;
  data_t Fu2__send_out__msg [0:1];
  logic [0:0] Fu2__send_out__rdy [0:1];
  logic [0:0] Fu2__send_out__val [0:1];
  payload_t Fu2__send_to_ctrl_mem__msg;
  logic [0:0] Fu2__send_to_ctrl_mem__rdy;
  logic [0:0] Fu2__send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] Fu2__to_mem_raddr__msg;
  logic [0:0] Fu2__to_mem_raddr__rdy;
  logic [0:0] Fu2__to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] Fu2__to_mem_waddr__msg;
  logic [0:0] Fu2__to_mem_waddr__rdy;
  logic [0:0] Fu2__to_mem_waddr__val;
  data_t Fu2__to_mem_wdata__msg;
  logic [0:0] Fu2__to_mem_wdata__rdy;
  logic [0:0] Fu2__to_mem_wdata__val;

  scalar_logic #(`CGRA_PROFILE_BIND) Fu2 (
    .clear( Fu2__clear ),
    .clk( Fu2__clk ),
    .ctrl_addr_inport( Fu2__ctrl_addr_inport ),
    .reset( Fu2__reset ),
    .from_mem_rdata__msg( Fu2__from_mem_rdata__msg ),
    .from_mem_rdata__rdy( Fu2__from_mem_rdata__rdy ),
    .from_mem_rdata__val( Fu2__from_mem_rdata__val ),
    .recv_const__msg( Fu2__recv_const__msg ),
    .recv_const__rdy( Fu2__recv_const__rdy ),
    .recv_const__val( Fu2__recv_const__val ),
    .recv_from_ctrl_mem__msg( Fu2__recv_from_ctrl_mem__msg ),
    .recv_from_ctrl_mem__rdy( Fu2__recv_from_ctrl_mem__rdy ),
    .recv_from_ctrl_mem__val( Fu2__recv_from_ctrl_mem__val ),
    .recv_in__msg( Fu2__recv_in__msg ),
    .recv_in__rdy( Fu2__recv_in__rdy ),
    .recv_in__val( Fu2__recv_in__val ),
    .recv_opt__msg( Fu2__recv_opt__msg ),
    .recv_opt__rdy( Fu2__recv_opt__rdy ),
    .recv_opt__val( Fu2__recv_opt__val ),
    .send_out__msg( Fu2__send_out__msg ),
    .send_out__rdy( Fu2__send_out__rdy ),
    .send_out__val( Fu2__send_out__val ),
    .send_to_ctrl_mem__msg( Fu2__send_to_ctrl_mem__msg ),
    .send_to_ctrl_mem__rdy( Fu2__send_to_ctrl_mem__rdy ),
    .send_to_ctrl_mem__val( Fu2__send_to_ctrl_mem__val ),
    .to_mem_raddr__msg( Fu2__to_mem_raddr__msg ),
    .to_mem_raddr__rdy( Fu2__to_mem_raddr__rdy ),
    .to_mem_raddr__val( Fu2__to_mem_raddr__val ),
    .to_mem_waddr__msg( Fu2__to_mem_waddr__msg ),
    .to_mem_waddr__rdy( Fu2__to_mem_waddr__rdy ),
    .to_mem_waddr__val( Fu2__to_mem_waddr__val ),
    .to_mem_wdata__msg( Fu2__to_mem_wdata__msg ),
    .to_mem_wdata__rdy( Fu2__to_mem_wdata__rdy ),
    .to_mem_wdata__val( Fu2__to_mem_wdata__val )
  );

  logic [0:0] Fu3__clear;
  logic [0:0] Fu3__clk;
  logic [CTRL_ADDR_W-1:0] Fu3__ctrl_addr_inport;
  logic [0:0] Fu3__reset;
  data_t Fu3__from_mem_rdata__msg;
  logic [0:0] Fu3__from_mem_rdata__rdy;
  logic [0:0] Fu3__from_mem_rdata__val;
  data_t Fu3__recv_const__msg;
  logic [0:0] Fu3__recv_const__rdy;
  logic [0:0] Fu3__recv_const__val;
  payload_t Fu3__recv_from_ctrl_mem__msg;
  logic [0:0] Fu3__recv_from_ctrl_mem__rdy;
  logic [0:0] Fu3__recv_from_ctrl_mem__val;
  data_t Fu3__recv_in__msg [0:3];
  logic [0:0] Fu3__recv_in__rdy [0:3];
  logic [0:0] Fu3__recv_in__val [0:3];
  ctrl_t Fu3__recv_opt__msg;
  logic [0:0] Fu3__recv_opt__rdy;
  logic [0:0] Fu3__recv_opt__val;
  data_t Fu3__send_out__msg [0:1];
  logic [0:0] Fu3__send_out__rdy [0:1];
  logic [0:0] Fu3__send_out__val [0:1];
  payload_t Fu3__send_to_ctrl_mem__msg;
  logic [0:0] Fu3__send_to_ctrl_mem__rdy;
  logic [0:0] Fu3__send_to_ctrl_mem__val;
  logic [GLOBAL_ADDR_W-1:0] Fu3__to_mem_raddr__msg;
  logic [0:0] Fu3__to_mem_raddr__rdy;
  logic [0:0] Fu3__to_mem_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] Fu3__to_mem_waddr__msg;
  logic [0:0] Fu3__to_mem_waddr__rdy;
  logic [0:0] Fu3__to_mem_waddr__val;
  data_t Fu3__to_mem_wdata__msg;
  logic [0:0] Fu3__to_mem_wdata__rdy;
  logic [0:0] Fu3__to_mem_wdata__val;

  scalar_grant #(`CGRA_PROFILE_BIND) Fu3 (
    .clear( Fu3__clear ),
    .clk( Fu3__clk ),
    .ctrl_addr_inport( Fu3__ctrl_addr_inport ),
    .reset( Fu3__reset ),
    .from_mem_rdata__msg( Fu3__from_mem_rdata__msg ),
    .from_mem_rdata__rdy( Fu3__from_mem_rdata__rdy ),
    .from_mem_rdata__val( Fu3__from_mem_rdata__val ),
    .recv_const__msg( Fu3__recv_const__msg ),
    .recv_const__rdy( Fu3__recv_const__rdy ),
    .recv_const__val( Fu3__recv_const__val ),
    .recv_from_ctrl_mem__msg( Fu3__recv_from_ctrl_mem__msg ),
    .recv_from_ctrl_mem__rdy( Fu3__recv_from_ctrl_mem__rdy ),
    .recv_from_ctrl_mem__val( Fu3__recv_from_ctrl_mem__val ),
    .recv_in__msg( Fu3__recv_in__msg ),
    .recv_in__rdy( Fu3__recv_in__rdy ),
    .recv_in__val( Fu3__recv_in__val ),
    .recv_opt__msg( Fu3__recv_opt__msg ),
    .recv_opt__rdy( Fu3__recv_opt__rdy ),
    .recv_opt__val( Fu3__recv_opt__val ),
    .send_out__msg( Fu3__send_out__msg ),
    .send_out__rdy( Fu3__send_out__rdy ),
    .send_out__val( Fu3__send_out__val ),
    .send_to_ctrl_mem__msg( Fu3__send_to_ctrl_mem__msg ),
    .send_to_ctrl_mem__rdy( Fu3__send_to_ctrl_mem__rdy ),
    .send_to_ctrl_mem__val( Fu3__send_to_ctrl_mem__val ),
    .to_mem_raddr__msg( Fu3__to_mem_raddr__msg ),
    .to_mem_raddr__rdy( Fu3__to_mem_raddr__rdy ),
    .to_mem_raddr__val( Fu3__to_mem_raddr__val ),
    .to_mem_waddr__msg( Fu3__to_mem_waddr__msg ),
    .to_mem_waddr__rdy( Fu3__to_mem_waddr__rdy ),
    .to_mem_waddr__val( Fu3__to_mem_waddr__val ),
    .to_mem_wdata__msg( Fu3__to_mem_wdata__msg ),
    .to_mem_wdata__rdy( Fu3__to_mem_wdata__rdy ),
    .to_mem_wdata__val( Fu3__to_mem_wdata__val )
  );

  always_comb begin : update_mem
    to_mem_waddr__val = 1'd0;
    to_mem_wdata__val = 1'd0;
    p_to_mem_wdata__msg = const_zero;
    to_mem_waddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__msg = GLOBAL_ADDR_W'(0);
    to_mem_raddr__val = 1'd0;
    from_mem_rdata__rdy = 1'd0;
  end

  always_comb begin : update_opt
    Fu0__recv_opt__msg = p_recv_opt__msg;
    Fu1__recv_opt__msg = p_recv_opt__msg;
    Fu2__recv_opt__msg = p_recv_opt__msg;
    Fu3__recv_opt__msg = p_recv_opt__msg;
    Fu0__recv_opt__msg.fu_in[2'd0] = 3'd1;
    Fu0__recv_opt__msg.fu_in[2'd1] = 3'd2;
    Fu1__recv_opt__msg.fu_in[2'd0] = 3'd1;
    Fu1__recv_opt__msg.fu_in[2'd1] = 3'd2;
    Fu2__recv_opt__msg.fu_in[2'd0] = 3'd1;
    Fu2__recv_opt__msg.fu_in[2'd1] = 3'd2;
    Fu3__recv_opt__msg.fu_in[2'd0] = 3'd1;
    Fu3__recv_opt__msg.fu_in[2'd1] = 3'd2;
    if ( p_recv_opt__msg.operation == 7'( OPT_INC_NE_CONST_NOT_GRT ) ) begin
      Fu0__recv_opt__msg.operation = 7'( OPT_INC );
      Fu1__recv_opt__msg.operation = 7'( OPT_NE_CONST );
      Fu2__recv_opt__msg.operation = 7'( OPT_NOT );
      Fu3__recv_opt__msg.operation = 7'( OPT_GRT_PRED );
    end
    else begin
      Fu0__recv_opt__msg.operation = 7'( OPT_START );
      Fu1__recv_opt__msg.operation = 7'( OPT_START );
      Fu2__recv_opt__msg.operation = 7'( OPT_START );
      Fu3__recv_opt__msg.operation = 7'( OPT_START );
    end
  end

  always_comb begin : update_send_to_controller
    send_to_ctrl_mem__val = 1'd0;
    p_send_to_ctrl_mem__msg = '0;
    recv_from_ctrl_mem__rdy = 1'd0;
  end

  always_comb begin : update_signal
    recv_in__rdy[2'd0] = Fu0__recv_in__rdy[2'd0];
    recv_in__rdy[2'd1] = Fu0__recv_in__rdy[2'd1];
    recv_in__rdy[2'd2] = Fu1__recv_in__rdy[2'd1];
    recv_in__rdy[2'd3] = Fu2__recv_in__rdy[2'd1];
    Fu0__recv_in__val[2'd0] = recv_in__val[2'd0];
    Fu0__recv_in__val[2'd1] = recv_in__val[2'd1];
    Fu1__recv_in__val[2'd1] = recv_in__val[2'd2];
    Fu2__recv_in__val[2'd1] = recv_in__val[2'd3];
    Fu1__recv_in__val[2'd0] = Fu0__send_out__val[1'd0];
    Fu2__recv_in__val[2'd0] = Fu1__send_out__val[1'd0];
    Fu3__recv_in__val[2'd0] = Fu0__send_out__val[1'd0];
    Fu3__recv_in__val[2'd1] = Fu1__send_out__val[1'd0];
    Fu0__recv_opt__val = recv_opt__val;
    Fu1__recv_opt__val = recv_opt__val;
    Fu2__recv_opt__val = recv_opt__val;
    Fu3__recv_opt__val = recv_opt__val;
    recv_opt__rdy = ( ( Fu0__recv_opt__rdy & Fu1__recv_opt__rdy ) & Fu2__recv_opt__rdy ) & Fu3__recv_opt__rdy;
    send_out__val[1'd0] = Fu2__send_out__val[1'd0];
    send_out__val[1'd1] = Fu3__send_out__val[1'd0];
    Fu0__send_out__rdy[1'd0] = Fu1__recv_in__rdy[2'd0] & Fu3__recv_in__rdy[2'd0];
    Fu1__send_out__rdy[1'd0] = Fu2__recv_in__rdy[2'd0] & Fu3__recv_in__rdy[2'd1];
    Fu2__send_out__rdy[1'd0] = send_out__rdy[1'd0];
    Fu3__send_out__rdy[1'd0] = send_out__rdy[1'd1];
  end

  assign Fu0__clk = clk;
  assign Fu0__reset = reset;
  assign Fu1__clk = clk;
  assign Fu1__reset = reset;
  assign Fu2__clk = clk;
  assign Fu2__reset = reset;
  assign Fu3__clk = clk;
  assign Fu3__reset = reset;
  assign Fu0__recv_in__msg[0] = p_recv_in__msg[0];
  assign Fu0__recv_in__msg[1] = p_recv_in__msg[1];
  assign Fu1__recv_in__msg[1] = p_recv_in__msg[2];
  assign Fu2__recv_in__msg[1] = p_recv_in__msg[3];
  assign Fu1__recv_in__msg[0] = Fu0__send_out__msg[0];
  assign Fu2__recv_in__msg[0] = Fu1__send_out__msg[0];
  assign Fu3__recv_in__msg[0] = Fu0__send_out__msg[0];
  assign Fu3__recv_in__msg[1] = Fu1__send_out__msg[0];
  assign p_send_out__msg[0] = Fu2__send_out__msg[0];
  assign p_send_out__msg[1] = Fu3__send_out__msg[0];
  assign Fu1__recv_const__msg = p_recv_const__msg;
  assign recv_const__rdy = Fu1__recv_const__rdy;
  assign Fu1__recv_const__val = recv_const__val;

endmodule
