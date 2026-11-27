// Read-only observations. Configuration, data and queries use the public host.
integer control_log=0, control_cycle=0;
string control_log_path;
logic cfg_write[0:NUM_TILES-1],ctrl_step[0:NUM_TILES-1],store_fire[0:NUM_TILES-1];
logic [CTRL_ADDR_W-1:0] cfg_address[0:NUM_TILES-1];
logic [CTRL_BITS-1:0] cfg_word[0:NUM_TILES-1];
for(genvar ct=0;ct<NUM_TILES;ct++) begin : control_observers
  assign cfg_write[ct]=dut.tiles[ct].tile.base.core.ctrl_mem.reg_file__wen[0];
  assign cfg_address[ct]=dut.tiles[ct].tile.base.core.ctrl_mem.reg_file__waddr[0];
  assign cfg_word[ct]=dut.tiles[ct].tile.base.core.ctrl_mem.reg_file__wdata[0];
  assign ctrl_step[ct]=dut.tiles[ct].tile.base.core.ctrl_mem__send_ctrl__val &&
                      dut.tiles[ct].tile.base.core.ctrl_mem__send_ctrl__rdy;
  assign store_fire[ct]=dut.tiles[ct].waddr_val && dut.tiles[ct].waddr_rdy &&
                       dut.tiles[ct].wdata_val && dut.tiles[ct].wdata_rdy;
end
initial begin
  if(!$value$plusargs("CONTROL_TRACE=%s",control_log_path))$fatal(1,"Missing CONTROL_TRACE");
  control_log=$fopen(control_log_path,"w");if(!control_log)$fatal(1,"Control trace open");
end
always @(posedge clk) begin : record_control_events
  host_packet_t cp;
  if(reset)control_cycle=0;
  else begin
    if(recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy)
      $fdisplay(control_log,"H %0d %h",control_cycle,recv_from_cpu_pkt__msg);
    if(dut.ring_recv_val[NUM_TILES] && dut.ring_recv_rdy[NUM_TILES])
      $fdisplay(control_log,"I %0d %h",control_cycle,dut.ring_recv_msg[NUM_TILES]);
    for(integer ct=0;ct<NUM_TILES;ct++)begin
      if(dut.ring_send_val[ct] && dut.ring_send_rdy[ct])
        $fdisplay(control_log,"D %0d %0d %h",control_cycle,ct,dut.ring_send_msg[ct]);
      if(cfg_write[ct])$fdisplay(control_log,"W %0d %0d %0d %h",control_cycle,ct,cfg_address[ct],cfg_word[ct]);
      if(ctrl_step[ct])$fdisplay(control_log,"E %0d %0d",control_cycle,ct);
      if(store_fire[ct])$fdisplay(control_log,"S %0d %0d",control_cycle,ct);
      if(dut.ring_recv_val[ct] && dut.ring_recv_rdy[ct])
        $fdisplay(control_log,"U %0d %0d %h",control_cycle,ct,dut.ring_recv_msg[ct]);
    end
    if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy)
      $fdisplay(control_log,"O %0d %h",control_cycle,send_to_cpu_pkt__msg);
    control_cycle++;
  end
end
final if(control_log)$fclose(control_log);
