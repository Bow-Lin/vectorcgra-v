`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_vector_arithmetic #(
  `CGRA_PROFILE_PARAMETERS,
  parameter integer LANES=4, KIND=0,
  parameter bit LEGACY_PYTHON=0
);
  `include "cgra_profile.svh"
  `include "vector_reduce_ports.svh"
`ifdef VECTOR_ARITHMETIC_POST_SYNTH
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
  vector_arithmetic_netlist dut (.recv_in__msg(flat_inputs),.recv_in__val(flat_valid),.recv_in__rdy(flat_ready),
    .send_out__msg(flat_outputs),.send_out__val(flat_out_valid),.send_out__rdy(flat_out_ready),.*);
`else
  if (KIND==0) begin : add
    tile_vector_adder_combo #(`CGRA_PROFILE_BIND,.LANES(LANES),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end else begin : mul
    tile_vector_mul_combo #(`CGRA_PROFILE_BIND,.LANES(LANES),.LEGACY_PYTHON(LEGACY_PYTHON)) dut (.*);
  end
`endif
  localparam integer IN_BITS=$bits({clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}),OUT_BITS=$bits({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val});
  localparam integer LANE_W=DATA_W/LANES;
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
    checks++;if (!ok) $fatal(1,"VECTOR_ARITHMETIC_CHECK %s sample=%0d checks=%0d",label,samples,checks);
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
      if (scan!=2) $fatal(1,"VECTOR_ARITHMETIC_VECTOR_FORMAT");
      {clear,reset,ctrl_addr_inport,from_mem_rdata__msg,from_mem_rdata__val,recv_const__msg,recv_const__val,recv_from_ctrl_mem__msg,recv_from_ctrl_mem__val,recv_in__msg[0],recv_in__msg[1],recv_in__msg[2],recv_in__msg[3],recv_in__val[0],recv_in__val[1],recv_in__val[2],recv_in__val[3],recv_opt__msg,recv_opt__val,send_out__rdy[0],send_out__rdy[1],send_to_ctrl_mem__rdy,to_mem_raddr__rdy,to_mem_waddr__rdy,to_mem_wdata__rdy}=input_word;#1;
      if (wrong && samples==4) expected=expected^1;
      if ({from_mem_rdata__rdy,recv_const__rdy,recv_from_ctrl_mem__rdy,recv_in__rdy[0],recv_in__rdy[1],recv_in__rdy[2],recv_in__rdy[3],recv_opt__rdy,send_out__msg[0],send_out__msg[1],send_out__val[0],send_out__val[1],send_to_ctrl_mem__msg,send_to_ctrl_mem__val,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,to_mem_wdata__msg,to_mem_wdata__val}!==expected)
        $fatal(1,"VECTOR_ARITHMETIC_REPLAY_MISMATCH sample=%0d",samples);
      samples++;tick();
    end
    $fclose(fd);require(samples==320,"replay coverage");
    $display("VECTOR_ARITHMETIC_REPLAY_PASS samples=%0d output_bits=%0d",samples,OUT_BITS);
  endtask
  task automatic control(input integer op,input bit valid=1);
    ctrl_t c;
    c='0;c.operation=7'(op);
    c.vector_factor_power=3'(rand32());c.is_last_ctrl=1'(rand32());
    for (integer i=0;i<4;i++) c.fu_in[i]=3'(i+1);
    recv_opt__msg=c;recv_opt__val=valid;
  endtask
  function automatic logic [DATA_W-1:0] arithmetic(input integer op,input logic [DATA_W-1:0] a,b,k);
    logic [127:0] total,part,x,y,mask;
    total=0;mask=(128'd1<<LANE_W)-1;
    case(op)
      71:total=128'(a)+128'(b);
      72:total=128'(a)+128'(k);
      73:total=128'(a)-128'(b);
      74:total=128'(a)-128'(k);
      51,52,53,54:for (integer lane=0;lane<LANES;lane++) begin
        x=(128'(a)>>(lane*LANE_W))&mask;
        y=(128'((op==52 || op==54)?k:b)>>(lane*LANE_W))&mask;
        part=(op==53 || op==54)?x-y:x+y;
        total=total|((part&mask)<<(lane*LANE_W));
      end
      // Python sums full products at lane offsets: carries can overlap lanes.
      55:for (integer lane=0;lane<4;lane++) begin
        x=(128'(a)>>(lane*LANE_W))&mask;y=(128'(b)>>(lane*LANE_W))&mask;
        total=total+((x*y)<<(lane*LANE_W));
      end
      75:begin
        mask=(128'd1<<(2*LANE_W))-1;
        total=(128'(a)&mask)*(128'(b)&mask);
      end
      default:total=0;
    endcase
    return DATA_W'(total);
  endfunction
  task automatic native_checks;
    integer op;
    logic [DATA_W-1:0] a,b,k,expected;
    logic [DATA_BITS-1:0] held;
    bit constant_op,active,pred,ready;
    integer opcodes[0:9]='{51,52,53,54,71,72,73,74,55,75};
    clear_inputs();reset=1;tick();reset=0;
    for (integer index=0;index<(KIND==0?8:2);index++) begin
      op=opcodes[KIND==0?index:index+8];constant_op=(op==52 || op==54 || op==72 || op==74);
      for (integer n=0;n<128;n++) begin
        a=randword();b=randword();k=randword();
        case(n%16)
          0:begin a='1;b=1;k=1;end
          1:begin a=0;b=1;k=1;end
          2:begin a=1;b='1;k='1;end
          3:begin a='1;b='1;k='1;end
          4:begin a=DATA_W'(1)<<(DATA_W-1);b=1;k=1;end
          default:begin end
        endcase
        control(op,n%11!=0);
        recv_in__msg[0]=data_word(a,1'(n));recv_in__msg[1]=data_word(b,1'(n>>1));
        recv_const__msg=data_word(k,1'(n>>2));
        recv_in__val[0]=1'(n);recv_in__val[1]=1'(n>>1);recv_const__val=1'(n>>2);
        recv_in__val[2]=1;recv_in__val[3]=1;recv_in__msg[2]='1;recv_in__msg[3]='1;
        send_out__rdy[0]=(n%3!=0);send_out__rdy[1]=1'(n);
        // Stateless source reset/clear semantics are retained by this arithmetic change.
        reset=(n%37==0);clear=(n%31==0);
        #2;
        expected=recv_opt__val?arithmetic(op,a,b,k):DATA_W'(0);
        if (wrong && n==3) expected=expected^1;
        active=recv_opt__val && recv_in__val[0] && (constant_op?recv_const__val:recv_in__val[1]);
        pred=1'(n) && (constant_op || 1'(n>>1));ready=active && send_out__rdy[0];
        require(result_data.payload===expected,"independent modular arithmetic");
        require(result_data.predicate===pred,"predicate contract");
        require(send_out__val[0]===active,"atomic valid");
        require(recv_in__rdy[0]===ready && recv_in__rdy[1]===(ready && !constant_op),"operand readiness");
        require(recv_const__rdy===(ready && constant_op),"constant readiness");
        require(recv_opt__rdy===(KIND==0?ready:send_out__rdy[0]),"source control ready contract");
        require(!recv_in__rdy[2] && !recv_in__rdy[3] && !send_out__val[1] && send_out__msg[1]=='0,"unused ports");
        require(!result_data.bypass && !result_data.delay,"metadata");
        require({send_to_ctrl_mem__val,send_to_ctrl_mem__msg,recv_from_ctrl_mem__rdy,
          from_mem_rdata__rdy,to_mem_raddr__msg,to_mem_raddr__val,to_mem_waddr__msg,to_mem_waddr__val,
          to_mem_wdata__msg,to_mem_wdata__val}==='0,"inactive interfaces");
        if (active && !send_out__rdy[0]) begin
          held=send_out__msg[0];repeat(3) begin tick();#1;require(send_out__val[0] && send_out__msg[0]===held,"held result");end
        end
        samples++;tick();
      end
    end
    $display("VECTOR_ARITHMETIC_NATIVE_PASS kind=%0d samples=%0d checks=%0d",KIND,samples,checks);
  endtask
  task automatic carry_defect;
    clear_inputs();control(72);recv_in__val[0]=1;recv_const__val=1;
    recv_in__msg[0]=data_word('1,1);recv_const__msg=data_word(1,1);send_out__rdy[0]=1;
    #2;require(send_out__val[0] && result_data.payload==0,"DEFECT_COMBINED_CONSTANT_CARRY");
    $display("VECTOR_ARITHMETIC_CARRY_FIXED");
  endtask
  task automatic high_lane_defect;
    clear_inputs();control(55);recv_in__val[0]=1;recv_in__val[1]=1;
    recv_in__msg[0]=data_word(DATA_W'(1)<<((LANES-1)*LANE_W),1);
    recv_in__msg[1]=recv_in__msg[0];send_out__rdy[0]=1;
    #2;require(result_data.payload==DATA_W'(1)<<((LANES-1)*LANE_W),"DEFECT_OMITTED_HIGH_LANES");
  endtask
  string path;
  initial begin
    clear_inputs();wrong=$test$plusargs("EXPECT_FAILURE");
    if ($value$plusargs("VECTORS=%s",path)) replay(path);
    else if ($test$plusargs("CARRY_DEFECT")) carry_defect();
    else if ($test$plusargs("HIGH_LANE_DEFECT")) high_lane_defect();
    else native_checks();
    $finish;
  end
endmodule
