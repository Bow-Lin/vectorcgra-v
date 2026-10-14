// Generic public-interface transport. All programs/data arrive as runtime files.
// No arithmetic oracle, architecture-name dispatch, force, or hierarchy writes.
host_packet_t packets[$], packet;
int barrier_at[$], barrier_count[$], boundary_port[$];
logic [DATA_BITS-1:0] boundary_words[$];
int pi=0, bi=0, xi=0, completes=0, reads=0, boundary_outputs=0;
int expected_complete, expected_reads, expected_boundary, schedule=0;
int stalled=0, hold_cycles=0, outstanding=0;
logic [31:0] rng;
bit host_pending=0, host_blocked=0;
logic [HOST_BITS-1:0] previous_host;
bit boundary_blocked[0:BOUNDARIES-1];
logic [DATA_BITS-1:0] previous_boundary[0:BOUNDARIES-1];
function automatic logic [31:0] next_random(input logic [31:0] x);
  x=x^(x<<13); x=x^(x>>17); return x^(x<<5);
endfunction
initial begin
  string vectors, trace;
  int fd, logfd, rc, at_packet, count, port, done=-1, cycle;
  logic [DATA_BITS-1:0] word;
  host_packet_t response;
  if(!$value$plusargs("VECTORS=%s",vectors) || !$value$plusargs("TRACE=%s",trace))
    $fatal(1,"Missing runtime files");
  if(!$value$plusargs("COMPLETIONS=%d",expected_complete) ||
     !$value$plusargs("READS=%d",expected_reads) ||
     !$value$plusargs("BOUNDARY_OUTPUTS=%d",expected_boundary)) $fatal(1,"Missing expected counts");
  rc=$value$plusargs("SCHEDULE=%d",schedule); rng=schedule==0 ? 1:32'(schedule);
  fd=$fopen({vectors,"/program.hex"},"r");if(!fd)$fatal(1,"Missing packets");
  while(!$feof(fd))begin
    rc=$fscanf(fd,"%h\n",packet);
    if(rc==1)packets.push_back(packet);else if(!$feof(fd))$fatal(1,"Malformed packet");
  end
  $fclose(fd);
  fd=$fopen({vectors,"/barriers.txt"},"r");if(!fd)$fatal(1,"Missing barriers");
  while(!$feof(fd))begin
    rc=$fscanf(fd,"%d %d\n",at_packet,count);
    if(rc==2)begin
      if(at_packet<0 || at_packet>packets.size() || count<0 ||
         (barrier_at.size()>0 && (at_packet<barrier_at[$] || count<barrier_count[$])))
        $fatal(1,"Malformed barrier order");
      barrier_at.push_back(at_packet);barrier_count.push_back(count);
    end else if(!$feof(fd))$fatal(1,"Malformed barrier");
  end
  $fclose(fd);
  fd=$fopen({vectors,"/boundary.txt"},"r");if(!fd)$fatal(1,"Missing boundary file");
  while(!$feof(fd))begin
    rc=$fscanf(fd,"%d %h\n",port,word);
    if(rc==2)begin
      if(port<0 || port>=BOUNDARIES)$fatal(1,"Boundary port outside interface");
      boundary_port.push_back(port);boundary_words.push_back(word);
    end else if(!$feof(fd))$fatal(1,"Malformed boundary input");
  end
  $fclose(fd);logfd=$fopen(trace,"w");if(!logfd)$fatal(1,"Cannot write trace");
  recv_from_cpu_pkt__val=0;recv_from_cpu_pkt__msg=0;send_to_cpu_pkt__rdy=0;
  for(int j=0;j<BOUNDARIES;j++)begin
    bin_val[j]=0;bin_msg[j]=0;bout_rdy[j]=0;boundary_blocked[j]=0;
  end
  reset=1;repeat(3)begin #5;clk=1;#5;clk=0;end reset=0;
  for(cycle=0;cycle<20000;cycle++)begin
    rng=next_random(rng);
    while(bi<barrier_at.size() && pi>=barrier_at[bi] && completes>=barrier_count[bi])bi++;
    if(!host_pending && pi<packets.size() &&
       !(bi<barrier_at.size() && pi>=barrier_at[bi]) &&
       (packets[pi].payload.cmd!=10 || outstanding==0) &&
       (schedule==0 || rng[2:0]!=0))host_pending=1;
    recv_from_cpu_pkt__val=host_pending;
    recv_from_cpu_pkt__msg=pi<packets.size() ? packets[pi]:'0;
    send_to_cpu_pkt__rdy=!$test$plusargs("STALL_FOREVER") &&
      (schedule==0 || (hold_cycles>=8 && rng[4:3]!=0));
    for(int j=0;j<BOUNDARIES;j++)begin
      bin_val[j]=xi<boundary_words.size() && boundary_port[xi]==j;
      bin_msg[j]=xi<boundary_words.size() ? boundary_words[xi]:'0;
      bout_rdy[j]=!$test$plusargs("STALL_FOREVER") && (schedule==0 || rng[6:5]!=0);
    end
    #5;
    if(recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy)begin
      if(packets[pi].payload.cmd==10)outstanding++;
      pi++;host_pending=0;
    end
    if(xi<boundary_words.size() && bin_rdy[boundary_port[xi]])xi++;
    if(host_blocked && (!send_to_cpu_pkt__val || send_to_cpu_pkt__msg!==previous_host))
      $fatal(1,"PARAM_HOST_UNSTABLE cycle=%0d",cycle);
    host_blocked=send_to_cpu_pkt__val && !send_to_cpu_pkt__rdy;
    previous_host=send_to_cpu_pkt__msg;
    if(host_blocked)begin stalled++;hold_cycles++;end
    if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy)begin
      response=send_to_cpu_pkt__msg;
      if(response.payload.cmd==14)completes++;
      else if(response.payload.cmd==11)begin reads++;outstanding--;end
      else $fatal(1,"PARAM_UNEXPECTED_COMMAND cmd=%0d",response.payload.cmd);
      $fdisplay(logfd,"H %0d %h",cycle,response);
    end
    for(int j=0;j<BOUNDARIES;j++)begin
      if(boundary_blocked[j] && (!bout_val[j] || bout_msg[j]!==previous_boundary[j]))
        $fatal(1,"PARAM_BOUNDARY_UNSTABLE port=%0d",j);
      boundary_blocked[j]=bout_val[j] && !bout_rdy[j];previous_boundary[j]=bout_msg[j];
      if(bout_val[j] && bout_rdy[j])begin
        boundary_outputs++;$fdisplay(logfd,"B %0d %0d %h",cycle,j,bout_msg[j]);
      end
    end
    if(completes>expected_complete || reads>expected_reads || boundary_outputs>expected_boundary)
      $fatal(1,"PARAM_EXCESS_OUTPUT");
    clk=1;#5;clk=0;
    if(pi==packets.size() && bi==barrier_at.size() && xi==boundary_words.size() &&
       completes==expected_complete && reads==expected_reads && boundary_outputs==expected_boundary)begin
      if(done<0)done=cycle;
      if(cycle>=done+32)break;
    end
  end
  $fclose(logfd);
  if(cycle==20000)$fatal(1,"PARAM_TIMEOUT sent=%0d/%0d complete=%0d/%0d reads=%0d/%0d boundary=%0d/%0d",
    pi,packets.size(),completes,expected_complete,reads,expected_reads,boundary_outputs,expected_boundary);
  if(schedule!=0 && stalled<8)$fatal(1,"PARAM_NO_BACKPRESSURE");
  $display("PARAM_TRANSPORT_PASS cycles=%0d sent=%0d complete=%0d reads=%0d boundary=%0d stalls=%0d",
    cycle,pi,completes,reads,boundary_outputs,stalled);$finish;
end
