// Native parameterized scalar profile; migrated from ac96 CrossbarRTL.
// State and update-block names preserve the original cycle semantics.
`include "cgra_profile_defs.svh"
module tile_static_crossbar #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int INPUTS=ROUTING_OUTPUTS,
  localparam int SELECT_W=$clog2(INPUTS+1),
  localparam int INPUT_W=$clog2(INPUTS)
) (
  input  logic [CGRA_ID_W-1:0] cgra_id ,
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [0:0] compute_done ,
  input  logic [0:0] crossbar_id ,
  input  logic [SELECT_W-1:0] crossbar_outport [0:ROUTING_OUTPUTS-1],
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [2:0] prologue_count_inport [0:CTRL_DEPTH-1][0:INPUTS-1],
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [DATA_BITS-1:0] recv_data__msg [0:INPUTS-1] ,
  output logic [0:0] recv_data__rdy [0:INPUTS-1] ,
  input logic [0:0] recv_data__val [0:INPUTS-1] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [DATA_BITS-1:0] send_data__msg [0:ROUTING_OUTPUTS-1] ,
  input logic [0:0] send_data__rdy [0:ROUTING_OUTPUTS-1] ,
  output logic [0:0] send_data__val [0:ROUTING_OUTPUTS-1] 
);
  `include "cgra_profile.svh"
  data_t recv_data__msg_typed [0:INPUTS-1];
  for (genvar p=0; p<INPUTS; p++) begin : port_recv_data__msg
    assign recv_data__msg_typed[p] = recv_data__msg[p];
  end
  data_t send_data__msg_typed [0:ROUTING_OUTPUTS-1];
  for (genvar p=0; p<ROUTING_OUTPUTS; p++) begin : port_send_data__msg
    assign send_data__msg[p] = send_data__msg_typed[p];
  end
  ctrl_t recv_opt__msg_typed ;
  assign recv_opt__msg_typed = recv_opt__msg;
  localparam int num_outports_at_update_signal = ROUTING_OUTPUTS;
  localparam logic [6:0] OPT_START  = 7'd0;
  localparam int num_outports_at_update_prologue_counter_next = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_send_accepted_next = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_prologue_allowing_vector = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_prologue_or_valid_vector = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_in_dir_vector = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_rdy_vector = ROUTING_OUTPUTS;
  localparam int outport_towards_local_base_id_at_update_rdy_vector = TILE_PORTS;
  localparam int num_outports_at_update_valid_vector = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_recv_required_vector = ROUTING_OUTPUTS;
  localparam int num_outports_at_update_send_required_vector = ROUTING_OUTPUTS;
  logic [0:0] all_send_accepted;
  logic [ROUTING_OUTPUTS-1:0] during_prologue_allowing_vector;
  logic [SELECT_W-1:0] in_dir [0:ROUTING_OUTPUTS-1];
  logic [INPUT_W-1:0] in_dir_local [0:ROUTING_OUTPUTS-1];
  logic [2:0] prologue_count_wire [0:CTRL_DEPTH-1][0:INPUTS-1];
  logic [2:0] prologue_counter [0:CTRL_DEPTH-1][0:INPUTS-1];
  logic [2:0] prologue_counter_next [0:CTRL_DEPTH-1][0:INPUTS-1];
  data_t recv_data_msg [0:INPUTS-1];
  logic [0:0] recv_data_val [0:INPUTS-1];
  logic [INPUTS-1:0] recv_required_vector;
  logic [ROUTING_OUTPUTS-1:0] recv_valid_or_during_prologue_allowing_vector;
  logic [ROUTING_OUTPUTS-1:0] recv_valid_vector;
  logic [ROUTING_OUTPUTS-1:0] send_accepted;
  logic [ROUTING_OUTPUTS-1:0] send_accepted_next;
  logic [ROUTING_OUTPUTS-1:0] send_rdy_vector;
  logic [ROUTING_OUTPUTS-1:0] send_required_vector;
  always_comb begin : update_in_dir_vector
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_in_dir_vector ); i++ ) begin
      in_dir[i] = '0;
      in_dir_local[i] = '0;
    end
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_in_dir_vector ); i++ ) begin
      in_dir[i] = crossbar_outport[i];
      if ( in_dir[i] != '0 ) begin
        in_dir_local[i] = INPUT_W'(in_dir[i] - SELECT_W'(1));
      end
    end
  end
  always_comb begin : update_prologue_allowing_vector
    during_prologue_allowing_vector = '0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_prologue_allowing_vector ); i++ )
      if ( in_dir[i] != '0 ) begin
        during_prologue_allowing_vector[i] = prologue_counter[ctrl_addr_inport][in_dir_local[i]] < prologue_count_wire[ctrl_addr_inport][in_dir_local[i]];
      end
      else
        during_prologue_allowing_vector[i] = 1'd0;
  end
  always_comb begin : update_prologue_counter_next
    for ( int unsigned addr = 0; addr < CTRL_DEPTH; addr++ )
      for ( int unsigned i = 0; i < INPUTS; i++ ) begin
        prologue_counter_next[CTRL_ADDR_W'(addr)][i] = prologue_counter[CTRL_ADDR_W'(addr)][i];
        for ( int unsigned j = 0; j < 4'( num_outports_at_update_prologue_counter_next ); j++ )
          if ( ( ( ( recv_opt__rdy & ( in_dir[j] != '0 ) ) & ( in_dir_local[j] == i ) ) & ( CTRL_ADDR_W'(addr) == ctrl_addr_inport ) ) & ( prologue_counter[CTRL_ADDR_W'(addr)][i] < prologue_count_wire[CTRL_ADDR_W'(addr)][i] ) ) begin
            prologue_counter_next[CTRL_ADDR_W'(addr)][i] = prologue_counter[CTRL_ADDR_W'(addr)][i] + 3'd1;
          end
      end
  end
  always_comb begin : update_prologue_or_valid_vector
    recv_valid_or_during_prologue_allowing_vector = '0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_prologue_or_valid_vector ); i++ )
      recv_valid_or_during_prologue_allowing_vector[i] = recv_valid_vector[i] | during_prologue_allowing_vector[i];
  end
  always_comb begin : update_rdy_vector
    send_rdy_vector = '0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_rdy_vector ); i++ )
      if ( ( in_dir[i] != '0 ) & ( ( ~compute_done ) | ( i < outport_towards_local_base_id_at_update_rdy_vector ) ) ) begin
        send_rdy_vector[i] = send_data__rdy[i];
      end
      else
        send_rdy_vector[i] = 1'd1;
  end
  always_comb begin : update_recv_required_vector
    for ( int unsigned i = 0; i < INPUTS; i++ )
      recv_required_vector[i] = 1'd0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_recv_required_vector ); i++ )
      if ( in_dir[i] != '0 ) begin
        recv_required_vector[in_dir_local[i]] = ~during_prologue_allowing_vector[i];
      end
  end
  always_comb begin : update_send_accepted_next
    send_accepted_next = send_accepted;
    if ( recv_opt__val & ( recv_opt__msg_typed.operation != 7'( OPT_START ) ) ) begin
      for ( int unsigned i = 0; i < 4'( num_outports_at_update_send_accepted_next ); i++ )
        if ( ( ( send_required_vector[i] & ( ~send_accepted[i] ) ) & send_data__rdy[i] ) & send_data__val[i] ) begin
          send_accepted_next[i] = 1'd1;
        end
      if ( recv_opt__rdy ) begin
        send_accepted_next = '0;
      end
    end
    else
      send_accepted_next = '0;
  end
  always_comb begin : update_send_required_vector
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_send_required_vector ); i++ )
      send_required_vector[i] = 1'd0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_send_required_vector ); i++ )
      if ( in_dir[i] != '0 ) begin
        send_required_vector[i] = 1'd1;
      end
  end
  always_comb begin : update_signal
    for ( int unsigned i = 0; i < INPUTS; i++ )
      recv_data__rdy[i] = 1'd0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_signal ); i++ ) begin
      send_data__val[i] = 1'd0;
      send_data__msg_typed[i] = '0;
    end
    recv_opt__rdy = 1'd0;
    all_send_accepted = 1'd0;
    if ( recv_opt__val & ( recv_opt__msg_typed.operation != 7'( OPT_START ) ) ) begin
      all_send_accepted = 1'd1;
      for ( int unsigned i = 0; i < 4'( num_outports_at_update_signal ); i++ )
        if ( ( send_required_vector[i] & ( ~send_accepted[i] ) ) & ( ~send_rdy_vector[i] ) ) begin
          all_send_accepted = 1'd0;
        end
      for ( int unsigned i = 0; i < INPUTS; i++ )
        recv_data__rdy[i] = ( ( & recv_valid_vector ) & all_send_accepted ) & recv_required_vector[i];
      for ( int unsigned i = 0; i < 4'( num_outports_at_update_signal ); i++ ) begin
        send_data__val[i] = ( ( & recv_valid_vector ) & send_required_vector[i] ) & ( ~send_accepted[i] );
        if ( ( ( & recv_valid_vector ) & send_required_vector[i] ) & ( ~send_accepted[i] ) ) begin
          send_data__msg_typed[i].payload = recv_data_msg[in_dir_local[i]].payload;
          send_data__msg_typed[i].predicate = recv_data_msg[in_dir_local[i]].predicate;
        end
      end
      recv_opt__rdy = all_send_accepted & ( & recv_valid_or_during_prologue_allowing_vector );
    end
  end
  always_comb begin : update_valid_vector
    recv_valid_vector = '0;
    for ( int unsigned i = 0; i < 4'( num_outports_at_update_valid_vector ); i++ )
      if ( in_dir[i] != '0 ) begin
        recv_valid_vector[i] = recv_data_val[in_dir_local[i]];
      end
      else
        recv_valid_vector[i] = 1'd1;
  end
  always_ff @(posedge clk) begin : update_prologue_counter
    if ( reset | clear ) begin
      for ( int unsigned addr = 0; addr < CTRL_DEPTH; addr++ )
        for ( int unsigned i = 0; i < INPUTS; i++ )
          prologue_counter[CTRL_ADDR_W'(addr)][i] <= 3'd0;
      send_accepted <= '0;
    end
    else begin
      for ( int unsigned addr = 0; addr < CTRL_DEPTH; addr++ )
        for ( int unsigned i = 0; i < INPUTS; i++ )
          prologue_counter[CTRL_ADDR_W'(addr)][i] <= prologue_counter_next[CTRL_ADDR_W'(addr)][i];
      send_accepted <= send_accepted_next;
    end
  end
  for (genvar i=0;i<INPUTS;i++) begin : input_aliases
    assign recv_data_msg[i]=recv_data__msg_typed[i];
    assign recv_data_val[i]=recv_data__val[i];
  end
  for (genvar a=0;a<CTRL_DEPTH;a++) begin : prologue_aliases
    for (genvar i=0;i<INPUTS;i++) begin : inputs
      assign prologue_count_wire[a][i]=prologue_count_inport[a][i];
    end
  end
endmodule
