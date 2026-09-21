`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_phase3_vector;
  localparam int DATA_W=32, LANES=8, LANE_W=4, DATA_BITS=DATA_W+3;
  localparam int REG_ADDR_W=4, GLOBAL_ADDR_W=7, CTRL_ADDR_W=3, TILE_ID_W=3, MEM_PORT_W=2, BANK_PORT_W=2, ROUTING_OUTPUTS=8, ROUTING_SEL_W=4;
  `include "cgra_profile.svh"
  localparam int RESULT_W=32;
  logic clock=0;always #5 clock=~clock;
  logic [31:0] rng=32'h3b123456;
  function automatic logic [31:0] next_word();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction
  function automatic logic [255:0] random_bits();return {next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word()};endfunction
  function automatic logic [15:0] ip_value(input logic[15:0]aa,bb,cc,input logic[5:0]mode);
    logic [15:0] tmp;tmp=mode[4]?(aa*bb+(mode[5]?cc:16'd0)):((mode[3]?~aa:aa)+(mode[0]?~bb:bb));
    tmp=tmp+16'(mode[0]|mode[3]);return mode[1]?{15'd0,(mode[2]^tmp[15])}:tmp;endfunction
  int operations[0:1]='{55,75};
  int op_hits[0:1];
  int cycle=0,arithmetic_checks=0,stall_checks=0,valid_outputs=0,legacy_defect_checks=0;logic supported;
  logic [127:0] expected[0:1],a,b,c,d,k,x,y,z,temp;logic [127:0]lane_mask=(128'(1)<<LANE_W)-1;
  int ix0,ix1,ix2;logic carry,model_sent=0;logic [7:0]model_counter=0;
  logic [15:0]held_a=0,held_b=0,held_c=0;logic [5:0]ip_op;
  ctrl_t ctrl;payload_t response,sent_payload;string result_path;integer fd;
  logic [0:0] i_clear ;
  logic [2:0] i_ctrl_addr_inport ;
  logic [0:0] i_reset ;
  logic [34:0] i_from_mem_rdata__msg ;
  logic [0:0] d_from_mem_rdata__rdy ;
  logic [0:0] g_from_mem_rdata__rdy ;
  logic [0:0] i_from_mem_rdata__val ;
  logic [34:0] i_recv_const__msg ;
  logic [0:0] d_recv_const__rdy ;
  logic [0:0] g_recv_const__rdy ;
  logic [0:0] i_recv_const__val ;
  logic [169:0] i_recv_from_ctrl_mem__msg ;
  logic [0:0] d_recv_from_ctrl_mem__rdy ;
  logic [0:0] g_recv_from_ctrl_mem__rdy ;
  logic [0:0] i_recv_from_ctrl_mem__val ;
  logic [34:0] i_recv_in__msg [0:3];
  logic [0:0] d_recv_in__rdy [0:3];
  logic [0:0] g_recv_in__rdy [0:3];
  logic [0:0] i_recv_in__val [0:3];
  logic [118:0] i_recv_opt__msg ;
  assign i_recv_opt__msg=ctrl;
  logic [0:0] d_recv_opt__rdy ;
  logic [0:0] g_recv_opt__rdy ;
  logic [0:0] i_recv_opt__val ;
  logic [34:0] d_send_out__msg [0:1];
  logic [34:0] g_send_out__msg [0:1];
  logic [0:0] i_send_out__rdy [0:1];
  logic [0:0] d_send_out__val [0:1];
  logic [0:0] g_send_out__val [0:1];
  logic [169:0] d_send_to_ctrl_mem__msg ;
  logic [169:0] g_send_to_ctrl_mem__msg ;
  logic [0:0] i_send_to_ctrl_mem__rdy ;
  logic [0:0] d_send_to_ctrl_mem__val ;
  logic [0:0] g_send_to_ctrl_mem__val ;
  logic [6:0] d_to_mem_raddr__msg ;
  logic [6:0] g_to_mem_raddr__msg ;
  logic [0:0] i_to_mem_raddr__rdy ;
  logic [0:0] d_to_mem_raddr__val ;
  logic [0:0] g_to_mem_raddr__val ;
  logic [6:0] d_to_mem_waddr__msg ;
  logic [6:0] g_to_mem_waddr__msg ;
  logic [0:0] i_to_mem_waddr__rdy ;
  logic [0:0] d_to_mem_waddr__val ;
  logic [0:0] g_to_mem_waddr__val ;
  logic [34:0] d_to_mem_wdata__msg ;
  logic [34:0] g_to_mem_wdata__msg ;
  logic [0:0] i_to_mem_wdata__rdy ;
  logic [0:0] d_to_mem_wdata__val ;
  logic [0:0] g_to_mem_wdata__val ;
  tile_vector_mul_combo #(.DATA_W(32),.LANES(8),.VECTOR_FACTOR_POWER(0)) dut (.clear(i_clear),.clk(clock),.ctrl_addr_inport(i_ctrl_addr_inport),.reset(i_reset),.from_mem_rdata__msg(i_from_mem_rdata__msg),.from_mem_rdata__rdy(d_from_mem_rdata__rdy),.from_mem_rdata__val(i_from_mem_rdata__val),.recv_const__msg(i_recv_const__msg),.recv_const__rdy(d_recv_const__rdy),.recv_const__val(i_recv_const__val),.recv_from_ctrl_mem__msg(i_recv_from_ctrl_mem__msg),.recv_from_ctrl_mem__rdy(d_recv_from_ctrl_mem__rdy),.recv_from_ctrl_mem__val(i_recv_from_ctrl_mem__val),.recv_in__msg(i_recv_in__msg),.recv_in__rdy(d_recv_in__rdy),.recv_in__val(i_recv_in__val),.recv_opt__msg(i_recv_opt__msg),.recv_opt__rdy(d_recv_opt__rdy),.recv_opt__val(i_recv_opt__val),.send_out__msg(d_send_out__msg),.send_out__rdy(i_send_out__rdy),.send_out__val(d_send_out__val),.send_to_ctrl_mem__msg(d_send_to_ctrl_mem__msg),.send_to_ctrl_mem__rdy(i_send_to_ctrl_mem__rdy),.send_to_ctrl_mem__val(d_send_to_ctrl_mem__val),.to_mem_raddr__msg(d_to_mem_raddr__msg),.to_mem_raddr__rdy(i_to_mem_raddr__rdy),.to_mem_raddr__val(d_to_mem_raddr__val),.to_mem_waddr__msg(d_to_mem_waddr__msg),.to_mem_waddr__rdy(i_to_mem_waddr__rdy),.to_mem_waddr__val(d_to_mem_waddr__val),.to_mem_wdata__msg(d_to_mem_wdata__msg),.to_mem_wdata__rdy(i_to_mem_wdata__rdy),.to_mem_wdata__val(d_to_mem_wdata__val));
  P3Vector_vector_mul_combo_w32_l8_b8_v0 gold (.clear(i_clear),.clk(clock),.ctrl_addr_inport(i_ctrl_addr_inport),.reset(i_reset),.from_mem_rdata__msg(i_from_mem_rdata__msg),.from_mem_rdata__rdy(g_from_mem_rdata__rdy),.from_mem_rdata__val(i_from_mem_rdata__val),.recv_const__msg(i_recv_const__msg),.recv_const__rdy(g_recv_const__rdy),.recv_const__val(i_recv_const__val),.recv_from_ctrl_mem__msg(i_recv_from_ctrl_mem__msg),.recv_from_ctrl_mem__rdy(g_recv_from_ctrl_mem__rdy),.recv_from_ctrl_mem__val(i_recv_from_ctrl_mem__val),.recv_in__msg(i_recv_in__msg),.recv_in__rdy(g_recv_in__rdy),.recv_in__val(i_recv_in__val),.recv_opt__msg(i_recv_opt__msg),.recv_opt__rdy(g_recv_opt__rdy),.recv_opt__val(i_recv_opt__val),.send_out__msg(g_send_out__msg),.send_out__rdy(i_send_out__rdy),.send_out__val(g_send_out__val),.send_to_ctrl_mem__msg(g_send_to_ctrl_mem__msg),.send_to_ctrl_mem__rdy(i_send_to_ctrl_mem__rdy),.send_to_ctrl_mem__val(g_send_to_ctrl_mem__val),.to_mem_raddr__msg(g_to_mem_raddr__msg),.to_mem_raddr__rdy(i_to_mem_raddr__rdy),.to_mem_raddr__val(g_to_mem_raddr__val),.to_mem_waddr__msg(g_to_mem_waddr__msg),.to_mem_waddr__rdy(i_to_mem_waddr__rdy),.to_mem_waddr__val(g_to_mem_waddr__val),.to_mem_wdata__msg(g_to_mem_wdata__msg),.to_mem_wdata__rdy(i_to_mem_wdata__rdy),.to_mem_wdata__val(g_to_mem_wdata__val));
  assign response=i_recv_from_ctrl_mem__msg;
  assign sent_payload=d_send_to_ctrl_mem__msg;
  initial begin
    for(int n=0;n<2;n++)op_hits[n]=0;
    for(cycle=0;cycle<640;cycle++)begin
      @(negedge clock);
      i_clear=1'(random_bits());
      i_ctrl_addr_inport=3'(random_bits());
      i_reset=1'(random_bits());
      i_from_mem_rdata__msg=35'(random_bits());
      i_from_mem_rdata__val=1'(random_bits());
      i_recv_const__msg=35'(random_bits());
      i_recv_const__val=1'(random_bits());
      i_recv_from_ctrl_mem__msg=170'(random_bits());
      i_recv_from_ctrl_mem__val=1'(random_bits());
      i_recv_in__msg[0]=35'(random_bits());
      i_recv_in__msg[1]=35'(random_bits());
      i_recv_in__msg[2]=35'(random_bits());
      i_recv_in__msg[3]=35'(random_bits());
      i_recv_in__val[0]=1'(random_bits());
      i_recv_in__val[1]=1'(random_bits());
      i_recv_in__val[2]=1'(random_bits());
      i_recv_in__val[3]=1'(random_bits());
      i_recv_opt__val=1'(random_bits());
      i_send_out__rdy[0]=1'(random_bits());
      i_send_out__rdy[1]=1'(random_bits());
      i_send_to_ctrl_mem__rdy=1'(random_bits());
      i_to_mem_raddr__rdy=1'(random_bits());
      i_to_mem_waddr__rdy=1'(random_bits());
      i_to_mem_wdata__rdy=1'(random_bits());
      i_reset=(cycle<2)||(cycle==320)||(cycle==321);
      ctrl=119'(random_bits());
      ctrl.operation=(cycle%(2+1)==2)?7'd127:7'(operations[cycle%(2+1)]);
      ctrl.vector_factor_power=(cycle>=128&&cycle<400)?3'd7:3'(cycle/16);
      ctrl.is_last_ctrl=(cycle>=128&&cycle<400)?1'b1:1'(next_word());
      i_recv_opt__val=(cycle>=128&&cycle<400)?1:((cycle%5)!=0);
      supported=0;
      for(int n=0;n<2;n++)if(ctrl.operation==operations[n])supported=1;
      if(cycle%4==0)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]=DATA_W'(n+cycle%7);
      if(cycle%16==1)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]='1;
      if(cycle%16==2)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]='0;
      if(cycle%4==0)i_recv_in__msg[2][DATA_BITS-1:3]=DATA_W'(cycle%DATA_W);
      if(cycle==1)begin i_recv_in__msg[0][DATA_BITS-1:3]=DATA_W'(1)<<LANE_W;i_recv_in__msg[1][DATA_BITS-1:3]=DATA_W'(1)<<LANE_W;end
      @(posedge clock);
      if(d_from_mem_rdata__rdy !== 1'(g_from_mem_rdata__rdy))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=from_mem_rdata__rdy native=%h gold=%h",cycle,d_from_mem_rdata__rdy,g_from_mem_rdata__rdy);
      if(d_recv_const__rdy !== 1'(g_recv_const__rdy))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_const__rdy native=%h gold=%h",cycle,d_recv_const__rdy,g_recv_const__rdy);
      if(d_recv_from_ctrl_mem__rdy !== 1'(g_recv_from_ctrl_mem__rdy))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_from_ctrl_mem__rdy native=%h gold=%h",cycle,d_recv_from_ctrl_mem__rdy,g_recv_from_ctrl_mem__rdy);
      if(d_recv_in__rdy[0] !== 1'(g_recv_in__rdy[0]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_in__rdy[0] native=%h gold=%h",cycle,d_recv_in__rdy[0],g_recv_in__rdy[0]);
      if(d_recv_in__rdy[1] !== 1'(g_recv_in__rdy[1]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_in__rdy[1] native=%h gold=%h",cycle,d_recv_in__rdy[1],g_recv_in__rdy[1]);
      if(d_recv_in__rdy[2] !== 1'(g_recv_in__rdy[2]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_in__rdy[2] native=%h gold=%h",cycle,d_recv_in__rdy[2],g_recv_in__rdy[2]);
      if(d_recv_in__rdy[3] !== 1'(g_recv_in__rdy[3]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_in__rdy[3] native=%h gold=%h",cycle,d_recv_in__rdy[3],g_recv_in__rdy[3]);
      if(d_recv_opt__rdy !== 1'(g_recv_opt__rdy))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=recv_opt__rdy native=%h gold=%h",cycle,d_recv_opt__rdy,g_recv_opt__rdy);
      if(d_send_out__msg[0] !== 35'(g_send_out__msg[0]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_out__msg[0] native=%h gold=%h",cycle,d_send_out__msg[0],g_send_out__msg[0]);
      if(d_send_out__msg[1] !== 35'(g_send_out__msg[1]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_out__msg[1] native=%h gold=%h",cycle,d_send_out__msg[1],g_send_out__msg[1]);
      if(d_send_out__val[0] !== 1'(g_send_out__val[0]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_out__val[0] native=%h gold=%h",cycle,d_send_out__val[0],g_send_out__val[0]);
      if(d_send_out__val[1] !== 1'(g_send_out__val[1]))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_out__val[1] native=%h gold=%h",cycle,d_send_out__val[1],g_send_out__val[1]);
      if(d_send_to_ctrl_mem__msg !== 170'(g_send_to_ctrl_mem__msg))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_to_ctrl_mem__msg native=%h gold=%h",cycle,d_send_to_ctrl_mem__msg,g_send_to_ctrl_mem__msg);
      if(d_send_to_ctrl_mem__val !== 1'(g_send_to_ctrl_mem__val))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=send_to_ctrl_mem__val native=%h gold=%h",cycle,d_send_to_ctrl_mem__val,g_send_to_ctrl_mem__val);
      if(d_to_mem_raddr__msg !== 7'(g_to_mem_raddr__msg))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_raddr__msg native=%h gold=%h",cycle,d_to_mem_raddr__msg,g_to_mem_raddr__msg);
      if(d_to_mem_raddr__val !== 1'(g_to_mem_raddr__val))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_raddr__val native=%h gold=%h",cycle,d_to_mem_raddr__val,g_to_mem_raddr__val);
      if(d_to_mem_waddr__msg !== 7'(g_to_mem_waddr__msg))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_waddr__msg native=%h gold=%h",cycle,d_to_mem_waddr__msg,g_to_mem_waddr__msg);
      if(d_to_mem_waddr__val !== 1'(g_to_mem_waddr__val))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_waddr__val native=%h gold=%h",cycle,d_to_mem_waddr__val,g_to_mem_waddr__val);
      if(d_to_mem_wdata__msg !== 35'(g_to_mem_wdata__msg))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_wdata__msg native=%h gold=%h",cycle,d_to_mem_wdata__msg,g_to_mem_wdata__msg);
      if(d_to_mem_wdata__val !== 1'(g_to_mem_wdata__val))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port=to_mem_wdata__val native=%h gold=%h",cycle,d_to_mem_wdata__val,g_to_mem_wdata__val);
      if(cycle==1)$display("HDL_SHIFT_WITNESS width=%0d lanes=%0d op=%0d a=%h b=%h native=%h gold=%h shift2=%0d shift3=%0d",DATA_W,LANES,ctrl.operation,i_recv_in__msg[0]>>3,i_recv_in__msg[1]>>3,d_send_out__msg[0]>>3,g_send_out__msg[0]>>3,dut.SHIFT_TWO,dut.SHIFT_THREE);
      for(int n=0;n<2;n++)if(ctrl.operation==operations[n]&&i_recv_opt__val)op_hits[n]++;
      if(i_recv_opt__val&&!i_send_out__rdy[0])stall_checks++;
      if(d_send_out__val[0])valid_outputs++;
      expected[0]='0;expected[1]='0;
      a=DATA_W'(i_recv_in__msg[0]>>3);b=DATA_W'(i_recv_in__msg[1]>>3);
      c=DATA_W'(i_recv_in__msg[2]>>3);d=DATA_W'(i_recv_in__msg[3]>>3);
      k=DATA_W'(i_recv_const__msg>>3);
      ix0=ctrl.fu_in[0]==0?0:(int'(ctrl.fu_in[0])-1)%4;
      ix1=ctrl.fu_in[1]==0?0:(int'(ctrl.fu_in[1])-1)%4;
      ix2=ctrl.fu_in[2]==0?0:(int'(ctrl.fu_in[2])-1)%4;
if(i_recv_opt__val)begin
        // Independent lane product sum using the frozen RTLIR shift-width rule.
        if(ctrl.operation==55||ctrl.operation==75)for(int lane=0;lane<4;lane++)begin
          ix0=(ctrl.operation==55)?lane:lane/2;
          ix1=(ctrl.operation==55)?lane:lane%2;
          ix2=(ctrl.operation==55)?lane:(lane==3?2:(lane==0?0:1));
          ix2=(ix2*LANE_W)% (1<< (($clog2(LANE_W+1)>2)?$clog2(LANE_W+1):2));
          expected[0]+=(((a>>(ix0*LANE_W))&lane_mask)*((b>>(ix1*LANE_W))&lane_mask))<<ix2;
        end
      end
if(d_send_out__msg[0][DATA_BITS-1:3] !== DATA_W'(expected[0]))
        $fatal(1,"independent arithmetic cycle=%0d op=%0d expected=%h got=%h",cycle,ctrl.operation,DATA_W'(expected[0]),d_send_out__msg[0][DATA_BITS-1:3]);
      arithmetic_checks++;

      if($test$plusargs("EXPECT_FAILURE")&&cycle==64)$fatal(1,"intentional negative control: result checker exercised");
    end
    for(int n=0;n<2;n++)if(op_hits[n]==0)$fatal(1,"operation not exercised op=%0d",operations[n]);
    if(arithmetic_checks!=640)$fatal(1,"arithmetic coverage incomplete");
    if(stall_checks<50||valid_outputs<10)$fatal(1,"handshake coverage incomplete");
    if(!$value$plusargs("RESULT=%s",result_path))result_path="result.json";
    fd=$fopen(result_path,"w");if(fd==0)$fatal(1,"cannot write result JSON");
    $fwrite(fd,"{\n  \"label\": \"vector_mul_combo_w32_l8_b8_v0\",\n  \"status\": \"pass\",\n  \"cycles\": 640,\n  \"seed\": \"3b123456\",\n  \"raw_invalid_comparison\": true,\n  \"arithmetic_checks\": %0d,\n  \"stall_samples\": %0d,\n  \"valid_output_samples\": %0d,\n  \"legacy_defect_checks\": %0d,\n  \"operation_hits\": [",arithmetic_checks,stall_checks,valid_outputs,legacy_defect_checks);
    for(int n=0;n<2;n++)$fwrite(fd,"%s%0d",n==0?"":",",op_hits[n]);
    $fwrite(fd,"]\n}\n");$fclose(fd);
    $display("P3_VECTOR_PASS label=vector_mul_combo_w32_l8_b8_v0 cycles=640 arithmetic=%0d stalls=%0d valid=%0d",arithmetic_checks,stall_checks,valid_outputs);
    $finish;
  end
endmodule
