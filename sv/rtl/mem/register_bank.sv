// Native parameterized scalar profile; migrated from ac96 RegisterBankRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module register_bank #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int BANK_ID=0
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [0:0] inport_ctrl_proceed ,
  input logic [CTRL_BITS-1:0] inport_opt ,
  input  logic [0:0] inport_valid [0:2],
  input logic [DATA_BITS-1:0] inport_wdata [0:2],
  output logic [0:0] outport_wr_rdy ,
  input  logic [0:0] reset ,
  output logic [DATA_BITS-1:0] send_data_to_fu__msg ,
  input logic [0:0] send_data_to_fu__rdy  ,
  output logic [0:0] send_data_to_fu__val  ,
  output logic [DATA_BITS-1:0] send_data_to_xbar__msg ,
  input logic [0:0] send_data_to_xbar__rdy  ,
  output logic [0:0] send_data_to_xbar__val  
);
  `include "cgra_profile.svh"
  data_t inport_wdata_typed [0:2];
  for (genvar p=0; p<=2; p++) begin : port_inport_wdata
    assign inport_wdata_typed[p] = inport_wdata[p];
  end
  data_t send_data_to_fu__msg_typed ;
  assign send_data_to_fu__msg = send_data_to_fu__msg_typed;
  data_t send_data_to_xbar__msg_typed ;
  assign send_data_to_xbar__msg = send_data_to_xbar__msg_typed;
  ctrl_t inport_opt_typed ;
  assign inport_opt_typed = inport_opt;
  localparam logic [0:0] READ_TOWARDS_FU  = 1'd1;
  localparam logic [1:0] READ_TOWARDS_BOTH  = 2'd3;
  localparam logic [1:0] READ_TOWARDS_ROUTING_XBAR  = 2'd2;
  logic [REG_DEPTH-1:0] armed;
  logic [0:0] read_armed;
  logic [0:0] read_token_valid;
  logic [0:0] read_towards_fu;
  logic [0:0] read_towards_xbar;
  logic [0:0] skid_commit;
  data_t skid_data;
  logic [REG_ADDR_W-1:0] skid_idx;
  logic [0:0] skid_park;
  logic [0:0] skid_target_being_read;
  logic [0:0] skid_target_holds_token;
  logic [0:0] skid_valid;
  logic [REG_DEPTH-1:0] token_clear_mask;
  logic [REG_DEPTH-1:0] token_set_mask;
  logic [REG_DEPTH-1:0] token_valid;
  logic [0:0] wr_accept;
  logic [0:0] wr_en;
  data_t wr_sel_data;
  logic [0:0] wr_target_being_read;
  logic [0:0] wr_target_holds_token;
  logic [0:0] reg_file__clk;
  logic [REG_ADDR_W-1:0] reg_file__raddr [0:0];
  data_t reg_file__rdata [0:0];
  logic [0:0] reg_file__reset;
  logic [REG_ADDR_W-1:0] reg_file__waddr [0:0];
  data_t reg_file__wdata [0:0];
  logic [0:0] reg_file__wen [0:0];
  cgra_register_file #(.WIDTH(DATA_BITS), .DEPTH(REG_DEPTH), .RD_PORTS(1), .WR_PORTS(1)) reg_file
  (
    .clk( reg_file__clk ),
    .raddr( reg_file__raddr ),
    .rdata( reg_file__rdata ),
    .reset( reg_file__reset ),
    .waddr( reg_file__waddr ),
    .wdata( reg_file__wdata ),
    .wen( reg_file__wen )
  );
  logic [1:0] tmp_update_token_status_read_towards;
  logic [1:0] tmp_access_registers_read_towards;
  logic [1:0] tmp_access_registers_write_reg_from;
  always_comb begin : access_registers
    reg_file__raddr[1'd0] = '0;
    send_data_to_fu__msg_typed = '0;
    send_data_to_xbar__msg_typed = '0;
    reg_file__waddr[1'd0] = '0;
    reg_file__wdata[1'd0] = '0;
    reg_file__wen[1'd0] = 1'd0;
    wr_accept = 1'd0;
    wr_en = 1'd0;
    skid_park = 1'd0;
    wr_sel_data = '0;
    tmp_access_registers_read_towards = inport_opt_typed.read_reg_towards[BANK_ID];
    if ( tmp_access_registers_read_towards > 2'd0 ) begin
      reg_file__raddr[1'd0] = inport_opt_typed.read_reg_idx[BANK_ID];
      send_data_to_fu__msg_typed = reg_file__rdata[1'd0];
      send_data_to_xbar__msg_typed = reg_file__rdata[1'd0];
    end
    tmp_access_registers_write_reg_from = inport_opt_typed.write_reg_from[BANK_ID];
    if ( ( ~reset ) & ( tmp_access_registers_write_reg_from > 2'd0 ) ) begin
      wr_sel_data = inport_wdata_typed[tmp_access_registers_write_reg_from - 2'd1];
      if ( inport_valid[tmp_access_registers_write_reg_from - 2'd1] & outport_wr_rdy ) begin
        wr_accept = 1'd1;
        if ( ( ( ~wr_target_holds_token ) & ( ~wr_target_being_read ) ) | ( wr_target_being_read & inport_ctrl_proceed ) ) begin
          wr_en = 1'd1;
        end
        else
          skid_park = 1'd1;
      end
    end
    if ( skid_commit ) begin
      reg_file__waddr[1'd0] = skid_idx;
      reg_file__wdata[1'd0] = skid_data;
      reg_file__wen[1'd0] = 1'd1;
    end
    else if ( wr_en ) begin
      reg_file__waddr[1'd0] = inport_opt_typed.write_reg_idx[BANK_ID];
      reg_file__wdata[1'd0] = wr_sel_data;
      reg_file__wen[1'd0] = 1'd1;
    end
  end
  always_comb begin : update_send_val
    send_data_to_fu__val = ( ( ~reset ) & read_towards_fu ) & ( read_token_valid | ( ~read_armed ) );
    send_data_to_xbar__val = ( ( ~reset ) & read_towards_xbar ) & ( read_token_valid | ( ~read_armed ) );
  end
  always_comb begin : update_token_masks
    for ( int unsigned r = 0; r < REG_DEPTH; r++ ) begin
      token_set_mask[REG_ADDR_W'(r)] = ( wr_en & ( inport_opt_typed.write_reg_idx[BANK_ID] == REG_ADDR_W'(r) ) ) | ( skid_commit & ( skid_idx == REG_ADDR_W'(r) ) );
      token_clear_mask[REG_ADDR_W'(r)] = ( ( inport_ctrl_proceed & ( read_towards_fu | read_towards_xbar ) ) & ( inport_opt_typed.read_reg_idx[BANK_ID] == REG_ADDR_W'(r) ) ) & token_valid[REG_ADDR_W'(r)];
    end
  end
  always_comb begin : update_token_status
    tmp_update_token_status_read_towards = inport_opt_typed.read_reg_towards[BANK_ID];
    read_towards_fu = ( tmp_update_token_status_read_towards == 2'( READ_TOWARDS_FU ) ) | ( tmp_update_token_status_read_towards == 2'( READ_TOWARDS_BOTH ) );
    read_towards_xbar = ( tmp_update_token_status_read_towards == 2'( READ_TOWARDS_ROUTING_XBAR ) ) | ( tmp_update_token_status_read_towards == 2'( READ_TOWARDS_BOTH ) );
    read_token_valid = 1'd0;
    read_armed = 1'd0;
    wr_target_holds_token = 1'd0;
    skid_target_holds_token = 1'd0;
    for ( int unsigned r = 0; r < REG_DEPTH; r++ ) begin
      if ( inport_opt_typed.read_reg_idx[BANK_ID] == REG_ADDR_W'(r) ) begin
        read_token_valid = token_valid[REG_ADDR_W'(r)];
        read_armed = armed[REG_ADDR_W'(r)];
      end
      if ( inport_opt_typed.write_reg_idx[BANK_ID] == REG_ADDR_W'(r) ) begin
        wr_target_holds_token = token_valid[REG_ADDR_W'(r)];
      end
      if ( skid_idx == REG_ADDR_W'(r) ) begin
        skid_target_holds_token = token_valid[REG_ADDR_W'(r)];
      end
    end
    wr_target_being_read = ( read_towards_fu | read_towards_xbar ) & ( inport_opt_typed.read_reg_idx[BANK_ID] == inport_opt_typed.write_reg_idx[BANK_ID] );
    skid_target_being_read = ( read_towards_fu | read_towards_xbar ) & ( inport_opt_typed.read_reg_idx[BANK_ID] == skid_idx );
    skid_commit = skid_valid & ( ( skid_target_being_read & inport_ctrl_proceed ) | ( ( ~skid_target_being_read ) & ( ~skid_target_holds_token ) ) );
    outport_wr_rdy = ( ( ~wr_target_holds_token ) & ( ~wr_target_being_read ) ) | ( wr_target_being_read & ( ~skid_valid ) );
  end
  always_ff @(posedge clk) begin : update_token_valid
    if ( reset | clear ) begin
      token_valid <= '0;
      armed <= '0;
      skid_valid <= 1'd0;
    end
    else begin
      token_valid <= ( token_valid & ( ~token_clear_mask ) ) | token_set_mask;
      armed <= armed | token_set_mask;
      if ( skid_park ) begin
        skid_valid <= 1'd1;
        skid_data <= wr_sel_data;
        skid_idx <= inport_opt_typed.write_reg_idx[BANK_ID];
      end
      else if ( skid_commit ) begin
        skid_valid <= 1'd0;
      end
    end
  end
  assign reg_file__clk = clk;
  assign reg_file__reset = reset;
endmodule
