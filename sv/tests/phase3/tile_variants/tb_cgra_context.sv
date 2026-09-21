`timescale 1ns/1ps
module tb_cgra_context;
  localparam COLS=2, ROWS=2, DATA_W=32, DATA_BITS=35, TILE_PORTS=4, GLOBAL_ADDR_W=7, CTRL_ADDR_W=3, REG_ADDR_W=4, TILE_ID_W=3;
  localparam ROUTING_OUTPUTS=8, ROUTING_SEL_W=4, CTRL_BITS=119, PAYLOAD_BITS=170, HOST_BITS=191, NOC_BITS=194, MEM_PORT_W=2, BANK_PORT_W=2;
  `include "cgra_profile.svh"
  logic [GLOBAL_ADDR_W-1:0] address_lower;
  logic [GLOBAL_ADDR_W-1:0] address_upper;
  logic  cgra_id;
  logic  clk;
  logic  reset;
  logic [DATA_BITS-1:0] recv_data_on_boundary_east__msg [0:ROWS-1];
  logic  recv_data_on_boundary_east__rdy [0:ROWS-1];
  logic  recv_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_north__msg [0:COLS-1];
  logic  recv_data_on_boundary_north__rdy [0:COLS-1];
  logic  recv_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_south__msg [0:COLS-1];
  logic  recv_data_on_boundary_south__rdy [0:COLS-1];
  logic  recv_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] recv_data_on_boundary_west__msg [0:ROWS-1];
  logic  recv_data_on_boundary_west__rdy [0:ROWS-1];
  logic  recv_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg;
  logic  recv_from_cpu_pkt__rdy;
  logic  recv_from_cpu_pkt__val;
  logic [NOC_BITS-1:0] recv_from_inter_cgra_noc__msg;
  logic  recv_from_inter_cgra_noc__rdy;
  logic  recv_from_inter_cgra_noc__val;
  logic [DATA_BITS-1:0] send_data_on_boundary_east__msg [0:ROWS-1];
  logic  send_data_on_boundary_east__rdy [0:ROWS-1];
  logic  send_data_on_boundary_east__val [0:ROWS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_north__msg [0:COLS-1];
  logic  send_data_on_boundary_north__rdy [0:COLS-1];
  logic  send_data_on_boundary_north__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_south__msg [0:COLS-1];
  logic  send_data_on_boundary_south__rdy [0:COLS-1];
  logic  send_data_on_boundary_south__val [0:COLS-1];
  logic [DATA_BITS-1:0] send_data_on_boundary_west__msg [0:ROWS-1];
  logic  send_data_on_boundary_west__rdy [0:ROWS-1];
  logic  send_data_on_boundary_west__val [0:ROWS-1];
  logic [HOST_BITS-1:0] send_to_cpu_pkt__msg;
  logic  send_to_cpu_pkt__rdy;
  logic  send_to_cpu_pkt__val;
  logic [NOC_BITS-1:0] send_to_inter_cgra_noc__msg;
  logic  send_to_inter_cgra_noc__rdy;
  logic  send_to_inter_cgra_noc__val;
  cgra_programmable #(.TILE_PORTS(TILE_PORTS),.TILE_VARIANT(1),.FU_COUNT(5),.FU_KINDS({8'd3,8'd2,8'd1,8'd0,8'd9})) dut(.*);
  logic [700:0] stimulus;
  logic [488:0] expected, actual;
  host_packet_t response; data_t west_data;
  assign response=send_to_cpu_pkt__msg; assign west_data=send_data_on_boundary_west__msg[1];
  integer fd,rc,cycle=0,west_events=0,completions=0,reads=0;
  logic [31:0] expected_west[0:9];
  assign actual={recv_from_cpu_pkt__rdy,send_to_cpu_pkt__msg,send_to_cpu_pkt__val,send_data_on_boundary_north__msg[0],send_data_on_boundary_north__val[0],recv_data_on_boundary_north__rdy[0],send_data_on_boundary_north__msg[1],send_data_on_boundary_north__val[1],recv_data_on_boundary_north__rdy[1],send_data_on_boundary_south__msg[0],send_data_on_boundary_south__val[0],recv_data_on_boundary_south__rdy[0],send_data_on_boundary_south__msg[1],send_data_on_boundary_south__val[1],recv_data_on_boundary_south__rdy[1],send_data_on_boundary_west__msg[0],send_data_on_boundary_west__val[0],recv_data_on_boundary_west__rdy[0],send_data_on_boundary_west__msg[1],send_data_on_boundary_west__val[1],recv_data_on_boundary_west__rdy[1],send_data_on_boundary_east__msg[0],send_data_on_boundary_east__val[0],recv_data_on_boundary_east__rdy[0],send_data_on_boundary_east__msg[1],send_data_on_boundary_east__val[1],recv_data_on_boundary_east__rdy[1]};
  initial begin
    clk=0;
    expected_west[0]=32'h0000001c;
    expected_west[1]=32'hfffffff5;
    fd=$fopen("reference/phase3/tile_variants/context-cgra-pyreplay-v2/cycles.txt","r");
    if(!fd) $fatal(1,"missing full CGRA Python replay");
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",stimulus,expected);
      if(rc!=2) $fatal(1,"bad CGRA replay row");
      {reset,cgra_id,address_lower,address_upper,recv_from_cpu_pkt__msg,recv_from_cpu_pkt__val,send_to_cpu_pkt__rdy,recv_from_inter_cgra_noc__msg,recv_from_inter_cgra_noc__val,send_to_inter_cgra_noc__rdy,recv_data_on_boundary_north__msg[0],recv_data_on_boundary_north__val[0],send_data_on_boundary_north__rdy[0],recv_data_on_boundary_north__msg[1],recv_data_on_boundary_north__val[1],send_data_on_boundary_north__rdy[1],recv_data_on_boundary_south__msg[0],recv_data_on_boundary_south__val[0],send_data_on_boundary_south__rdy[0],recv_data_on_boundary_south__msg[1],recv_data_on_boundary_south__val[1],send_data_on_boundary_south__rdy[1],recv_data_on_boundary_west__msg[0],recv_data_on_boundary_west__val[0],send_data_on_boundary_west__rdy[0],recv_data_on_boundary_west__msg[1],recv_data_on_boundary_west__val[1],send_data_on_boundary_west__rdy[1],recv_data_on_boundary_east__msg[0],recv_data_on_boundary_east__val[0],send_data_on_boundary_east__rdy[0],recv_data_on_boundary_east__msg[1],recv_data_on_boundary_east__val[1],send_data_on_boundary_east__rdy[1]}=stimulus;
      #4;
      if($test$plusargs("EXPECT_FAILURE") && cycle==20) expected[0]=~expected[0];
      if(actual!==expected) $fatal(1,"CGRA replay mismatch cycle=%0d actual=%h expected=%h xor=%h",cycle,actual,expected,actual^expected);
      if(send_data_on_boundary_west__val[1] && send_data_on_boundary_west__rdy[1]) begin
        if(west_events>=2 || west_data.payload!==expected_west[west_events] || west_data.predicate!==1) $fatal(1,"independent CGRA arithmetic mismatch");
        west_events++;
      end
      if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin
        if(response.payload.cmd==14) completions++;
        else if(response.payload.cmd==11) reads++;
        else $fatal(1,"unexpected CPU response");
      end
      clk=1; #1; clk=0; #1; cycle++;
    end
    if(cycle!=134 || west_events!=2 || completions!=8 || reads!=4) $fatal(1,"incomplete full CGRA coverage");
    $display("CGRA_CONTEXT_PASS cycles=%0d outputs=%0d complete=%0d reads=%0d",cycle,west_events,completions,reads);
    $finish;
  end
endmodule
