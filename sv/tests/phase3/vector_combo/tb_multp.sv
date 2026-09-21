`timescale 1ns/1ps
module multp_case #(parameter int A=8,B=8,O=A+B+2)(output logic done=0);
  logic[A-1:0]a;logic[B-1:0]b;logic tc;
  logic[O-1:0]d0,d1,g0,g1,expected;
  logic signed[O-1:0]signed_a,signed_b;
  logic[31:0]rng=32'h4c271828+A*17+B;
  function automatic logic[31:0]next_word();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction
  cgra_multp #(.A_W(A),.B_W(B),.OUT_W(O))dut(.a,.b,.tc,.out0(d0),.out1(d1));
  DW02_multp #(A,B,O)gold(.a,.b,.tc,.out0(g0),.out1(g1));
  initial begin
    for(int sample=0;sample<2048;sample++)begin
      a=A'(next_word());b=B'(next_word());tc=1'(sample);
      if(A+B<=9)begin a=A'(sample>>1);b=B'(sample>>(A+1));end
      else case(sample%16)
        0:begin a=0;b=0;end
        1:begin a='1;b='1;end
        2:begin a=A'(1)<<(A-1);b=B'(1)<<(B-1);end
        3:begin a=(A'(1)<<(A-1))-1;b='1;end
        4:begin a='1;b=B'(1)<<(B-1);end
        default:begin end
      endcase
      #1;
      if(d0!==g0||d1!==g1)$fatal(1,"MULTP_PARTIAL_DIFF A=%0d B=%0d O=%0d sample=%0d tc=%b a=%h b=%h native=%h,%h gold=%h,%h",A,B,O,sample,tc,a,b,d0,d1,g0,g1);
      signed_a=O'($signed(a));signed_b=O'($signed(b));
      expected=tc?O'(signed_a*signed_b):O'(O'(a)*O'(b));
      if(O'(d0+d1)!==expected)$fatal(1,"MULTP_MATH_DIFF A=%0d B=%0d sample=%0d",A,B,sample);
    end
    $display("MULTP_CASE_PASS A=%0d B=%0d O=%0d samples=2048 signed_unsigned=1 exact_partials=1",A,B,O);
    done=1;
  end
endmodule
module tb_multp;
  logic[8:0]done;
  multp_case #(1,1,4)c0(done[0]);
  multp_case #(2,3,7)c1(done[1]);
  multp_case #(3,5,10)c2(done[2]);
  multp_case #(4,4,10)c3(done[3]);
  multp_case #(5,3,16)c4(done[4]);
  multp_case #(8,8,18)c5(done[5]);
  multp_case #(9,6,20)c6(done[6]);
  multp_case #(16,16,34)c7(done[7]);
  multp_case #(17,11,32)c8(done[8]);
  initial begin wait(&done);$display("MULTP_PASS configurations=9 total_samples=18432");$finish;end
  initial begin #3000;$fatal(1,"MULTP_TIMEOUT");end
endmodule
