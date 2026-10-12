`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_memory_boundary_replay #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  logic [GLOBAL_ADDR_W-1:0] address_lower ;
  logic [GLOBAL_ADDR_W-1:0] address_upper ;
  logic [CGRA_ID_W-1:0] cgra_id ;
  logic [0:0] clk ;
  logic [0:0] reset ;
  logic [32-1:0] recv_from_controller_spm_rd_req__msg ;
  logic [0:0] recv_from_controller_spm_rd_req__rdy ;
  logic [0:0] recv_from_controller_spm_rd_req__val ;
  logic [68-1:0] recv_from_controller_spm_wr_req__msg ;
  logic [0:0] recv_from_controller_spm_wr_req__rdy ;
  logic [0:0] recv_from_controller_spm_wr_req__val ;
  logic [NOC_BITS-1:0] recv_from_noc_load_request__msg ;
  logic [0:0] recv_from_noc_load_request__rdy ;
  logic [0:0] recv_from_noc_load_request__val ;
  logic [NOC_BITS-1:0] recv_from_noc_load_response_pkt__msg ;
  logic [0:0] recv_from_noc_load_response_pkt__rdy ;
  logic [0:0] recv_from_noc_load_response_pkt__val ;
  logic [NOC_BITS-1:0] recv_from_noc_store_request__msg ;
  logic [0:0] recv_from_noc_store_request__rdy ;
  logic [0:0] recv_from_noc_store_request__val ;
  logic [GLOBAL_ADDR_W-1:0] recv_raddr__msg [0:MEM_PORTS-1];
  wire [MEM_PORTS*(GLOBAL_ADDR_W)-1:0] flat_recv_raddr__msg;
  logic [0:0] recv_raddr__rdy [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_recv_raddr__rdy;
  logic [0:0] recv_raddr__val [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_recv_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] recv_waddr__msg [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(GLOBAL_ADDR_W)-1:0] flat_recv_waddr__msg;
  logic [0:0] recv_waddr__rdy [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_waddr__rdy;
  logic [0:0] recv_waddr__val [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_waddr__val;
  logic [DATA_BITS-1:0] recv_wdata__msg [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(DATA_BITS)-1:0] flat_recv_wdata__msg;
  logic [0:0] recv_wdata__rdy [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_wdata__rdy;
  logic [0:0] recv_wdata__val [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_wdata__val;
  logic [DATA_BITS-1:0] send_rdata__msg [0:MEM_PORTS-1];
  wire [MEM_PORTS*(DATA_BITS)-1:0] flat_send_rdata__msg;
  logic [0:0] send_rdata__rdy [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_send_rdata__rdy;
  logic [0:0] send_rdata__val [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_send_rdata__val;
  logic [32-1:0] send_to_controller_spm_rd_resp__msg ;
  logic [0:0] send_to_controller_spm_rd_resp__rdy ;
  logic [0:0] send_to_controller_spm_rd_resp__val ;
  logic [NOC_BITS-1:0] send_to_noc_load_request_pkt__msg ;
  logic [0:0] send_to_noc_load_request_pkt__rdy ;
  logic [0:0] send_to_noc_load_request_pkt__val ;
  logic [NOC_BITS-1:0] send_to_noc_load_response_pkt__msg ;
  logic [0:0] send_to_noc_load_response_pkt__rdy ;
  logic [0:0] send_to_noc_load_response_pkt__val ;
  logic [NOC_BITS-1:0] send_to_noc_store_pkt__msg ;
  logic [0:0] send_to_noc_store_pkt__rdy ;
  logic [0:0] send_to_noc_store_pkt__val ;
`ifdef MEMORY_BOUNDARIES_POST_SYNTH
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__msg assign flat_recv_raddr__msg[(MEM_PORTS-1-i)*(GLOBAL_ADDR_W)+:(GLOBAL_ADDR_W)]=recv_raddr__msg[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__rdy assign recv_raddr__rdy[i]=flat_recv_raddr__rdy[(MEM_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__val assign flat_recv_raddr__val[(MEM_PORTS-1-i)*(1)+:(1)]=recv_raddr__val[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__msg assign flat_recv_waddr__msg[(MEM_WRITE_PORTS-1-i)*(GLOBAL_ADDR_W)+:(GLOBAL_ADDR_W)]=recv_waddr__msg[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__rdy assign recv_waddr__rdy[i]=flat_recv_waddr__rdy[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__val assign flat_recv_waddr__val[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]=recv_waddr__val[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__msg assign flat_recv_wdata__msg[(MEM_WRITE_PORTS-1-i)*(DATA_BITS)+:(DATA_BITS)]=recv_wdata__msg[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__rdy assign recv_wdata__rdy[i]=flat_recv_wdata__rdy[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__val assign flat_recv_wdata__val[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]=recv_wdata__val[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__msg assign send_rdata__msg[i]=flat_send_rdata__msg[(MEM_PORTS-1-i)*(DATA_BITS)+:(DATA_BITS)]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__rdy assign flat_send_rdata__rdy[(MEM_PORTS-1-i)*(1)+:(1)]=send_rdata__rdy[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__val assign send_rdata__val[i]=flat_send_rdata__val[(MEM_PORTS-1-i)*(1)+:(1)]; end
  memory_boundaries_netlist dut(.address_lower(address_lower),.address_upper(address_upper),.cgra_id(cgra_id),.clk(clk),.reset(reset),.recv_from_controller_spm_rd_req__msg(recv_from_controller_spm_rd_req__msg),.recv_from_controller_spm_rd_req__rdy(recv_from_controller_spm_rd_req__rdy),.recv_from_controller_spm_rd_req__val(recv_from_controller_spm_rd_req__val),.recv_from_controller_spm_wr_req__msg(recv_from_controller_spm_wr_req__msg),.recv_from_controller_spm_wr_req__rdy(recv_from_controller_spm_wr_req__rdy),.recv_from_controller_spm_wr_req__val(recv_from_controller_spm_wr_req__val),.recv_from_noc_load_request__msg(recv_from_noc_load_request__msg),.recv_from_noc_load_request__rdy(recv_from_noc_load_request__rdy),.recv_from_noc_load_request__val(recv_from_noc_load_request__val),.recv_from_noc_load_response_pkt__msg(recv_from_noc_load_response_pkt__msg),.recv_from_noc_load_response_pkt__rdy(recv_from_noc_load_response_pkt__rdy),.recv_from_noc_load_response_pkt__val(recv_from_noc_load_response_pkt__val),.recv_from_noc_store_request__msg(recv_from_noc_store_request__msg),.recv_from_noc_store_request__rdy(recv_from_noc_store_request__rdy),.recv_from_noc_store_request__val(recv_from_noc_store_request__val),.recv_raddr__msg(flat_recv_raddr__msg),.recv_raddr__rdy(flat_recv_raddr__rdy),.recv_raddr__val(flat_recv_raddr__val),.recv_waddr__msg(flat_recv_waddr__msg),.recv_waddr__rdy(flat_recv_waddr__rdy),.recv_waddr__val(flat_recv_waddr__val),.recv_wdata__msg(flat_recv_wdata__msg),.recv_wdata__rdy(flat_recv_wdata__rdy),.recv_wdata__val(flat_recv_wdata__val),.send_rdata__msg(flat_send_rdata__msg),.send_rdata__rdy(flat_send_rdata__rdy),.send_rdata__val(flat_send_rdata__val),.send_to_controller_spm_rd_resp__msg(send_to_controller_spm_rd_resp__msg),.send_to_controller_spm_rd_resp__rdy(send_to_controller_spm_rd_resp__rdy),.send_to_controller_spm_rd_resp__val(send_to_controller_spm_rd_resp__val),.send_to_noc_load_request_pkt__msg(send_to_noc_load_request_pkt__msg),.send_to_noc_load_request_pkt__rdy(send_to_noc_load_request_pkt__rdy),.send_to_noc_load_request_pkt__val(send_to_noc_load_request_pkt__val),.send_to_noc_load_response_pkt__msg(send_to_noc_load_response_pkt__msg),.send_to_noc_load_response_pkt__rdy(send_to_noc_load_response_pkt__rdy),.send_to_noc_load_response_pkt__val(send_to_noc_load_response_pkt__val),.send_to_noc_store_pkt__msg(send_to_noc_store_pkt__msg),.send_to_noc_store_pkt__rdy(send_to_noc_store_pkt__rdy),.send_to_noc_store_pkt__val(send_to_noc_store_pkt__val));
`else
  cgra_data_memory #(`CGRA_PROFILE_BIND) dut(.*);
`endif
  integer samples /* verilator public_flat_rw */ =0;
  integer fd,scan;
  logic [785-1:0] inputs;
  logic [742-1:0] expected;
  string path;
  task automatic tick;#4;clk=1;#4;clk=0;endtask
  initial begin
    clk=0;{address_lower,address_upper,cgra_id,reset,recv_from_controller_spm_rd_req__msg,recv_from_controller_spm_rd_req__val,recv_from_controller_spm_wr_req__msg,recv_from_controller_spm_wr_req__val,recv_from_noc_load_request__msg,recv_from_noc_load_request__val,recv_from_noc_load_response_pkt__msg,recv_from_noc_load_response_pkt__val,recv_from_noc_store_request__msg,recv_from_noc_store_request__val,recv_raddr__msg[0],recv_raddr__val[0],recv_raddr__msg[1],recv_raddr__val[1],recv_raddr__msg[2],recv_raddr__val[2],recv_waddr__msg[0],recv_waddr__val[0],recv_wdata__msg[0],recv_wdata__val[0],send_rdata__rdy[0],send_rdata__rdy[1],send_rdata__rdy[2],send_to_controller_spm_rd_resp__rdy,send_to_noc_load_request_pkt__rdy,send_to_noc_load_response_pkt__rdy,send_to_noc_store_pkt__rdy}='0;reset=1;tick();
    if(!$value$plusargs("VECTORS=%s",path))$fatal(1,"MEM_REPLAY_PATH");
    fd=$fopen(path,"r");if(!fd)$fatal(1,"MEM_REPLAY_OPEN");
    while(!$feof(fd))begin
      scan=$fscanf(fd,"%h %h\n",inputs,expected);if(scan!=2)$fatal(1,"MEM_REPLAY_FORMAT");
      {address_lower,address_upper,cgra_id,reset,recv_from_controller_spm_rd_req__msg,recv_from_controller_spm_rd_req__val,recv_from_controller_spm_wr_req__msg,recv_from_controller_spm_wr_req__val,recv_from_noc_load_request__msg,recv_from_noc_load_request__val,recv_from_noc_load_response_pkt__msg,recv_from_noc_load_response_pkt__val,recv_from_noc_store_request__msg,recv_from_noc_store_request__val,recv_raddr__msg[0],recv_raddr__val[0],recv_raddr__msg[1],recv_raddr__val[1],recv_raddr__msg[2],recv_raddr__val[2],recv_waddr__msg[0],recv_waddr__val[0],recv_wdata__msg[0],recv_wdata__val[0],send_rdata__rdy[0],send_rdata__rdy[1],send_rdata__rdy[2],send_to_controller_spm_rd_resp__rdy,send_to_noc_load_request_pkt__rdy,send_to_noc_load_response_pkt__rdy,send_to_noc_store_pkt__rdy}=inputs;#1;if($test$plusargs("EXPECT_FAILURE") && samples==7)expected^=1;
      if({recv_from_controller_spm_rd_req__rdy,recv_from_controller_spm_wr_req__rdy,recv_from_noc_load_request__rdy,recv_from_noc_load_response_pkt__rdy,recv_from_noc_store_request__rdy,recv_raddr__rdy[0],recv_raddr__rdy[1],recv_raddr__rdy[2],recv_waddr__rdy[0],recv_wdata__rdy[0],send_rdata__msg[0],send_rdata__val[0],send_rdata__msg[1],send_rdata__val[1],send_rdata__msg[2],send_rdata__val[2],send_to_controller_spm_rd_resp__msg,send_to_controller_spm_rd_resp__val,send_to_noc_load_request_pkt__msg,send_to_noc_load_request_pkt__val,send_to_noc_load_response_pkt__msg,send_to_noc_load_response_pkt__val,send_to_noc_store_pkt__msg,send_to_noc_store_pkt__val}!==expected)$fatal(1,"MEM_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,{recv_from_controller_spm_rd_req__rdy,recv_from_controller_spm_wr_req__rdy,recv_from_noc_load_request__rdy,recv_from_noc_load_response_pkt__rdy,recv_from_noc_store_request__rdy,recv_raddr__rdy[0],recv_raddr__rdy[1],recv_raddr__rdy[2],recv_waddr__rdy[0],recv_wdata__rdy[0],send_rdata__msg[0],send_rdata__val[0],send_rdata__msg[1],send_rdata__val[1],send_rdata__msg[2],send_rdata__val[2],send_to_controller_spm_rd_resp__msg,send_to_controller_spm_rd_resp__val,send_to_noc_load_request_pkt__msg,send_to_noc_load_request_pkt__val,send_to_noc_load_response_pkt__msg,send_to_noc_load_response_pkt__val,send_to_noc_store_pkt__msg,send_to_noc_store_pkt__val},expected);
      samples++;tick();
    end
    $fclose(fd);if(samples!=440)$fatal(1,"MEM_REPLAY_COVERAGE");
    $display("MEMORY_REPLAY_PASS samples=%0d output_bits=742",samples);$finish;
  end
endmodule
