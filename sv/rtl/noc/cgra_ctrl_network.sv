// Optional single-root control transport. The generic credit ring is unchanged.
// LAYOUT=1 balanced tree, LAYOUT=2 row-grouped tree; complete packets are retained.
`include "cgra_ctrl_commands.svh"
module cgra_ctrl_network #(
  parameter int WIDTH=191, TILES=4, MAX_TILES=TILES, COLS=2, LAYOUT=1,
  parameter int DST_LSB=185, DST_WIDTH=$clog2(MAX_TILES+1), VC_LSB=170,
  parameter bit MULTICAST=0,
  parameter int CMD_LSB=164, DATA_LSB=132, DATA_WIDTH=32,
  parameter int MASK_ADDR_LSB=122, MASK_ADDR_WIDTH=7,
  parameter int CTRL_ADDR_WIDTH=3, CTRL_DEPTH=8
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg [0:MAX_TILES],
  input logic recv_val [0:MAX_TILES],
  output logic recv_rdy [0:MAX_TILES],
  output logic [WIDTH-1:0] send_msg [0:MAX_TILES],
  output logic send_val [0:MAX_TILES],
  input logic send_rdy [0:MAX_TILES]
);
  initial if(TILES<1 || MAX_TILES<TILES || COLS<1 || TILES%COLS!=0 ||
             (LAYOUT!=1 && LAYOUT!=2) || DST_WIDTH<$clog2(MAX_TILES+1))
    $fatal(1,"CTRL_NETWORK_PARAMETERS");
  // Preserve the public VC bit seen after the native ring's shortest-path
  // dateline routing. No physical VC or cyclic channel exists in this backend.
  function automatic bit crosses_dateline(input integer src,input integer dst);
    integer left_distance,right_distance;
    begin
      left_distance=(src-dst+MAX_TILES+1)%(MAX_TILES+1);
      right_distance=(dst-src+MAX_TILES+1)%(MAX_TILES+1);
      if(src==dst) crosses_dateline=0;
      else if(left_distance<right_distance) crosses_dateline=(dst>src);
      else crosses_dateline=(dst<src);
    end
  endfunction
  logic [TILES-1:0] targets;
  logic down_ready, legal_target, is_mask, mask_ready;
  logic [WIDTH-1:0] dispatch_msg;
  logic [WIDTH-1:0] down_msg [0:TILES-1], up_msg [0:TILES-1];
  logic down_val [0:TILES-1], down_rdy [0:TILES-1];
  logic up_val [0:TILES-1], up_rdy [0:TILES-1];
  if(!MULTICAST) begin : unicast_only
    assign legal_target=int'(recv_msg[TILES][DST_LSB+:DST_WIDTH])<TILES;
    assign is_mask=0;assign mask_ready=0;
    assign dispatch_msg=recv_msg[TILES];
    always_comb begin
      targets='0;
      for(integer t=0;t<TILES;t++)
        targets[t]=(recv_msg[TILES][DST_LSB+:DST_WIDTH]==DST_WIDTH'(t));
    end
`ifndef SYNTHESIS
    always @(posedge clk) if(!reset && recv_val[TILES] &&
      (recv_msg[TILES][CMD_LSB+:6]==`CGRA_CMD_CTRL_MASK_WORD ||
       recv_msg[TILES][CMD_LSB+:6]==`CGRA_CMD_CONFIG_MULTICAST))
      $fatal(1,"CTRL_MULTICAST_DISABLED");
