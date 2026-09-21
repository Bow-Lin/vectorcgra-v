`timescale 1ns/1ps
module tb_tile_context;
  localparam TILE_PORTS=4, DATA_BITS=35, TILE_ID_W=3, CTRL_ADDR_W=3, GLOBAL_ADDR_W=7, HOST_BITS=191;
  logic [0:0] cgra_id ;
  logic [0:0] clk ;
  logic [0:0] reset ;
  logic [TILE_ID_W-1:0] tile_id ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg ;
  logic [0:0] from_mem_rdata__rdy ;
  logic [0:0] from_mem_rdata__val ;
  logic [DATA_BITS-1:0] recv_data__msg [0:TILE_PORTS-1];
  logic [0:0] recv_data__rdy [0:TILE_PORTS-1];
  logic [0:0] recv_data__val [0:TILE_PORTS-1];
  logic [HOST_BITS-1:0] recv_from_controller_pkt__msg ;
  logic [0:0] recv_from_controller_pkt__rdy ;
  logic [0:0] recv_from_controller_pkt__val ;
  logic [DATA_BITS-1:0] send_data__msg [0:TILE_PORTS-1];
  logic [0:0] send_data__rdy [0:TILE_PORTS-1];
  logic [0:0] send_data__val [0:TILE_PORTS-1];
  logic [HOST_BITS-1:0] send_to_controller_pkt__msg ;
  logic [0:0] send_to_controller_pkt__rdy ;
  logic [0:0] send_to_controller_pkt__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg ;
  logic [0:0] to_mem_raddr__rdy ;
  logic [0:0] to_mem_raddr__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg ;
  logic [0:0] to_mem_waddr__rdy ;
  logic [0:0] to_mem_waddr__val ;
  logic [DATA_BITS-1:0] to_mem_wdata__msg ;
  logic [0:0] to_mem_wdata__rdy ;
  logic [0:0] to_mem_wdata__val ;
  tile_context #(.TILE_PORTS(4),.NUM_CTRL(1),.TOTAL_STEPS(6),.FU_COUNT(5),.FU_KINDS({8'd3,8'd2,8'd1,8'd0,8'd9})) dut(.*);
  logic [384:0] stimulus;
  logic [393:0] expected, actual;
  integer fd, rc, cycle=0, outputs_seen=0, completions=0, requests=0;
  integer expected_value[0:5];
  assign actual={from_mem_rdata__rdy,recv_from_controller_pkt__rdy,send_to_controller_pkt__msg,send_to_controller_pkt__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val,recv_data__rdy[0],send_data__msg[0],send_data__val[0],recv_data__rdy[1],send_data__msg[1],send_data__val[1],recv_data__rdy[2],send_data__msg[2],send_data__val[2],recv_data__rdy[3],send_data__msg[3],send_data__val[3]};
  initial begin
    clk=0; expected_value[0]=4; expected_value[1]=12; expected_value[2]=0; expected_value[3]=0; expected_value[4]=20; expected_value[5]=28;
    fd=$fopen("reference/phase3/tile_variants/context-tile-pyreplay-clear/cycles.txt","r");
    if(!fd) $fatal(1,"missing frozen tile reference");
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",stimulus,expected);
      if(rc!=2) $fatal(1,"malformed tile trace");
      {reset,cgra_id,tile_id,from_mem_rdata__msg,from_mem_rdata__val,recv_from_controller_pkt__msg,recv_from_controller_pkt__val,send_to_controller_pkt__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy,recv_data__msg[0],recv_data__val[0],send_data__rdy[0],recv_data__msg[1],recv_data__val[1],send_data__rdy[1],recv_data__msg[2],recv_data__val[2],send_data__rdy[2],recv_data__msg[3],recv_data__val[3],send_data__rdy[3]}=stimulus;
      #4;
      if($test$plusargs("EXPECT_FAILURE") && cycle==20) expected[0]=~expected[0];
      if(actual!==expected) $fatal(1,"tile replay mismatch cycle=%0d actual=%h expected=%h xor=%h",cycle,actual,expected,actual^expected);
      if(send_data__val[0] && send_data__rdy[0]) begin
        if(cycle<95 && send_data__msg[0] !== 35'(expected_value[outputs_seen])) $fatal(1,"independent context Tile output");
        outputs_seen++;
      end
      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completions++;
      if(to_mem_raddr__val && to_mem_raddr__rdy) begin
        if(to_mem_raddr__msg !== 7'(10+2*(requests%5))) $fatal(1,"independent streaming Tile request");
        requests++;
      end
      if(cycle==193) for(int i=0;i<TILE_PORTS;i++) if(recv_data__rdy[i]!==0) $fatal(1,"clear setup requires full channels");
      if(cycle==195) for(int i=0;i<TILE_PORTS;i++) if(recv_data__rdy[i]!==1) $fatal(1,"TERMINATE failed to clear channels");
      clk=1; #1; clk=0; #1; cycle++;
    end
    if(cycle!=210 || outputs_seen!=12 || completions!=2 || requests!=0)
      $fatal(1,"incomplete Tile coverage cycles=%0d outputs=%0d complete=%0d req=%0d",cycle,outputs_seen,completions,requests);
    $display("TILE_CONTEXT_PASS cycles=%0d outputs=%0d complete=%0d requests=%0d",cycle,outputs_seen,completions,requests);
    $finish;
  end
endmodule
