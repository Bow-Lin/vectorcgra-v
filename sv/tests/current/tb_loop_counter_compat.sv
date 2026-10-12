`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
// Full-port frozen Python check for the unused temporary's default assignment.
module tb_loop_counter_compat #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  `include "vector_reduce_ports.svh"
  scalar_loop_counter #(`CGRA_PROFILE_BIND) dut(.*);
  localparam integer IN_BITS=$bits({clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}),OUT_BITS=$bits({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val});
  localparam int CYCLES=DATA_W==32 ? 2881 : 3105;
  logic [IN_BITS-1:0] inputs[CYCLES];
  logic [OUT_BITS-1:0] expected[CYCLES];
  integer cycle /* verilator public_flat_rw */;
  string base;
  bit wrong;
  initial begin
    clk=0;wrong=$test$plusargs("EXPECT_FAILURE");
    base=DATA_W==32 ? "reference/phase3/scalar/w32/vectors/" : "reference/phase3/scalar/w64/vectors/";
    $readmemh({base,"inputs.hex"},inputs);$readmemh({base,"LoopCounter.hex"},expected);
    for(cycle=0;cycle<CYCLES;cycle++) begin
      {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}=inputs[cycle];#2;
      if(wrong && cycle==7) expected[cycle]^=1;
      if({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val}!==expected[cycle]) $fatal(1,"LOOP_COUNTER_COMPAT_MISMATCH cycle=%0d",cycle);
      #1;clk=1;#2;clk=0;#1;
    end
    $display("LOOP_COUNTER_COMPAT_PASS width=%0d cycles=%0d output_bits=%0d",DATA_W,CYCLES,OUT_BITS);$finish;
  end
endmodule
