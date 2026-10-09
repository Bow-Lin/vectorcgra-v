`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_phase3_float #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int FP_EXP_W=8, FP_SIG_W=23,
  parameter bit MULTIPLY=0
);
  `include "cgra_profile.svh"
  logic [0:0] clear ;
  logic [0:0] clk ;
  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ;
  logic [0:0] reset ;
  logic [DATA_BITS-1:0] from_mem_rdata__msg ;
  logic [0:0] from_mem_rdata__rdy ;
  logic [0:0] gold_from_mem_rdata__rdy ;
  logic [0:0] from_mem_rdata__val ;
  logic [DATA_BITS-1:0] recv_const__msg ;
  logic [0:0] recv_const__rdy ;
  logic [0:0] gold_recv_const__rdy ;
  logic [0:0] recv_const__val ;
  logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg ;
  logic [0:0] recv_from_ctrl_mem__rdy ;
  logic [0:0] gold_recv_from_ctrl_mem__rdy ;
  logic [0:0] recv_from_ctrl_mem__val ;
  logic [DATA_BITS-1:0] recv_in__msg [0:3];
  logic [0:0] recv_in__rdy [0:3];
  logic [0:0] gold_recv_in__rdy [0:3];
  logic [0:0] recv_in__val [0:3];
  logic [CTRL_BITS-1:0] recv_opt__msg ;
  logic [0:0] recv_opt__rdy ;
  logic [0:0] gold_recv_opt__rdy ;
  logic [0:0] recv_opt__val ;
  logic [DATA_BITS-1:0] send_out__msg [0:1];
  logic [DATA_BITS-1:0] gold_send_out__msg [0:1];
  logic [0:0] send_out__rdy [0:1];
  logic [0:0] send_out__val [0:1];
  logic [0:0] gold_send_out__val [0:1];
  logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg ;
  logic [PAYLOAD_BITS-1:0] gold_send_to_ctrl_mem__msg ;
  logic [0:0] send_to_ctrl_mem__rdy ;
  logic [0:0] send_to_ctrl_mem__val ;
  logic [0:0] gold_send_to_ctrl_mem__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_raddr__msg ;
  logic [0:0] to_mem_raddr__rdy ;
  logic [0:0] to_mem_raddr__val ;
  logic [0:0] gold_to_mem_raddr__val ;
  logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg ;
  logic [GLOBAL_ADDR_W-1:0] gold_to_mem_waddr__msg ;
  logic [0:0] to_mem_waddr__rdy ;
  logic [0:0] to_mem_waddr__val ;
  logic [0:0] gold_to_mem_waddr__val ;
  logic [DATA_BITS-1:0] to_mem_wdata__msg ;
  logic [DATA_BITS-1:0] gold_to_mem_wdata__msg ;
  logic [0:0] to_mem_wdata__rdy ;
  logic [0:0] to_mem_wdata__val ;
  logic [0:0] gold_to_mem_wdata__val ;
  `FP_DUT #(`CGRA_PROFILE_BIND,.FP_EXP_W(FP_EXP_W),.FP_SIG_W(FP_SIG_W)) dut (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .reset(reset),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_out__msg(send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(send_out__val),
    .send_to_ctrl_mem__msg(send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(send_to_ctrl_mem__val),
    .to_mem_raddr__msg(to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(to_mem_raddr__val),
    .to_mem_waddr__msg(to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(to_mem_waddr__val),
    .to_mem_wdata__msg(to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(to_mem_wdata__val)
  );
  `FP_GOLD gold (
    .clear(clear),
    .clk(clk),
    .ctrl_addr_inport(ctrl_addr_inport),
    .reset(reset),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(gold_from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_const__msg(recv_const__msg),
    .recv_const__rdy(gold_recv_const__rdy),
    .recv_const__val(recv_const__val),
    .recv_from_ctrl_mem__msg(recv_from_ctrl_mem__msg),
    .recv_from_ctrl_mem__rdy(gold_recv_from_ctrl_mem__rdy),
    .recv_from_ctrl_mem__val(recv_from_ctrl_mem__val),
    .recv_in__msg(recv_in__msg),
    .recv_in__rdy(gold_recv_in__rdy),
    .recv_in__val(recv_in__val),
    .recv_opt__msg(recv_opt__msg),
    .recv_opt__rdy(gold_recv_opt__rdy),
    .recv_opt__val(recv_opt__val),
    .send_out__msg(gold_send_out__msg),
    .send_out__rdy(send_out__rdy),
    .send_out__val(gold_send_out__val),
    .send_to_ctrl_mem__msg(gold_send_to_ctrl_mem__msg),
    .send_to_ctrl_mem__rdy(send_to_ctrl_mem__rdy),
    .send_to_ctrl_mem__val(gold_send_to_ctrl_mem__val),
    .to_mem_raddr__msg(gold_to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(gold_to_mem_raddr__val),
    .to_mem_waddr__msg(gold_to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(gold_to_mem_waddr__val),
    .to_mem_wdata__msg(gold_to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(gold_to_mem_wdata__val)
  );
  logic [31:0] random_state=32'hc03e2026;
  int samples=0, independent_checks=0;
  ctrl_t control;
  data_t operand, observed;
  function automatic logic [31:0] random_word();
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return random_state;
  endfunction
  // Exact finite integer/2 encoding, independent of either arithmetic circuit.
  // HardFloat exponent bits=FP_EXP_W+1, fraction bits=FP_SIG_W-1 in ac96.
  function automatic logic [DATA_W-1:0] half_integer(input int signed twice);
    logic [63:0] magnitude, fraction, exponent;
    int high_bit;
    if (twice==0) return '0;
    magnitude = twice<0 ? -64'(twice) : 64'(twice);
    high_bit=0;
    for(int i=0;i<32;i++) if(magnitude>>i) high_bit=i;
    exponent=(1<<FP_EXP_W)-1+high_bit-1;
    fraction=(magnitude-(64'd1<<high_bit))<<(FP_SIG_W-1-high_bit);
    return DATA_W'((64'(twice<0)<<(DATA_W-1)) | (exponent<<(FP_SIG_W-1)) | fraction);
  endfunction
  task automatic compare;
    if (from_mem_rdata__rdy !== gold_from_mem_rdata__rdy) $fatal(1,"FP mismatch cycle=%0d from_mem_rdata__rdy", samples);
    if (recv_const__rdy !== gold_recv_const__rdy) $fatal(1,"FP mismatch cycle=%0d recv_const__rdy", samples);
    if (recv_from_ctrl_mem__rdy !== gold_recv_from_ctrl_mem__rdy) $fatal(1,"FP mismatch cycle=%0d recv_from_ctrl_mem__rdy", samples);
    for (int i=0; i<=3; i++) if (recv_in__rdy[i] !== gold_recv_in__rdy[i]) $fatal(1,"FP mismatch cycle=%0d recv_in__rdy[%0d]", samples, i);
    if (recv_opt__rdy !== gold_recv_opt__rdy) $fatal(1,"FP mismatch cycle=%0d recv_opt__rdy", samples);
    for (int i=0; i<=1; i++) if (send_out__msg[i] !== gold_send_out__msg[i]) $fatal(1,"FP mismatch cycle=%0d send_out__msg[%0d]", samples, i);
    for (int i=0; i<=1; i++) if (send_out__val[i] !== gold_send_out__val[i]) $fatal(1,"FP mismatch cycle=%0d send_out__val[%0d]", samples, i);
    if (send_to_ctrl_mem__msg !== gold_send_to_ctrl_mem__msg) $fatal(1,"FP mismatch cycle=%0d send_to_ctrl_mem__msg", samples);
    if (send_to_ctrl_mem__val !== gold_send_to_ctrl_mem__val) $fatal(1,"FP mismatch cycle=%0d send_to_ctrl_mem__val", samples);
    if (to_mem_raddr__msg !== gold_to_mem_raddr__msg) $fatal(1,"FP mismatch cycle=%0d to_mem_raddr__msg", samples);
    if (to_mem_raddr__val !== gold_to_mem_raddr__val) $fatal(1,"FP mismatch cycle=%0d to_mem_raddr__val", samples);
    if (to_mem_waddr__msg !== gold_to_mem_waddr__msg) $fatal(1,"FP mismatch cycle=%0d to_mem_waddr__msg", samples);
    if (to_mem_waddr__val !== gold_to_mem_waddr__val) $fatal(1,"FP mismatch cycle=%0d to_mem_waddr__val", samples);
    if (to_mem_wdata__msg !== gold_to_mem_wdata__msg) $fatal(1,"FP mismatch cycle=%0d to_mem_wdata__msg", samples);
    if (to_mem_wdata__val !== gold_to_mem_wdata__val) $fatal(1,"FP mismatch cycle=%0d to_mem_wdata__val", samples);
    samples++;
  endtask
  task automatic tick;
    #1; compare(); #4; clk=1; #5; clk=0;
  endtask
  task automatic random_inputs;
    clear = random_word();
    ctrl_addr_inport = random_word();
    reset = random_word();
    from_mem_rdata__msg = random_word();
    from_mem_rdata__val = random_word();
    recv_const__msg = random_word();
    recv_const__val = random_word();
    recv_from_ctrl_mem__msg = random_word();
    recv_from_ctrl_mem__val = random_word();
    for (int i=0; i<=3; i++) recv_in__msg[i] = random_word();
    for (int i=0; i<=3; i++) recv_in__val[i] = random_word();
    recv_opt__msg = random_word();
    recv_opt__val = random_word();
    for (int i=0; i<=1; i++) send_out__rdy[i] = random_word();
    send_to_ctrl_mem__rdy = random_word();
    to_mem_raddr__rdy = random_word();
    to_mem_waddr__rdy = random_word();
    to_mem_wdata__rdy = random_word();
    control=recv_opt__msg;
    control.operation=7'(37+(random_word()%8));
    control.fu_in[0]=3'(random_word());
    control.fu_in[1]=3'(random_word());
    recv_opt__msg=control;
  endtask
  initial begin
    clk=0;
    random_inputs(); reset=1; recv_opt__val=0; tick(); tick(); reset=0;
    for(int n=0;n<160;n++) begin
      int op, a_value, b_value, twice_result;
      logic [DATA_W-1:0] expected_bits;
      random_inputs(); reset=(n==80); clear=(n%11==0);
      a_value=(n%11)-5; b_value=((n/3)%9)-4;
      op=MULTIPLY ? 41+(n%2) : 37+(n%4);
      control='0; control.operation=7'(op); control.fu_in[0]=1; control.fu_in[1]=2;
      control.vector_factor_power=3'(n); control.is_last_ctrl=n%2;
      recv_opt__msg=control; recv_opt__val=1;
      operand='0; operand.payload=half_integer(2*a_value); operand.predicate=n%3!=0;
      recv_in__msg[0]=operand; recv_in__val[0]=1;
      operand.payload=half_integer(2*b_value); operand.predicate=n%5!=0;
      recv_in__msg[1]=operand; recv_in__val[1]=1;
      operand.payload=half_integer(6); operand.predicate=0;
      recv_const__msg=operand; recv_const__val=(op==42) ? 0 : 1;
      send_out__rdy[0]=(n%4!=0);
      case(op)
        37: twice_result=2*(a_value+b_value);
        38: twice_result=2*(a_value-b_value);
        39: twice_result=2*(a_value+3);
        40: twice_result=2*a_value+1; // Original FLOATING_ONE encodes 0.5 for the actual IP format.
        41: twice_result=2*a_value*b_value;
        42: twice_result=2*a_value*3;
        default: twice_result=0;
      endcase
      expected_bits=half_integer(twice_result);
      if(op==41 && twice_result==0 && ((a_value<0) != (b_value<0))) expected_bits[DATA_W-1]=1;
      if($test$plusargs("EXPECT_FAILURE") && n==0) expected_bits^=1;
      #1; compare(); observed=send_out__msg[0];
      if(observed.payload!==expected_bits) $fatal(1,"FP arithmetic op=%0d a=%0d b=%0d got=%h expected=%h",op,a_value,b_value,observed.payload,expected_bits);
      if(send_out__val[0] !== ((op==40) ? send_out__rdy[0] : 1'b1)) $fatal(1,"FP val/backpressure semantics");
      if(recv_opt__rdy !== send_out__rdy[0]) $fatal(1,"FP ctrl ready semantics");
      if(observed.bypass || observed.delay) $fatal(1,"FP metadata must remain zero");
      if(observed.predicate !== ((n%3!=0) & ((op==37 || op==38 || op==41) ? n%5!=0 : 1'b1))) $fatal(1,"FP predicate semantics");
      independent_checks++;
      #4; clk=1; #5; clk=0;
    end
    for(int n=0;n<8;n++) begin
      logic [DATA_W-1:0] infinity, sign_mask, normal_min, quiet_nan, a_bits, b_bits, expected_bits;
      bit expect_nan;
      infinity=DATA_W'(((64'd1<<(FP_EXP_W+1))-1)<<(FP_SIG_W-1));
      sign_mask=DATA_W'(64'd1<<(DATA_W-1));
      normal_min=DATA_W'(64'd1<<(FP_SIG_W-1));
      quiet_nan=infinity | DATA_W'(64'd1<<(FP_SIG_W-2));
      a_bits=0; b_bits=0; expected_bits=0; expect_nan=0;
      case(n)
        0: begin a_bits=infinity; b_bits=half_integer(2); expected_bits=infinity; end
        1: begin a_bits=infinity|sign_mask; b_bits=half_integer(2); expected_bits=infinity|sign_mask; end
        2: begin a_bits=infinity; b_bits=infinity|sign_mask; expect_nan=!MULTIPLY; expected_bits=infinity|sign_mask; end
        3: begin a_bits=quiet_nan; b_bits=half_integer(2); expect_nan=1; end
        4: begin a_bits=sign_mask; b_bits=sign_mask; expected_bits=MULTIPLY ? '0 : sign_mask; end
        5: begin a_bits=1; b_bits=1; expected_bits=MULTIPLY ? 0 : 2; end
        6: begin a_bits=normal_min; b_bits=normal_min; expected_bits=MULTIPLY ? '0 : normal_min<<1; end
        7: begin a_bits=sign_mask; b_bits=half_integer(4); expected_bits=MULTIPLY ? sign_mask : half_integer(4); end
      endcase
      control='0; control.operation=MULTIPLY ? 41 : 37; control.fu_in[0]=1; control.fu_in[1]=2;
      recv_opt__msg=control; recv_opt__val=1; reset=0; clear=0;
      operand='0; operand.payload=a_bits; operand.predicate=1; recv_in__msg[0]=operand;
      operand.payload=b_bits; recv_in__msg[1]=operand;
      recv_in__val[0]=1; recv_in__val[1]=1; send_out__rdy[0]=n%2;
      #1; compare(); observed=send_out__msg[0];
      if(expect_nan) begin
        if((observed.payload & infinity)!==infinity || (observed.payload & (normal_min-1))==0) $fatal(1,"FP expected NaN class");
      end else if(observed.payload!==expected_bits) $fatal(1,"FP special n=%0d got=%h expected=%h",n,observed.payload,expected_bits);
      independent_checks++; #4; clk=1; #5; clk=0;
    end
    for(int n=0;n<1000;n++) begin random_inputs(); tick(); end
    $display("PHASE3_FLOAT_PASS multiply=%0d exp=%0d sig=%0d samples=%0d arithmetic_checks=%0d special_checks=8 seed=c03e2026",MULTIPLY,FP_EXP_W,FP_SIG_W,samples,independent_checks);
    $finish;
  end
endmodule
