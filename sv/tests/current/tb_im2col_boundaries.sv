`timescale 1ns/1ps
module tb_im2col_boundaries #(parameter int DATA_W=32,SCRATCH_DEPTH=64, parameter bit LEGACY_PYTHON=0);
  localparam int HOST_BITS=159+DATA_W;
  `include "im2col_boundary_fixture.svh"
  logic clk=0,reset=0,recv_cmd_pkt__val=0,recv_cmd_pkt__rdy,send_pkt__val,send_pkt__rdy=0,done;
  logic [HOST_BITS-1:0] recv_cmd_pkt__msg=0,send_pkt__msg;
  bit wrong;
`ifdef IM2COL_BOUNDARIES_POST_SYNTH
  im2col_boundaries_netlist dut(.*);
`else
  cgra_im2col_engine #(.DATA_W(DATA_W),.SCRATCH_DEPTH(SCRATCH_DEPTH),.PRELOAD_IMAGE(IMAGE),.LEGACY_PYTHON(LEGACY_PYTHON)) dut(.*);
`endif
  localparam int CTRL_BITS=119,CTRL_ADDR_W=3,GLOBAL_ADDR_W=7,DATA_BITS=DATA_W+3,PAYLOAD_BITS=6+DATA_BITS+7+119+3;
  int cycles=0,emits=0,runs=0,config_packets=0;
  function automatic logic [HOST_BITS-1:0] packet(input int cmd,input logic[DATA_W-1:0] value,input int addr);
    logic [HOST_BITS-1:0] p;p='0;
    p[CTRL_ADDR_W+CTRL_BITS+:7]=7'(addr);
    p[CTRL_ADDR_W+CTRL_BITS+7+:DATA_BITS]={value,3'b100};
    p[PAYLOAD_BITS-6+:6]=6'(cmd);return p;
  endfunction
  task automatic tick;
    #4;#1;clk=1;#5;clk=0;cycles++;
  endtask
  task automatic reset_engine;
    reset=1;recv_cmd_pkt__val=0;send_pkt__rdy=0;repeat(3)tick();reset=0;tick();
    if(done || !recv_cmd_pkt__rdy || send_pkt__val)$fatal(1,"im2col reset");
  endtask
  task automatic command(input int cmd,input int value,input int addr);
    recv_cmd_pkt__msg=packet(cmd,DATA_W'(value),addr);recv_cmd_pkt__val=1;#1;
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
            if(wrong && emits==0) expected^=1;
            if(send_pkt__msg!==expected)$fatal(1,"independent image window index=%0d expected=%h got=%h",index,expected,send_pkt__msg);
            accepted=send_pkt__rdy;
          end
          tick();timeout++;if(timeout>5000)$fatal(1,"IM2COL TIMEOUT");
        end
      end
      index++;emits++;
      if(abort_early && index==3)begin recv_cmd_pkt__val=0;return;end
    end
    recv_cmd_pkt__val=0;#1;
    if(!done || send_pkt__val || !recv_cmd_pkt__rdy)$fatal(1,"im2col final done");
    repeat(5)begin tick();if(!done || !recv_cmd_pkt__rdy || send_pkt__val || send_pkt__msg!=0)$fatal(1,"terminal done hold");end
    recv_cmd_pkt__val=0;runs++;
  endtask
  integer samples /* verilator public_flat_rw */ =0;
  task automatic replay(input string path);
    integer fd,scan;
    logic [HOST_BITS+2:0] inputs,expected;
    fd=$fopen(path,"r");if(!fd)$fatal(1,"IM2COL_REPLAY_OPEN");
    // A reset edge defines the FSM state independently of synthesis encoding.
    reset=1;tick();
    while(!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",inputs,expected);if(scan!=2)$fatal(1,"IM2COL_REPLAY_FORMAT");
      {reset,recv_cmd_pkt__msg,recv_cmd_pkt__val,send_pkt__rdy}=inputs;#1;
      if(wrong && samples==20)expected^=1;
      if({recv_cmd_pkt__rdy,send_pkt__msg,send_pkt__val,done}!==expected)$fatal(1,"IM2COL_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,{recv_cmd_pkt__rdy,send_pkt__msg,send_pkt__val,done},expected);
      samples++;tick();
    end
    $fclose(fd);if(samples!=860)$fatal(1,"IM2COL_REPLAY_COVERAGE");
    $display("IM2COL_REPLAY_PASS width=%0d depth=%0d samples=%0d output_bits=%0d",DATA_W,SCRATCH_DEPTH,samples,HOST_BITS+3);
  endtask
  task automatic isolated_reset;
    reset=1;recv_cmd_pkt__val=1;send_pkt__rdy=1;#1;
    if(recv_cmd_pkt__rdy || send_pkt__val || send_pkt__msg || done)$fatal(1,"IM2COL_RESET_ISOLATION");
    tick();#1;if(recv_cmd_pkt__rdy || send_pkt__val || done)$fatal(1,"IM2COL_RESET_ISOLATION");
    recv_cmd_pkt__val=0;reset=0;send_pkt__rdy=0;tick();
  endtask
  string vectors,invalid;
  initial begin
    wrong=$test$plusargs("EXPECT_FAILURE");
    if($value$plusargs("VECTORS=%s",vectors))begin replay(vectors);$finish;end
    reset_engine();
    if($value$plusargs("INVALID=%s",invalid))begin
      if(invalid=="zero")begin recv_cmd_pkt__msg=packet(53,0,0);end
      else if(invalid=="oversize")begin recv_cmd_pkt__msg=packet(54,DATA_W'(SCRATCH_DEPTH+1),0);end
      else if(invalid=="stride")begin recv_cmd_pkt__msg=packet(57,DATA_W'($clog2(SCRATCH_DEPTH)+1),0);end
      else begin
        if(invalid=="kernel")configure(2,2,3,1,0,0);
        else if(invalid=="image")configure(SCRATCH_DEPTH,2,1,1,0,0);
        else if(invalid=="destination")configure(5,5,2,3,0,100);
        // 'reset' launches with the configuration cleared by reset.
        recv_cmd_pkt__msg=packet(52,0,0);
      end
      recv_cmd_pkt__val=1;#1;if(recv_cmd_pkt__rdy)$fatal(1,"IM2COL_INVALID_ACCEPTED");
`ifdef IM2COL_BOUNDARIES_POST_SYNTH
      repeat(4)begin tick();if(recv_cmd_pkt__rdy || send_pkt__val || done)$fatal(1,"IM2COL_INVALID_ACCEPTED");end
      $display("IM2COL_INVALID_REJECT_PASS");$finish;
