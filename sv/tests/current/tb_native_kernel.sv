`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tb_native_kernel #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS);
  logic [GLOBAL_ADDR_W-1:0] address_lower, address_upper;
  logic [CGRA_ID_W-1:0] cgra_id;
  logic clk, reset;
  logic [DATA_BITS-1:0] recv_data_on_boundary_east__msg [0:ROWS-1];
  logic recv_data_on_boundary_east__rdy [0:ROWS-1];
  logic recv_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_north__msg [0:COLS-1];
  logic recv_data_on_boundary_north__rdy [0:COLS-1];
  logic recv_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_south__msg [0:COLS-1];
  logic recv_data_on_boundary_south__rdy [0:COLS-1];
  logic recv_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_west__msg [0:ROWS-1];
  logic recv_data_on_boundary_west__rdy [0:ROWS-1];
  logic recv_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg;
  logic recv_from_cpu_pkt__rdy;
  logic recv_from_cpu_pkt__val;
  logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg;
  logic recv_from_inter_cgra_noc__rdy;
  logic recv_from_inter_cgra_noc__val;
  logic [DATA_BITS-1:0] send_data_on_boundary_east__msg [0:ROWS-1];
  logic send_data_on_boundary_east__rdy [0:ROWS-1];
  logic send_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_north__msg [0:COLS-1];
  logic send_data_on_boundary_north__rdy [0:COLS-1];
  logic send_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_south__msg [0:COLS-1];
  logic send_data_on_boundary_south__rdy [0:COLS-1];
  logic send_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_west__msg [0:ROWS-1];
  logic send_data_on_boundary_west__rdy [0:ROWS-1];
  logic send_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] send_to_cpu_pkt__msg;
  logic send_to_cpu_pkt__rdy;
  logic send_to_cpu_pkt__val;
  logic [NOC_BITS-1:0] send_to_inter_cgra_noc__msg;
  logic send_to_inter_cgra_noc__rdy;
  logic send_to_inter_cgra_noc__val;
  logic [138:0] dma_cmd__msg;
  logic dma_cmd__val;
  logic dma_cmd__rdy;
  logic [7:0] dma_done__msg;
  logic dma_done__val;
  logic dma_done__rdy;
  logic [31:0] recv_from_dma_spm_rd_req__msg;
  logic recv_from_dma_spm_rd_req__val;
  logic recv_from_dma_spm_rd_req__rdy;
  logic [67:0] recv_from_dma_spm_wr_req__msg;
  logic recv_from_dma_spm_wr_req__val;
  logic recv_from_dma_spm_wr_req__rdy;
  logic [31:0] send_to_dma_spm_rd_resp__msg;
  logic send_to_dma_spm_rd_resp__val;
  logic send_to_dma_spm_rd_resp__rdy;
  logic [HOST_BITS-1:0] recv_from_im2col_pkt__msg;
  logic recv_from_im2col_pkt__val;
  logic recv_from_im2col_pkt__rdy;
  logic [HOST_BITS-1:0] send_to_im2col_engine_pkt__msg;
  logic send_to_im2col_engine_pkt__val;
  logic send_to_im2col_engine_pkt__rdy;
  `include "cgra_profile.svh"
  cgra_system #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND, .IS_MULTI(0)) dut(.*);
  int cycle=0,fd,rc,completed=0,loads=0,query_index=0,words=0;
  int expected_addr[0:255];
  logic [DATA_W-1:0] expected_value[0:255];
  logic [HOST_BITS-1:0] program_packet, expected_return;
  host_packet_t packet, response;
  logic [NUM_TILES-1:0] administrative_done='0;
  string directory;
  int diagnostic_drain=0, max_cycles=12000, math_errors=0;
  int identity_nnz=-1;
  int identity_stores /*verilator public_flat_rw*/ =0;
  bit [255:0] stored_addresses /*verilator public_flat_rw*/ ='0;
  bit check_store_counts=0;
  int required_stores /*verilator public_flat_rw*/ =0;
  int watched_stores /*verilator public_flat_rw*/ =0;
  int expected_stores [0:255];
  int actual_stores [0:255];
  string store_file;
  int file_addr, file_count;
  logic [DATA_W-1:0] file_value;
  task automatic tick;
    bit completion_this_edge;
    completion_this_edge=0;
    #5;
    if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
      response=send_to_cpu_pkt__msg;
      if(response.payload.cmd==6'd14) begin
        if(send_to_cpu_pkt__msg===expected_return) begin
          completion_this_edge=1;
          if($test$plusargs("TRACE_FU")) $display("KERNEL_RETURN_SAMPLE cycle=%0d",cycle);
        end
        else if(response.src<NUM_TILES && response.payload.ctrl=='0 && response.payload.data=='0 && response.payload.data_addr=='0 && response.payload.ctrl_addr=='0) begin
          if(administrative_done[response.src]) $fatal(1,"Duplicate control-count completion");
          administrative_done[response.src]=1'b1;
        end else $fatal(1,"UNEXPECTED_RETURN cycle=%0d got=%h expected=%h",cycle,send_to_cpu_pkt__msg,expected_return);
      end else if(response.payload.cmd==6'd11) begin
        if(loads>=words) $fatal(1,"Unrequested load response");
        if(response.payload.data_addr!==GLOBAL_ADDR_W'(expected_addr[loads]) || response.src_cgra_id!=0 || response.dst_cgra_id!=0)
          $fatal(1,"KERNEL_RESPONSE_ADDRESS index=%0d got=%0d expected=%0d",loads,response.payload.data_addr,expected_addr[loads]);
        if(response.payload.data.payload!==expected_value[loads] || !response.payload.data.predicate) begin
          if(!$test$plusargs("DIAGNOSTIC_ALL_RESULTS"))
            $fatal(1,"KERNEL_MATH index=%0d addr=%0d actual=%0d expected=%0d",loads,expected_addr[loads],response.payload.data.payload,expected_value[loads]);
          $display("KERNEL_MATH index=%0d addr=%0d actual=%0d expected=%0d",loads,expected_addr[loads],response.payload.data.payload,expected_value[loads]);
          math_errors++;
        end
        loads++;
      end else $fatal(1,"Unexpected host response command=%0d",response.payload.cmd);
    end
    // Sample both host completion and memory handshakes on the same edge.
    // Checking before posedge wrongly rejects a legal concurrent last store.
    clk=1;#5;
    if(completion_this_edge) begin
      if(identity_nnz>=0 && identity_stores!=identity_nnz)
        $fatal(1,"KERNEL_EARLY_RETURN cycle=%0d stores=%0d expected=%0d",cycle,identity_stores,identity_nnz);
      if(check_store_counts && watched_stores!=required_stores)
        $fatal(1,"KERNEL_EARLY_RETURN cycle=%0d stores=%0d expected=%0d",cycle,watched_stores,required_stores);
      completed++;
    end
    clk=0;cycle++;
    send_to_cpu_pkt__rdy=!$test$plusargs("STALL_FOREVER") &&
        (!$test$plusargs("BACKPRESSURE") || (cycle%11>=5 && cycle%7!=0));
    if(cycle>max_cycles) $fatal(1,"NATIVE_KERNEL_TIMEOUT completed=%0d loads=%0d",completed,loads);
  endtask
  task automatic send_packet(input logic [HOST_BITS-1:0] value);
    if($test$plusargs("HOST_GAPS")) repeat(cycle%4)tick();
    recv_from_cpu_pkt__msg=value;recv_from_cpu_pkt__val=1;
    #1;while(!recv_from_cpu_pkt__rdy) begin tick();#1;end
    tick();recv_from_cpu_pkt__val=0;
  endtask
  initial begin
    clk=0;
    if($value$plusargs("DIAGNOSTIC_DRAIN=%d",diagnostic_drain)) begin end
    if($value$plusargs("MAX_CYCLES=%d",max_cycles)) begin end
    if($value$plusargs("IDENTITY_NNZ=%d",identity_nnz)) begin
      if(identity_nnz<0 || identity_nnz>32)$fatal(1,"Invalid IDENTITY_NNZ");
    end

    address_upper='0;
    cgra_id='0;
    reset='0;
    for(int p=0;p<=ROWS-1;p++) recv_data_on_boundary_east__msg[p]='0;
    for(int p=0;p<=ROWS-1;p++) recv_data_on_boundary_east__val[p]='0;
    for(int p=0;p<=COLS-1;p++) recv_data_on_boundary_north__msg[p]='0;
    for(int p=0;p<=COLS-1;p++) recv_data_on_boundary_north__val[p]='0;
    for(int p=0;p<=COLS-1;p++) recv_data_on_boundary_south__msg[p]='0;
    for(int p=0;p<=COLS-1;p++) recv_data_on_boundary_south__val[p]='0;
    for(int p=0;p<=ROWS-1;p++) recv_data_on_boundary_west__msg[p]='0;
    for(int p=0;p<=ROWS-1;p++) recv_data_on_boundary_west__val[p]='0;
    recv_from_cpu_pkt__msg='0;
    recv_from_cpu_pkt__val='0;
    recv_from_inter_cgra_noc__msg='0;
    recv_from_inter_cgra_noc__val='0;
    for(int p=0;p<=ROWS-1;p++) send_data_on_boundary_east__rdy[p]='0;
    for(int p=0;p<=COLS-1;p++) send_data_on_boundary_north__rdy[p]='0;
    for(int p=0;p<=COLS-1;p++) send_data_on_boundary_south__rdy[p]='0;
    for(int p=0;p<=ROWS-1;p++) send_data_on_boundary_west__rdy[p]='0;
    send_to_cpu_pkt__rdy='0;
    send_to_inter_cgra_noc__rdy='0;
    dma_cmd__rdy='0;
    dma_done__msg='0;
    dma_done__val='0;
    recv_from_dma_spm_rd_req__msg='0;
    recv_from_dma_spm_rd_req__val='0;
    recv_from_dma_spm_wr_req__msg='0;
    recv_from_dma_spm_wr_req__val='0;
    send_to_dma_spm_rd_resp__rdy='0;
    recv_from_im2col_pkt__msg='0;
    recv_from_im2col_pkt__val='0;
    send_to_im2col_engine_pkt__rdy='0;

    if(!$value$plusargs("PROGRAM=%s",directory)) $fatal(1,"Missing PROGRAM directory");
    fd=$fopen({directory,"/return.hex"},"r");if(!fd)$fatal(1,"Missing expected return");
    rc=$fscanf(fd,"%h",expected_return);if(rc!=1)$fatal(1,"Invalid return");$fclose(fd);
    for(int i=0;i<256;i++) begin expected_stores[i]=0;actual_stores[i]=0;end
    if($value$plusargs("STORE_COUNTS=%s",store_file)) begin
      check_store_counts=1;
      fd=$fopen(store_file,"r");if(!fd)$fatal(1,"Missing store counts");
      while(!$feof(fd)) begin
        rc=$fscanf(fd,"%d %d\n",file_addr,file_count);
        if(rc==2) begin
          if(file_addr<0 || file_addr>=256 || file_count<1 || expected_stores[file_addr]!=0)
            $fatal(1,"Malformed store counts");
          expected_stores[file_addr]=file_count;required_stores+=file_count;
        end else if(rc>0 || !$feof(fd)) $fatal(1,"Malformed store counts");
      end
      $fclose(fd);
    end
    fd=$fopen({directory,"/expected.hex"},"r");if(!fd)$fatal(1,"Missing expected memory");
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%d %h\n",file_addr,file_value);
      if(rc==2) begin
        if(words>=256 || file_addr<0 || file_addr>=NUM_BANKS*BANK_DEPTH) $fatal(1,"Invalid expected memory address");
        expected_addr[words]=file_addr;expected_value[words]=file_value;words++;
      end else if(rc>0 || !$feof(fd)) $fatal(1,"Malformed expected memory");
    end
    $fclose(fd);
    if($test$plusargs("EXPECT_FAILURE")) expected_value[0]^=1;
    address_lower=0;address_upper=GLOBAL_ADDR_W'(NUM_BANKS*BANK_DEPTH-1);
    send_to_cpu_pkt__rdy=!$test$plusargs("STALL_FOREVER");reset=1;tick();tick();tick();reset=0;
    fd=$fopen({directory,"/program.hex"},"r");if(!fd)$fatal(1,"Missing program");
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%h\n",program_packet);
      if(rc==1)send_packet(program_packet);else if(rc>0 || !$feof(fd))$fatal(1,"Malformed program");
    end
    $fclose(fd);
    while(completed==0)tick();
    repeat(diagnostic_drain)tick();
    for(query_index=0;query_index<words;query_index++) begin
      packet='0;packet.payload.cmd=6'd10;
      packet.payload.data_addr=GLOBAL_ADDR_W'(expected_addr[query_index]);
      send_packet(packet);
      while(loads<=query_index)tick();
    end
    if(completed!=1 || loads!=words || words==0 || math_errors!=0)$fatal(1,"Incomplete functional acceptance");
    if(identity_nnz>=0 && identity_stores!=identity_nnz)$fatal(1,"KERNEL_STORE_COUNT");
    if(check_store_counts) begin
      for(int i=0;i<256;i++) if(expected_stores[i]!=actual_stores[i])
        $fatal(1,"KERNEL_STORE_COUNT addr=%0d actual=%0d expected=%0d",i,actual_stores[i],expected_stores[i]);
      $display("NATIVE_STORE_COUNTS_PASS stores=%0d",watched_stores);
    end
    if(identity_nnz>=0)$display("NATIVE_IDENTITY_STORES_PASS nnz=%0d stores=%0d",identity_nnz,identity_stores);
    $display("NATIVE_KERNEL_MATH_PASS program=%s cycles=%0d words=%0d",directory,cycle,loads);
    $finish;
  end
  for(genvar t=0;t<NUM_TILES;t++) begin : diagnostics
    always @(posedge clk) if(!reset && check_store_counts &&
        dut.tiles[t].tile.base.core.to_mem_wdata__val &&
        dut.tiles[t].tile.base.core.to_mem_wdata__rdy) begin
      if(completed!=0)$fatal(1,"KERNEL_LATE_STORE tile=%0d",t);
      if(!dut.tiles[t].tile.base.core.to_mem_waddr__val ||
         !dut.tiles[t].tile.base.core.to_mem_waddr__rdy)
        $fatal(1,"KERNEL_STORE_PAIR tile=%0d",t);
      if(int'(dut.tiles[t].tile.base.core.to_mem_waddr__msg)>=256 ||
         actual_stores[dut.tiles[t].tile.base.core.to_mem_waddr__msg]>=
         expected_stores[dut.tiles[t].tile.base.core.to_mem_waddr__msg])
        $fatal(1,"KERNEL_STRAY_STORE tile=%0d addr=%0d",t,dut.tiles[t].tile.base.core.to_mem_waddr__msg);
      actual_stores[dut.tiles[t].tile.base.core.to_mem_waddr__msg]++;
      watched_stores++;
    end
    always @(posedge clk) if(identity_nnz>=0 &&
        dut.tiles[t].tile.base.core.to_mem_wdata__val &&
        dut.tiles[t].tile.base.core.to_mem_wdata__rdy) begin
      if(completed!=0)$fatal(1,"KERNEL_LATE_STORE tile=%0d",t);
      if(!dut.tiles[t].tile.base.core.to_mem_waddr__val ||
         !dut.tiles[t].tile.base.core.to_mem_waddr__rdy)
        $fatal(1,"KERNEL_STORE_PAIR tile=%0d",t);
      if(int'(dut.tiles[t].tile.base.core.to_mem_waddr__msg)>=identity_nnz ||
         stored_addresses[dut.tiles[t].tile.base.core.to_mem_waddr__msg])
        $fatal(1,"KERNEL_STRAY_STORE tile=%0d addr=%0d",t,dut.tiles[t].tile.base.core.to_mem_waddr__msg);
      stored_addresses[dut.tiles[t].tile.base.core.to_mem_waddr__msg]=1'b1;
      identity_stores++;
    end
    always @(posedge clk) if($test$plusargs("TRACE_FU") && dut.tiles[t].tile.base.core.element__recv_opt__val && dut.tiles[t].tile.base.core.element__recv_opt__rdy)
      $display("EXEC cycle=%0d tile=%0d pc=%0d op=%0d operands=%p out=%p const=%p",cycle,t,
        dut.tiles[t].tile.base.core.ctrl_mem__ctrl_addr_outport,
        dut.tiles[t].tile.base.core.ctrl_mem__send_ctrl__msg.operation,
        dut.tiles[t].tile.base.core.element__recv_in__msg,
        dut.tiles[t].tile.base.core.element__send_out__msg,
        dut.tiles[t].tile.base.core.element__recv_const__msg);
    always @(negedge clk) if($test$plusargs("TRACE_STATE") && cycle%1000==999) begin
      $display("TILE cycle=%0d t=%0d pc=%0d times=%0d active=%b complete=%b op=%0d done=%b%b%b rdy=%b%b%b",cycle,t,
        dut.tiles[t].tile.base.core.ctrl_mem__ctrl_addr_outport,
        dut.tiles[t].tile.base.core.ctrl_mem.times,
        dut.tiles[t].tile.base.core.ctrl_mem.start_iterate_ctrl,
        dut.tiles[t].tile.base.core.ctrl_mem.sent_complete,
        dut.tiles[t].tile.base.core.ctrl_mem__send_ctrl__msg.operation,
        dut.tiles[t].tile.base.core.element_done,
        dut.tiles[t].tile.base.core.routing_crossbar_done,
        dut.tiles[t].tile.base.core.fu_crossbar_done,
        dut.tiles[t].tile.base.core.element__recv_opt__rdy,
        dut.tiles[t].tile.base.core.routing_crossbar__recv_opt__rdy,
        dut.tiles[t].tile.base.core.fu_crossbar__recv_opt__rdy);
      if(cycle==999) begin
        $display("DETAIL t=%0d control=%p",t,dut.tiles[t].tile.base.core.ctrl_mem__send_ctrl__msg);
        $display("ROUTE t=%0d dirs=%p in_val=%p in_rdy=%p out_val=%p out_rdy=%p accepted=%b required=%b",t,
          dut.tiles[t].tile.base.core.routing_crossbar.in_dir,
          dut.tiles[t].tile.base.core.routing_crossbar__recv_data__val,
          dut.tiles[t].tile.base.core.routing_crossbar__recv_data__rdy,
          dut.tiles[t].tile.base.core.routing_crossbar__send_data__val,
          dut.tiles[t].tile.base.core.routing_crossbar__send_data__rdy,
          dut.tiles[t].tile.base.core.routing_crossbar.send_accepted,
          dut.tiles[t].tile.base.core.routing_crossbar.recv_required_vector);
        $display("FU t=%0d val=%p rdy=%p const_val=%b const_rdy=%b mem_addr_val=%b mem_addr_rdy=%b mem_data_val=%b mem_data_rdy=%b",t,
          dut.tiles[t].tile.base.core.element__recv_in__val,
          dut.tiles[t].tile.base.core.element__recv_in__rdy,
          dut.tiles[t].tile.base.core.element__recv_const__val,
          dut.tiles[t].tile.base.core.element__recv_const__rdy,
          dut.tiles[t].tile.base.core.to_mem_raddr__val,
          dut.tiles[t].tile.base.core.to_mem_raddr__rdy,
          dut.tiles[t].tile.base.core.from_mem_rdata__val,
          dut.tiles[t].tile.base.core.from_mem_rdata__rdy);
      end
    end
  end
endmodule
