`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_vector_reduce #(
  `CGRA_PROFILE_PARAMETERS,
  parameter integer LANES=4,
  parameter bit LEGACY_PYTHON=0
);
  `include "cgra_profile.svh"
  `include "vector_reduce_ports.svh"
`ifdef VECTOR_REDUCE_POST_SYNTH
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
  vector_reduce_netlist dut (.recv_in__msg(flat_inputs),.recv_in__val(flat_valid),.recv_in__rdy(flat_ready),
    .send_out__msg(flat_outputs),.send_out__val(flat_out_valid),.send_out__rdy(flat_out_ready),.*);
`else
  tile_vector_all_reduce #(`CGRA_PROFILE_BIND,.LANES(LANES),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
`endif
  localparam integer IN_BITS=$bits({clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}),OUT_BITS=$bits({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val});
  localparam integer LANE_W=DATA_W/LANES;
  integer samples /* verilator public_flat_rw */ =0;
  integer checks /* verilator public_flat_rw */ =0;
  integer requests /* verilator public_flat_rw */ =0;
  integer results /* verilator public_flat_rw */ =0;
  integer controls /* verilator public_flat_rw */ =0;
  logic [31:0] rng=32'h33ac0;
  bit wrong;
  payload_t request;
  assign request=send_to_ctrl_mem__msg;
  data_t result_data;
  assign result_data=send_out__msg[0];
  always @(posedge clk) if (!reset && !clear) begin
    if (send_to_ctrl_mem__val && send_to_ctrl_mem__rdy) requests++;
    if (send_out__val[0] && send_out__rdy[0]) results++;
    if (recv_opt__val && recv_opt__rdy) controls++;
  end
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
  function automatic logic [DATA_W-1:0] reduce_math(input logic [DATA_W-1:0] value,input bit multiply);
    logic [127:0] total,part,mask;
    total=multiply?128'd1:128'd0;mask=(128'd1<<LANE_W)-1;
    for (integer i=0;i<LANES;i++) begin
      part=(128'(value)>>(i*LANE_W))&mask;
      total=multiply?total*part:total+part;
    end
    return DATA_W'(total);
  endfunction
  task automatic tick;
    #1;clk=1;#1;clk=0;#1;
  endtask
  task automatic require(input bit ok,input string label);
    checks++;if (!ok) $fatal(1,"VECTOR_REDUCE_CHECK %s sample=%0d checks=%0d",label,samples,checks);
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
      if (scan!=2) $fatal(1,"VECTOR_REDUCE_VECTOR_FORMAT");
      {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}=input_word;#1;
      if (wrong && samples==4) expected=expected^1;
      if ({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val}!==expected)
        $fatal(1,"VECTOR_REDUCE_REPLAY_MISMATCH sample=%0d",samples);
      samples++;tick();
    end
    $fclose(fd);require(samples==360,"replay coverage");
    $display("VECTOR_REDUCE_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic control(input integer op,input bit valid=1);
    ctrl_t c;
    c='0;c.operation=7'(op);
    c.vector_factor_power=3'(rand32());c.is_last_ctrl=1'(rand32());
    for (integer i=0;i<4;i++) c.fu_in[i]=3'(i+1);
    recv_opt__msg=c;recv_opt__val=valid;
  endtask
  task automatic response(input logic [DATA_W-1:0] value,input bit pred,input bit multiply);
    payload_t p;p='0;p.cmd=multiply?6'd21:6'd20;p.data=data_word(value,pred);
    recv_from_ctrl_mem__msg=p;recv_from_ctrl_mem__val=1;
  endtask
  task automatic auxiliary_zero;
    require(!recv_const__rdy && !send_out__val[1] && send_out__msg[1]=='0,"unused output and const deterministic");
    require(!recv_in__rdy[2] && !recv_in__rdy[3],"unused operand ready");
    require({from_mem_rdata__rdy,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,
      to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val}==='0,"inactive memory ports");
    require(result_data.bypass==0 && result_data.delay==0,"output metadata");
  endtask
  task automatic one_operation(input integer op,input integer variation);
    bit multiply,base,global_op,pred0,pred1,predr;
    logic [DATA_W-1:0] vector_value,base_value,reduced,remote_value,expected;
    logic [127:0] wide_result;
    logic [PAYLOAD_BITS-1:0] held_request;
    integer old_requests,old_results,old_controls;
    multiply=(op==57 || op==69 || op==77 || op==79);
    base=(op==68 || op==69 || op==78 || op==79);global_op=(op>=76);
    vector_value=randword();base_value=randword();pred0=1'(variation);pred1=1'(variation>>1);predr=1'(variation>>2);
    if (variation==0) vector_value='0;
    if (variation==1) vector_value='1;
    if (variation==2) begin
      vector_value='0;for (integer i=0;i<LANES;i++) vector_value[i*LANE_W +: LANE_W]=LANE_W'(i+1);
    end
    reduced=reduce_math(vector_value,multiply);
    remote_value=multiply ? DATA_W'(128'(reduced)*128'(randword())) : DATA_W'(128'(reduced)+128'(randword()));
    wide_result=128'(global_op?remote_value:reduced);
    if (base) wide_result=multiply ? wide_result*128'(base_value) : wide_result+128'(base_value);
    expected=DATA_W'(wide_result);
    if (wrong && op==56 && variation==0) expected=expected^1;
    old_requests=requests;old_results=results;old_controls=controls;
    clear_inputs();control(op);recv_in__msg[0]=data_word(vector_value,pred0);recv_in__msg[1]=data_word(base_value,pred1);
    recv_in__val[0]=0;recv_in__val[1]=base;
    send_out__rdy[0]=1;send_to_ctrl_mem__rdy=1;#1;
    require(!recv_opt__rdy && !send_out__val[0] && !send_to_ctrl_mem__val,"missing vector cannot retire or issue");
    require(!recv_in__rdy[1],"missing vector cannot consume base");
    recv_in__val[0]=1;
    if (base) begin
      recv_in__val[1]=0;#1;
      require(!recv_opt__rdy && !recv_in__rdy[0] && !send_out__val[0] && !send_to_ctrl_mem__val,"atomic base operand");
      recv_in__val[1]=1;
    end
    if (!global_op) begin
      send_out__rdy[0]=0;#1;
      repeat(3) begin
        require(send_out__val[0] && send_out__msg[0]===data_word(expected,pred0 && (!base || pred1)),"REDUCE_LOCAL_RESULT");
        require(!recv_opt__rdy && !recv_in__rdy[0] && !recv_in__rdy[1],"local stall holds all consumers");
        auxiliary_zero();tick();
      end
      send_out__rdy[0]=1;#1;
      require(recv_opt__rdy && recv_in__rdy[0] && recv_in__rdy[1]==base,"local atomic accept");tick();
      require(requests==old_requests && results==old_results+1 && controls==old_controls+1,"one local result/control");
    end else begin
      send_to_ctrl_mem__rdy=0;#1;held_request=send_to_ctrl_mem__msg;
      repeat(3) begin
        require(send_to_ctrl_mem__val && send_to_ctrl_mem__msg===held_request,"held global request");
        require(request.cmd==(multiply?19:18) && request.data===data_word(reduced,pred0) &&
          request.ctrl===recv_opt__msg && request.data_addr==0 && request.ctrl_addr==0,"global command/reduction/full control");
        require(!recv_opt__rdy && !recv_in__rdy[0] && !recv_in__rdy[1] && !recv_from_ctrl_mem__rdy,"request stall cannot retire");
        auxiliary_zero();tick();
      end
      send_to_ctrl_mem__rdy=1;#1;
      require(recv_in__rdy[0] && recv_in__rdy[1]==base && !recv_opt__rdy,"request consumes operands once");tick();
      require(requests==old_requests+1,"one accepted request");
      // Accepted operands may change immediately. Result must use saved base.
      recv_in__msg[0]='1;recv_in__msg[1]='0;recv_in__val[0]=0;recv_in__val[1]=0;
      repeat(4) begin
        #1;require(!send_to_ctrl_mem__val && !recv_opt__rdy && !send_out__val[0] &&
          !recv_in__rdy[0] && !recv_in__rdy[1],"pending request cannot repeat/retire");tick();
      end
      send_out__rdy[0]=0;response(remote_value,predr,multiply);#1;
      repeat(5) begin
        require(send_out__val[0] && send_out__msg[0]===data_word(expected,predr && (!base || pred1)),"REDUCE_GLOBAL_RESULT and saved base");
        require(!recv_from_ctrl_mem__rdy && !recv_opt__rdy && !send_to_ctrl_mem__val,"response held until downstream accepts");
        auxiliary_zero();tick();
      end
      send_out__rdy[0]=1;#1;require(recv_from_ctrl_mem__rdy && recv_opt__rdy,"response/control retire together");tick();
      require(requests==old_requests+1 && results==old_results+1 && controls==old_controls+1,"one request/result/control");
    end
    clear_inputs();#1;require(!send_to_ctrl_mem__val && !send_out__val[0] && !recv_opt__rdy,"no ghost work after completion");
    samples++;
  endtask
  task automatic clear_pending;
    integer old_results;
    clear_inputs();control(78);recv_in__val[0]=1;recv_in__val[1]=1;
    recv_in__msg[0]=data_word(DATA_W'(1),1);recv_in__msg[1]=data_word(DATA_W'(7),1);
    send_to_ctrl_mem__rdy=1;tick();old_results=results;
    clear=1;response(DATA_W'(123),1,0);send_out__rdy[0]=1;#1;
    require(!send_out__val[0] && !recv_opt__rdy && !recv_from_ctrl_mem__rdy,"clear cancels without accepting response");tick();
    clear=0;recv_from_ctrl_mem__val=0;control(79);
    repeat(3) begin
      #1;require(!send_to_ctrl_mem__val && !recv_opt__rdy && recv_from_ctrl_mem__rdy,"cancelled transaction waits to drain");tick();
    end
    response(DATA_W'(123),1,0);#1;
    require(!send_out__val[0] && !recv_opt__rdy && recv_from_ctrl_mem__rdy,"old response is discarded");tick();
    recv_from_ctrl_mem__val=0;#1;
    require(send_to_ctrl_mem__val && results==old_results,"new reduction unblocks only after drain");
    reset=1;#1;require(!send_to_ctrl_mem__val && !send_out__val[0] && !recv_opt__rdy,"reset gates transactions");tick();
    clear_inputs();
  endtask
  task automatic native_checks;
    integer ops[8]='{56,57,68,69,76,77,78,79};
    reset=1;tick();clear_inputs();
    for (integer i=0;i<8;i++) begin
      control(ops[i],0);recv_in__val[0]=1;recv_in__val[1]=1;send_to_ctrl_mem__rdy=1;send_out__rdy[0]=1;#1;
      require(!send_to_ctrl_mem__val && !send_out__val[0] && !recv_opt__rdy && !recv_in__rdy[0] && !recv_in__rdy[1],"invalid control has no effects");tick();
    end
    for (integer i=0;i<8;i++) for (integer v=0;v<24;v++) one_operation(ops[i],v);
    clear_pending();one_operation(79,7);
    control(127);recv_in__val[0]=1;recv_in__val[1]=1;send_out__rdy[0]=1;send_to_ctrl_mem__rdy=1;#1;
    require(!send_to_ctrl_mem__val && !send_out__val[0] && !recv_opt__rdy,"unsupported opcode inert");auxiliary_zero();
    require(samples==193,"native operation coverage");
    $display("VECTOR_REDUCE_NATIVE_PASS operations=%0d checks=%0d requests=%0d results=%0d controls=%0d",samples,checks,requests,results,controls);
  endtask
  task automatic defect(input string name);
    logic [DATA_W-1:0] v;
    reset=1;tick();clear_inputs();v='0;
    for (integer i=0;i<LANES;i++) v[i*LANE_W +: LANE_W]=LANE_W'(i+2);
    recv_in__msg[0]=data_word(v,1);recv_in__msg[1]=data_word(DATA_W'(3),1);
    recv_in__val[0]=1;recv_in__val[1]=1;send_to_ctrl_mem__rdy=1;
    if (name=="mul_request") begin
      control(77);#1;require(request.data.payload==reduce_math(v,1),"DEFECT_MUL_REQUEST");
    end else if (name=="invalid_control") begin
      control(78,0);#1;require(!send_to_ctrl_mem__val,"DEFECT_INVALID_CONTROL");
    end else if (name=="duplicate") begin
      control(78);tick();#1;require(!send_to_ctrl_mem__val,"DEFECT_DUPLICATE");
    end else if (name=="base_ready") begin
      control(78);#1;require(recv_in__rdy[1],"DEFECT_BASE_READY");
    end else begin
      control(76);tick();send_to_ctrl_mem__rdy=0;recv_in__val[0]=0;recv_in__val[1]=0;
      if (name=="early_retire") begin
        send_out__rdy[0]=1;#1;require(!recv_opt__rdy,"DEFECT_EARLY_RETIRE");
      end else begin
        response(DATA_W'(91),1,0);#1;
        if (name=="predicate") require(result_data.predicate,"DEFECT_PREDICATE");
        else if (name=="response_stall") require(!recv_from_ctrl_mem__rdy,"DEFECT_RESPONSE_STALL");
        else if (name=="clear") begin
          clear=1;send_out__rdy[0]=1;#1;require(!send_out__val[0] && !recv_opt__rdy,"DEFECT_CLEAR");
        end else $fatal(1,"UNKNOWN_DEFECT");
      end
    end
    $display("VECTOR_REDUCE_DEFECT_FIXED %s",name);
  endtask
  string path,name;
  initial begin
    clear_inputs();wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($value$plusargs("DEFECT=%s",name)) defect(name);
    else native_checks();
    $finish;
  end
endmodule
