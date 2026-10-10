`timescale 1ns/1ps
module tb_multi_migration;
  logic clk=0, reset;
  logic [192:0] recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val,recv_from_cpu_pkt__rdy,send_to_cpu_pkt__val,send_to_cpu_pkt__rdy;
  cgra_multi #(.DATA_W(32),.COLS(2),.ROWS(2),.MULTI_COLS(2),.MULTI_ROWS(2),.TILE_PORTS(4),.CTRL_DEPTH(8),.GLOBAL_ADDR_W(7),.BANK_DEPTH(16),.NUM_BANKS(2),.REG_DEPTH(16),.NUM_CTRL(8),.TOTAL_STEPS(8),.TILE_VARIANT(0),
    .REDUCE_LEGACY_PYTHON(1),.FU_COUNT(4),.FU_KINDS({8'd3,8'd13,8'd21,8'd2})) dut (.*);
  logic [195:0] replay_input;
  logic [1778:0] expected_output,actual_output;
  assign actual_output={recv_from_cpu_pkt__rdy,send_to_cpu_pkt__msg,send_to_cpu_pkt__val,dut.noc_send_msg[0],dut.noc_send_val[0],dut.noc_send_rdy[0],dut.noc_recv_msg[0],dut.noc_recv_val[0],dut.noc_recv_rdy[0],dut.noc_send_msg[1],dut.noc_send_val[1],dut.noc_send_rdy[1],dut.noc_recv_msg[1],dut.noc_recv_val[1],dut.noc_recv_rdy[1],dut.noc_send_msg[2],dut.noc_send_val[2],dut.noc_send_rdy[2],dut.noc_recv_msg[2],dut.noc_recv_val[2],dut.noc_recv_rdy[2],dut.noc_send_msg[3],dut.noc_send_val[3],dut.noc_send_rdy[3],dut.noc_recv_msg[3],dut.noc_recv_val[3],dut.noc_recv_rdy[3]};
  integer fd /* verilator public_flat_rw */;
  integer status /* verilator public_flat_rw */;
  integer cycle /* verilator public_flat_rw */;
  integer expected_cycles /* verilator public_flat_rw */;
  integer host_inputs /* verilator public_flat_rw */;
  integer complete_count /* verilator public_flat_rw */;
  integer result_count /* verilator public_flat_rw */;
  integer math_expected /* verilator public_flat_rw */;
  integer fdresult /* verilator public_flat_rw */;
  integer boundary_transfers /* verilator public_flat_rw */;
  integer resume_count /* verilator public_flat_rw */;
  bit intentional_failure; string vector_path,result_path;
  bit [15:0] completion_seen /* verilator public_flat_rw */;
  bit [15:0] saved_seen /* verilator public_flat_rw */;
  bit [15:0] resume_seen /* verilator public_flat_rw */;
  bit [15:0] cleared_seen /* verilator public_flat_rw */;
  integer source_cgra /* verilator public_flat_rw */;
  integer source_tile /* verilator public_flat_rw */;
  initial begin
#50000; $fatal(1,"MIGRATION_TIMEOUT wall-clock guard");
  end
  initial begin
    cycle=0;host_inputs=0;complete_count=0;result_count=0;boundary_transfers=0;resume_count=0;
    completion_seen='0;saved_seen='0;resume_seen='0;cleared_seen='0;
    intentional_failure=$test$plusargs("EXPECT_FAILURE");
    if(!$value$plusargs("TRACE=%s",vector_path)) $fatal(1,"TRACE argument required");
    if(!$value$plusargs("CYCLES=%d",expected_cycles) || expected_cycles<1) $fatal(1,"CYCLES required");
    if(!$value$plusargs("RESULT=%s",result_path)) result_path="migration-result.json";
    fd=$fopen(vector_path,"r");if(fd==0) $fatal(1,"cannot read replay trace");
    while(!$feof(fd)) begin
      status=$fscanf(fd,"%h %h\n",replay_input,expected_output);
      if(status!=2) $fatal(1,"malformed replay row %0d",cycle);
      {reset,recv_from_cpu_pkt__msg,recv_from_cpu_pkt__val,send_to_cpu_pkt__rdy}=replay_input;
      #4;
      if(actual_output!==expected_output) begin
        if(actual_output[1778+:1]!==expected_output[1778+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=host_recv_rdy actual=%h expected=%h",cycle,actual_output[1778+:1],expected_output[1778+:1]);
        if(actual_output[1585+:193]!==expected_output[1585+:193]) $fatal(1,"RAW_DIFF cycle=%0d field=host_send_msg actual=%h expected=%h",cycle,actual_output[1585+:193],expected_output[1585+:193]);
        if(actual_output[1584+:1]!==expected_output[1584+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=host_send_val actual=%h expected=%h",cycle,actual_output[1584+:1],expected_output[1584+:1]);
        if(actual_output[1388+:196]!==expected_output[1388+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_recv_msg actual=%h expected=%h",cycle,actual_output[1388+:196],expected_output[1388+:196]);
        if(actual_output[1387+:1]!==expected_output[1387+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_recv_val actual=%h expected=%h",cycle,actual_output[1387+:1],expected_output[1387+:1]);
        if(actual_output[1386+:1]!==expected_output[1386+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_recv_rdy actual=%h expected=%h",cycle,actual_output[1386+:1],expected_output[1386+:1]);
        if(actual_output[1190+:196]!==expected_output[1190+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_send_msg actual=%h expected=%h",cycle,actual_output[1190+:196],expected_output[1190+:196]);
        if(actual_output[1189+:1]!==expected_output[1189+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_send_val actual=%h expected=%h",cycle,actual_output[1189+:1],expected_output[1189+:1]);
        if(actual_output[1188+:1]!==expected_output[1188+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra0_noc_send_rdy actual=%h expected=%h",cycle,actual_output[1188+:1],expected_output[1188+:1]);
        if(actual_output[992+:196]!==expected_output[992+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_recv_msg actual=%h expected=%h",cycle,actual_output[992+:196],expected_output[992+:196]);
        if(actual_output[991+:1]!==expected_output[991+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_recv_val actual=%h expected=%h",cycle,actual_output[991+:1],expected_output[991+:1]);
        if(actual_output[990+:1]!==expected_output[990+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_recv_rdy actual=%h expected=%h",cycle,actual_output[990+:1],expected_output[990+:1]);
        if(actual_output[794+:196]!==expected_output[794+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_send_msg actual=%h expected=%h",cycle,actual_output[794+:196],expected_output[794+:196]);
        if(actual_output[793+:1]!==expected_output[793+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_send_val actual=%h expected=%h",cycle,actual_output[793+:1],expected_output[793+:1]);
        if(actual_output[792+:1]!==expected_output[792+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra1_noc_send_rdy actual=%h expected=%h",cycle,actual_output[792+:1],expected_output[792+:1]);
        if(actual_output[596+:196]!==expected_output[596+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_recv_msg actual=%h expected=%h",cycle,actual_output[596+:196],expected_output[596+:196]);
        if(actual_output[595+:1]!==expected_output[595+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_recv_val actual=%h expected=%h",cycle,actual_output[595+:1],expected_output[595+:1]);
        if(actual_output[594+:1]!==expected_output[594+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_recv_rdy actual=%h expected=%h",cycle,actual_output[594+:1],expected_output[594+:1]);
        if(actual_output[398+:196]!==expected_output[398+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_send_msg actual=%h expected=%h",cycle,actual_output[398+:196],expected_output[398+:196]);
        if(actual_output[397+:1]!==expected_output[397+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_send_val actual=%h expected=%h",cycle,actual_output[397+:1],expected_output[397+:1]);
        if(actual_output[396+:1]!==expected_output[396+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra2_noc_send_rdy actual=%h expected=%h",cycle,actual_output[396+:1],expected_output[396+:1]);
        if(actual_output[200+:196]!==expected_output[200+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_recv_msg actual=%h expected=%h",cycle,actual_output[200+:196],expected_output[200+:196]);
        if(actual_output[199+:1]!==expected_output[199+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_recv_val actual=%h expected=%h",cycle,actual_output[199+:1],expected_output[199+:1]);
        if(actual_output[198+:1]!==expected_output[198+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_recv_rdy actual=%h expected=%h",cycle,actual_output[198+:1],expected_output[198+:1]);
        if(actual_output[2+:196]!==expected_output[2+:196]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_send_msg actual=%h expected=%h",cycle,actual_output[2+:196],expected_output[2+:196]);
        if(actual_output[1+:1]!==expected_output[1+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_send_val actual=%h expected=%h",cycle,actual_output[1+:1],expected_output[1+:1]);
        if(actual_output[0+:1]!==expected_output[0+:1]) $fatal(1,"RAW_DIFF cycle=%0d field=cgra3_noc_send_rdy actual=%h expected=%h",cycle,actual_output[0+:1],expected_output[0+:1]);
        $fatal(1,"unclassified replay mismatch");
      end
      if(!reset) begin
        if(recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy) host_inputs++;
        if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
          source_cgra=int'(send_to_cpu_pkt__msg[185 +: 2]);source_tile=int'(send_to_cpu_pkt__msg[190 +: 3]);
          if(send_to_cpu_pkt__msg[164 +: 6]!=6'd14) $fatal(1,"unexpected non-complete host packet");
          if(completion_seen[4*source_cgra+source_tile]) $fatal(1,"duplicate completion");
          completion_seen[4*source_cgra+source_tile]=1;complete_count++;
          if(source_tile==1) begin
            math_expected=0;for(int i=1;i<=8;i++) math_expected+=i;
            if(source_cgra==0) math_expected+=17;else if(source_cgra==3) math_expected-=5;else $fatal(1,"wrong reduce participant");
            if(intentional_failure) math_expected++;
            if(send_to_cpu_pkt__msg[132 +: 32]!=32'(math_expected) || send_to_cpu_pkt__msg[131 +: 1]!=1'b1)
              $fatal(1,"MATH_RESULT mismatch%s",intentional_failure?" intentional negative control":"");
            result_count++;
          end
        end
      end
      #1;clk=1;#1;clk=0;cycle++;
    end
$fclose(fd);
    if(cycle!=expected_cycles) $fatal(1,"truncated cycle replay actual=%0d expected=%0d",cycle,expected_cycles);
    if(host_inputs!=35 || complete_count!=6 || result_count!=2) $fatal(1,"coverage count mismatch inputs=%0d complete=%0d results=%0d",host_inputs,complete_count,result_count);
    fdresult=$fopen(result_path,"w");if(fdresult==0) $fatal(1,"result output unavailable");
    $fdisplay(fdresult,"{\"status\":\"pass\",\"cycles\":%0d,\"raw_bits_per_cycle\":1779,\"host_inputs\":%0d,\"completions\":%0d,\"math_results\":%0d,\"boundary_transfers\":%0d,\"resume_count\":%0d}",cycle,host_inputs,complete_count,result_count,boundary_transfers,resume_count);
    $fclose(fdresult);
    $display("CURRENT_MIGRATION_PASS label=global_add cycles=%0d raw_bits=1779 inputs=%0d completions=%0d math=%0d boundary=%0d resume=%0d",cycle,host_inputs,complete_count,result_count,boundary_transfers,resume_count);
    $finish;
  end
endmodule