`else
      tick();$fatal(1,"IM2COL_MISSING_DIAGNOSTIC");
`endif
    end
    configure(5,5,2,3,0,9);run_image(5,5,2,3,0,9,0);
    run_image(5,5,2,3,0,9,0); // DONE accepts a new launch without reset.
    configure(5,5,3,2,1,101);run_image(5,5,3,2,1,101,0);
    isolated_reset();configure(5,5,2,2,0,0);run_image(5,5,2,2,0,0,1);
    isolated_reset();configure(5,5,2,2,0,0);run_image(5,5,2,2,0,0,0);
    // A dimension equal to the entire depth must not narrow to zero.
    configure(1,SCRATCH_DEPTH,1,1,0,0);run_image(1,SCRATCH_DEPTH,1,1,0,0,0);
    // Hold an output, cancel it with reset, then configure a fresh launch.
    configure(5,5,1,1,0,0);command(52,0,0);send_pkt__rdy=0;
    repeat(4)tick();if(!send_pkt__val)$fatal(1,"IM2COL_EXPECT_HELD");
    isolated_reset();configure(1,1,1,1,0,127);run_image(1,1,1,1,0,127,0);
    $display("IM2COL_BOUNDARIES_PASS width=%0d depth=%0d cycles=%0d runs=%0d emits=%0d",DATA_W,SCRATCH_DEPTH,cycles,runs,emits);$finish;
  end
endmodule
