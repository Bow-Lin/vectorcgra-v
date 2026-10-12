`timescale 1ns/1ps
module tb_data_mem #(
  parameter integer DATA_BITS=35, DEPTH=5, RD_PORTS=3, WR_PORTS=2,
  parameter bit PRELOAD_ENABLE=1, ORIGINAL=0, LEGACY_PYTHON=0, SCALABLE=0,
  parameter integer ADDR_W=(DEPTH>1)?$clog2(DEPTH):1
);
  logic clk=0, reset=0;
  logic [ADDR_W-1:0] recv_raddr__msg [0:RD_PORTS-1];
  logic [RD_PORTS-1:0] recv_raddr__val;
  logic [RD_PORTS-1:0] recv_raddr__rdy;
  logic [DATA_BITS-1:0] send_rdata__msg [0:RD_PORTS-1];
  logic [RD_PORTS-1:0] send_rdata__val;
  logic [RD_PORTS-1:0] send_rdata__rdy;
  logic [ADDR_W-1:0] recv_waddr__msg [0:WR_PORTS-1];
  logic [WR_PORTS-1:0] recv_waddr__val;
  logic [WR_PORTS-1:0] recv_waddr__rdy;
  logic [DATA_BITS-1:0] recv_wdata__msg [0:WR_PORTS-1];
  logic [WR_PORTS-1:0] recv_wdata__val;
  logic [WR_PORTS-1:0] recv_wdata__rdy;
  logic [DATA_BITS-1:0] recv_from_noc__msg='0,send_to_noc__msg;
  logic recv_from_noc__val=0,recv_from_noc__rdy,send_to_noc__val,send_to_noc__rdy=0;
  `include "data_mem_fixture.svh"
`ifdef DATA_MEM_POST_SYNTH
  wire [RD_PORTS*ADDR_W-1:0] flat_raddr;
  wire [RD_PORTS*DATA_BITS-1:0] flat_rdata;
  wire [WR_PORTS*ADDR_W-1:0] flat_waddr;
  wire [WR_PORTS*DATA_BITS-1:0] flat_wdata;
  for (genvar r=0;r<RD_PORTS;r++) begin : flatten_read
    assign flat_raddr[(RD_PORTS-1-r)*ADDR_W +: ADDR_W]=recv_raddr__msg[r];
    assign send_rdata__msg[r]=flat_rdata[(RD_PORTS-1-r)*DATA_BITS +: DATA_BITS];
  end
  for (genvar w=0;w<WR_PORTS;w++) begin : flatten_write
    assign flat_waddr[(WR_PORTS-1-w)*ADDR_W +: ADDR_W]=recv_waddr__msg[w];
    assign flat_wdata[(WR_PORTS-1-w)*DATA_BITS +: DATA_BITS]=recv_wdata__msg[w];
  end
`ifdef DATA_MEM_SCALABLE_NETLIST
    data_mem_netlist dut (.recv_raddr__msg(flat_raddr),.send_rdata__msg(flat_rdata),
      .recv_waddr__msg(flat_waddr),.recv_wdata__msg(flat_wdata),
      .recv_from_noc__msg(recv_from_noc__msg),.recv_from_noc__val(recv_from_noc__val),
      .recv_from_noc__rdy(recv_from_noc__rdy),.send_to_noc__msg(send_to_noc__msg),
      .send_to_noc__val(send_to_noc__val),.send_to_noc__rdy(send_to_noc__rdy),.*);
