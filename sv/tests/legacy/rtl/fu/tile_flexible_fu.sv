`include "cgra_opcodes.svh"
// Native parameterized scalar profile; migrated from ac96 FlexibleFuRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_flexible_fu #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clear [0:3],
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [2:0] prologue_count_inport ,
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg [0:3] ,
  output logic [0:0] from_mem_rdata__rdy [0:3] ,
  input logic [0:0] from_mem_rdata__val [0:3] ,
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
  input logic [HOST_BITS-1:0] recv_pkt_from_controller__msg ,
  output logic [0:0] recv_pkt_from_controller__rdy  ,
  input logic [0:0] recv_pkt_from_controller__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg [0:3] ,
  input logic [0:0] to_mem_raddr__rdy [0:3] ,
  output logic [0:0] to_mem_raddr__val [0:3] ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg [0:3] ,
  input logic [0:0] to_mem_waddr__rdy [0:3] ,
  output logic [0:0] to_mem_waddr__val [0:3] ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg [0:3] ,
  input logic [0:0] to_mem_wdata__rdy [0:3] ,
  output logic [0:0] to_mem_wdata__val [0:3] 
);
  `include "cgra_profile.svh"
  data_t from_mem_rdata__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_from_mem_rdata__msg
    assign from_mem_rdata__msg_typed[p] = from_mem_rdata__msg[p];
  end
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
  data_t to_mem_wdata__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_to_mem_wdata__msg
    assign to_mem_wdata__msg[p] = to_mem_wdata__msg_typed[p];
  end
  ctrl_t recv_opt__msg_typed ;
  assign recv_opt__msg_typed = recv_opt__msg;
  payload_t recv_from_ctrl_mem__msg_typed ;
  assign recv_from_ctrl_mem__msg_typed = recv_from_ctrl_mem__msg;
  payload_t send_to_ctrl_mem__msg_typed ;
  assign send_to_ctrl_mem__msg = send_to_ctrl_mem__msg_typed;
  host_packet_t recv_pkt_from_controller__msg_typed ;
  assign recv_pkt_from_controller__msg_typed = recv_pkt_from_controller__msg;
  localparam logic [1:0] num_outports_at_comb_logic  = 2'd2;
  localparam logic [6:0] OPT_NAH  = `CGRA_OPT_NAH;
  localparam logic [2:0] num_inports_at_comb_logic  = 3'd4;
  logic [3:0] fu_recv_const_rdy_vector;
  logic [3:0] fu_recv_in_rdy_vector [0:3];
  logic [3:0] fu_recv_opt_rdy_vector;
  logic [3:0] recv_from_controller_rdy_vector;
  logic [0:0] fu__clear [0:3];
  logic [0:0] fu__clk [0:3];
  logic [CTRL_ADDR_W-1:0] fu__ctrl_addr_inport [0:3];
  logic [0:0] fu__reset [0:3];
  data_t fu__from_mem_rdata__msg [0:3];
  logic [0:0] fu__from_mem_rdata__rdy [0:3];
  logic [0:0] fu__from_mem_rdata__val [0:3];
  data_t fu__recv_const__msg [0:3];
  logic [0:0] fu__recv_const__rdy [0:3];
  logic [0:0] fu__recv_const__val [0:3];
  payload_t fu__recv_from_ctrl_mem__msg [0:3];
  logic [0:0] fu__recv_from_ctrl_mem__rdy [0:3];
  logic [0:0] fu__recv_from_ctrl_mem__val [0:3];
  data_t fu__recv_in__msg [0:3][0:3];
  logic [0:0] fu__recv_in__rdy [0:3][0:3];
  logic [0:0] fu__recv_in__val [0:3][0:3];
  ctrl_t fu__recv_opt__msg [0:3];
  logic [0:0] fu__recv_opt__rdy [0:3];
  logic [0:0] fu__recv_opt__val [0:3];
  data_t fu__send_out__msg [0:3][0:1];
  logic [0:0] fu__send_out__rdy [0:3][0:1];
  logic [0:0] fu__send_out__val [0:3][0:1];
  payload_t fu__send_to_ctrl_mem__msg [0:3];
  logic [0:0] fu__send_to_ctrl_mem__rdy [0:3];
  logic [0:0] fu__send_to_ctrl_mem__val [0:3];
  logic [GLOBAL_ADDR_W-1:0] fu__to_mem_raddr__msg [0:3];
  logic [0:0] fu__to_mem_raddr__rdy [0:3];
  logic [0:0] fu__to_mem_raddr__val [0:3];
  logic [GLOBAL_ADDR_W-1:0] fu__to_mem_waddr__msg [0:3];
  logic [0:0] fu__to_mem_waddr__rdy [0:3];
  logic [0:0] fu__to_mem_waddr__val [0:3];
  data_t fu__to_mem_wdata__msg [0:3];
  logic [0:0] fu__to_mem_wdata__rdy [0:3];
  logic [0:0] fu__to_mem_wdata__val [0:3];
  tile_adder #(`CGRA_PROFILE_BIND) fu__0
  (
    .clear( fu__clear[0] ),
    .clk( fu__clk[0] ),
    .ctrl_addr_inport( fu__ctrl_addr_inport[0] ),
    .reset( fu__reset[0] ),
    .from_mem_rdata__msg( fu__from_mem_rdata__msg[0] ),
    .from_mem_rdata__rdy( fu__from_mem_rdata__rdy[0] ),
    .from_mem_rdata__val( fu__from_mem_rdata__val[0] ),
    .recv_const__msg( fu__recv_const__msg[0] ),
    .recv_const__rdy( fu__recv_const__rdy[0] ),
    .recv_const__val( fu__recv_const__val[0] ),
    .recv_from_ctrl_mem__msg( fu__recv_from_ctrl_mem__msg[0] ),
    .recv_from_ctrl_mem__rdy( fu__recv_from_ctrl_mem__rdy[0] ),
    .recv_from_ctrl_mem__val( fu__recv_from_ctrl_mem__val[0] ),
    .recv_in__msg( fu__recv_in__msg[0] ),
    .recv_in__rdy( fu__recv_in__rdy[0] ),
    .recv_in__val( fu__recv_in__val[0] ),
    .recv_opt__msg( fu__recv_opt__msg[0] ),
    .recv_opt__rdy( fu__recv_opt__rdy[0] ),
    .recv_opt__val( fu__recv_opt__val[0] ),
    .send_out__msg( fu__send_out__msg[0] ),
    .send_out__rdy( fu__send_out__rdy[0] ),
    .send_out__val( fu__send_out__val[0] ),
    .send_to_ctrl_mem__msg( fu__send_to_ctrl_mem__msg[0] ),
    .send_to_ctrl_mem__rdy( fu__send_to_ctrl_mem__rdy[0] ),
    .send_to_ctrl_mem__val( fu__send_to_ctrl_mem__val[0] ),
    .to_mem_raddr__msg( fu__to_mem_raddr__msg[0] ),
    .to_mem_raddr__rdy( fu__to_mem_raddr__rdy[0] ),
    .to_mem_raddr__val( fu__to_mem_raddr__val[0] ),
    .to_mem_waddr__msg( fu__to_mem_waddr__msg[0] ),
    .to_mem_waddr__rdy( fu__to_mem_waddr__rdy[0] ),
    .to_mem_waddr__val( fu__to_mem_waddr__val[0] ),
    .to_mem_wdata__msg( fu__to_mem_wdata__msg[0] ),
    .to_mem_wdata__rdy( fu__to_mem_wdata__rdy[0] ),
    .to_mem_wdata__val( fu__to_mem_wdata__val[0] )
  );
  tile_multiplier #(`CGRA_PROFILE_BIND) fu__1
  (
    .clear( fu__clear[1] ),
    .clk( fu__clk[1] ),
    .ctrl_addr_inport( fu__ctrl_addr_inport[1] ),
    .reset( fu__reset[1] ),
    .from_mem_rdata__msg( fu__from_mem_rdata__msg[1] ),
    .from_mem_rdata__rdy( fu__from_mem_rdata__rdy[1] ),
    .from_mem_rdata__val( fu__from_mem_rdata__val[1] ),
    .recv_const__msg( fu__recv_const__msg[1] ),
    .recv_const__rdy( fu__recv_const__rdy[1] ),
    .recv_const__val( fu__recv_const__val[1] ),
    .recv_from_ctrl_mem__msg( fu__recv_from_ctrl_mem__msg[1] ),
    .recv_from_ctrl_mem__rdy( fu__recv_from_ctrl_mem__rdy[1] ),
    .recv_from_ctrl_mem__val( fu__recv_from_ctrl_mem__val[1] ),
    .recv_in__msg( fu__recv_in__msg[1] ),
    .recv_in__rdy( fu__recv_in__rdy[1] ),
    .recv_in__val( fu__recv_in__val[1] ),
    .recv_opt__msg( fu__recv_opt__msg[1] ),
    .recv_opt__rdy( fu__recv_opt__rdy[1] ),
    .recv_opt__val( fu__recv_opt__val[1] ),
    .send_out__msg( fu__send_out__msg[1] ),
    .send_out__rdy( fu__send_out__rdy[1] ),
    .send_out__val( fu__send_out__val[1] ),
    .send_to_ctrl_mem__msg( fu__send_to_ctrl_mem__msg[1] ),
    .send_to_ctrl_mem__rdy( fu__send_to_ctrl_mem__rdy[1] ),
    .send_to_ctrl_mem__val( fu__send_to_ctrl_mem__val[1] ),
    .to_mem_raddr__msg( fu__to_mem_raddr__msg[1] ),
    .to_mem_raddr__rdy( fu__to_mem_raddr__rdy[1] ),
    .to_mem_raddr__val( fu__to_mem_raddr__val[1] ),
    .to_mem_waddr__msg( fu__to_mem_waddr__msg[1] ),
    .to_mem_waddr__rdy( fu__to_mem_waddr__rdy[1] ),
    .to_mem_waddr__val( fu__to_mem_waddr__val[1] ),
    .to_mem_wdata__msg( fu__to_mem_wdata__msg[1] ),
    .to_mem_wdata__rdy( fu__to_mem_wdata__rdy[1] ),
    .to_mem_wdata__val( fu__to_mem_wdata__val[1] )
  );
  tile_memory_fu #(`CGRA_PROFILE_BIND) fu__2
  (
    .clear( fu__clear[2] ),
    .clk( fu__clk[2] ),
    .ctrl_addr_inport( fu__ctrl_addr_inport[2] ),
    .reset( fu__reset[2] ),
    .from_mem_rdata__msg( fu__from_mem_rdata__msg[2] ),
    .from_mem_rdata__rdy( fu__from_mem_rdata__rdy[2] ),
    .from_mem_rdata__val( fu__from_mem_rdata__val[2] ),
    .recv_const__msg( fu__recv_const__msg[2] ),
    .recv_const__rdy( fu__recv_const__rdy[2] ),
    .recv_const__val( fu__recv_const__val[2] ),
    .recv_from_ctrl_mem__msg( fu__recv_from_ctrl_mem__msg[2] ),
    .recv_from_ctrl_mem__rdy( fu__recv_from_ctrl_mem__rdy[2] ),
    .recv_from_ctrl_mem__val( fu__recv_from_ctrl_mem__val[2] ),
    .recv_in__msg( fu__recv_in__msg[2] ),
    .recv_in__rdy( fu__recv_in__rdy[2] ),
    .recv_in__val( fu__recv_in__val[2] ),
    .recv_opt__msg( fu__recv_opt__msg[2] ),
    .recv_opt__rdy( fu__recv_opt__rdy[2] ),
    .recv_opt__val( fu__recv_opt__val[2] ),
    .send_out__msg( fu__send_out__msg[2] ),
    .send_out__rdy( fu__send_out__rdy[2] ),
    .send_out__val( fu__send_out__val[2] ),
    .send_to_ctrl_mem__msg( fu__send_to_ctrl_mem__msg[2] ),
    .send_to_ctrl_mem__rdy( fu__send_to_ctrl_mem__rdy[2] ),
    .send_to_ctrl_mem__val( fu__send_to_ctrl_mem__val[2] ),
    .to_mem_raddr__msg( fu__to_mem_raddr__msg[2] ),
    .to_mem_raddr__rdy( fu__to_mem_raddr__rdy[2] ),
    .to_mem_raddr__val( fu__to_mem_raddr__val[2] ),
    .to_mem_waddr__msg( fu__to_mem_waddr__msg[2] ),
    .to_mem_waddr__rdy( fu__to_mem_waddr__rdy[2] ),
    .to_mem_waddr__val( fu__to_mem_waddr__val[2] ),
    .to_mem_wdata__msg( fu__to_mem_wdata__msg[2] ),
    .to_mem_wdata__rdy( fu__to_mem_wdata__rdy[2] ),
    .to_mem_wdata__val( fu__to_mem_wdata__val[2] )
  );
  tile_nah #(`CGRA_PROFILE_BIND) fu__3
  (
    .clear( fu__clear[3] ),
    .clk( fu__clk[3] ),
    .ctrl_addr_inport( fu__ctrl_addr_inport[3] ),
    .reset( fu__reset[3] ),
    .from_mem_rdata__msg( fu__from_mem_rdata__msg[3] ),
    .from_mem_rdata__rdy( fu__from_mem_rdata__rdy[3] ),
    .from_mem_rdata__val( fu__from_mem_rdata__val[3] ),
    .recv_const__msg( fu__recv_const__msg[3] ),
    .recv_const__rdy( fu__recv_const__rdy[3] ),
    .recv_const__val( fu__recv_const__val[3] ),
    .recv_from_ctrl_mem__msg( fu__recv_from_ctrl_mem__msg[3] ),
    .recv_from_ctrl_mem__rdy( fu__recv_from_ctrl_mem__rdy[3] ),
    .recv_from_ctrl_mem__val( fu__recv_from_ctrl_mem__val[3] ),
    .recv_in__msg( fu__recv_in__msg[3] ),
    .recv_in__rdy( fu__recv_in__rdy[3] ),
    .recv_in__val( fu__recv_in__val[3] ),
    .recv_opt__msg( fu__recv_opt__msg[3] ),
    .recv_opt__rdy( fu__recv_opt__rdy[3] ),
    .recv_opt__val( fu__recv_opt__val[3] ),
    .send_out__msg( fu__send_out__msg[3] ),
    .send_out__rdy( fu__send_out__rdy[3] ),
    .send_out__val( fu__send_out__val[3] ),
    .send_to_ctrl_mem__msg( fu__send_to_ctrl_mem__msg[3] ),
    .send_to_ctrl_mem__rdy( fu__send_to_ctrl_mem__rdy[3] ),
    .send_to_ctrl_mem__val( fu__send_to_ctrl_mem__val[3] ),
    .to_mem_raddr__msg( fu__to_mem_raddr__msg[3] ),
    .to_mem_raddr__rdy( fu__to_mem_raddr__rdy[3] ),
    .to_mem_raddr__val( fu__to_mem_raddr__val[3] ),
    .to_mem_waddr__msg( fu__to_mem_waddr__msg[3] ),
    .to_mem_waddr__rdy( fu__to_mem_waddr__rdy[3] ),
    .to_mem_waddr__val( fu__to_mem_waddr__val[3] ),
    .to_mem_wdata__msg( fu__to_mem_wdata__msg[3] ),
    .to_mem_wdata__rdy( fu__to_mem_wdata__rdy[3] ),
    .to_mem_wdata__val( fu__to_mem_wdata__val[3] )
  );
  always_comb begin : comb_logic
    for ( int unsigned j = 0; j < 2'( num_outports_at_comb_logic ); j++ ) begin
      send_out__val[1'(j)] = 1'd0;
      send_out__msg_typed[1'(j)] = '0;
    end
    for ( int unsigned i = 0; i < 3'd4; i++ ) begin
      fu__recv_const__msg[2'(i)] = recv_const__msg_typed;
      fu__recv_const__val[2'(i)] = recv_const__val;
      fu_recv_const_rdy_vector[2'(i)] = fu__recv_const__rdy[2'(i)];
      fu__recv_opt__msg[2'(i)] = recv_opt__msg_typed;
      if ( prologue_count_inport != 3'd0 ) begin
        fu__recv_opt__msg[2'(i)].operation = 7'( OPT_NAH );
      end
      fu__recv_opt__val[2'(i)] = recv_opt__val;
      fu_recv_opt_rdy_vector[2'(i)] = fu__recv_opt__rdy[2'(i)];
      for ( int unsigned j = 0; j < 2'( num_outports_at_comb_logic ); j++ ) begin
        if ( fu__send_out__val[2'(i)][1'(j)] ) begin
          send_out__msg_typed[1'(j)] = fu__send_out__msg[2'(i)][1'(j)];
          send_out__val[1'(j)] = fu__send_out__val[2'(i)][1'(j)];
        end
        fu__send_out__rdy[2'(i)][1'(j)] = send_out__rdy[1'(j)];
      end
    end
    recv_const__rdy = ( | fu_recv_const_rdy_vector );
    recv_opt__rdy = ( | fu_recv_opt_rdy_vector ) | ( prologue_count_inport != 3'd0 );
    for ( int unsigned j = 0; j < 3'( num_inports_at_comb_logic ); j++ )
      recv_in__rdy[2'(j)] = 1'd0;
    for ( int unsigned port = 0; port < 3'( num_inports_at_comb_logic ); port++ ) begin
      for ( int unsigned i = 0; i < 3'd4; i++ ) begin
        fu__recv_in__msg[2'(i)][2'(port)] = recv_in__msg_typed[2'(port)];
        fu__recv_in__val[2'(i)][2'(port)] = recv_in__val[2'(port)];
        fu_recv_in_rdy_vector[2'(port)][2'(i)] = fu__recv_in__rdy[2'(i)][2'(port)];
      end
      recv_in__rdy[2'(port)] = ( | fu_recv_in_rdy_vector[2'(port)] );
    end
  end
  always_comb begin : connect_to_controller
    for ( int unsigned i = 0; i < 3'd4; i++ ) begin
      fu__recv_from_ctrl_mem__msg[2'(i)] = recv_from_ctrl_mem__msg_typed;
      fu__recv_from_ctrl_mem__val[2'(i)] = recv_from_ctrl_mem__val;
      recv_from_controller_rdy_vector[2'(i)] = fu__recv_from_ctrl_mem__rdy[2'(i)];
    end
    recv_from_ctrl_mem__rdy = ( | recv_from_controller_rdy_vector );
    send_to_ctrl_mem__msg_typed = '0;
    send_to_ctrl_mem__val = 1'd0;
    for ( int unsigned i = 0; i < 3'd4; i++ ) begin
      if ( fu__send_to_ctrl_mem__val[2'(i)] ) begin
        send_to_ctrl_mem__msg_typed = fu__send_to_ctrl_mem__msg[2'(i)];
        send_to_ctrl_mem__val = fu__send_to_ctrl_mem__val[2'(i)];
      end
      fu__send_to_ctrl_mem__rdy[2'(i)] = send_to_ctrl_mem__rdy;
      fu__ctrl_addr_inport[2'(i)] = ctrl_addr_inport;
    end
  end
  assign fu__clk[0] = clk;
  assign fu__reset[0] = reset;
  assign fu__clk[1] = clk;
  assign fu__reset[1] = reset;
  assign fu__clk[2] = clk;
  assign fu__reset[2] = reset;
  assign fu__clk[3] = clk;
  assign fu__reset[3] = reset;
  assign to_mem_raddr__msg[0] = fu__to_mem_raddr__msg[0];
  assign fu__to_mem_raddr__rdy[0] = to_mem_raddr__rdy[0];
  assign to_mem_raddr__val[0] = fu__to_mem_raddr__val[0];
  assign fu__from_mem_rdata__msg[0] = from_mem_rdata__msg_typed[0];
  assign from_mem_rdata__rdy[0] = fu__from_mem_rdata__rdy[0];
  assign fu__from_mem_rdata__val[0] = from_mem_rdata__val[0];
  assign to_mem_waddr__msg[0] = fu__to_mem_waddr__msg[0];
  assign fu__to_mem_waddr__rdy[0] = to_mem_waddr__rdy[0];
  assign to_mem_waddr__val[0] = fu__to_mem_waddr__val[0];
  assign to_mem_wdata__msg_typed[0] = fu__to_mem_wdata__msg[0];
  assign fu__to_mem_wdata__rdy[0] = to_mem_wdata__rdy[0];
  assign to_mem_wdata__val[0] = fu__to_mem_wdata__val[0];
  assign fu__clear[0] = clear[0];
  assign to_mem_raddr__msg[1] = fu__to_mem_raddr__msg[1];
  assign fu__to_mem_raddr__rdy[1] = to_mem_raddr__rdy[1];
  assign to_mem_raddr__val[1] = fu__to_mem_raddr__val[1];
  assign fu__from_mem_rdata__msg[1] = from_mem_rdata__msg_typed[1];
  assign from_mem_rdata__rdy[1] = fu__from_mem_rdata__rdy[1];
  assign fu__from_mem_rdata__val[1] = from_mem_rdata__val[1];
  assign to_mem_waddr__msg[1] = fu__to_mem_waddr__msg[1];
  assign fu__to_mem_waddr__rdy[1] = to_mem_waddr__rdy[1];
  assign to_mem_waddr__val[1] = fu__to_mem_waddr__val[1];
  assign to_mem_wdata__msg_typed[1] = fu__to_mem_wdata__msg[1];
  assign fu__to_mem_wdata__rdy[1] = to_mem_wdata__rdy[1];
  assign to_mem_wdata__val[1] = fu__to_mem_wdata__val[1];
  assign fu__clear[1] = clear[1];
  assign to_mem_raddr__msg[2] = fu__to_mem_raddr__msg[2];
  assign fu__to_mem_raddr__rdy[2] = to_mem_raddr__rdy[2];
  assign to_mem_raddr__val[2] = fu__to_mem_raddr__val[2];
  assign fu__from_mem_rdata__msg[2] = from_mem_rdata__msg_typed[2];
  assign from_mem_rdata__rdy[2] = fu__from_mem_rdata__rdy[2];
  assign fu__from_mem_rdata__val[2] = from_mem_rdata__val[2];
  assign to_mem_waddr__msg[2] = fu__to_mem_waddr__msg[2];
  assign fu__to_mem_waddr__rdy[2] = to_mem_waddr__rdy[2];
  assign to_mem_waddr__val[2] = fu__to_mem_waddr__val[2];
  assign to_mem_wdata__msg_typed[2] = fu__to_mem_wdata__msg[2];
  assign fu__to_mem_wdata__rdy[2] = to_mem_wdata__rdy[2];
  assign to_mem_wdata__val[2] = fu__to_mem_wdata__val[2];
  assign fu__clear[2] = clear[2];
  assign to_mem_raddr__msg[3] = fu__to_mem_raddr__msg[3];
  assign fu__to_mem_raddr__rdy[3] = to_mem_raddr__rdy[3];
  assign to_mem_raddr__val[3] = fu__to_mem_raddr__val[3];
  assign fu__from_mem_rdata__msg[3] = from_mem_rdata__msg_typed[3];
  assign from_mem_rdata__rdy[3] = fu__from_mem_rdata__rdy[3];
  assign fu__from_mem_rdata__val[3] = from_mem_rdata__val[3];
  assign to_mem_waddr__msg[3] = fu__to_mem_waddr__msg[3];
  assign fu__to_mem_waddr__rdy[3] = to_mem_waddr__rdy[3];
  assign to_mem_waddr__val[3] = fu__to_mem_waddr__val[3];
  assign to_mem_wdata__msg_typed[3] = fu__to_mem_wdata__msg[3];
  assign fu__to_mem_wdata__rdy[3] = to_mem_wdata__rdy[3];
  assign to_mem_wdata__val[3] = fu__to_mem_wdata__val[3];
  assign fu__clear[3] = clear[3];
endmodule
