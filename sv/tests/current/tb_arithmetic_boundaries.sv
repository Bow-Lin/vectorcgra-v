`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_arithmetic_boundaries #(
  `CGRA_PROFILE_PARAMETERS,
  parameter integer LATENCY=1, KIND=0,
  parameter bit LEGACY_PYTHON=0
);
  `include "cgra_profile.svh"
  `include "vector_reduce_ports.svh"
`ifdef ARITHMETIC_BOUNDARIES_POST_SYNTH
  wire [4*DATA_BITS-1:0] flat_inputs;
  wire [3:0] flat_valid,flat_ready;
  wire [2*DATA_BITS-1:0] flat_outputs;
  wire [1:0] flat_out_valid,flat_out_ready;
  for (genvar i=0;i<4;i++) begin : flat_in
    assign flat_inputs[(3-i)*DATA_BITS +: DATA_BITS]=recv_in__msg[i];
    assign flat_valid[3-i]=recv_in__val[i];
    assign recv_in__rdy[i]=flat_ready[3-i];
  end
  for (genvar i=0;i<2;i++) begin : flat_out
    assign send_out__msg[i]=flat_outputs[(1-i)*DATA_BITS +: DATA_BITS];
    assign send_out__val[i]=flat_out_valid[1-i];
    assign flat_out_ready[1-i]=send_out__rdy[i];
  end
  arithmetic_boundaries_netlist dut (.recv_in__msg(flat_inputs),.recv_in__val(flat_valid),.recv_in__rdy(flat_ready),
    .send_out__msg(flat_outputs),.send_out__val(flat_out_valid),.send_out__rdy(flat_out_ready),.*);
`else
  if (KIND==0) begin : div
    scalar_div #(`CGRA_PROFILE_BIND,.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else if (KIND==1) begin : inclusive
    scalar_inclusive_div #(`CGRA_PROFILE_BIND,.LATENCY(LATENCY),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else if (KIND==2) begin : exclusive
    scalar_exclusive_div #(`CGRA_PROFILE_BIND,.LATENCY(LATENCY),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else if (KIND==3) begin : mac
    tile_alu_gen_mac #(`CGRA_PROFILE_BIND,.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else begin : loop_control
    scalar_loop_control #(`CGRA_PROFILE_BIND,.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end