`else
    data_mem_netlist dut (.recv_raddr__msg(flat_raddr),.send_rdata__msg(flat_rdata),
      .recv_waddr__msg(flat_waddr),.recv_wdata__msg(flat_wdata),.*);
`endif
`else
  if (SCALABLE) begin : scalable_rtl
    data_mem_scalable_synth #(.DATA_BITS(DATA_BITS),.DEPTH(DEPTH),.RD_PORTS(RD_PORTS),.WR_PORTS(WR_PORTS),
      .PRELOAD_ENABLE(PRELOAD_ENABLE),.ORIGINAL(ORIGINAL),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else begin : plain_rtl
  data_mem_synth #(.DATA_BITS(DATA_BITS),.DEPTH(DEPTH),.RD_PORTS(RD_PORTS),.WR_PORTS(WR_PORTS),
    .PRELOAD_ENABLE(PRELOAD_ENABLE),.ORIGINAL(ORIGINAL),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end
`endif
  localparam integer IN_BITS=1+RD_PORTS*(ADDR_W+2)+WR_PORTS*(ADDR_W+DATA_BITS+2)+(SCALABLE?DATA_BITS+2:0);
  localparam integer OUT_BITS=RD_PORTS*(DATA_BITS+2)+2*WR_PORTS+(SCALABLE?DATA_BITS+2:0);
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  integer reads /* verilator public_flat_rw */ =0;
  integer writes /* verilator public_flat_rw */ =0;
  integer stalls /* verilator public_flat_rw */ =0;
  logic [DATA_BITS-1:0] model [0:DEPTH-1];
  logic [DATA_BITS-1:0] snapshots [0:RD_PORTS-1];
  bit pending [0:RD_PORTS-1];
  bit wrong;
  logic [31:0] random_state=32'h27da7a;
  function automatic logic [31:0] rand32();
    random_state=random_state^(random_state<<13);
    random_state=random_state^(random_state>>17);
    random_state=random_state^(random_state<<5);
    return random_state;
  endfunction
  function automatic logic [DATA_BITS-1:0] randword();
    logic [DATA_BITS-1:0] value;
    value='0;
    for (integer i=0;i<DATA_BITS;i+=16) value=(value<<16)|DATA_BITS'(rand32()&65535);
    return value;
  endfunction
  task automatic require(input bit ok,input string label);
    checks++;
    if (!ok) $fatal(1,"DATA_MEM_CHECK %s sample=%0d checks=%0d",label,samples,checks);
  endtask
  task automatic tick;
    #2;clk=1;#2;clk=0;#1;
  endtask
  task automatic clear_inputs;
    recv_raddr__val='0;send_rdata__rdy='0;recv_waddr__val='0;recv_wdata__val='0;
    for (integer r=0;r<RD_PORTS;r++) recv_raddr__msg[r]='0;
    for (integer w=0;w<WR_PORTS;w++) begin recv_waddr__msg[w]='0;recv_wdata__msg[w]='0;end
  endtask
  task automatic replay(input string path);
    integer fd,scan,pos;
    logic [IN_BITS-1:0] ins;
    logic [OUT_BITS-1:0] expected,actual;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",ins,expected);
      if (scan!=2) $fatal(1,"DATA_MEM_VECTOR_FORMAT");
      pos=IN_BITS-1;reset=ins[pos];pos--;
      for (integer r=0;r<RD_PORTS;r++) begin
        recv_raddr__msg[r]=ins[pos -: ADDR_W];pos-=ADDR_W;
        recv_raddr__val[r]=ins[pos];pos--;send_rdata__rdy[r]=ins[pos];pos--;
      end
      for (integer w=0;w<WR_PORTS;w++) begin
        recv_waddr__msg[w]=ins[pos -: ADDR_W];pos-=ADDR_W;
        recv_waddr__val[w]=ins[pos];pos--;
        recv_wdata__msg[w]=ins[pos -: DATA_BITS];pos-=DATA_BITS;
        recv_wdata__val[w]=ins[pos];pos--;
      end
      if (SCALABLE) begin
        recv_from_noc__msg=ins[pos -: DATA_BITS];pos-=DATA_BITS;
        recv_from_noc__val=ins[pos];pos--;send_to_noc__rdy=ins[pos];pos--;
      end
      #1;actual='0;
      for (integer r=0;r<RD_PORTS;r++)
        actual=(actual<<(DATA_BITS+2))|OUT_BITS'({recv_raddr__rdy[r],send_rdata__val[r],send_rdata__msg[r]});
      for (integer w=0;w<WR_PORTS;w++)
        actual=(actual<<2)|OUT_BITS'({recv_waddr__rdy[w],recv_wdata__rdy[w]});
      if (SCALABLE) actual=(actual<<(DATA_BITS+2))|
        OUT_BITS'({recv_from_noc__rdy,send_to_noc__val,send_to_noc__msg});
      if (wrong && samples==3) expected=expected^1;
      if (actual!==expected) $fatal(1,"DATA_MEM_REPLAY_MISMATCH sample=%0d got=%h expected=%h",samples,actual,expected);
      samples++;tick();
    end
    $fclose(fd);require(samples==(ORIGINAL?13:248),"replay coverage");
    $display("DATA_MEM_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic check_native;
    logic [DATA_BITS-1:0] expected;
    recv_from_noc__val=1'(samples);send_to_noc__rdy=1'(samples>>1);
    recv_from_noc__msg=(DATA_BITS'(1)<<(DATA_BITS-1))|DATA_BITS'(samples);
    #1;
    if (SCALABLE) require({recv_from_noc__rdy,send_to_noc__val,send_to_noc__msg}==='0,"inactive NoC ports");
    for (integer r=0;r<RD_PORTS;r++) begin
      require(recv_raddr__rdy[r]==(!reset && send_rdata__rdy[r]),"read acceptance");
      require(send_rdata__val[r]==(!reset && (pending[r] || recv_raddr__val[r])),"read valid");
      expected=reset || !(pending[r] || recv_raddr__val[r]) ? '0 :
        pending[r] ? snapshots[r] : model[recv_raddr__msg[r]];
      if (wrong && samples==5 && r==0) expected=expected^1;
      require(send_rdata__msg[r]===expected,"read data / metadata / held snapshot");
      if (reset) pending[r]=0;
      else if (send_rdata__rdy[r]) begin
        reads+=int'(send_rdata__val[r]);pending[r]=0;
      end else if (send_rdata__val[r]) begin
        stalls++;pending[r]=1;snapshots[r]=expected;
      end
    end
    for (integer w=0;w<WR_PORTS;w++) begin
      require(recv_waddr__rdy[w]==(!reset && recv_wdata__val[w]),"atomic write address");
      require(recv_wdata__rdy[w]==(!reset && recv_waddr__val[w]),"atomic write data");
      if (!reset && recv_waddr__val[w] && recv_wdata__val[w]) begin
        model[recv_waddr__msg[w]]=recv_wdata__msg[w];writes++;
      end
    end
    if (reset) for (integer a=0;a<DEPTH;a++) model[a]=PRELOAD_ENABLE?fixture_word(a):'0;
    samples++;tick();
  endtask
  task automatic native_checks;
    bit hold_addr,hold_data,hold_read;
    reset=1;check_native();reset=0;
    // All write ports collide; all readers see pre-edge data, then the winner.
    recv_raddr__val='1;send_rdata__rdy='1;recv_waddr__val='1;recv_wdata__val='1;
    for (integer w=0;w<WR_PORTS;w++) recv_wdata__msg[w]=DATA_BITS'(w+55);
    check_native();recv_waddr__val='0;recv_wdata__val='0;check_native();
    // Capture a stalled read while writes keep replacing the same word.
    send_rdata__rdy='0;recv_waddr__val='1;recv_wdata__val='1;
    for (integer n=0;n<5;n++) begin
      for (integer w=0;w<WR_PORTS;w++) recv_wdata__msg[w]=DATA_BITS'(n+93+w);
      check_native();
    end
    send_rdata__rdy='1;check_native();clear_inputs();
    for (integer n=0;n<350;n++) begin
      reset=(n==71 || n==72 || n==173 || n==279);
      for (integer r=0;r<RD_PORTS;r++) begin
        hold_read=recv_raddr__val[r] && !send_rdata__rdy[r] && !reset;
        if (!hold_read) begin recv_raddr__msg[r]=ADDR_W'(rand32()%DEPTH);recv_raddr__val[r]=1'(rand32());end
        send_rdata__rdy[r]=(rand32()%4==0);
      end
      for (integer w=0;w<WR_PORTS;w++) begin
        hold_addr=recv_waddr__val[w] && !recv_waddr__rdy[w] && !reset;
        hold_data=recv_wdata__val[w] && !recv_wdata__rdy[w] && !reset;
        if (!hold_addr) begin recv_waddr__msg[w]=ADDR_W'(rand32()%DEPTH);recv_waddr__val[w]=1'(rand32());end
        if (!hold_data) begin recv_wdata__msg[w]=randword();recv_wdata__val[w]=1'(rand32());end
      end
      check_native();
    end
    reset=0;recv_waddr__val='0;recv_wdata__val='0;send_rdata__rdy='1;
    check_native();
    // Read back every location on every port; restores no hidden writes.
    recv_raddr__val='1;
    for (integer a=0;a<DEPTH;a++) begin
      for (integer r=0;r<RD_PORTS;r++) recv_raddr__msg[r]=ADDR_W'(a);
      check_native();
    end
    require(reads>10 && writes>10 && stalls>10,"native traffic coverage");
    $display("DATA_MEM_NATIVE_PASS samples=%0d checks=%0d reads=%0d writes=%0d stalls=%0d",samples,checks,reads,writes,stalls);
  endtask
  task automatic defect(input string name);
    reset=1;tick();reset=0;
    if (name=="unpaired") begin
      recv_waddr__val[0]=1;#1;
      require(!recv_waddr__rdy[0],"DEFECT_UNPAIRED");
    end else if (name=="preload") begin
      recv_waddr__val[0]=1;recv_wdata__val[0]=1;recv_wdata__msg[0]=DATA_BITS'(77);
      tick();recv_waddr__val='0;recv_wdata__val='0;recv_raddr__val[0]=1;send_rdata__rdy[0]=1;#1;
      require(send_rdata__msg[0]==DATA_BITS'(77),"DEFECT_PRELOAD");
    end else if (name=="held") begin
      // Make address zero initialized before measuring the held-data violation.
      recv_raddr__val[0]=1;send_rdata__rdy[0]=1;tick();send_rdata__rdy[0]=0;tick();
      recv_waddr__val[0]=1;recv_wdata__val[0]=1;recv_wdata__msg[0]=DATA_BITS'(77);
      tick();#1;require(send_rdata__msg[0]==fixture_word(0),"DEFECT_HELD");
    end else if (name=="reset") begin
      recv_raddr__val[0]=1;send_rdata__rdy[0]=1;tick();
      recv_waddr__val[0]=1;recv_wdata__val[0]=1;recv_wdata__msg[0]=DATA_BITS'(77);tick();
      recv_waddr__val='0;recv_wdata__val='0;reset=1;tick();reset=0;#1;
      require(send_rdata__msg[0]==fixture_word(0),"DEFECT_RESET");
    end else $fatal(1,"UNKNOWN_DEFECT");
    $display("DATA_MEM_DEFECT_FIXED %s",name);
  endtask
  string path,name;
  initial begin
    clear_inputs();wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($value$plusargs("DEFECT=%s",name)) defect(name);
    else if ($test$plusargs("INVALID_ADDRESS")) begin
      reset=1;tick();reset=0;recv_raddr__val[0]=1;recv_raddr__msg[0]=ADDR_W'(DEPTH);tick();
      $fatal(1,"ADDRESS_NOT_REJECTED");
    end else native_checks();
    $finish;
  end
endmodule
