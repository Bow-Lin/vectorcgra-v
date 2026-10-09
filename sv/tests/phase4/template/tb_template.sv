`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_template #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  `include "heterogeneous/architecture.svh"
  logic clk=0,reset=0;
  logic [HOST_BITS-1:0] recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg,gold_msg;
  logic recv_from_cpu_pkt__val,recv_from_cpu_pkt__rdy,send_to_cpu_pkt__val,send_to_cpu_pkt__rdy,gold_val,gold_rdy;
  cgra_multi_template #(`CGRA_PROFILE_BIND,.FU_COUNT(5),.CGRA_COLS(ARCH_SIZES),.CGRA_ROWS(ARCH_SIZES),
    .TILE_FU_COUNTS(ARCH_COUNTS),.TILE_FU_KINDS(ARCH_FUS),.CUSTOM_TOPOLOGY(4'hf),
    .LINK_COUNT(ARCH_LINKS),.LINK_ENABLED(ARCH_ENABLED),.LINK_SRC_TILE(ARCH_SRC_TILE),.LINK_SRC_PORT(ARCH_SRC_PORT),
    .LINK_DST_TILE(ARCH_DST_TILE),.LINK_DST_PORT(ARCH_DST_PORT),.READ_PORT_TILE(ARCH_READ),.WRITE_PORT_TILE(ARCH_WRITE),
    .BOUNDARY_IN_ENABLE(ARCH_BIN),.BOUNDARY_OUT_ENABLE(ARCH_BOUT)) dut(.*);
  Phase4Heterogeneous gold(.clk,.reset,.recv_from_cpu_pkt__msg,.recv_from_cpu_pkt__val,
    .recv_from_cpu_pkt__rdy(gold_rdy),.send_to_cpu_pkt__msg(gold_msg),.send_to_cpu_pkt__val(gold_val),.send_to_cpu_pkt__rdy);
  localparam int IN_BITS=HOST_BITS+3,OUT_BITS=HOST_BITS+2;
  logic [IN_BITS-1:0] inputs[0:32767];
  logic [OUT_BITS-1:0] outputs[0:32767];
  bit complete[0:3][0:8];
  int completions=0,reads=0,stalls=0,remote_requests=0,disabled_links=0;
  noc_packet_t outgoing[0:3];
  for(genvar c=0;c<4;c++) assign outgoing[c]=dut.noc_recv_msg[c];
  always @(posedge clk) if(!reset) for(int c=0;c<4;c++)
    if(dut.noc_recv_val[c] && dut.noc_recv_rdy[c] && outgoing[c].src!=outgoing[c].dst &&
       (outgoing[c].payload.cmd==10 || outgoing[c].payload.cmd==12)) remote_requests++;
  initial begin
    string vectors;int samples,fd,owner,tile,addr,expected;host_packet_t p;
    logic [OUT_BITS-1:0] got;
    if(!$value$plusargs("VECTORS=%s",vectors)) $fatal(1,"VECTORS required");
    fd=$fopen({vectors,"/samples.txt"},"r");if(!fd) $fatal(1,"Missing sample file");
    if($fscanf(fd,"%d",samples)!=1) $fatal(1,"Bad sample count");$fclose(fd);
    if(samples>32768) $fatal(1,"Trace exceeds capacity");
    $readmemh({vectors,"/inputs.hex"},inputs);$readmemh({vectors,"/outputs.hex"},outputs);
    for(int c=0;c<4;c++) for(int k=0;k<ARCH_LINKS;k++) if(!ARCH_ENABLED[c][k]) disabled_links++;
    for(int i=0;i<samples;i++) begin
      {send_to_cpu_pkt__rdy,recv_from_cpu_pkt__msg,recv_from_cpu_pkt__val,reset}=inputs[i];#1;
      got={send_to_cpu_pkt__msg,send_to_cpu_pkt__val,recv_from_cpu_pkt__rdy};
      if(got !== {gold_msg,gold_val,gold_rdy}) $fatal(1,"Template HDL mismatch sample=%0d native=%h gold=%h",i,got,{gold_msg,gold_val,gold_rdy});
      if($test$plusargs("NEGATIVE") && i==20) got[0]=~got[0];
      if(got !== outputs[i]) $fatal(1,"Template Python mismatch sample=%0d native=%h expected=%h",i,got,outputs[i]);
      if(!reset && send_to_cpu_pkt__val) begin
        if(!send_to_cpu_pkt__rdy) stalls++;
        else begin
          p=send_to_cpu_pkt__msg;owner=int'(p.src_cgra_id);tile=int'(p.src);
          if(p.payload.cmd==14) begin
            if(owner>=4 || tile>=ARCH_SIZES[owner]*ARCH_SIZES[owner] || complete[owner][tile]) $fatal(1,"Invalid or duplicate heterogeneous completion");
            complete[owner][tile]=1;completions++;
          end else begin
            addr=int'(p.payload.data_addr);expected=7+7*(addr/32);
            if(addr%32==16) expected=(expected+5)*3-8;
            if(p.payload.cmd!=11 || owner!=addr/32 || p.dst_cgra_id!=0 || !p.payload.data.predicate ||
               p.payload.data.payload!=DATA_W'(expected) || addr!=(reads/2)*32+(reads%2==0 ? 16:15))
              $fatal(1,"Heterogeneous result/address/owner mismatch addr=%0d value=%h expected=%0d",addr,p.payload.data.payload,expected);
            reads++;
          end
        end
      end
      #4;clk=1;#5;clk=0;
    end
    if(completions!=21 || reads!=8 || stalls<8 || remote_requests<8 || disabled_links==0) $fatal(1,"Insufficient template coverage");
    $display("PHASE4_TEMPLATE_PASS samples=%0d bits=%0d completions=%0d reads=%0d stalls=%0d remote_requests=%0d",samples,OUT_BITS,completions,reads,stalls,remote_requests);
    $finish;
  end
endmodule
