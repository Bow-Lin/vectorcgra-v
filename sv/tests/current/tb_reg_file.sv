`timescale 1ns/1ps
module tb_reg_file;
  parameter int DATA_BITS=32, DEPTH=16;
  localparam int ADDR_W=(DEPTH<=1)?1:$clog2(DEPTH);
  logic clk=0, reset=0;
  logic [ADDR_W-1:0] recv_waddr__msg, recv_raddr__msg;
  logic [DATA_BITS-1:0] recv_wdata__msg, send_rdata__msg;
  logic recv_waddr__val, recv_waddr__rdy, recv_wdata__val, recv_wdata__rdy;
  logic recv_raddr__val, recv_raddr__rdy, send_rdata__val, send_rdata__rdy;
  logic [DATA_BITS-1:0] expected [0:DEPTH-1];
  logic [31:0] rng=32'h531ad431;
  int checks=0, stalled_writes=0, reset_writes=0, invalid_writes=0;
`ifdef REG_FILE_POST_SYNTH
  reg_file_netlist dut (.*);
`else
  cgra_reg_file #(.DATA_BITS(DATA_BITS), .DEPTH(DEPTH)) dut (.*);
`endif
  task automatic tick;
    #2; clk=1; #2; clk=0; #2;
  endtask
  task automatic check_output(input bit corrupt);
    #1;
    if (send_rdata__msg !== (expected[int'(recv_raddr__msg)] ^ DATA_BITS'(corrupt)) ||
        send_rdata__val !== recv_raddr__val || recv_raddr__rdy !== send_rdata__rdy ||
        recv_waddr__rdy !== send_rdata__rdy || recv_wdata__rdy !== send_rdata__rdy)
      $fatal(1,"REG_FILE_CHECK cycle=%0d addr=%0d", checks, recv_raddr__msg);
    checks++;
  endtask
  initial begin
    // Explicit initialization: neither Python primitive nor SV promises reset data.
    recv_raddr__msg=0; recv_raddr__val=0;
    recv_waddr__val=0; recv_wdata__val=0; send_rdata__rdy=0;
    for (int a=0; a<DEPTH; a++) begin
      recv_waddr__msg=ADDR_W'(a); recv_wdata__msg=DATA_BITS'(a+23);
      tick(); expected[a]=recv_wdata__msg;
    end
    for (int n=0; n<320; n++) begin
      rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
      reset=(n%17==0); recv_waddr__msg=ADDR_W'(rng%DEPTH);
      recv_raddr__msg=ADDR_W'((rng>>8)%DEPTH);
      recv_wdata__msg=DATA_BITS'({rng,~rng,rng^32'hfedcba98});
      recv_waddr__val=rng[0]; recv_wdata__val=rng[1];
      recv_raddr__val=rng[2]; send_rdata__rdy=rng[3];
      check_output($test$plusargs("EXPECT_FAILURE") && n==7);
      tick(); expected[int'(recv_waddr__msg)]=recv_wdata__msg;
      check_output(0);
      if (!send_rdata__rdy) stalled_writes++;
      if (reset) reset_writes++;
      if (!recv_waddr__val || !recv_wdata__val) invalid_writes++;
    end
    if (stalled_writes<20 || reset_writes<10 || invalid_writes<50) $fatal(1,"REG_FILE_COVERAGE");
    $display("REG_FILE_PASS bits=%0d depth=%0d checks=%0d stalled_writes=%0d reset_writes=%0d invalid_writes=%0d",DATA_BITS,DEPTH,checks,stalled_writes,reset_writes,invalid_writes);
    $finish;
  end
endmodule