`endif
  end else begin : multicast_ingress
    localparam int WORDS=(TILES+DATA_WIDTH-1)/DATA_WIDTH;
    localparam int INDEX_W=WORDS<=1 ? 1 : $clog2(WORDS);
    logic [TILES-1:0] mask;
    logic mask_valid,is_multicast,valid_piece;
    logic [INDEX_W-1:0] next_word;
    logic [MASK_ADDR_WIDTH-1:0] word_index;
    initial if(DATA_WIDTH<1 || DATA_LSB+DATA_WIDTH>WIDTH || MASK_ADDR_WIDTH>32 ||
      64'(WORDS)>(64'd1<<MASK_ADDR_WIDTH))$fatal(1,"CTRL_MULTICAST_PARAMETERS");
    assign is_mask=recv_msg[TILES][CMD_LSB+:6]==`CGRA_CMD_CTRL_MASK_WORD;
    assign is_multicast=recv_msg[TILES][CMD_LSB+:6]==`CGRA_CMD_CONFIG_MULTICAST;
    assign word_index=recv_msg[TILES][MASK_ADDR_LSB+:MASK_ADDR_WIDTH];
    always_comb begin
      valid_piece=(int'(word_index)<WORDS) && (word_index==0 || int'(word_index)==int'(next_word));
      for(integer b=0;b<DATA_WIDTH;b++)
        if(int'(word_index)*DATA_WIDTH+b>=TILES && recv_msg[TILES][DATA_LSB+b])valid_piece=0;
    end
    assign mask_ready=valid_piece;
    always_ff @(posedge clk) begin
      if(reset)begin mask<='0;mask_valid<=0;next_word<='0;end
      else if(recv_val[TILES] && recv_rdy[TILES] && is_mask)begin
        for(integer b=0;b<TILES;b++)
          if(b/DATA_WIDTH==int'(word_index))mask[b]<=recv_msg[TILES][DATA_LSB+(b%DATA_WIDTH)];
        if(int'(word_index)==WORDS-1)begin mask_valid<=1;next_word<='0;end
        else begin mask_valid<=0;next_word<=INDEX_W'(word_index+1'b1);end
      end
    end
    always_comb begin
      dispatch_msg=recv_msg[TILES];targets='0;
      legal_target=int'(recv_msg[TILES][DST_LSB+:DST_WIDTH])<TILES;
      if(is_multicast)begin
        targets=mask;
        dispatch_msg[CMD_LSB+:6]=6'd3;
        legal_target=mask_valid && (mask!='0) &&
          int'(recv_msg[TILES][0+:CTRL_ADDR_WIDTH])<CTRL_DEPTH;
      end else for(integer t=0;t<TILES;t++)
        targets[t]=(recv_msg[TILES][DST_LSB+:DST_WIDTH]==DST_WIDTH'(t));
    end
`ifndef SYNTHESIS
    always @(posedge clk) if(!reset && recv_val[TILES])begin
      if(is_mask && !mask_ready)$fatal(1,"CTRL_MULTICAST_MASK_WORD");
      if(is_multicast && !legal_target)$fatal(1,"CTRL_MULTICAST_TARGETS");
    end
`endif
  end
  assign recv_rdy[TILES]=!reset && (is_mask ? mask_ready : (legal_target && down_ready));
  cgra_ctrl_fanout #(.WIDTH(WIDTH),.LEAVES(TILES),.COLS(COLS),.LAYOUT(LAYOUT)) distribute (
    .clk,.reset,.recv_msg(dispatch_msg),.recv_mask(targets),
    .recv_val(!reset && !is_mask && legal_target && recv_val[TILES]),.recv_rdy(down_ready),
    .send_msg(down_msg),.send_val(down_val),.send_rdy(down_rdy));
  cgra_ctrl_gather #(.WIDTH(WIDTH),.LEAVES(TILES),.COLS(COLS),.LAYOUT(LAYOUT)) gather (
    .clk,.reset,.recv_msg(up_msg),.recv_val(up_val),.recv_rdy(up_rdy),
    .send_msg(send_msg[TILES]),.send_val(send_val[TILES]),.send_rdy(send_rdy[TILES]));
  for(genvar t=0;t<TILES;t++) begin : tiles
    logic legal_return;
    assign legal_return=recv_msg[t][DST_LSB+:DST_WIDTH]==DST_WIDTH'(TILES);
    always_comb begin
      send_msg[t]=down_msg[t];
      send_msg[t][DST_LSB+:DST_WIDTH]=DST_WIDTH'(t);
      send_msg[t][VC_LSB]=down_msg[t][VC_LSB] | crosses_dateline(TILES,t);
      up_msg[t]=recv_msg[t];
      up_msg[t][VC_LSB]=recv_msg[t][VC_LSB] | crosses_dateline(t,TILES);
    end
    assign send_val[t]=!reset && down_val[t];
    assign down_rdy[t]=!reset && send_rdy[t];
    assign up_val[t]=!reset && legal_return && recv_val[t];
    assign recv_rdy[t]=!reset && legal_return && up_rdy[t];
`ifndef SYNTHESIS
    always @(posedge clk) if(!reset && recv_val[t] && !legal_return)
      $fatal(1,"CTRL_NETWORK_RETURN_TARGET tile=%0d",t);
`endif
  end
  for(genvar t=TILES+1;t<=MAX_TILES;t++) begin : absent
    assign recv_rdy[t]=1'b0;
    assign send_msg[t]='0;
    assign send_val[t]=1'b0;
`ifndef SYNTHESIS
    always @(posedge clk) if(!reset && recv_val[t]) $fatal(1,"CTRL_NETWORK_ABSENT_SOURCE");
`endif
  end
`ifndef SYNTHESIS
  always @(posedge clk) if(!reset && recv_val[TILES] && !is_mask && !legal_target &&
    !(MULTICAST && recv_msg[TILES][CMD_LSB+:6]==`CGRA_CMD_CONFIG_MULTICAST))
    $fatal(1,"CTRL_NETWORK_INVALID_TARGET");
`endif
endmodule
