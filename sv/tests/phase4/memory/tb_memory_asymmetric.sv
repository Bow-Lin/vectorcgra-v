`timescale 1ns/1ps
module tb_memory_asymmetric;
  logic [6:0] address_lower;
  logic [6:0] address_upper;
  logic [1:0] cgra_id;
  logic [0:0] clk;
  logic [0:0] reset;
  logic [31:0] recv_from_controller_spm_rd_req__msg;
  logic [0:0] d_recv_from_controller_spm_rd_req__rdy;
  logic [0:0] g_recv_from_controller_spm_rd_req__rdy;
  logic [0:0] recv_from_controller_spm_rd_req__val;
  logic [67:0] recv_from_controller_spm_wr_req__msg;
  logic [0:0] d_recv_from_controller_spm_wr_req__rdy;
  logic [0:0] g_recv_from_controller_spm_wr_req__rdy;
  logic [0:0] recv_from_controller_spm_wr_req__val;
  logic [194:0] recv_from_noc_load_request__msg;
  logic [0:0] d_recv_from_noc_load_request__rdy;
  logic [0:0] g_recv_from_noc_load_request__rdy;
  logic [0:0] recv_from_noc_load_request__val;
  logic [194:0] recv_from_noc_load_response_pkt__msg;
  logic [0:0] d_recv_from_noc_load_response_pkt__rdy;
  logic [0:0] g_recv_from_noc_load_response_pkt__rdy;
  logic [0:0] recv_from_noc_load_response_pkt__val;
  logic [194:0] recv_from_noc_store_request__msg;
  logic [0:0] d_recv_from_noc_store_request__rdy;
  logic [0:0] g_recv_from_noc_store_request__rdy;
  logic [0:0] recv_from_noc_store_request__val;
  logic [6:0] recv_raddr__msg[0:0];
  logic [0:0] d_recv_raddr__rdy[0:0];
  logic [0:0] g_recv_raddr__rdy[0:0];
  logic [0:0] recv_raddr__val[0:0];
  logic [6:0] recv_waddr__msg[0:2];
  logic [0:0] d_recv_waddr__rdy[0:2];
  logic [0:0] g_recv_waddr__rdy[0:2];
  logic [0:0] recv_waddr__val[0:2];
  logic [34:0] recv_wdata__msg[0:2];
  logic [0:0] d_recv_wdata__rdy[0:2];
  logic [0:0] g_recv_wdata__rdy[0:2];
  logic [0:0] recv_wdata__val[0:2];
  logic [34:0] d_send_rdata__msg[0:0];
  logic [34:0] g_send_rdata__msg[0:0];
  logic [0:0] send_rdata__rdy[0:0];
  logic [0:0] d_send_rdata__val[0:0];
  logic [0:0] g_send_rdata__val[0:0];
  logic [31:0] d_send_to_controller_spm_rd_resp__msg;
  logic [31:0] g_send_to_controller_spm_rd_resp__msg;
  logic [0:0] send_to_controller_spm_rd_resp__rdy;
  logic [0:0] d_send_to_controller_spm_rd_resp__val;
  logic [0:0] g_send_to_controller_spm_rd_resp__val;
  logic [194:0] d_send_to_noc_load_request_pkt__msg;
  logic [194:0] g_send_to_noc_load_request_pkt__msg;
  logic [0:0] send_to_noc_load_request_pkt__rdy;
  logic [0:0] d_send_to_noc_load_request_pkt__val;
  logic [0:0] g_send_to_noc_load_request_pkt__val;
  logic [194:0] d_send_to_noc_load_response_pkt__msg;
  logic [194:0] g_send_to_noc_load_response_pkt__msg;
  logic [0:0] send_to_noc_load_response_pkt__rdy;
  logic [0:0] d_send_to_noc_load_response_pkt__val;
  logic [0:0] g_send_to_noc_load_response_pkt__val;
  logic [194:0] d_send_to_noc_store_pkt__msg;
  logic [194:0] g_send_to_noc_store_pkt__msg;
  logic [0:0] send_to_noc_store_pkt__rdy;
  logic [0:0] d_send_to_noc_store_pkt__val;
  logic [0:0] g_send_to_noc_store_pkt__val;
  cgra_data_memory #(.MEMORY_LEGACY_PYTHON(1),.COLS(2),.ROWS(2),.MULTI_COLS(2),.MULTI_ROWS(2),.DATA_W(32),.CTRL_DEPTH(8),.REG_DEPTH(16),.GLOBAL_ADDR_W(7),.NUM_BANKS(2),.BANK_DEPTH(16),.MEM_PORTS(1),.MEM_WRITE_PORTS(3),.MAX_MEM_PORTS(1)) dut (.address_lower(address_lower),.address_upper(address_upper),.cgra_id(cgra_id),.clk(clk),.reset(reset),.recv_from_controller_spm_rd_req__msg(recv_from_controller_spm_rd_req__msg),.recv_from_controller_spm_rd_req__rdy(d_recv_from_controller_spm_rd_req__rdy),.recv_from_controller_spm_rd_req__val(recv_from_controller_spm_rd_req__val),.recv_from_controller_spm_wr_req__msg(recv_from_controller_spm_wr_req__msg),.recv_from_controller_spm_wr_req__rdy(d_recv_from_controller_spm_wr_req__rdy),.recv_from_controller_spm_wr_req__val(recv_from_controller_spm_wr_req__val),.recv_from_noc_load_request__msg(recv_from_noc_load_request__msg),.recv_from_noc_load_request__rdy(d_recv_from_noc_load_request__rdy),.recv_from_noc_load_request__val(recv_from_noc_load_request__val),.recv_from_noc_load_response_pkt__msg(recv_from_noc_load_response_pkt__msg),.recv_from_noc_load_response_pkt__rdy(d_recv_from_noc_load_response_pkt__rdy),.recv_from_noc_load_response_pkt__val(recv_from_noc_load_response_pkt__val),.recv_from_noc_store_request__msg(recv_from_noc_store_request__msg),.recv_from_noc_store_request__rdy(d_recv_from_noc_store_request__rdy),.recv_from_noc_store_request__val(recv_from_noc_store_request__val),.recv_raddr__msg(recv_raddr__msg),.recv_raddr__rdy(d_recv_raddr__rdy),.recv_raddr__val(recv_raddr__val),.recv_waddr__msg(recv_waddr__msg),.recv_waddr__rdy(d_recv_waddr__rdy),.recv_waddr__val(recv_waddr__val),.recv_wdata__msg(recv_wdata__msg),.recv_wdata__rdy(d_recv_wdata__rdy),.recv_wdata__val(recv_wdata__val),.send_rdata__msg(d_send_rdata__msg),.send_rdata__rdy(send_rdata__rdy),.send_rdata__val(d_send_rdata__val),.send_to_controller_spm_rd_resp__msg(d_send_to_controller_spm_rd_resp__msg),.send_to_controller_spm_rd_resp__rdy(send_to_controller_spm_rd_resp__rdy),.send_to_controller_spm_rd_resp__val(d_send_to_controller_spm_rd_resp__val),.send_to_noc_load_request_pkt__msg(d_send_to_noc_load_request_pkt__msg),.send_to_noc_load_request_pkt__rdy(send_to_noc_load_request_pkt__rdy),.send_to_noc_load_request_pkt__val(d_send_to_noc_load_request_pkt__val),.send_to_noc_load_response_pkt__msg(d_send_to_noc_load_response_pkt__msg),.send_to_noc_load_response_pkt__rdy(send_to_noc_load_response_pkt__rdy),.send_to_noc_load_response_pkt__val(d_send_to_noc_load_response_pkt__val),.send_to_noc_store_pkt__msg(d_send_to_noc_store_pkt__msg),.send_to_noc_store_pkt__rdy(send_to_noc_store_pkt__rdy),.send_to_noc_store_pkt__val(d_send_to_noc_store_pkt__val));
  Phase4Memory_r1w3 gold (.address_lower(address_lower),.address_upper(address_upper),.cgra_id(cgra_id),.clk(clk),.reset(reset),.recv_from_controller_spm_rd_req__msg(recv_from_controller_spm_rd_req__msg),.recv_from_controller_spm_rd_req__rdy(g_recv_from_controller_spm_rd_req__rdy),.recv_from_controller_spm_rd_req__val(recv_from_controller_spm_rd_req__val),.recv_from_controller_spm_wr_req__msg(recv_from_controller_spm_wr_req__msg),.recv_from_controller_spm_wr_req__rdy(g_recv_from_controller_spm_wr_req__rdy),.recv_from_controller_spm_wr_req__val(recv_from_controller_spm_wr_req__val),.recv_from_noc_load_request__msg(recv_from_noc_load_request__msg),.recv_from_noc_load_request__rdy(g_recv_from_noc_load_request__rdy),.recv_from_noc_load_request__val(recv_from_noc_load_request__val),.recv_from_noc_load_response_pkt__msg(recv_from_noc_load_response_pkt__msg),.recv_from_noc_load_response_pkt__rdy(g_recv_from_noc_load_response_pkt__rdy),.recv_from_noc_load_response_pkt__val(recv_from_noc_load_response_pkt__val),.recv_from_noc_store_request__msg(recv_from_noc_store_request__msg),.recv_from_noc_store_request__rdy(g_recv_from_noc_store_request__rdy),.recv_from_noc_store_request__val(recv_from_noc_store_request__val),.recv_raddr__msg(recv_raddr__msg),.recv_raddr__rdy(g_recv_raddr__rdy),.recv_raddr__val(recv_raddr__val),.recv_waddr__msg(recv_waddr__msg),.recv_waddr__rdy(g_recv_waddr__rdy),.recv_waddr__val(recv_waddr__val),.recv_wdata__msg(recv_wdata__msg),.recv_wdata__rdy(g_recv_wdata__rdy),.recv_wdata__val(recv_wdata__val),.send_rdata__msg(g_send_rdata__msg),.send_rdata__rdy(send_rdata__rdy),.send_rdata__val(g_send_rdata__val),.send_to_controller_spm_rd_resp__msg(g_send_to_controller_spm_rd_resp__msg),.send_to_controller_spm_rd_resp__rdy(send_to_controller_spm_rd_resp__rdy),.send_to_controller_spm_rd_resp__val(g_send_to_controller_spm_rd_resp__val),.send_to_noc_load_request_pkt__msg(g_send_to_noc_load_request_pkt__msg),.send_to_noc_load_request_pkt__rdy(send_to_noc_load_request_pkt__rdy),.send_to_noc_load_request_pkt__val(g_send_to_noc_load_request_pkt__val),.send_to_noc_load_response_pkt__msg(g_send_to_noc_load_response_pkt__msg),.send_to_noc_load_response_pkt__rdy(send_to_noc_load_response_pkt__rdy),.send_to_noc_load_response_pkt__val(g_send_to_noc_load_response_pkt__val),.send_to_noc_store_pkt__msg(g_send_to_noc_store_pkt__msg),.send_to_noc_store_pkt__rdy(send_to_noc_store_pkt__rdy),.send_to_noc_store_pkt__val(g_send_to_noc_store_pkt__val));
  localparam int NOC_W=195;
  integer cycles,local_writes,local_reads,noc_stores,noc_reads,remote_loads,remote_stores,stall_samples;
  integer count[0:2],stage_steps,read_index,data_expected,accepted,replied,seen_stores,fd;
  logic [31:0] rng=32'h50a4c311; bit intentional_failure; string result_path;
  function automatic logic[31:0] random32();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction
  function automatic logic[NOC_W-1:0] packet(input int cmd,addr,value,source,tile,port);
    logic[NOC_W-1:0] p;p='0;
    p[164+:6]=6'(cmd);
    p[122+:7]=7'(addr);
    p[132+:32]=32'(value);
    p[131+:1]=1'(1);
    p[193+:2]=2'(source);
    p[184+:3]=3'(tile);
    p[180+:1]=1'(port);
    return p;endfunction
  task automatic idle;
    address_lower='0;
    address_upper='0;
    cgra_id='0;
    reset='0;
    recv_from_controller_spm_rd_req__msg='0;
    recv_from_controller_spm_rd_req__val='0;
    recv_from_controller_spm_wr_req__msg='0;
    recv_from_controller_spm_wr_req__val='0;
    recv_from_noc_load_request__msg='0;
    recv_from_noc_load_request__val='0;
    recv_from_noc_load_response_pkt__msg='0;
    recv_from_noc_load_response_pkt__val='0;
    recv_from_noc_store_request__msg='0;
    recv_from_noc_store_request__val='0;
    recv_raddr__msg[0]='0;
    recv_raddr__val[0]='0;
    recv_waddr__msg[0]='0;
    recv_waddr__msg[1]='0;
    recv_waddr__msg[2]='0;
    recv_waddr__val[0]='0;
    recv_waddr__val[1]='0;
    recv_waddr__val[2]='0;
    recv_wdata__msg[0]='0;
    recv_wdata__msg[1]='0;
    recv_wdata__msg[2]='0;
    recv_wdata__val[0]='0;
    recv_wdata__val[1]='0;
    recv_wdata__val[2]='0;
    send_rdata__rdy[0]='0;
    send_to_controller_spm_rd_resp__rdy='0;
    send_to_noc_load_request_pkt__rdy='0;
    send_to_noc_load_response_pkt__rdy='0;
    send_to_noc_store_pkt__rdy='0;
    address_upper=7'd31;
    send_rdata__rdy[0]=1;send_to_noc_load_request_pkt__rdy=1;send_to_noc_load_response_pkt__rdy=1;send_to_noc_store_pkt__rdy=1;
  endtask
  task automatic compare;
    if(d_recv_from_controller_spm_rd_req__rdy!==g_recv_from_controller_spm_rd_req__rdy) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_from_controller_spm_rd_req__rdy actual=%h expected=%h",cycles,d_recv_from_controller_spm_rd_req__rdy,g_recv_from_controller_spm_rd_req__rdy);
    if(d_recv_from_controller_spm_wr_req__rdy!==g_recv_from_controller_spm_wr_req__rdy) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_from_controller_spm_wr_req__rdy actual=%h expected=%h",cycles,d_recv_from_controller_spm_wr_req__rdy,g_recv_from_controller_spm_wr_req__rdy);
    if(d_recv_from_noc_load_request__rdy!==g_recv_from_noc_load_request__rdy) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_from_noc_load_request__rdy actual=%h expected=%h",cycles,d_recv_from_noc_load_request__rdy,g_recv_from_noc_load_request__rdy);
    if(d_recv_from_noc_load_response_pkt__rdy!==g_recv_from_noc_load_response_pkt__rdy) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_from_noc_load_response_pkt__rdy actual=%h expected=%h",cycles,d_recv_from_noc_load_response_pkt__rdy,g_recv_from_noc_load_response_pkt__rdy);
    if(d_recv_from_noc_store_request__rdy!==g_recv_from_noc_store_request__rdy) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_from_noc_store_request__rdy actual=%h expected=%h",cycles,d_recv_from_noc_store_request__rdy,g_recv_from_noc_store_request__rdy);
    if(d_recv_raddr__rdy[0]!==g_recv_raddr__rdy[0]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_raddr__rdy[0] actual=%h expected=%h",cycles,d_recv_raddr__rdy[0],g_recv_raddr__rdy[0]);
    if(d_recv_waddr__rdy[0]!==g_recv_waddr__rdy[0]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_waddr__rdy[0] actual=%h expected=%h",cycles,d_recv_waddr__rdy[0],g_recv_waddr__rdy[0]);
    if(d_recv_waddr__rdy[1]!==g_recv_waddr__rdy[1]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_waddr__rdy[1] actual=%h expected=%h",cycles,d_recv_waddr__rdy[1],g_recv_waddr__rdy[1]);
    if(d_recv_waddr__rdy[2]!==g_recv_waddr__rdy[2]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_waddr__rdy[2] actual=%h expected=%h",cycles,d_recv_waddr__rdy[2],g_recv_waddr__rdy[2]);
    if(d_recv_wdata__rdy[0]!==g_recv_wdata__rdy[0]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_wdata__rdy[0] actual=%h expected=%h",cycles,d_recv_wdata__rdy[0],g_recv_wdata__rdy[0]);
    if(d_recv_wdata__rdy[1]!==g_recv_wdata__rdy[1]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_wdata__rdy[1] actual=%h expected=%h",cycles,d_recv_wdata__rdy[1],g_recv_wdata__rdy[1]);
    if(d_recv_wdata__rdy[2]!==g_recv_wdata__rdy[2]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=recv_wdata__rdy[2] actual=%h expected=%h",cycles,d_recv_wdata__rdy[2],g_recv_wdata__rdy[2]);
    if(d_send_rdata__msg[0]!==g_send_rdata__msg[0]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_rdata__msg[0] actual=%h expected=%h",cycles,d_send_rdata__msg[0],g_send_rdata__msg[0]);
    if(d_send_rdata__val[0]!==g_send_rdata__val[0]) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_rdata__val[0] actual=%h expected=%h",cycles,d_send_rdata__val[0],g_send_rdata__val[0]);
    if(d_send_to_controller_spm_rd_resp__msg!==g_send_to_controller_spm_rd_resp__msg) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_controller_spm_rd_resp__msg actual=%h expected=%h",cycles,d_send_to_controller_spm_rd_resp__msg,g_send_to_controller_spm_rd_resp__msg);
    if(d_send_to_controller_spm_rd_resp__val!==g_send_to_controller_spm_rd_resp__val) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_controller_spm_rd_resp__val actual=%h expected=%h",cycles,d_send_to_controller_spm_rd_resp__val,g_send_to_controller_spm_rd_resp__val);
    if(d_send_to_noc_load_request_pkt__msg!==g_send_to_noc_load_request_pkt__msg) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_load_request_pkt__msg actual=%h expected=%h",cycles,d_send_to_noc_load_request_pkt__msg,g_send_to_noc_load_request_pkt__msg);
    if(d_send_to_noc_load_request_pkt__val!==g_send_to_noc_load_request_pkt__val) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_load_request_pkt__val actual=%h expected=%h",cycles,d_send_to_noc_load_request_pkt__val,g_send_to_noc_load_request_pkt__val);
    if(d_send_to_noc_load_response_pkt__msg!==g_send_to_noc_load_response_pkt__msg) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_load_response_pkt__msg actual=%h expected=%h",cycles,d_send_to_noc_load_response_pkt__msg,g_send_to_noc_load_response_pkt__msg);
    if(d_send_to_noc_load_response_pkt__val!==g_send_to_noc_load_response_pkt__val) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_load_response_pkt__val actual=%h expected=%h",cycles,d_send_to_noc_load_response_pkt__val,g_send_to_noc_load_response_pkt__val);
    if(d_send_to_noc_store_pkt__msg!==g_send_to_noc_store_pkt__msg) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_store_pkt__msg actual=%h expected=%h",cycles,d_send_to_noc_store_pkt__msg,g_send_to_noc_store_pkt__msg);
    if(d_send_to_noc_store_pkt__val!==g_send_to_noc_store_pkt__val) $fatal(1,"MEM_RAW_DIFF cycle=%0d field=send_to_noc_store_pkt__val actual=%h expected=%h",cycles,d_send_to_noc_store_pkt__val,g_send_to_noc_store_pkt__val);
  endtask
  task automatic evaluate;#4;compare();endtask
  task automatic advance_cycle;#1;clk=1;#1;clk=0;cycles++;endtask
  task automatic tick;evaluate();advance_cycle();endtask
  task automatic read_local(input int addr,expected);
    integer done,issued,guard;done=0;issued=0;guard=0;
    while(!done && guard<80) begin
      idle();recv_raddr__msg[0]=7'(addr);recv_raddr__val[0]=!issued;send_rdata__rdy[0]=(guard%5>=2);
      evaluate();if(recv_raddr__val[0] && d_recv_raddr__rdy[0]) issued=1;
      if(d_send_rdata__val[0] && !send_rdata__rdy[0]) stall_samples++;
      if(d_send_rdata__val[0] && send_rdata__rdy[0]) begin
        if(intentional_failure) expected++;
        if(d_send_rdata__msg[0]!=={32'(expected),3'b100}) $fatal(1,"MEM_MATH_MISMATCH%s addr=%0d value=%h expected=%0d",intentional_failure?" intentional negative control":"",addr,d_send_rdata__msg[0],expected);
        done=1;local_reads++;end
      advance_cycle();guard++;end
    if(!done || !issued) $fatal(1,"MEM_TIMEOUT local read");endtask
  initial begin #50000;$fatal(1,"MEM_TIMEOUT wall clock");end
  initial begin
    clk=0;cycles=0;local_writes=0;local_reads=0;noc_stores=0;noc_reads=0;remote_loads=0;remote_stores=0;stall_samples=0;
    intentional_failure=$test$plusargs("EXPECT_FAILURE");
    if(!$value$plusargs("RESULT=%s",result_path)) result_path="memory-result.json";
    idle();reset=1;repeat(3) tick();idle();
    for(int p=0;p<3;p++) count[p]=0;
    stage_steps=0;
    while((count[0]<8 || count[1]<8 || count[2]<8) && stage_steps<100) begin
      idle();for(int p=0;p<3;p++) begin
        recv_waddr__msg[p]=7'(8*p+count[p]);recv_wdata__msg[p]={32'(256+16*p+count[p]),3'b100};
        recv_waddr__val[p]=count[p]<8;recv_wdata__val[p]=count[p]<8;end
      evaluate();for(int p=0;p<3;p++) begin
        if(recv_waddr__val[p] && d_recv_waddr__rdy[p] && d_recv_wdata__rdy[p]) begin count[p]++;local_writes++;end
        else if(recv_waddr__val[p]) stall_samples++;end
      advance_cycle();stage_steps++;end
    if(local_writes!=24) $fatal(1,"MEM_TIMEOUT writes");idle();repeat(12) tick();
    for(int a=0;a<24;a++) read_local(a,256+16*(a/8)+a%8);
    idle();recv_from_noc_store_request__msg=packet(12,24,1365,3,2,0);recv_from_noc_store_request__val=1;
    accepted=0;stage_steps=0;while(!accepted && stage_steps<50) begin evaluate();accepted=d_recv_from_noc_store_request__rdy;advance_cycle();stage_steps++;end
    if(!accepted) $fatal(1,"MEM_TIMEOUT inbound store");noc_stores++;idle();repeat(12) tick();read_local(24,1365);
    accepted=0;replied=0;stage_steps=0;
    while(!replied && stage_steps<80) begin
      idle();recv_from_noc_load_request__msg=packet(10,24,0,2,3,0);recv_from_noc_load_request__val=!accepted;
      send_to_noc_load_response_pkt__rdy=stage_steps>6 && stage_steps%3!=0;
      evaluate();if(recv_from_noc_load_request__val && d_recv_from_noc_load_request__rdy) accepted=1;
      if(d_send_to_noc_load_response_pkt__val && !send_to_noc_load_response_pkt__rdy) stall_samples++;
      if(d_send_to_noc_load_response_pkt__val && send_to_noc_load_response_pkt__rdy) begin
        if(d_send_to_noc_load_response_pkt__msg[164+:6]!=6'(11)) $fatal(1,"MEM_REMOTE_REPLY payload.cmd");
        if(d_send_to_noc_load_response_pkt__msg[132+:32]!=32'(1365)) $fatal(1,"MEM_REMOTE_REPLY payload.data.payload");
        if(d_send_to_noc_load_response_pkt__msg[131+:1]!=1'(1)) $fatal(1,"MEM_REMOTE_REPLY payload.data.predicate");
        if(d_send_to_noc_load_response_pkt__msg[191+:2]!=2'(2)) $fatal(1,"MEM_REMOTE_REPLY dst");
        if(d_send_to_noc_load_response_pkt__msg[181+:3]!=3'(3)) $fatal(1,"MEM_REMOTE_REPLY dst_tile_id");
        replied=1;noc_reads++;end
      advance_cycle();stage_steps++;end
    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT incoming NoC load");
    accepted=0;replied=0;stage_steps=0;
    while(!replied && stage_steps<80) begin
      idle();recv_raddr__msg[0]=7'd64;recv_raddr__val[0]=!accepted;send_to_noc_load_request_pkt__rdy=stage_steps>5;
      evaluate();if(recv_raddr__val[0] && d_recv_raddr__rdy[0]) accepted=1;
      if(d_send_to_noc_load_request_pkt__val && !send_to_noc_load_request_pkt__rdy) stall_samples++;
      if(d_send_to_noc_load_request_pkt__val && send_to_noc_load_request_pkt__rdy) begin
        if(d_send_to_noc_load_request_pkt__msg[164+:6]!=6'(10)) $fatal(1,"MEM_REMOTE_REQUEST payload.cmd");
        if(d_send_to_noc_load_request_pkt__msg[122+:7]!=7'(64)) $fatal(1,"MEM_REMOTE_REQUEST payload.data_addr");
        if(d_send_to_noc_load_request_pkt__msg[180+:1]!=1'(0)) $fatal(1,"MEM_REMOTE_REQUEST remote_src_port");
        replied=1;remote_loads++;end
      advance_cycle();stage_steps++;end
    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT outbound load");
    accepted=0;replied=0;stage_steps=0;
    while(!replied && stage_steps<80) begin
      idle();recv_from_noc_load_response_pkt__msg=packet(11,64,51966,2,0,0);recv_from_noc_load_response_pkt__val=!accepted;
      send_rdata__rdy[0]=stage_steps>5;evaluate();
      if(recv_from_noc_load_response_pkt__val && d_recv_from_noc_load_response_pkt__rdy) accepted=1;
      if(d_send_rdata__val[0] && send_rdata__rdy[0]) begin
        if(d_send_rdata__msg[0]!=={32'd51966,3'b100}) $fatal(1,"MEM_REMOTE_DATA");replied=1;end
      advance_cycle();stage_steps++;end
    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT load reply");
    for(int p=0;p<3;p++) count[p]=0;seen_stores=0;stage_steps=0;
    while(seen_stores!=7 && stage_steps<100) begin
      idle();for(int p=0;p<3;p++) begin recv_waddr__msg[p]=7'(64+p);recv_wdata__msg[p]={32'(2304+p),3'b100};recv_waddr__val[p]=!count[p];recv_wdata__val[p]=!count[p];end
      send_to_noc_store_pkt__rdy=stage_steps>8 && stage_steps%3!=0;evaluate();
      for(int p=0;p<3;p++) if(recv_waddr__val[p] && d_recv_waddr__rdy[p] && d_recv_wdata__rdy[p]) count[p]=1;
      if(d_send_to_noc_store_pkt__val && !send_to_noc_store_pkt__rdy) stall_samples++;
      if(d_send_to_noc_store_pkt__val && send_to_noc_store_pkt__rdy) begin
        read_index=int'(d_send_to_noc_store_pkt__msg[122+:7])-64;
        if(read_index<0 || read_index>2 || (seen_stores&(1<<read_index))) $fatal(1,"remote store identity");
        if(d_send_to_noc_store_pkt__msg[164+:6]!=6'(12)) $fatal(1,"MEM_REMOTE_STORE payload.cmd");
        if(d_send_to_noc_store_pkt__msg[132+:32]!=32'(2304+read_index)) $fatal(1,"MEM_REMOTE_STORE payload.data.payload");
        if(d_send_to_noc_store_pkt__msg[180+:1]!=1'(read_index%2)) $fatal(1,"MEM_REMOTE_STORE remote_src_port");
        seen_stores|=1<<read_index;remote_stores++;end
      advance_cycle();stage_steps++;end
    if(seen_stores!=7) $fatal(1,"MEM_TIMEOUT remote stores");idle();repeat(12) tick();
    // Additional deterministic raw-cycle traffic; this phase is not scored as a transaction model.
    repeat(300) begin
      idle();reset=(cycles%79==0);recv_raddr__msg[0]=7'(random32());recv_raddr__val[0]=1'(random32());send_rdata__rdy[0]=1'(random32());
      for(int p=0;p<3;p++) begin recv_waddr__msg[p]=7'(random32());recv_wdata__msg[p]={random32(),3'(random32())};recv_waddr__val[p]=1'(random32());recv_wdata__val[p]=1'(random32());end
      recv_from_noc_load_request__msg=packet(10,int'(random32()%32),0,2,1,0);recv_from_noc_load_request__val=1'(random32());
      recv_from_noc_store_request__msg=packet(12,int'(random32()%32),int'(random32()),3,2,0);recv_from_noc_store_request__val=1'(random32());
      recv_from_noc_load_response_pkt__msg=packet(11,64,int'(random32()),2,0,0);recv_from_noc_load_response_pkt__val=1'(random32());
      send_to_noc_load_request_pkt__rdy=1'(random32());send_to_noc_load_response_pkt__rdy=1'(random32());send_to_noc_store_pkt__rdy=1'(random32());tick();end
    if(local_writes!=24 || local_reads!=25 || noc_stores!=1 || noc_reads!=1 || remote_loads!=1 || remote_stores!=3 || stall_samples<8) $fatal(1,"MEM_COVERAGE");
    fd=$fopen(result_path,"w");if(fd==0) $fatal(1,"cannot write result");
    $fdisplay(fd,"{\"status\":\"pass\",\"cycles\":%0d,\"raw_bits_per_cycle\":669,\"local_writes\":24,\"local_reads\":25,\"noc_inbound_store\":1,\"noc_inbound_load\":1,\"remote_load\":1,\"remote_store\":3,\"stall_samples\":%0d}",cycles,stall_samples);
    $fclose(fd);$display("PHASE4_MEMORY_PASS cycles=%0d stalls=%0d",cycles,stall_samples);$finish;end
endmodule
