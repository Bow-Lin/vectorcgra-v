// Native parameterized scalar profile; migrated from ac96 ConstQueueDynamicRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_variant_const_queue #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int CONST_DEPTH = CTRL_DEPTH,
  localparam int CONST_ADDR_W = $clog2(CONST_DEPTH)
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [0:0] ctrl_proceed ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] recv_const__msg ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  output logic [DATA_BITS-1:0] send_const__msg ,
  input logic [0:0] send_const__rdy  ,
  output logic [0:0] send_const__val  
);
  `include "cgra_profile.svh"
  localparam int CONST_WR_W=$clog2(CONST_DEPTH+1);
  data_t recv_const__msg_typed ;
  assign recv_const__msg_typed = recv_const__msg;
  data_t send_const__msg_typed ;
  assign send_const__msg = send_const__msg_typed;
  logic [CONST_ADDR_W-1:0] rd_cur;
  logic [CONST_WR_W-1:0] wr_cur;
  logic [0:0] reg_file__clk;
  logic [CONST_ADDR_W-1:0] reg_file__raddr [0:0];
  data_t reg_file__rdata [0:0];
  logic [0:0] reg_file__reset;
  logic [CONST_ADDR_W-1:0] reg_file__waddr [0:0];
  data_t reg_file__wdata [0:0];
  logic [0:0] reg_file__wen [0:0];
  cgra_register_file #(.WIDTH(DATA_BITS), .DEPTH(CONST_DEPTH), .RD_PORTS(1), .WR_PORTS(1)) reg_file
  (
    .clk( reg_file__clk ),
    .raddr( reg_file__raddr ),
    .rdata( reg_file__rdata ),
    .reset( reg_file__reset ),
    .waddr( reg_file__waddr ),
    .wdata( reg_file__wdata ),
    .wen( reg_file__wen )
  );
  logic [0:0] tmp_load_const_not_full;
  logic [0:0] tmp_update_wr_cur_not_full;
  always_comb begin : load_const
    reg_file__waddr[1'd0] = CONST_ADDR_W'(0);
    reg_file__wdata[1'd0] = '0;
    reg_file__wen[1'd0] = 1'd0;
    tmp_load_const_not_full = wr_cur < CONST_DEPTH;
    recv_const__rdy = tmp_load_const_not_full;
    if ( recv_const__val & tmp_load_const_not_full ) begin
      reg_file__waddr[1'd0] = CONST_ADDR_W'(wr_cur);
      reg_file__wdata[1'd0] = recv_const__msg_typed;
      reg_file__wen[1'd0] = 1'd1;
    end
  end
  always_comb begin : update_send_val
    if ( CONST_WR_W'(rd_cur) < wr_cur ) begin
      send_const__val = 1'd1;
    end
    else
      send_const__val = 1'd0;
  end
  always_ff @(posedge clk) begin : update_rd_cur
    if ( reset | clear ) begin
      rd_cur <= CONST_ADDR_W'(0);
    end
    else if ( send_const__rdy & ctrl_proceed ) begin
      if ( CONST_WR_W'(rd_cur) < ( wr_cur - CONST_WR_W'(1) ) ) begin
        rd_cur <= rd_cur + CONST_ADDR_W'(1);
      end
      else
        rd_cur <= CONST_ADDR_W'(0);
    end
  end
  always_ff @(posedge clk) begin : update_wr_cur
    tmp_update_wr_cur_not_full = wr_cur < CONST_DEPTH;
    if ( reset | clear ) begin
      wr_cur <= CONST_WR_W'(0);
    end
    else if ( recv_const__val & tmp_update_wr_cur_not_full ) begin
      wr_cur <= wr_cur + CONST_WR_W'(1);
    end
  end
  assign reg_file__clk = clk;
  assign reg_file__reset = reset;
  assign send_const__msg_typed = reg_file__rdata[0];
  assign reg_file__raddr[0] = rd_cur;
endmodule
