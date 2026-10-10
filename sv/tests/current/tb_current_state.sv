`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_current_state #(`CGRA_PROFILE_PARAMETERS);
 `include "cgra_profile.svh"
 logic clk=0,reset=0,clear=0;
 logic q_proceed=0,q_rdy=0,q_val=0,q_outval,q_inrdy;
 logic [DATA_BITS-1:0] q_msg=0,q_outmsg;
 const_queue q(.clk,.reset,.clear,.ctrl_proceed(q_proceed),.recv_const__msg(q_msg),.recv_const__val(q_val),.recv_const__rdy(q_inrdy),.send_const__msg(q_outmsg),.send_const__val(q_outval),.send_const__rdy(q_rdy));
 logic [DATA_BITS-1:0] vq_outmsg;logic vq_outval,vq_inrdy;
 tile_variant_const_queue vq(.clk,.reset,.clear,.ctrl_proceed(q_proceed),.recv_const__msg(q_msg),.recv_const__val(q_val),.recv_const__rdy(vq_inrdy),.send_const__msg(vq_outmsg),.send_const__val(vq_outval),.send_const__rdy(q_rdy));
 always @(negedge clk) if (!reset) begin
   if ({vq_outmsg,vq_outval,vq_inrdy} !== {q_outmsg,q_outval,q_inrdy}) $fatal(1,"variant constant queue mismatch");
 end
 logic [3:0] sel[0:7];logic [2:0] counts[0:7][0:7];
 logic [DATA_BITS-1:0] xm[0:7],xo[0:7];logic xv[0:7],xr[0:7],xov[0:7],xor_[0:7];
 logic [CTRL_BITS-1:0] xc=0;logic xcv=0,xcr;
 tile_static_crossbar x(.clk,.reset,.clear,.cgra_id(1'b0),.tile_id(3'b0),.crossbar_id(1'b0),.compute_done(1'b0),.ctrl_addr_inport(3'b0),.crossbar_outport(sel),.prologue_count_inport(counts),.recv_data__msg(xm),.recv_data__val(xv),.recv_data__rdy(xr),.recv_opt__msg(xc),.recv_opt__val(xcv),.recv_opt__rdy(xcr),.send_data__msg(xo),.send_data__val(xov),.send_data__rdy(xor_));
 logic [CTRL_BITS-1:0] rc=0;
 logic [DATA_BITS-1:0] rm[0:3],zero_m[0:3],ro[0:3],rrouteo[0:3];
 logic rv[0:3],zero_v[0:3],rdy0[0:3],furdy[0:3],rr[0:3],rconstready[0:3],rfuready[0:3],rov[0:3],rroutev[0:3];
 register_cluster r(.clk,.reset,.clear,.inport_ctrl_proceed(1'b0),.inport_opt(rc),.recv_data_from_routing_crossbar__msg(rm),.recv_data_from_routing_crossbar__val(rv),.recv_data_from_routing_crossbar__rdy(rr),.recv_data_from_fu_crossbar__msg(zero_m),.recv_data_from_fu_crossbar__val(zero_v),.recv_data_from_fu_crossbar__rdy(rfuready),.recv_data_from_const__msg(zero_m),.recv_data_from_const__val(zero_v),.recv_data_from_const__rdy(rconstready),.send_data_to_fu__msg(ro),.send_data_to_fu__val(rov),.send_data_to_fu__rdy(furdy),.send_data_to_routing_crossbar__msg(rrouteo),.send_data_to_routing_crossbar__val(rroutev),.send_data_to_routing_crossbar__rdy(rdy0));
 ctrl_t ctrl;data_t v;
 task tick();clk=0;#5;clk=1;#5;clk=0;#1;endtask
 initial begin
  for(int i=0;i<8;i++)begin sel[i]=0;xm[i]=DATA_BITS'(((i+50)<<3)|4);xv[i]=0;xor_[i]=1;for(int a=0;a<8;a++)counts[a][i]=0;end
  for(int i=0;i<4;i++)begin rm[i]=DATA_BITS'(((i+10)<<3)|4);rv[i]=0;zero_m[i]=0;zero_v[i]=0;rdy0[i]=0;furdy[i]=0;end
  reset=1;tick();reset=0;
  q_val=1;q_msg=DATA_BITS'((10<<3)|4);tick();q_msg=DATA_BITS'((20<<3)|4);tick();q_val=0;
  q_rdy=1;q_proceed=0;tick();q_rdy=0;q_proceed=1;tick();
  v=q_outmsg;$display("STATE_CONST value=%0d",v.payload);if(v.payload!=20)$fatal(1,"CURRENT_CONST_UNEXPECTED");
  ctrl='0;ctrl.operation=31;xc=ctrl;xcv=1;sel[0]=1;sel[1]=2;counts[0][0]=1;xv[1]=1;xor_[0]=0;#5;
  $display("STATE_PROLOGUE_EMPTY ctrl=%0d val0=%0d val1=%0d in0=%0d in1=%0d",xcr,xov[0],xov[1],xr[0],xr[1]);
  if({xcr,xov[0],xov[1],xr[0],xr[1]}!=5'b10101)$fatal(1,"CURRENT_PROLOGUE_UNEXPECTED");
  xv[0]=1;xor_[0]=1;#5;
  $display("STATE_PROLOGUE_STALE ctrl=%0d val0=%0d val1=%0d in0=%0d in1=%0d",xcr,xov[0],xov[1],xr[0],xr[1]);
  if({xcr,xov[0],xov[1],xr[0],xr[1]}!=5'b10101)$fatal(1,"CURRENT_STALE_UNEXPECTED");
  ctrl='0;ctrl.operation=2;ctrl.fu_in[0]=3;ctrl.fu_in[1]=1;rc=ctrl;for(int i=0;i<4;i++)rv[i]=1;#5;
  $display("STATE_REGISTER ready=%0d%0d%0d%0d",rr[0],rr[1],rr[2],rr[3]);
  if({rr[0],rr[1],rr[2],rr[3]}!=4'b0101)$fatal(1,"CURRENT_REGISTER_UNEXPECTED");
  rc=0;for(int i=0;i<4;i++)rv[i]=0;reset=1;tick();reset=0;
  ctrl='0;ctrl.operation=1;ctrl.write_reg_from[0]=1;rc=ctrl;rv[0]=1;tick();
  ctrl='0;ctrl.operation=2;ctrl.fu_in[0]=1;ctrl.fu_in[1]=2;ctrl.write_reg_from[0]=1;ctrl.read_reg_towards[0]=1;ctrl.read_reg_idx[0]=1;rc=ctrl;furdy[0]=1;rm[0]=DATA_BITS'((99<<3)|4);#5;
  $display("STATE_PARALLEL_WRITE routing_ready=%0d bank_write_ready=%0d",rr[0],r.reg_bank__0.outport_wr_rdy);
  if(rr[0]!=0 || r.reg_bank__0.outport_wr_rdy!=0)$fatal(1,"CURRENT_PARALLEL_WRITE_UNEXPECTED");
  // Multicast: an output that accepted early must never receive the token twice.
  reset=1;tick();reset=0;
  for(int i=0;i<8;i++)begin sel[i]=0;xv[i]=0;xor_[i]=0;counts[0][i]=0;end
  sel[0]=1;sel[1]=1;xv[0]=1;xor_[0]=1;xcv=1;#2;
  if(!xov[0] || !xov[1] || xr[0] || xcr)$fatal(1,"multicast initial handshake");
  tick();#2;
  if(xov[0] || !xov[1] || xr[0] || xcr)$fatal(1,"multicast duplicate delivery");
  xor_[1]=1;#2;
  if(xov[0] || !xov[1] || !xr[0] || !xcr)$fatal(1,"multicast retirement");
  tick();xv[0]=0;#2;
  if(xov[0] || xov[1])$fatal(1,"multicast phantom token");
  $display("CURRENT_STATE_PASS");$finish;
 end
endmodule
