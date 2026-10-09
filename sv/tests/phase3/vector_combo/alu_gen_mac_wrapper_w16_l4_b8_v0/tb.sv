`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_phase3_vector;
  localparam int DATA_W=16, LANES=4, LANE_W=4, DATA_BITS=DATA_W+3;
  localparam int REG_ADDR_W=4, GLOBAL_ADDR_W=7, CTRL_ADDR_W=3, TILE_ID_W=3, MEM_PORT_W=2, BANK_PORT_W=2, ROUTING_OUTPUTS=8, ROUTING_SEL_W=4;
  localparam int CGRA_ID_W=1, CGRA_X_W=1, CGRA_Y_W=1, XBAR_MEM_PORT_W=2, XBAR_WR_MEM_PORT_W=2;
  `include "cgra_profile.svh"
  localparam int RESULT_W=16;
  logic clock=0;always #5 clock=~clock;
  logic [31:0] rng=32'h3b123456;
  function automatic logic [31:0] next_word();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction
  function automatic logic [255:0] random_bits();return {next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word()};endfunction
  function automatic logic [15:0] ip_value(input logic[15:0]aa,bb,cc,input logic[5:0]mode);
    logic [15:0] tmp;tmp=mode[4]?(aa*bb+(mode[5]?cc:16'd0)):((mode[3]?~aa:aa)+(mode[0]?~bb:bb));
    tmp=tmp+16'(mode[0]|mode[3]);return mode[1]?{15'd0,(mode[2]^tmp[15])}:tmp;endfunction
  int operations[0:63]='{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63};
  int op_hits[0:63];
  int cycle=0,arithmetic_checks=0,stall_checks=0,valid_outputs=0,legacy_defect_checks=0;logic supported;
  logic [127:0] expected[0:1],a,b,c,d,k,x,y,z,temp;logic [127:0]lane_mask=(128'(1)<<LANE_W)-1;
  int ix0,ix1,ix2;logic carry,model_sent=0;logic [7:0]model_counter=0;
  logic [15:0]held_a=0,held_b=0,held_c=0;logic [5:0]ip_op;
  ctrl_t ctrl;payload_t response,sent_payload;string result_path;integer fd;
  logic [0:0] i_reset ;
  logic [15:0] d_lhs_0 ;
  logic [15:0] g_lhs_0 ;
  logic [15:0] i_rhs_0 ;
  logic [15:0] i_rhs_1 ;
  logic [15:0] i_rhs_1b ;
  logic [5:0] i_rhs_2 ;
  cgra_alu_gen_mac dut (.reset(i_reset),.clk(clock),.lhs_0(d_lhs_0),.rhs_0(i_rhs_0),.rhs_1(i_rhs_1),.rhs_1b(i_rhs_1b),.rhs_2(i_rhs_2));
  P3Vector_alu_gen_mac_wrapper_w16_l4_b8_v0 gold (.reset(i_reset),.clk(clock),.lhs_0(g_lhs_0),.rhs_0(i_rhs_0),.rhs_1(i_rhs_1),.rhs_1b(i_rhs_1b),.rhs_2(i_rhs_2));
  initial begin
    for(int n=0;n<64;n++)op_hits[n]=0;
    for(cycle=0;cycle<640;cycle++)begin
      @(negedge clock);
      i_reset=1'(random_bits());
      i_rhs_0=16'(random_bits());
      i_rhs_1=16'(random_bits());
      i_rhs_1b=16'(random_bits());
      i_rhs_2=6'(random_bits());
      i_reset=(cycle<2)||(cycle==320)||(cycle==321);
      ctrl=119'(random_bits());
      ctrl.operation=(cycle%(64+1)==64)?7'd127:7'(operations[cycle%(64+1)]);
      ctrl.vector_factor_power=(cycle>=128&&cycle<400)?3'd7:3'(cycle/16);
      ctrl.is_last_ctrl=(cycle>=128&&cycle<400)?1'b1:1'(next_word());
      i_rhs_2=6'(cycle);
      supported=1;
      @(posedge clock);
      if(d_lhs_0 !== 16'(g_lhs_0))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=lhs_0 native=%h gold=%h",cycle,d_lhs_0,g_lhs_0);
      op_hits[int'(i_rhs_2)]++;
      expected[0]=ip_value(i_rhs_0,i_rhs_1,i_rhs_1b,i_rhs_2);
      if(d_lhs_0 !== 16'(expected[0]))$fatal(1,"independent IP arithmetic cycle=%0d",cycle);
      arithmetic_checks++;
      if($test$plusargs("EXPECT_FAILURE")&&cycle==64)$fatal(1,"intentional negative control: result checker exercised");
    end
    for(int n=0;n<64;n++)if(op_hits[n]==0)$fatal(1,"operation not exercised op=%0d",operations[n]);
    if(arithmetic_checks!=640)$fatal(1,"arithmetic coverage incomplete");
    if(!$value$plusargs("RESULT=%s",result_path))result_path="result.json";
    fd=$fopen(result_path,"w");if(fd==0)$fatal(1,"cannot write result JSON");
    $fwrite(fd,"{\n  \"label\": \"alu_gen_mac_wrapper_w16_l4_b8_v0\",\n  \"status\": \"pass\",\n  \"cycles\": 640,\n  \"seed\": \"3b123456\",\n  \"raw_invalid_comparison\": true,\n  \"arithmetic_checks\": %0d,\n  \"stall_samples\": %0d,\n  \"valid_output_samples\": %0d,\n  \"legacy_defect_checks\": %0d,\n  \"operation_hits\": [",arithmetic_checks,stall_checks,valid_outputs,legacy_defect_checks);
    for(int n=0;n<64;n++)$fwrite(fd,"%s%0d",n==0?"":",",op_hits[n]);
    $fwrite(fd,"]\n}\n");$fclose(fd);
    $display("P3_VECTOR_PASS label=alu_gen_mac_wrapper_w16_l4_b8_v0 cycles=640 arithmetic=%0d stalls=%0d valid=%0d",arithmetic_checks,stall_checks,valid_outputs);
    $finish;
  end
endmodule