`endif
  localparam integer IN_BITS=$bits({clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}),OUT_BITS=$bits({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val});
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  logic [31:0] rng=32'h377ac;
  bit wrong;
  data_t result_data;
  assign result_data=send_out__msg[0];
  function automatic logic [31:0] rand32();
    rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);return rng;
  endfunction
  function automatic logic [DATA_W-1:0] randword();
    logic [DATA_W-1:0] value;
    value='0;for (integer i=0;i<DATA_W;i+=16) value=(value<<16)|DATA_W'(rand32()&65535);
    return value;
  endfunction
  function automatic data_t data_word(input logic [DATA_W-1:0] value,input bit pred);
    data_t d;d='0;d.payload=value;d.predicate=pred;return d;
  endfunction
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  task automatic require(input bit ok,input string label);
    checks++;if (!ok) $fatal(1,"ARITHMETIC_BOUNDARIES_CHECK %s sample=%0d checks=%0d",label,samples,checks);
  endtask
  task automatic clear_inputs;
    {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}='0;
  endtask
  task automatic replay(input string path);
    integer fd,scan;
    logic [IN_BITS-1:0] input_word;
    logic [OUT_BITS-1:0] expected;
    fd=$fopen(path,"r");require(fd!=0,"open vectors");
    while (!$feof(fd)) begin
      scan=$fscanf(fd,"%h %h\n",input_word,expected);
      if (scan!=2) $fatal(1,"ARITHMETIC_BOUNDARIES_VECTOR_FORMAT");
      {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}=input_word;#1;
      if (wrong && samples==4) expected=expected^1;
      if ({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val}!==expected)
        $fatal(1,"ARITHMETIC_BOUNDARIES_REPLAY_MISMATCH sample=%0d",samples);
      samples++;tick();
    end
    $fclose(fd);require(samples==360,"replay coverage");
    $display("ARITHMETIC_BOUNDARIES_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic control(input int op,input int first=1,input int second=3,input int third=2,input int fourth=0,input int power=0,input bit last=0);
    ctrl_t c;
    c='0;c.operation=7'(op);c.fu_in[0]=3'(first+1);c.fu_in[1]=3'(second+1);
    c.fu_in[2]=3'(third+1);c.fu_in[3]=3'(fourth+1);c.vector_factor_power=3'(power);c.is_last_ctrl=last;
    recv_opt__msg=c;recv_opt__val=1;
  endtask
  task automatic restart;
    clear_inputs();reset=1;tick();reset=0;#1;
  endtask
  task automatic no_transactions(input string label);
    #1;
    require(!recv_opt__rdy && !recv_const__rdy && !send_out__val[0] && !send_out__val[1],label);
    for(integer i=0;i<4;i++) require(!recv_in__rdy[i],label);
    require(!send_to_ctrl_mem__val && !recv_from_ctrl_mem__rdy && !from_mem_rdata__rdy &&
      !to_mem_raddr__val && !to_mem_waddr__val && !to_mem_wdata__val,"inactive sidebands");
  endtask
  task automatic operands(input logic [DATA_W-1:0] a,b,input bit pred=1);
    for(integer i=0;i<4;i++) begin recv_in__msg[i]=data_word(DATA_W'(100+i),1);recv_in__val[i]=1;end
    recv_in__msg[1]=data_word(a,pred);recv_in__msg[3]=data_word(b,1);
    recv_const__msg=data_word(b,0);recv_const__val=1;
  endtask
  task automatic wait_result;
    integer elapsed;
    elapsed=0;#1;
    while(!send_out__val[0] && elapsed<LATENCY+5) begin tick();#1;elapsed++;end
    require(send_out__val[0],"bounded result latency");
  endtask
  task automatic accept_result(input logic [DATA_W-1:0] value,input bit pred,input bit constant_op=0,input bit snoop=0);
    logic [DATA_BITS-1:0] expected;
    expected=data_word(value,pred);if(wrong && samples==0) expected=expected^8;
    wait_result();
    for(integer stall=0;stall<4;stall++) begin
      require(send_out__msg[0]===expected,"independent arithmetic and held metadata");
      require(!recv_opt__rdy && !recv_in__rdy[1] && !recv_in__rdy[3] && !recv_const__rdy,"no early retirement");
      require(!send_out__val[1] && send_out__msg[1]==0,"unused result zero");tick();#1;
    end
    send_out__rdy[0]=1;#1;
    require(recv_opt__rdy && recv_in__rdy[1],"control and input0 retire together");
    require(recv_in__rdy[3]==(!constant_op && !snoop),"input1 token versus snooping contract");
    require(recv_const__rdy==constant_op,"constant token retirement");
    require(!recv_in__rdy[0] && !recv_in__rdy[2],"unselected inputs isolated");
    tick();recv_opt__val=0;send_out__rdy[0]=0;samples++;#1;
  endtask
  task automatic divider_checks;
    logic [DATA_W-1:0] a,b,value;
    bit remainder_op,constant_op,pred;
    restart();
    for(integer n=0;n<64;n++) begin
      a=randword();b=randword();pred=n[0];
      case(n%8)
        0:begin a='1;b=3;end
        1:b=0;
        2:begin a=0;b=1;end
        3:begin a=DATA_W'(1)<<(DATA_W-1);b='1;end
        4:begin a='1;b=1;end
        default:begin end
      endcase
      remainder_op=KIND!=0 && n[0];constant_op=KIND==0 && n[0];
      operands(a,b,pred);control(KIND==1 ? (remainder_op?59:48) : (remainder_op?44:(constant_op?65:26)));
      recv_in__val[1]=0;send_out__rdy[0]=1;
      repeat(LATENCY+2) begin no_transactions("missing dividend does not advance divider");tick();end
      recv_in__val[1]=1;send_out__rdy[0]=0;
      value=remainder_op ? (b==0?a:a%b) : (b==0?{DATA_W{1'b1}}:a/b);
      if(KIND==1) begin
        accept_result(0,pred,0,1);
        // END carries dummy input0 data; the result must belong to START.
        operands(~a,b,!pred);control(remainder_op?15:49);
      end
      accept_result(value,pred,constant_op,KIND==1);
      repeat(3) begin no_transactions("no duplicate output after retirement");tick();end
    end
    // Cancellation while a result is held and while a pipeline is in flight.
    for(integer how=0;how<4;how++) begin
      restart();operands(77,3);control(KIND==1?48:26);
      if(KIND==1) begin accept_result(0,1,0,1);control(49);end
      if(how[1]) wait_result();else tick();
      if(how[0]) clear=1;else reset=1;
      send_out__rdy[0]=1;no_transactions("reset/clear cancels pending transaction");tick();
      clear=0;reset=0;recv_opt__val=0;
      repeat(LATENCY+4) begin no_transactions("cancelled transaction cannot reappear");tick();end
    end
    // Vector factor counts retired controls; backpressure cannot change predicate.
    if(KIND!=1) begin
      restart();
      for(integer n=0;n<4;n++) begin
        operands(42,3);control(26,1,3,2,0,2,1);accept_result(14,n==3);
      end
    end
    if(KIND==1) begin
      restart();
      for(integer n=0;n<LATENCY;n++) begin
        operands(DATA_W'(17+5*n),3,n[0]);control(48);send_out__rdy[0]=1;#1;
        require(send_out__val[0] && recv_opt__rdy && recv_in__rdy[1] && !recv_in__rdy[3],"back-to-back START accepted");
        require(send_out__msg[0]===data_word(0,n[0]),"START acknowledgement");tick();send_out__rdy[0]=0;recv_opt__val=0;samples++;
      end
      for(integer n=0;n<LATENCY;n++) begin
        operands('1,0,1);control(n[0]?15:49);
        value=n[0] ? DATA_W'((17+5*n)%3) : DATA_W'((17+5*n)/3);
        accept_result(value,n[0],0,1);
      end
      control(49);repeat(5) begin no_transactions("END without outstanding START stalls");tick();end
      restart();
      for(integer n=0;n<LATENCY;n++) begin operands(DATA_W'(19+n),3);control(48);accept_result(0,1,0,1);end
      control(48);send_out__rdy[0]=1;
      repeat(LATENCY+3) begin no_transactions("full outstanding capacity cannot overwrite results");tick();end
      clear=1;tick();clear=0;recv_opt__val=0;no_transactions("clear cancels full queue");
    end
    restart();operands(9,2);control(127);send_out__rdy[0]=1;
    repeat(3) begin no_transactions("unsupported opcode cannot retire");tick();end
  endtask
  task automatic mac_checks;
    int operations[8]='{2,4,60,61,62,63,7,18};
    logic [15:0] a,b,c,value;
    logic [DATA_BITS-1:0] expected;
    bit pred;
    restart();
    for(integer op=0;op<8;op++) for(integer n=0;n<128;n++) begin
      a=16'(rand32());b=16'(rand32());c=16'(rand32());
      case(n%8)
        0:begin a=16'h8000;b=1;end
        1:begin a=16'h7fff;b=16'hffff;end
        2:begin a=16'h8000;b=16'h7fff;end
        3:begin a='1;b='1;end
        4:begin a=0;b=0;end
        default:begin end
      endcase
      case(op)
        0:value=a+b;1:value=a-b;2:value=16'($signed(a)<$signed(b));
        3:value=16'($signed(a)>=$signed(b));4:value=16'($signed(a)>$signed(b));
        5:value=16'($signed(a)<=$signed(b));6:value=a*b;7:value=a*b+c;
      endcase
      operands(a,b);recv_in__msg[2]=data_word(c,n[0]);pred=n[0];control(operations[op]);
      expected=data_word(value,pred);if(wrong && samples==0) expected^=8;
      for(integer stall=0;stall<3;stall++) begin
        #1;require(send_out__val[0] && send_out__msg[0]===expected,"MAC signed/modular math and stable selection");
        require(!recv_opt__rdy,"MAC control waits for output");tick();
      end
      send_out__rdy[0]=1;#1;require(recv_opt__rdy && recv_in__rdy[1] && recv_in__rdy[3] && recv_in__rdy[2] && !recv_in__rdy[0],"MAC selected input handshake");
      tick();send_out__rdy[0]=0;recv_opt__val=0;samples++;
    end
    control(2);send_out__rdy[0]=1;reset=1;no_transactions("MAC reset isolation");tick();reset=0;
    clear=1;no_transactions("MAC clear isolation");tick();clear=0;
    recv_in__val[2]=0;#1;require(!send_out__val[0] && !recv_opt__rdy,"binary MAC retains three-input predicate/token contract");
    restart();
    for(integer n=0;n<4;n++) begin
      operands(16'h8000,1);recv_in__msg[2]=data_word(9,1);control(18,1,3,2,0,2,1);
      // The original MAC ignores vector-factor metadata in its predicate.
      expected=data_word(16'h8009,1);
      repeat(5) begin
        #1;require(send_out__val[0] && send_out__msg[0]===expected && !recv_opt__rdy,"MAC retains three-input predicate under vector control and backpressure");tick();
      end
      send_out__rdy[0]=1;#1;require(recv_opt__rdy,"MAC vector replay retires");
      tick();send_out__rdy[0]=0;recv_opt__val=0;samples++;
    end
    operands(1,2);recv_in__msg[2]=data_word(3,1);control(18,1,3,2,0,2,1);
    send_out__rdy[0]=1;tick();send_out__rdy[0]=0;clear=1;tick();clear=0;#1;
    require(send_out__val[0] && result_data.predicate,"MAC resumes the original predicate contract after clear");
  endtask
  task automatic loop_checks;
    data_t d0,d1;
    bit valid_iteration;
    logic [DATA_W-1:0] base;
    ctrl_t zero_select;
    base=DATA_W>32 ? (DATA_W'(1)<<40)+3 : DATA_W'(3);
    restart();
    for(integer n=0;n<5;n++) begin
      control(83,0,1,2,3);
      for(integer i=0;i<4;i++) recv_in__val[i]=1;
      recv_in__msg[0]=data_word(0,n!=2);recv_in__msg[1]=data_word(base,1);
      recv_in__msg[2]=data_word(base+5,1);recv_in__msg[3]=data_word(2,1);
      valid_iteration=(3+2*n<8) && n!=2;
      d0=data_word(base+DATA_W'(2*n),valid_iteration);d1=data_word(DATA_W'(valid_iteration),1);
      if(wrong && n==0) d0.payload^=1;
      #1;require(send_out__val[0] && send_out__val[1] && send_out__msg[0]===d0 && send_out__msg[1]===d1,"loop index/predicate");
      send_out__rdy[n%2]=1;#1;require(!recv_opt__rdy,"one output cannot retire loop control");tick();
      repeat(4) begin
        #1;require(!send_out__val[n%2] && send_out__val[1-n%2],"accepted output is not repeated");
        require(send_out__msg[0]===d0 && send_out__msg[1]===d1,"loop state stable until both outputs accepted");
        require(!recv_opt__rdy,"partial delivery retains control");tick();
      end
      send_out__rdy[1-n%2]=1;#1;require(recv_opt__rdy,"both outputs retire loop control");
      for(integer i=0;i<4;i++) require(recv_in__rdy[i],"loop inputs retire once together");
      tick();send_out__rdy[0]=0;send_out__rdy[1]=0;recv_opt__val=0;samples++;
    end
    control(83,0,1,2,3);send_out__rdy[0]=1;tick();clear=1;
    no_transactions("clear cancels partially delivered loop");tick();clear=0;recv_opt__val=0;no_transactions("no stale loop delivery");
    control(83,0,1,2,3);#1;require(send_out__val[0] && result_data.payload==base,"clear resets loop index");
    reset=1;no_transactions("loop reset isolation");tick();reset=0;
    zero_select='0;zero_select.operation=83;recv_opt__msg=zero_select;
    recv_in__msg[0]=data_word(base,1);#1;
    require(send_out__val[0] && result_data.payload==base && !result_data.predicate,"zero selectors map to port0 without retaining old indices");
    restart();
    for(integer n=0;n<4;n++) begin
      for(integer i=0;i<4;i++) recv_in__val[i]=1;
      recv_in__msg[0]=data_word(0,1);recv_in__msg[1]=data_word(base,1);
      recv_in__msg[2]=data_word(base+100,1);recv_in__msg[3]=data_word(2,1);
      control(83,0,1,2,3,2,1);send_out__rdy[0]=1;send_out__rdy[1]=1;#1;
      require(recv_opt__rdy && result_data.predicate==(n==3) && send_out__msg[1][2]==(n==3),"loop vector factor follows retired controls");
      tick();samples++;
    end
  endtask
  string vectors;
  initial begin
    clk=0;wrong=$test$plusargs("EXPECT_FAILURE");clear_inputs();
    if($value$plusargs("VECTORS=%s",vectors)) replay(vectors);
    else begin
      if(KIND<3) divider_checks();else if(KIND==3) mac_checks();else loop_checks();
      $display("ARITHMETIC_BOUNDARIES_NATIVE_PASS kind=%0d width=%0d latency=%0d samples=%0d checks=%0d",KIND,DATA_W,LATENCY,samples,checks);
    end
    $finish;
  end
endmodule
