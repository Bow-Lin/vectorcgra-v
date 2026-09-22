`timescale 1ns/1ps
module tb_im2col;
  localparam int DATA_W=32,HOST_BITS=191,SCRATCH_DEPTH=64;
  localparam logic [SCRATCH_DEPTH*DATA_W-1:0] IMAGE=2048'h19b0000018a0000017980000168000001570000014600000135000001240000011300000102800000f1000000e0000000cf000000be000000ad0000009c0000008b8000007a00000069000000580000004700000036000000250000001480000003;

  logic [1-1:0] clk=0;
  logic [1-1:0] reset=0;
  logic [191-1:0] recv_cmd_pkt__msg=0;
  logic [1-1:0] recv_cmd_pkt__val=0;
  logic [1-1:0] recv_cmd_pkt__rdy, gold_recv_cmd_pkt__rdy;
  logic [191-1:0] send_pkt__msg, gold_send_pkt__msg;
  logic [1-1:0] send_pkt__val, gold_send_pkt__val;
  logic [1-1:0] send_pkt__rdy=0;
  logic [1-1:0] done, gold_done;
  cgra_im2col_engine #(.DATA_W(DATA_W),.SCRATCH_DEPTH(SCRATCH_DEPTH),.PRELOAD_IMAGE(IMAGE)) dut (.clk(clk),
    .reset(reset),
    .recv_cmd_pkt__msg(recv_cmd_pkt__msg),
    .recv_cmd_pkt__val(recv_cmd_pkt__val),
    .recv_cmd_pkt__rdy(recv_cmd_pkt__rdy),
    .send_pkt__msg(send_pkt__msg),
    .send_pkt__val(send_pkt__val),
    .send_pkt__rdy(send_pkt__rdy),
    .done(done));
  Phase4Im2Col gold (.clk(clk),
    .reset(reset),
    .recv_cmd_pkt__msg(recv_cmd_pkt__msg),
    .recv_cmd_pkt__val(recv_cmd_pkt__val),
    .recv_cmd_pkt__rdy(gold_recv_cmd_pkt__rdy),
    .send_pkt__msg(gold_send_pkt__msg),
    .send_pkt__val(gold_send_pkt__val),
    .send_pkt__rdy(send_pkt__rdy),
    .done(gold_done));
  task automatic compare_outputs;
    if ({recv_cmd_pkt__rdy,send_pkt__msg,send_pkt__val,done} !== ({gold_recv_cmd_pkt__rdy,gold_send_pkt__msg,gold_send_pkt__val,gold_done} ^ (($test$plusargs("EXPECT_FAILURE") && cycles==20)?1:0)))
      begin
        if(recv_cmd_pkt__rdy!==gold_recv_cmd_pkt__rdy) $display("recv_cmd_pkt__rdy native=%h gold=%h",recv_cmd_pkt__rdy,gold_recv_cmd_pkt__rdy);
        if(send_pkt__msg!==gold_send_pkt__msg) $display("send_pkt__msg native=%h gold=%h",send_pkt__msg,gold_send_pkt__msg);
        if(send_pkt__val!==gold_send_pkt__val) $display("send_pkt__val native=%h gold=%h",send_pkt__val,gold_send_pkt__val);
        if(done!==gold_done) $display("done native=%h gold=%h",done,gold_done);
        $fatal(1,"im2col mismatch cycle=%0d",cycles);end
  endtask

  localparam int CTRL_BITS=119,CTRL_ADDR_W=3,GLOBAL_ADDR_W=7,DATA_BITS=DATA_W+3,PAYLOAD_BITS=6+DATA_BITS+7+119+3;
  int cycles=0,emits=0,runs=0,config_packets=0;
  function automatic logic [HOST_BITS-1:0] packet(input int cmd,input logic[DATA_W-1:0] value,input int addr);
    logic [HOST_BITS-1:0] p;p='0;
    p[CTRL_ADDR_W+CTRL_BITS+:7]=7'(addr);
    p[CTRL_ADDR_W+CTRL_BITS+7+:DATA_BITS]={value,3'b100};
    p[PAYLOAD_BITS-6+:6]=6'(cmd);return p;
  endfunction
  task automatic tick;
    #4;compare_outputs();#1;clk=1;#5;clk=0;cycles++;
  endtask
  task automatic reset_engine;
    reset=1;recv_cmd_pkt__val=0;send_pkt__rdy=0;repeat(3)tick();reset=0;tick();
    if(done || !recv_cmd_pkt__rdy || send_pkt__val)$fatal(1,"im2col reset");
  endtask
  task automatic command(input int cmd,input int value,input int addr);
    recv_cmd_pkt__msg=packet(cmd,DATA_W'(value),addr);recv_cmd_pkt__val=1;
    if(!recv_cmd_pkt__rdy)$fatal(1,"config not ready");tick();recv_cmd_pkt__val=0;config_packets++;
  endtask
  task automatic configure(input int h,input int w,input int kh,input int kw,input int lg,input int base);
    command(53,h,0);command(54,w,0);command(55,kh,0);command(56,kw,0);command(57,lg,0);command(58,0,base);
  endtask
  task automatic run_image(input int h,input int w,input int kh,input int kw,input int lg,input int base,input bit abort_early);
    int oh,ow,index,timeout;logic[HOST_BITS-1:0] expected;logic[DATA_W-1:0] pixel;
    oh=((h-kh)>>lg)+1;ow=((w-kw)>>lg)+1;index=0;timeout=0;
    command(52,0,0);
    for(int ky=0;ky<kh;ky++)for(int kx=0;kx<kw;kx++)for(int oy=0;oy<oh;oy++)for(int ox=0;ox<ow;ox++)begin
      pixel=IMAGE[DATA_W*(((oy<<lg)+ky)*w+(ox<<lg)+kx)+:DATA_W];
      expected=packet(12,pixel,base+index);
      begin:wait_emit
        bit accepted;accepted=0;
        while(!accepted)begin
          send_pkt__rdy=(cycles%7<3);
          // Commands presented while busy must remain unaccepted and ignored.
          recv_cmd_pkt__val=1;recv_cmd_pkt__msg=packet(53,DATA_W'(1),0);
          #1;
          if(recv_cmd_pkt__rdy || done)$fatal(1,"premature idle/done");
          if(send_pkt__val)begin
            if(send_pkt__msg!==expected)$fatal(1,"independent image window index=%0d expected=%h got=%h",index,expected,send_pkt__msg);
            accepted=send_pkt__rdy;
          end
          tick();timeout++;if(timeout>5000)$fatal(1,"IM2COL TIMEOUT");
        end
      end
      index++;emits++;
      if(abort_early && index==3)begin recv_cmd_pkt__val=0;return;end
    end
    if(!done || send_pkt__val || recv_cmd_pkt__rdy)$fatal(1,"im2col final done");
    repeat(5)begin tick();if(!done || recv_cmd_pkt__rdy || send_pkt__val || send_pkt__msg!=0)$fatal(1,"terminal done hold");end
    recv_cmd_pkt__val=0;runs++;
  endtask
  initial begin
    reset_engine();configure(5,5,2,3,0,9);run_image(5,5,2,3,0,9,0);
    // Reset preserves configuration and lazily initialized image contents.
    reset_engine();run_image(5,5,2,3,0,9,0);
    reset_engine();configure(5,5,3,2,1,101);run_image(5,5,3,2,1,101,0);
    reset_engine();configure(5,5,2,2,0,0);run_image(5,5,2,2,0,0,1);
    reset_engine();run_image(5,5,2,2,0,0,0);
    $display("IM2COL_PASS cycles=%0d completed_runs=%0d emits=%0d config_packets=%0d",cycles,runs,emits,config_packets);$finish;
  end
endmodule

