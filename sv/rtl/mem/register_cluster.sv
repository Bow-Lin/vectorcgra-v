// Native parameterized scalar profile; migrated from ac96 RegisterClusterRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module register_cluster #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [0:0] inport_ctrl_proceed ,
  input logic [CTRL_BITS-1:0] inport_opt ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] recv_data_from_const__msg [0:3] ,
  output logic [0:0] recv_data_from_const__rdy [0:3] ,
  input logic [0:0] recv_data_from_const__val [0:3] ,
  input logic [DATA_BITS-1:0] recv_data_from_fu_crossbar__msg [0:3] ,
  output logic [0:0] recv_data_from_fu_crossbar__rdy [0:3] ,
  input logic [0:0] recv_data_from_fu_crossbar__val [0:3] ,
  input logic [DATA_BITS-1:0] recv_data_from_routing_crossbar__msg [0:3] ,
  output logic [0:0] recv_data_from_routing_crossbar__rdy [0:3] ,
  input logic [0:0] recv_data_from_routing_crossbar__val [0:3] ,
  output logic [DATA_BITS-1:0] send_data_to_fu__msg [0:3] ,
  input logic [0:0] send_data_to_fu__rdy [0:3] ,
  output logic [0:0] send_data_to_fu__val [0:3] ,
  output logic [DATA_BITS-1:0] send_data_to_routing_crossbar__msg [0:3] ,
  input logic [0:0] send_data_to_routing_crossbar__rdy [0:3] ,
  output logic [0:0] send_data_to_routing_crossbar__val [0:3] 
);
  `include "cgra_profile.svh"
  data_t recv_data_from_const__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_recv_data_from_const__msg
    assign recv_data_from_const__msg_typed[p] = recv_data_from_const__msg[p];
  end
  data_t recv_data_from_fu_crossbar__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_recv_data_from_fu_crossbar__msg
    assign recv_data_from_fu_crossbar__msg_typed[p] = recv_data_from_fu_crossbar__msg[p];
  end
  data_t recv_data_from_routing_crossbar__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_recv_data_from_routing_crossbar__msg
    assign recv_data_from_routing_crossbar__msg_typed[p] = recv_data_from_routing_crossbar__msg[p];
  end
  data_t send_data_to_fu__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_send_data_to_fu__msg
    assign send_data_to_fu__msg[p] = send_data_to_fu__msg_typed[p];
  end
  data_t send_data_to_routing_crossbar__msg_typed [0:3];
  for (genvar p=0; p<=3; p++) begin : port_send_data_to_routing_crossbar__msg
    assign send_data_to_routing_crossbar__msg[p] = send_data_to_routing_crossbar__msg_typed[p];
  end
  ctrl_t inport_opt_typed ;
  assign inport_opt_typed = inport_opt;
  localparam logic [2:0] num_reg_banks_at_update_msgs_signals  = 3'd4;
  localparam logic [0:0] PORT_ROUTING_CROSSBAR  = 1'd1;
  localparam logic [6:0] OPT_NAH  = 7'd1;
  localparam logic [1:0] PORT_FU_CROSSBAR  = 2'd2;
  localparam logic [1:0] PORT_CONST  = 2'd3;
  logic [0:0] reg_bank__clear [0:3];
  logic [0:0] reg_bank__clk [0:3];
  logic [0:0] reg_bank__inport_ctrl_proceed [0:3];
  ctrl_t reg_bank__inport_opt [0:3];
  logic [0:0] reg_bank__inport_valid [0:3][0:2];
  data_t reg_bank__inport_wdata [0:3][0:2];
  logic [0:0] reg_bank__outport_wr_rdy [0:3];
  logic [0:0] reg_bank__reset [0:3];
  data_t reg_bank__send_data_to_fu__msg [0:3];
  logic [0:0] reg_bank__send_data_to_fu__rdy [0:3];
  logic [0:0] reg_bank__send_data_to_fu__val [0:3];
  data_t reg_bank__send_data_to_xbar__msg [0:3];
  logic [0:0] reg_bank__send_data_to_xbar__rdy [0:3];
  logic [0:0] reg_bank__send_data_to_xbar__val [0:3];
  register_bank #(`CGRA_PROFILE_BIND) reg_bank__0
  (
    .clear( reg_bank__clear[0] ),
    .clk( reg_bank__clk[0] ),
    .inport_ctrl_proceed( reg_bank__inport_ctrl_proceed[0] ),
    .inport_opt( reg_bank__inport_opt[0] ),
    .inport_valid( reg_bank__inport_valid[0] ),
    .inport_wdata( reg_bank__inport_wdata[0] ),
    .outport_wr_rdy( reg_bank__outport_wr_rdy[0] ),
    .reset( reg_bank__reset[0] ),
    .send_data_to_fu__msg( reg_bank__send_data_to_fu__msg[0] ),
    .send_data_to_fu__rdy( reg_bank__send_data_to_fu__rdy[0] ),
    .send_data_to_fu__val( reg_bank__send_data_to_fu__val[0] ),
    .send_data_to_xbar__msg( reg_bank__send_data_to_xbar__msg[0] ),
    .send_data_to_xbar__rdy( reg_bank__send_data_to_xbar__rdy[0] ),
    .send_data_to_xbar__val( reg_bank__send_data_to_xbar__val[0] )
  );
  register_bank #(`CGRA_PROFILE_BIND, .BANK_ID(1)) reg_bank__1
  (
    .clear( reg_bank__clear[1] ),
    .clk( reg_bank__clk[1] ),
    .inport_ctrl_proceed( reg_bank__inport_ctrl_proceed[1] ),
    .inport_opt( reg_bank__inport_opt[1] ),
    .inport_valid( reg_bank__inport_valid[1] ),
    .inport_wdata( reg_bank__inport_wdata[1] ),
    .outport_wr_rdy( reg_bank__outport_wr_rdy[1] ),
    .reset( reg_bank__reset[1] ),
    .send_data_to_fu__msg( reg_bank__send_data_to_fu__msg[1] ),
    .send_data_to_fu__rdy( reg_bank__send_data_to_fu__rdy[1] ),
    .send_data_to_fu__val( reg_bank__send_data_to_fu__val[1] ),
    .send_data_to_xbar__msg( reg_bank__send_data_to_xbar__msg[1] ),
    .send_data_to_xbar__rdy( reg_bank__send_data_to_xbar__rdy[1] ),
    .send_data_to_xbar__val( reg_bank__send_data_to_xbar__val[1] )
  );
  register_bank #(`CGRA_PROFILE_BIND, .BANK_ID(2)) reg_bank__2
  (
    .clear( reg_bank__clear[2] ),
    .clk( reg_bank__clk[2] ),
    .inport_ctrl_proceed( reg_bank__inport_ctrl_proceed[2] ),
    .inport_opt( reg_bank__inport_opt[2] ),
    .inport_valid( reg_bank__inport_valid[2] ),
    .inport_wdata( reg_bank__inport_wdata[2] ),
    .outport_wr_rdy( reg_bank__outport_wr_rdy[2] ),
    .reset( reg_bank__reset[2] ),
    .send_data_to_fu__msg( reg_bank__send_data_to_fu__msg[2] ),
    .send_data_to_fu__rdy( reg_bank__send_data_to_fu__rdy[2] ),
    .send_data_to_fu__val( reg_bank__send_data_to_fu__val[2] ),
    .send_data_to_xbar__msg( reg_bank__send_data_to_xbar__msg[2] ),
    .send_data_to_xbar__rdy( reg_bank__send_data_to_xbar__rdy[2] ),
    .send_data_to_xbar__val( reg_bank__send_data_to_xbar__val[2] )
  );
  register_bank #(`CGRA_PROFILE_BIND, .BANK_ID(3)) reg_bank__3
  (
    .clear( reg_bank__clear[3] ),
    .clk( reg_bank__clk[3] ),
    .inport_ctrl_proceed( reg_bank__inport_ctrl_proceed[3] ),
    .inport_opt( reg_bank__inport_opt[3] ),
    .inport_valid( reg_bank__inport_valid[3] ),
    .inport_wdata( reg_bank__inport_wdata[3] ),
    .outport_wr_rdy( reg_bank__outport_wr_rdy[3] ),
    .reset( reg_bank__reset[3] ),
    .send_data_to_fu__msg( reg_bank__send_data_to_fu__msg[3] ),
    .send_data_to_fu__rdy( reg_bank__send_data_to_fu__rdy[3] ),
    .send_data_to_fu__val( reg_bank__send_data_to_fu__val[3] ),
    .send_data_to_xbar__msg( reg_bank__send_data_to_xbar__msg[3] ),
    .send_data_to_xbar__rdy( reg_bank__send_data_to_xbar__rdy[3] ),
    .send_data_to_xbar__val( reg_bank__send_data_to_xbar__val[3] )
  );
  always_comb begin : update_msgs_signals
    for ( int unsigned i = 0; i < 3'( num_reg_banks_at_update_msgs_signals ); i++ ) begin
      send_data_to_fu__msg_typed[2'(i)] = '0;
      recv_data_from_routing_crossbar__rdy[2'(i)] = 1'd0;
      recv_data_from_fu_crossbar__rdy[2'(i)] = 1'd0;
      recv_data_from_const__rdy[2'(i)] = 1'd0;
      send_data_to_fu__val[2'(i)] = 1'd0;
    end
    for ( int unsigned i = 0; i < 3'( num_reg_banks_at_update_msgs_signals ); i++ ) begin
      if ( reg_bank__send_data_to_fu__val[2'(i)] ) begin
        send_data_to_fu__msg_typed[2'(i)] = reg_bank__send_data_to_fu__msg[2'(i)];
      end
      else if ( recv_data_from_routing_crossbar__val[2'(i)] ) begin
        send_data_to_fu__msg_typed[2'(i)] = recv_data_from_routing_crossbar__msg_typed[2'(i)];
      end
      send_data_to_fu__val[2'(i)] = recv_data_from_routing_crossbar__val[2'(i)] | reg_bank__send_data_to_fu__val[2'(i)];
      reg_bank__send_data_to_fu__rdy[2'(i)] = send_data_to_fu__rdy[2'(i)];
      recv_data_from_routing_crossbar__rdy[2'(i)] = ( ( ( inport_opt_typed.write_reg_from[2'(i)] == 2'( PORT_ROUTING_CROSSBAR ) ) & ( inport_opt_typed.operation == 7'( OPT_NAH ) ) ) & reg_bank__outport_wr_rdy[2'(i)] ) | send_data_to_fu__rdy[2'(i)];
      recv_data_from_fu_crossbar__rdy[2'(i)] = ( inport_opt_typed.write_reg_from[2'(i)] != 2'( PORT_FU_CROSSBAR ) ) | reg_bank__outport_wr_rdy[2'(i)];
      recv_data_from_const__rdy[2'(i)] = ( inport_opt_typed.write_reg_from[2'(i)] != 2'( PORT_CONST ) ) | reg_bank__outport_wr_rdy[2'(i)];
    end
  end
  assign reg_bank__clk[0] = clk;
  assign reg_bank__reset[0] = reset;
  assign reg_bank__clk[1] = clk;
  assign reg_bank__reset[1] = reset;
  assign reg_bank__clk[2] = clk;
  assign reg_bank__reset[2] = reset;
  assign reg_bank__clk[3] = clk;
  assign reg_bank__reset[3] = reset;
  assign reg_bank__inport_opt[0] = inport_opt_typed;
  assign reg_bank__inport_ctrl_proceed[0] = inport_ctrl_proceed;
  assign reg_bank__clear[0] = clear;
  assign reg_bank__inport_wdata[0][0] = recv_data_from_routing_crossbar__msg_typed[0];
  assign reg_bank__inport_wdata[0][1] = recv_data_from_fu_crossbar__msg_typed[0];
  assign reg_bank__inport_wdata[0][2] = recv_data_from_const__msg_typed[0];
  assign reg_bank__inport_valid[0][0] = recv_data_from_routing_crossbar__val[0];
  assign reg_bank__inport_valid[0][1] = recv_data_from_fu_crossbar__val[0];
  assign reg_bank__inport_valid[0][2] = recv_data_from_const__val[0];
  assign send_data_to_routing_crossbar__msg_typed[0] = reg_bank__send_data_to_xbar__msg[0];
  assign reg_bank__send_data_to_xbar__rdy[0] = send_data_to_routing_crossbar__rdy[0];
  assign send_data_to_routing_crossbar__val[0] = reg_bank__send_data_to_xbar__val[0];
  assign reg_bank__inport_opt[1] = inport_opt_typed;
  assign reg_bank__inport_ctrl_proceed[1] = inport_ctrl_proceed;
  assign reg_bank__clear[1] = clear;
  assign reg_bank__inport_wdata[1][0] = recv_data_from_routing_crossbar__msg_typed[1];
  assign reg_bank__inport_wdata[1][1] = recv_data_from_fu_crossbar__msg_typed[1];
  assign reg_bank__inport_wdata[1][2] = recv_data_from_const__msg_typed[1];
  assign reg_bank__inport_valid[1][0] = recv_data_from_routing_crossbar__val[1];
  assign reg_bank__inport_valid[1][1] = recv_data_from_fu_crossbar__val[1];
  assign reg_bank__inport_valid[1][2] = recv_data_from_const__val[1];
  assign send_data_to_routing_crossbar__msg_typed[1] = reg_bank__send_data_to_xbar__msg[1];
  assign reg_bank__send_data_to_xbar__rdy[1] = send_data_to_routing_crossbar__rdy[1];
  assign send_data_to_routing_crossbar__val[1] = reg_bank__send_data_to_xbar__val[1];
  assign reg_bank__inport_opt[2] = inport_opt_typed;
  assign reg_bank__inport_ctrl_proceed[2] = inport_ctrl_proceed;
  assign reg_bank__clear[2] = clear;
  assign reg_bank__inport_wdata[2][0] = recv_data_from_routing_crossbar__msg_typed[2];
  assign reg_bank__inport_wdata[2][1] = recv_data_from_fu_crossbar__msg_typed[2];
  assign reg_bank__inport_wdata[2][2] = recv_data_from_const__msg_typed[2];
  assign reg_bank__inport_valid[2][0] = recv_data_from_routing_crossbar__val[2];
  assign reg_bank__inport_valid[2][1] = recv_data_from_fu_crossbar__val[2];
  assign reg_bank__inport_valid[2][2] = recv_data_from_const__val[2];
  assign send_data_to_routing_crossbar__msg_typed[2] = reg_bank__send_data_to_xbar__msg[2];
  assign reg_bank__send_data_to_xbar__rdy[2] = send_data_to_routing_crossbar__rdy[2];
  assign send_data_to_routing_crossbar__val[2] = reg_bank__send_data_to_xbar__val[2];
  assign reg_bank__inport_opt[3] = inport_opt_typed;
  assign reg_bank__inport_ctrl_proceed[3] = inport_ctrl_proceed;
  assign reg_bank__clear[3] = clear;
  assign reg_bank__inport_wdata[3][0] = recv_data_from_routing_crossbar__msg_typed[3];
  assign reg_bank__inport_wdata[3][1] = recv_data_from_fu_crossbar__msg_typed[3];
  assign reg_bank__inport_wdata[3][2] = recv_data_from_const__msg_typed[3];
  assign reg_bank__inport_valid[3][0] = recv_data_from_routing_crossbar__val[3];
  assign reg_bank__inport_valid[3][1] = recv_data_from_fu_crossbar__val[3];
  assign reg_bank__inport_valid[3][2] = recv_data_from_const__val[3];
  assign send_data_to_routing_crossbar__msg_typed[3] = reg_bank__send_data_to_xbar__msg[3];
  assign reg_bank__send_data_to_xbar__rdy[3] = send_data_to_routing_crossbar__rdy[3];
  assign send_data_to_routing_crossbar__val[3] = reg_bank__send_data_to_xbar__val[3];
endmodule
