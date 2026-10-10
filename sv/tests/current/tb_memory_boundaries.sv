`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
module tb_memory_boundaries #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  logic [GLOBAL_ADDR_W-1:0] address_lower ;
  logic [GLOBAL_ADDR_W-1:0] address_upper ;
  logic [CGRA_ID_W-1:0] cgra_id ;
  logic [0:0] clk ;
  logic [0:0] reset ;
  logic [32-1:0] recv_from_controller_spm_rd_req__msg ;
  logic [0:0] recv_from_controller_spm_rd_req__rdy ;
  logic [0:0] recv_from_controller_spm_rd_req__val ;
  logic [68-1:0] recv_from_controller_spm_wr_req__msg ;
  logic [0:0] recv_from_controller_spm_wr_req__rdy ;
  logic [0:0] recv_from_controller_spm_wr_req__val ;
  logic [NOC_BITS-1:0] recv_from_noc_load_request__msg ;
  logic [0:0] recv_from_noc_load_request__rdy ;
  logic [0:0] recv_from_noc_load_request__val ;
  logic [NOC_BITS-1:0] recv_from_noc_load_response_pkt__msg ;
  logic [0:0] recv_from_noc_load_response_pkt__rdy ;
  logic [0:0] recv_from_noc_load_response_pkt__val ;
  logic [NOC_BITS-1:0] recv_from_noc_store_request__msg ;
  logic [0:0] recv_from_noc_store_request__rdy ;
  logic [0:0] recv_from_noc_store_request__val ;
  logic [GLOBAL_ADDR_W-1:0] recv_raddr__msg [0:MEM_PORTS-1];
  wire [MEM_PORTS*(GLOBAL_ADDR_W)-1:0] flat_recv_raddr__msg;
  logic [0:0] recv_raddr__rdy [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_recv_raddr__rdy;
  logic [0:0] recv_raddr__val [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_recv_raddr__val;
  logic [GLOBAL_ADDR_W-1:0] recv_waddr__msg [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(GLOBAL_ADDR_W)-1:0] flat_recv_waddr__msg;
  logic [0:0] recv_waddr__rdy [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_waddr__rdy;
  logic [0:0] recv_waddr__val [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_waddr__val;
  logic [DATA_BITS-1:0] recv_wdata__msg [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(DATA_BITS)-1:0] flat_recv_wdata__msg;
  logic [0:0] recv_wdata__rdy [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_wdata__rdy;
  logic [0:0] recv_wdata__val [0:MEM_WRITE_PORTS-1];
  wire [MEM_WRITE_PORTS*(1)-1:0] flat_recv_wdata__val;
  logic [DATA_BITS-1:0] send_rdata__msg [0:MEM_PORTS-1];
  wire [MEM_PORTS*(DATA_BITS)-1:0] flat_send_rdata__msg;
  logic [0:0] send_rdata__rdy [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_send_rdata__rdy;
  logic [0:0] send_rdata__val [0:MEM_PORTS-1];
  wire [MEM_PORTS*(1)-1:0] flat_send_rdata__val;
  logic [32-1:0] send_to_controller_spm_rd_resp__msg ;
  logic [0:0] send_to_controller_spm_rd_resp__rdy ;
  logic [0:0] send_to_controller_spm_rd_resp__val ;
  logic [NOC_BITS-1:0] send_to_noc_load_request_pkt__msg ;
  logic [0:0] send_to_noc_load_request_pkt__rdy ;
  logic [0:0] send_to_noc_load_request_pkt__val ;
  logic [NOC_BITS-1:0] send_to_noc_load_response_pkt__msg ;
  logic [0:0] send_to_noc_load_response_pkt__rdy ;
  logic [0:0] send_to_noc_load_response_pkt__val ;
  logic [NOC_BITS-1:0] send_to_noc_store_pkt__msg ;
  logic [0:0] send_to_noc_store_pkt__rdy ;
  logic [0:0] send_to_noc_store_pkt__val ;
`ifdef MEMORY_BOUNDARIES_POST_SYNTH
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__msg assign flat_recv_raddr__msg[(MEM_PORTS-1-i)*(GLOBAL_ADDR_W)+:(GLOBAL_ADDR_W)]=recv_raddr__msg[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__rdy assign recv_raddr__rdy[i]=flat_recv_raddr__rdy[(MEM_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_recv_raddr__val assign flat_recv_raddr__val[(MEM_PORTS-1-i)*(1)+:(1)]=recv_raddr__val[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__msg assign flat_recv_waddr__msg[(MEM_WRITE_PORTS-1-i)*(GLOBAL_ADDR_W)+:(GLOBAL_ADDR_W)]=recv_waddr__msg[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__rdy assign recv_waddr__rdy[i]=flat_recv_waddr__rdy[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_waddr__val assign flat_recv_waddr__val[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]=recv_waddr__val[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__msg assign flat_recv_wdata__msg[(MEM_WRITE_PORTS-1-i)*(DATA_BITS)+:(DATA_BITS)]=recv_wdata__msg[i]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__rdy assign recv_wdata__rdy[i]=flat_recv_wdata__rdy[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]; end
  for(genvar i=0;i<MEM_WRITE_PORTS;i++)begin:adapt_recv_wdata__val assign flat_recv_wdata__val[(MEM_WRITE_PORTS-1-i)*(1)+:(1)]=recv_wdata__val[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__msg assign send_rdata__msg[i]=flat_send_rdata__msg[(MEM_PORTS-1-i)*(DATA_BITS)+:(DATA_BITS)]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__rdy assign flat_send_rdata__rdy[(MEM_PORTS-1-i)*(1)+:(1)]=send_rdata__rdy[i]; end
  for(genvar i=0;i<MEM_PORTS;i++)begin:adapt_send_rdata__val assign send_rdata__val[i]=flat_send_rdata__val[(MEM_PORTS-1-i)*(1)+:(1)]; end
  memory_boundaries_netlist dut(.address_lower(address_lower),.address_upper(address_upper),.cgra_id(cgra_id),.clk(clk),.reset(reset),.recv_from_controller_spm_rd_req__msg(recv_from_controller_spm_rd_req__msg),.recv_from_controller_spm_rd_req__rdy(recv_from_controller_spm_rd_req__rdy),.recv_from_controller_spm_rd_req__val(recv_from_controller_spm_rd_req__val),.recv_from_controller_spm_wr_req__msg(recv_from_controller_spm_wr_req__msg),.recv_from_controller_spm_wr_req__rdy(recv_from_controller_spm_wr_req__rdy),.recv_from_controller_spm_wr_req__val(recv_from_controller_spm_wr_req__val),.recv_from_noc_load_request__msg(recv_from_noc_load_request__msg),.recv_from_noc_load_request__rdy(recv_from_noc_load_request__rdy),.recv_from_noc_load_request__val(recv_from_noc_load_request__val),.recv_from_noc_load_response_pkt__msg(recv_from_noc_load_response_pkt__msg),.recv_from_noc_load_response_pkt__rdy(recv_from_noc_load_response_pkt__rdy),.recv_from_noc_load_response_pkt__val(recv_from_noc_load_response_pkt__val),.recv_from_noc_store_request__msg(recv_from_noc_store_request__msg),.recv_from_noc_store_request__rdy(recv_from_noc_store_request__rdy),.recv_from_noc_store_request__val(recv_from_noc_store_request__val),.recv_raddr__msg(flat_recv_raddr__msg),.recv_raddr__rdy(flat_recv_raddr__rdy),.recv_raddr__val(flat_recv_raddr__val),.recv_waddr__msg(flat_recv_waddr__msg),.recv_waddr__rdy(flat_recv_waddr__rdy),.recv_waddr__val(flat_recv_waddr__val),.recv_wdata__msg(flat_recv_wdata__msg),.recv_wdata__rdy(flat_recv_wdata__rdy),.recv_wdata__val(flat_recv_wdata__val),.send_rdata__msg(flat_send_rdata__msg),.send_rdata__rdy(flat_send_rdata__rdy),.send_rdata__val(flat_send_rdata__val),.send_to_controller_spm_rd_resp__msg(send_to_controller_spm_rd_resp__msg),.send_to_controller_spm_rd_resp__rdy(send_to_controller_spm_rd_resp__rdy),.send_to_controller_spm_rd_resp__val(send_to_controller_spm_rd_resp__val),.send_to_noc_load_request_pkt__msg(send_to_noc_load_request_pkt__msg),.send_to_noc_load_request_pkt__rdy(send_to_noc_load_request_pkt__rdy),.send_to_noc_load_request_pkt__val(send_to_noc_load_request_pkt__val),.send_to_noc_load_response_pkt__msg(send_to_noc_load_response_pkt__msg),.send_to_noc_load_response_pkt__rdy(send_to_noc_load_response_pkt__rdy),.send_to_noc_load_response_pkt__val(send_to_noc_load_response_pkt__val),.send_to_noc_store_pkt__msg(send_to_noc_store_pkt__msg),.send_to_noc_store_pkt__rdy(send_to_noc_store_pkt__rdy),.send_to_noc_store_pkt__val(send_to_noc_store_pkt__val));
`else
  cgra_data_memory #(`CGRA_PROFILE_BIND) dut(.*);
`endif
  integer cycles=0,checks=0,writes=0,reads=0,stalls=0,remote_reads=0;
  bit wrong;
  data_t model [0:31];
  function automatic data_t token(input integer n);
    data_t d;d.payload=DATA_W'(32'h80010000+n*17);if(DATA_W==64)d.payload|=DATA_W'(n)<<40;
    d.predicate=n%2;d.bypass=(n/2)%2;d.delay=(n/4)%2;return d;
  endfunction
  task automatic tick;
    #4;clk=1;#4;clk=0;cycles++;if(cycles>10000)$fatal(1,"MEM_BOUNDARY_TIMEOUT");
  endtask
  task automatic idle;
    reset=0;address_lower=0;address_upper=31;cgra_id=0;
    recv_from_controller_spm_rd_req__msg=0;recv_from_controller_spm_rd_req__val=0;
    recv_from_controller_spm_wr_req__msg=0;recv_from_controller_spm_wr_req__val=0;
    recv_from_noc_load_request__msg=0;recv_from_noc_load_request__val=0;
    recv_from_noc_load_response_pkt__msg=0;recv_from_noc_load_response_pkt__val=0;
    recv_from_noc_store_request__msg=0;recv_from_noc_store_request__val=0;
    send_to_controller_spm_rd_resp__rdy=1;send_to_noc_load_request_pkt__rdy=1;
    send_to_noc_load_response_pkt__rdy=1;send_to_noc_store_pkt__rdy=1;
    for(integer p=0;p<MEM_PORTS;p++)begin recv_raddr__msg[p]=0;recv_raddr__val[p]=0;send_rdata__rdy[p]=1;end
    for(integer p=0;p<MEM_WRITE_PORTS;p++)begin recv_waddr__msg[p]=0;recv_waddr__val[p]=0;recv_wdata__msg[p]=0;recv_wdata__val[p]=0;end
  endtask
  task automatic check_reset;
    #1;
    for(integer p=0;p<MEM_PORTS;p++)if(recv_raddr__rdy[p] || send_rdata__val[p] || send_rdata__msg[p])$fatal(1,"MEM_RESET_READ");
    for(integer p=0;p<MEM_WRITE_PORTS;p++)if(recv_waddr__rdy[p] || recv_wdata__rdy[p])$fatal(1,"MEM_RESET_WRITE");
    if(recv_from_noc_load_request__rdy || recv_from_noc_load_response_pkt__rdy || recv_from_noc_store_request__rdy ||
       send_to_noc_load_request_pkt__val || send_to_noc_load_response_pkt__val || send_to_noc_store_pkt__val ||
       recv_from_controller_spm_rd_req__rdy || recv_from_controller_spm_wr_req__rdy || send_to_controller_spm_rd_resp__val)$fatal(1,"MEM_RESET_OTHER");
    checks++;
  endtask
  task automatic write_word(input integer p,a,input data_t d,input integer split);
    integer guard;
    idle();recv_waddr__msg[p]=GLOBAL_ADDR_W'(a);recv_wdata__msg[p]=d;
    if(split!=0)begin
      recv_waddr__val[p]=split==1;recv_wdata__val[p]=split==2;
      repeat(3)begin
        #1;if((split==1 && recv_waddr__rdy[p]) || (split==2 && recv_wdata__rdy[p]))$fatal(1,"MEM_UNPAIRED_WRITE");
        tick();checks++;
      end
    end
    recv_waddr__val[p]=1;recv_wdata__val[p]=1;guard=0;#1;
    while(!recv_waddr__rdy[p] || !recv_wdata__rdy[p])begin tick();#1;guard++;if(guard>50)$fatal(1,"MEM_WRITE_TIMEOUT");end
    tick();writes++;idle();repeat(4)tick();model[a]=d;
  endtask
  task automatic read_word(input integer p,a,input data_t expected);
    integer guard;bit issued,received;
    idle();guard=0;issued=0;received=0;
    while(!received)begin
      recv_raddr__val[p]=!issued;recv_raddr__msg[p]=GLOBAL_ADDR_W'(a);send_rdata__rdy[p]=guard>5 && guard%3!=0;#1;
      if(recv_raddr__val[p] && recv_raddr__rdy[p])issued=1;
      if(send_rdata__val[p])begin
        if(send_rdata__msg[p] !== (expected ^ DATA_BITS'(wrong && reads==0)))$fatal(1,"MEM_WORD_MISMATCH port=%0d addr=%0d got=%h expected=%h",p,a,send_rdata__msg[p],expected);
        checks++;if(!send_rdata__rdy[p])stalls++;
        if(send_rdata__rdy[p])received=1;
      end
      tick();guard++;if(guard>80)$fatal(1,"MEM_READ_TIMEOUT");
    end
    if(!issued)$fatal(1,"MEM_READ_WITHOUT_REQUEST");reads++;idle();
  endtask
  task automatic collision;
    integer guard;data_t old_value;
    idle();old_value=model[4];recv_raddr__val[0]=1;recv_raddr__msg[0]=4;send_rdata__rdy[0]=0;#1;
    guard=0;while(!recv_raddr__rdy[0])begin tick();#1;guard++;if(guard>50)$fatal(1,"MEM_COLLISION_REQUEST");end
    tick();recv_raddr__val[0]=0;#1;
    guard=0;while(!send_rdata__val[0])begin tick();#1;guard++;if(guard>50)$fatal(1,"MEM_COLLISION_RESPONSE");end
    tick(); // Captured read-before-write snapshot must remain stable.
    recv_waddr__msg[0]=4;recv_wdata__msg[0]=token(90);recv_waddr__val[0]=1;recv_wdata__val[0]=1;#1;
    if(!recv_waddr__rdy[0] || !recv_wdata__rdy[0])$fatal(1,"MEM_COLLISION_WRITE");tick();
    recv_waddr__val[0]=0;recv_wdata__val[0]=0;
    repeat(5)begin #1;if(!send_rdata__val[0] || send_rdata__msg[0]!==old_value)$fatal(1,"MEM_HELD_RESPONSE_CHANGED");checks++;tick();end
    send_rdata__rdy[0]=1;tick();model[4]=token(90);read_word(0,4,model[4]);
  endtask
  task automatic remote_roundtrip(input integer p);
    noc_packet_t request,response;integer guard;bit issued,sent,reply_accepted,received;
    idle();issued=0;sent=0;guard=0;
    while(!sent)begin
      recv_raddr__msg[p]=GLOBAL_ADDR_W'(64+p);recv_raddr__val[p]=!issued;send_to_noc_load_request_pkt__rdy=guard>4;#1;
      if(recv_raddr__val[p] && recv_raddr__rdy[p])issued=1;
      if(send_to_noc_load_request_pkt__val)begin
        request=send_to_noc_load_request_pkt__msg;
        if(request.payload.cmd!=10 || request.payload.data_addr!=64+p || request.remote_src_port!=p)$fatal(1,"MEM_REMOTE_REQUEST");
        checks++;sent=send_to_noc_load_request_pkt__rdy;
      end
      tick();guard++;if(guard>80)$fatal(1,"MEM_REMOTE_TIMEOUT");
    end
    idle();reply_accepted=0;received=0;guard=0;response='0;response.src=1;
    response.remote_src_port=MEM_PORT_W'(p);response.payload.cmd=11;response.payload.data=token(120+p);response.payload.data_addr=GLOBAL_ADDR_W'(64+p);
    while(!received)begin
      recv_from_noc_load_response_pkt__msg=response;recv_from_noc_load_response_pkt__val=!reply_accepted;
      send_rdata__rdy[p]=guard>5;#1;
      if(recv_from_noc_load_response_pkt__val && recv_from_noc_load_response_pkt__rdy)reply_accepted=1;
      for(integer q=0;q<MEM_PORTS;q++)if(send_rdata__val[q])begin
        if(q!=p || send_rdata__msg[q]!==token(120+p))$fatal(1,"MEM_REMOTE_RESPONSE");
        checks++;if(send_rdata__rdy[q])received=1;
      end
      tick();guard++;if(guard>80)$fatal(1,"MEM_REMOTE_REPLY_TIMEOUT");
    end
    if(!issued || !reply_accepted)$fatal(1,"MEM_REMOTE_MISSING_HANDSHAKE");remote_reads++;idle();
  endtask
  task automatic dma_access;
    integer guard;bit issued,received;
    idle();recv_from_controller_spm_wr_req__msg={32'd30,32'hfedc1234,4'hf};recv_from_controller_spm_wr_req__val=1;#1;
    guard=0;while(!recv_from_controller_spm_wr_req__rdy)begin tick();#1;guard++;if(guard>80)$fatal(1,"MEM_DMA_WRITE_TIMEOUT");end
    tick();idle();repeat(6)tick();model[30]={DATA_W'(32'hfedc1234),3'b100};read_word(0,30,model[30]);
    issued=0;received=0;guard=0;
    while(!received)begin
      recv_from_controller_spm_rd_req__msg=30;recv_from_controller_spm_rd_req__val=!issued;send_to_controller_spm_rd_resp__rdy=guard>5;#1;
      if(recv_from_controller_spm_rd_req__val && recv_from_controller_spm_rd_req__rdy)issued=1;
      if(send_to_controller_spm_rd_resp__val)begin
        if(send_to_controller_spm_rd_resp__msg!==32'hfedc1234)$fatal(1,"MEM_DMA_READ");checks++;received=send_to_controller_spm_rd_resp__rdy;
      end
      tick();guard++;if(guard>80)$fatal(1,"MEM_DMA_READ_TIMEOUT");
    end
    if(!issued)$fatal(1,"MEM_DMA_MISSING_REQUEST");idle();
  endtask
  integer count [0:MEM_WRITE_PORTS-1];
  integer guard,total;
  noc_packet_t packet,response;
  initial begin
    clk=0;wrong=$test$plusargs("EXPECT_FAILURE");idle();reset=1;tick();check_reset();tick();idle();
    if($test$plusargs("INVALID_MASK"))begin
      if(!HAS_DMA)$fatal(1,"MEM_INVALID_TEST_PROFILE");
      recv_from_controller_spm_wr_req__val=1;recv_from_controller_spm_wr_req__msg={32'd3,32'hdeadbeef,4'h1};#1;
      if(recv_from_controller_spm_wr_req__rdy)$fatal(1,"MEM_MASK_ACCEPTED");
`ifdef MEMORY_BOUNDARIES_POST_SYNTH
      repeat(4)begin tick();if(recv_from_controller_spm_wr_req__rdy)$fatal(1,"MEM_MASK_ACCEPTED");end
      $display("MEM_DMA_MASK_REJECT_PASS");$finish;
`else
      tick();$fatal(1,"MEM_MISSING_MASK_DIAGNOSTIC");
`endif
    end
    for(integer a=0;a<32;a++)write_word(a%MEM_WRITE_PORTS,a,token(a),a%3);
    for(integer p=0;p<MEM_PORTS;p++)for(integer a=0;a<32;a++)read_word(p,a,model[a]);
    // All writers contend for bank zero, then verify every independently addressed word.
    for(integer p=0;p<MEM_WRITE_PORTS;p++)count[p]=0;
    total=0;guard=0;
    while(total<4*MEM_WRITE_PORTS)begin
      idle();for(integer p=0;p<MEM_WRITE_PORTS;p++)begin
        recv_waddr__msg[p]=GLOBAL_ADDR_W'(p*4+count[p]);recv_wdata__msg[p]=token(40+p*4+count[p]);
        recv_waddr__val[p]=count[p]<4;recv_wdata__val[p]=count[p]<4;
      end
      #1;for(integer p=0;p<MEM_WRITE_PORTS;p++)if(recv_waddr__val[p] && recv_waddr__rdy[p] && recv_wdata__rdy[p])begin
        model[p*4+count[p]]=token(40+p*4+count[p]);count[p]++;total++;writes++;
      end
      tick();guard++;if(guard>80)$fatal(1,"MEM_CONTENDED_WRITE_TIMEOUT");
    end
    idle();repeat(6)tick();for(integer a=0;a<4*MEM_WRITE_PORTS;a++)read_word(a%MEM_PORTS,a,model[a]);
    collision();
    // A write accepted into a registered bank queue is canceled at reset.
    idle();recv_waddr__msg[0]=5;recv_wdata__msg[0]=token(100);recv_waddr__val[0]=1;recv_wdata__val[0]=1;#1;
    if(!recv_waddr__rdy[0] || !recv_wdata__rdy[0])$fatal(1,"MEM_RESET_SETUP");tick();
    if(MEM_COMBINATIONAL)model[5]=token(100);
    reset=1;recv_raddr__val[0]=1;recv_raddr__msg[0]=5;check_reset();tick();check_reset();idle();repeat(5)tick();
    for(integer a=0;a<32;a++)read_word(a%MEM_PORTS,a,model[a]);
    for(integer p=0;p<MEM_PORTS;p++)remote_roundtrip(p);
    idle();packet='0;packet.src=1;packet.payload.cmd=12;packet.payload.data_addr=31;packet.payload.data=token(150);
    recv_from_noc_store_request__msg=packet;recv_from_noc_store_request__val=1;#1;guard=0;
    while(!recv_from_noc_store_request__rdy)begin tick();#1;guard++;if(guard>80)$fatal(1,"MEM_NOC_STORE_TIMEOUT");end
    tick();idle();repeat(5)tick();model[31]=token(150);read_word(0,31,model[31]);
    packet.payload.cmd=10;packet.src_tile_id=2;packet.remote_src_port=MEM_PORT_W'(MEM_PORTS-1);
    recv_from_noc_load_request__msg=packet;recv_from_noc_load_request__val=1;send_to_noc_load_response_pkt__rdy=0;#1;guard=0;
    while(!recv_from_noc_load_request__rdy)begin tick();#1;guard++;if(guard>80)$fatal(1,"MEM_NOC_LOAD_TIMEOUT");end
    tick();recv_from_noc_load_request__val=0;#1;guard=0;
    while(!send_to_noc_load_response_pkt__val)begin tick();#1;guard++;if(guard>80)$fatal(1,"MEM_NOC_RESPONSE_TIMEOUT");end
    repeat(5)begin
      response=send_to_noc_load_response_pkt__msg;
      if(!send_to_noc_load_response_pkt__val || response.dst!=1 || response.dst_tile_id!=2 || response.remote_src_port!=MEM_PORTS-1 || response.payload.data!==model[31] || response.payload.cmd!=11)$fatal(1,"MEM_NOC_RESPONSE");checks++;tick();
    end
    send_to_noc_load_response_pkt__rdy=1;tick();idle();
    if(HAS_DMA)dma_access();
    if(reads<64 || writes<32 || stalls<32 || remote_reads!=MEM_PORTS)$fatal(1,"MEM_BOUNDARY_COVERAGE");
    $display("MEMORY_BOUNDARIES_PASS reads=%0d writes=%0d width=%0d combinational=%0d dma=%0d cycles=%0d checks=%0d",MEM_PORTS,MEM_WRITE_PORTS,DATA_W,MEM_COMBINATIONAL,HAS_DMA,cycles,checks);$finish;
  end
endmodule
