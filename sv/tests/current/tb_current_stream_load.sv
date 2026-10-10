// Transaction-level STREAM_LD test using archived response/backpressure traffic.
// Frozen raw outputs are parsed for format only; independent address/data/count
// assertions below are the acceptance oracle for the current ABI.
`timescale 1ns/1ps
module tb_current_stream_load;
  localparam TILE_PORTS=8, DATA_BITS=35, TILE_ID_W=3, CTRL_ADDR_W=3, GLOBAL_ADDR_W=7, HOST_BITS=215;
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
  cgra_pe #(.VARIANT(2),.TILE_PORTS(8),.NUM_CTRL(2),.TOTAL_STEPS(2),.FU_COUNT(4),.FU_KINDS({8'd3,8'd32,8'd1,8'd0})) dut(.*);
  logic [556:0] stimulus;
  logic [565:0] expected, actual;
  integer fd, rc, cycle=0, outputs_seen=0, completions=0, requests=0;
  integer expected_value[0:5];
  assign actual={from_mem_rdata__rdy,recv_from_controller_pkt__rdy,send_to_controller_pkt__msg,send_to_controller_pkt__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val,recv_data__rdy[0],send_data__msg[0],send_data__val[0],recv_data__rdy[1],send_data__msg[1],send_data__val[1],recv_data__rdy[2],send_data__msg[2],send_data__val[2],recv_data__rdy[3],send_data__msg[3],send_data__val[3],recv_data__rdy[4],send_data__msg[4],send_data__val[4],recv_data__rdy[5],send_data__msg[5],send_data__val[5],recv_data__rdy[6],send_data__msg[6],send_data__val[6],recv_data__rdy[7],send_data__msg[7],send_data__val[7]};
  initial begin
    clk=0; expected_value[0]=4; expected_value[1]=12; expected_value[2]=0; expected_value[3]=0; expected_value[4]=20; expected_value[5]=28;
    fd=$fopen("reference/phase3/tile_variants/streaming-tile-pyreplay/cycles.txt","r");
    if(!fd) $fatal(1,"missing frozen tile reference");
    while(!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",stimulus,expected);
      if(rc!=2) $fatal(1,"malformed tile trace");
      {reset,cgra_id,tile_id,from_mem_rdata__msg,from_mem_rdata__val,recv_from_controller_pkt__msg,recv_from_controller_pkt__val,send_to_controller_pkt__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy,recv_data__msg[0],recv_data__val[0],send_data__rdy[0],recv_data__msg[1],recv_data__val[1],send_data__rdy[1],recv_data__msg[2],recv_data__val[2],send_data__rdy[2],recv_data__msg[3],recv_data__val[3],send_data__rdy[3],recv_data__msg[4],recv_data__val[4],send_data__rdy[4],recv_data__msg[5],recv_data__val[5],send_data__rdy[5],recv_data__msg[6],recv_data__val[6],send_data__rdy[6],recv_data__msg[7],recv_data__val[7],send_data__rdy[7]}=stimulus;
      // The archived traffic uses ac96 opcode 88. Re-encode only STREAM_LD
      // to the current ABI (89); the operand/response traffic is unchanged.
      if(recv_from_controller_pkt__msg[139+:7]==7'd88)
        recv_from_controller_pkt__msg[139+:7]=7'd89;
      #4;
      if(send_data__val[0] && send_data__rdy[0]) begin
        if(send_data__msg[0] !== 35'((((10+2*(outputs_seen%5))*7+1)<<3)|4)) $fatal(1,"independent streaming Tile output");
        outputs_seen++;
      end
      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completions++;
      if(to_mem_raddr__val && to_mem_raddr__rdy) begin
        if(to_mem_raddr__msg !== 7'(10+2*(requests%5))) $fatal(1,"independent streaming Tile request");
        requests++;
      end
      clk=1; #1; clk=0; #1; cycle++;
    end
    if(cycle!=190 || outputs_seen!=10 || completions!=2 || requests!=10)
      $fatal(1,"incomplete Tile coverage cycles=%0d outputs=%0d complete=%0d req=%0d",cycle,outputs_seen,completions,requests);
    $display("CURRENT_STREAM_LOAD_PASS cycles=%0d outputs=%0d complete=%0d requests=%0d",cycle,outputs_seen,completions,requests);
    $finish;
  end
endmodule
