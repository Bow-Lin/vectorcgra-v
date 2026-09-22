"""Write the checked-in asymmetric memory SV test; original HDL stays frozen."""
import json,re
from pathlib import Path

SV=Path(__file__).resolve().parents[1]
ref=SV/'reference/phase4/memory/r1w3';m=json.loads((ref/'manifest.json').read_text())
assert m['status']=='exported'
out=SV/'tests/phase4/memory';out.mkdir(parents=True,exist_ok=True)
fields={f['field']:f for f in m['packet']['fields']};nw=m['packet']['nbits']
ports=[]
for line in (ref/'top_ports.txt').read_text().splitlines():
  match=re.match(r'\s*(input|output)\s+(logic\s+\[\d+:\d+\]|\w+)\s+(\w+)\s*(\[\d+:\d+\])?',line)
  if not match:continue
  direction,kind,name,array=match.groups()
  width=int(re.search(r'\[(\d+):',kind).group(1))+1 if kind.startswith('logic') else \
    35 if kind.startswith('CgraData') else 32 if kind.startswith(('DmaSpmReadReq','DmaSpmReadResp')) else 68 if kind.startswith('DmaSpmWriteReq') else nw
  ports.append(dict(direction=direction,width=width,name=name,count=int(array[3:-1])+1 if array else 0))
assert len(ports)>35
decl=[];dc=[];gc=[];outputs=[];defaults=[]
for p in ports:
  names=[p['name']] if p['direction']=='input' else ['d_'+p['name'],'g_'+p['name']]
  for name in names:decl.append(f"  logic [{p['width']-1}:0] {name}"+(f"[0:{p['count']-1}]" if p['count'] else '')+';')
  dc.append(f".{p['name']}({names[0]})");gc.append(f".{p['name']}({names[0] if p['direction']=='input' else names[1]})")
  entries=[p['name']+f'[{i}]' for i in range(p['count'])] if p['count'] else [p['name']]
  if p['direction']=='output':outputs += [(n,p['width']) for n in entries]
  elif p['name']!='clk':defaults += [f"    {n}='0;" for n in entries]
lines=['`timescale 1ns/1ps','module tb_memory_asymmetric;',*decl,
  '  cgra_data_memory #('+','.join(f'.{k}({v})' for k,v in m['parameters'].items())+') dut ('+','.join(dc)+');',
  '  '+m['top']+' gold ('+','.join(gc)+');',
  f'  localparam int NOC_W={nw};',
  '  integer cycles,local_writes,local_reads,noc_stores,noc_reads,remote_loads,remote_stores,stall_samples;',
  '  integer count[0:2],stage_steps,read_index,data_expected,accepted,replied,seen_stores,fd;',
  "  logic [31:0] rng=32'h50a4c311; bit intentional_failure; string result_path;",
  "  function automatic logic[31:0] random32();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction",
  '  function automatic logic[NOC_W-1:0] packet(input int cmd,addr,value,source,tile,port);',
  "    logic[NOC_W-1:0] p;p='0;"]
for name,expression in [('payload.cmd','cmd'),('payload.data_addr','addr'),('payload.data.payload','value'),('payload.data.predicate','1'),('src','source'),('src_tile_id','tile'),('remote_src_port','port')]:
  f=fields[name];lines.append(f"    p[{f['lsb']}+:{f['nbits']}]={f['nbits']}'({expression});")
lines += ['    return p;endfunction','  task automatic idle;',*defaults,
  "    address_upper=7'd31;","    send_rdata__rdy[0]=1;send_to_noc_load_request_pkt__rdy=1;send_to_noc_load_response_pkt__rdy=1;send_to_noc_store_pkt__rdy=1;",'  endtask',
  '  task automatic compare;']
for name,_ in outputs:lines.append(f'    if(d_{name}!==g_{name}) $fatal(1,"MEM_RAW_DIFF cycle=%0d field={name} actual=%h expected=%h",cycles,d_{name},g_{name});')
lines += ['  endtask','  task automatic evaluate;#4;compare();endtask',
  '  task automatic edge;#1;clk=1;#1;clk=0;cycles++;endtask',
  '  task automatic tick;evaluate();edge();endtask',
  '  task automatic read_local(input int addr,expected);',
  '    integer done,issued,guard;done=0;issued=0;guard=0;',
  '    while(!done && guard<80) begin',
  "      idle();recv_raddr__msg[0]=7'(addr);recv_raddr__val[0]=!issued;send_rdata__rdy[0]=(guard%5>=2);",
  '      evaluate();if(recv_raddr__val[0] && d_recv_raddr__rdy[0]) issued=1;',
  '      if(d_send_rdata__val[0] && !send_rdata__rdy[0]) stall_samples++;',
  '      if(d_send_rdata__val[0] && send_rdata__rdy[0]) begin',
  '        if(intentional_failure) expected++;',
  "        if(d_send_rdata__msg[0]!=={32'(expected),3'b100}) $fatal(1,\"MEM_MATH_MISMATCH%s addr=%0d value=%h expected=%0d\",intentional_failure?\" intentional negative control\":\"\",addr,d_send_rdata__msg[0],expected);",
  '        done=1;local_reads++;end',
  '      edge();guard++;end',
  '    if(!done || !issued) $fatal(1,"MEM_TIMEOUT local read");endtask',
  '  initial begin #50000;$fatal(1,"MEM_TIMEOUT wall clock");end',
  '  initial begin',
  '    clk=0;cycles=0;local_writes=0;local_reads=0;noc_stores=0;noc_reads=0;remote_loads=0;remote_stores=0;stall_samples=0;',
  '    intentional_failure=$test$plusargs("EXPECT_FAILURE");',
  '    if(!$value$plusargs("RESULT=%s",result_path)) result_path="memory-result.json";',
  '    idle();reset=1;repeat(3) tick();idle();',
  '    for(int p=0;p<3;p++) count[p]=0;',
  '    stage_steps=0;',
  '    while((count[0]<8 || count[1]<8 || count[2]<8) && stage_steps<100) begin',
  '      idle();for(int p=0;p<3;p++) begin',
  "        recv_waddr__msg[p]=7'(8*p+count[p]);recv_wdata__msg[p]={32'(256+16*p+count[p]),3'b100};",
  '        recv_waddr__val[p]=count[p]<8;recv_wdata__val[p]=count[p]<8;end',
  '      evaluate();for(int p=0;p<3;p++) begin',
  '        if(recv_waddr__val[p] && d_recv_waddr__rdy[p] && d_recv_wdata__rdy[p]) begin count[p]++;local_writes++;end',
  '        else if(recv_waddr__val[p]) stall_samples++;end',
  '      edge();stage_steps++;end',
  '    if(local_writes!=24) $fatal(1,"MEM_TIMEOUT writes");idle();repeat(12) tick();',
  '    for(int a=0;a<24;a++) read_local(a,256+16*(a/8)+a%8);',
  '    idle();recv_from_noc_store_request__msg=packet(12,24,1365,3,2,0);recv_from_noc_store_request__val=1;',
  '    accepted=0;stage_steps=0;while(!accepted && stage_steps<50) begin evaluate();accepted=d_recv_from_noc_store_request__rdy;edge();stage_steps++;end',
  '    if(!accepted) $fatal(1,"MEM_TIMEOUT inbound store");noc_stores++;idle();repeat(12) tick();read_local(24,1365);',
  '    accepted=0;replied=0;stage_steps=0;',
  '    while(!replied && stage_steps<80) begin',
  '      idle();recv_from_noc_load_request__msg=packet(10,24,0,2,3,0);recv_from_noc_load_request__val=!accepted;',
  '      send_to_noc_load_response_pkt__rdy=stage_steps>6 && stage_steps%3!=0;',
  '      evaluate();if(recv_from_noc_load_request__val && d_recv_from_noc_load_request__rdy) accepted=1;',
  '      if(d_send_to_noc_load_response_pkt__val && !send_to_noc_load_response_pkt__rdy) stall_samples++;',
  '      if(d_send_to_noc_load_response_pkt__val && send_to_noc_load_response_pkt__rdy) begin']
for name,expected in [('payload.cmd',11),('payload.data.payload',1365),('payload.data.predicate',1),('dst',2),('dst_tile_id',3)]:
  f=fields[name];lines.append(f"        if(d_send_to_noc_load_response_pkt__msg[{f['lsb']}+:{f['nbits']}]!={f['nbits']}'({expected})) $fatal(1,\"MEM_REMOTE_REPLY {name}\");")
lines += ['        replied=1;noc_reads++;end','      edge();stage_steps++;end',
  '    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT incoming NoC load");',
  '    accepted=0;replied=0;stage_steps=0;',
  '    while(!replied && stage_steps<80) begin',
  "      idle();recv_raddr__msg[0]=7'd64;recv_raddr__val[0]=!accepted;send_to_noc_load_request_pkt__rdy=stage_steps>5;",
  '      evaluate();if(recv_raddr__val[0] && d_recv_raddr__rdy[0]) accepted=1;',
  '      if(d_send_to_noc_load_request_pkt__val && !send_to_noc_load_request_pkt__rdy) stall_samples++;',
  '      if(d_send_to_noc_load_request_pkt__val && send_to_noc_load_request_pkt__rdy) begin']
for name,expected in [('payload.cmd',10),('payload.data_addr',64),('remote_src_port',0)]:
  f=fields[name];lines.append(f"        if(d_send_to_noc_load_request_pkt__msg[{f['lsb']}+:{f['nbits']}]!={f['nbits']}'({expected})) $fatal(1,\"MEM_REMOTE_REQUEST {name}\");")
lines += ['        replied=1;remote_loads++;end','      edge();stage_steps++;end',
  '    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT outbound load");',
  '    accepted=0;replied=0;stage_steps=0;',
  '    while(!replied && stage_steps<80) begin',
  '      idle();recv_from_noc_load_response_pkt__msg=packet(11,64,51966,2,0,0);recv_from_noc_load_response_pkt__val=!accepted;',
  '      send_rdata__rdy[0]=stage_steps>5;evaluate();',
  '      if(recv_from_noc_load_response_pkt__val && d_recv_from_noc_load_response_pkt__rdy) accepted=1;',
  '      if(d_send_rdata__val[0] && send_rdata__rdy[0]) begin',
  "        if(d_send_rdata__msg[0]!=={32'd51966,3'b100}) $fatal(1,\"MEM_REMOTE_DATA\");replied=1;end",
  '      edge();stage_steps++;end','    if(!accepted || !replied) $fatal(1,"MEM_TIMEOUT load reply");',
  '    for(int p=0;p<3;p++) count[p]=0;seen_stores=0;stage_steps=0;',
  '    while(seen_stores!=7 && stage_steps<100) begin',
  "      idle();for(int p=0;p<3;p++) begin recv_waddr__msg[p]=7'(64+p);recv_wdata__msg[p]={32'(2304+p),3'b100};recv_waddr__val[p]=!count[p];recv_wdata__val[p]=!count[p];end",
  '      send_to_noc_store_pkt__rdy=stage_steps>8 && stage_steps%3!=0;evaluate();',
  '      for(int p=0;p<3;p++) if(recv_waddr__val[p] && d_recv_waddr__rdy[p] && d_recv_wdata__rdy[p]) count[p]=1;',
  '      if(d_send_to_noc_store_pkt__val && !send_to_noc_store_pkt__rdy) stall_samples++;',
  '      if(d_send_to_noc_store_pkt__val && send_to_noc_store_pkt__rdy) begin']
f=fields['payload.data_addr'];lines.append(f"        read_index=int'(d_send_to_noc_store_pkt__msg[{f['lsb']}+:{f['nbits']}])-64;")
lines += ['        if(read_index<0 || read_index>2 || (seen_stores&(1<<read_index))) $fatal(1,"remote store identity");']
for name,expr in [('payload.cmd','12'),('payload.data.payload','2304+read_index'),('remote_src_port','read_index%2')]:
  f=fields[name];lines.append(f"        if(d_send_to_noc_store_pkt__msg[{f['lsb']}+:{f['nbits']}]!={f['nbits']}'({expr})) $fatal(1,\"MEM_REMOTE_STORE {name}\");")
lines += ['        seen_stores|=1<<read_index;remote_stores++;end','      edge();stage_steps++;end',
  '    if(seen_stores!=7) $fatal(1,"MEM_TIMEOUT remote stores");idle();repeat(12) tick();',
  '    // Additional deterministic raw-cycle traffic; this phase is not scored as a transaction model.',
  '    repeat(300) begin',
  "      idle();reset=(cycles%79==0);recv_raddr__msg[0]=7'(random32());recv_raddr__val[0]=1'(random32());send_rdata__rdy[0]=1'(random32());",
  "      for(int p=0;p<3;p++) begin recv_waddr__msg[p]=7'(random32());recv_wdata__msg[p]={random32(),3'(random32())};recv_waddr__val[p]=1'(random32());recv_wdata__val[p]=1'(random32());end",
  "      recv_from_noc_load_request__msg=packet(10,int'(random32()%32),0,2,1,0);recv_from_noc_load_request__val=1'(random32());",
  "      recv_from_noc_store_request__msg=packet(12,int'(random32()%32),int'(random32()),3,2,0);recv_from_noc_store_request__val=1'(random32());",
  "      recv_from_noc_load_response_pkt__msg=packet(11,64,int'(random32()),2,0,0);recv_from_noc_load_response_pkt__val=1'(random32());",
  "      send_to_noc_load_request_pkt__rdy=1'(random32());send_to_noc_load_response_pkt__rdy=1'(random32());send_to_noc_store_pkt__rdy=1'(random32());tick();end",
  '    if(local_writes!=24 || local_reads!=25 || noc_stores!=1 || noc_reads!=1 || remote_loads!=1 || remote_stores!=3 || stall_samples<8) $fatal(1,"MEM_COVERAGE");',
  '    fd=$fopen(result_path,"w");if(fd==0) $fatal(1,"cannot write result");',
  f'    $fdisplay(fd,"{{\\"status\\":\\"pass\\",\\"cycles\\":%0d,\\"raw_bits_per_cycle\\":{sum(w for _,w in outputs)},\\"local_writes\\":24,\\"local_reads\\":25,\\"noc_inbound_store\\":1,\\"noc_inbound_load\\":1,\\"remote_load\\":1,\\"remote_store\\":3,\\"stall_samples\\":%0d}}",cycles,stall_samples);',
  '    $fclose(fd);$display("PHASE4_MEMORY_PASS cycles=%0d stalls=%0d",cycles,stall_samples);$finish;end','endmodule']
(out/'tb_memory_asymmetric.sv').write_text(re.sub(r'\bedge\b','advance_cycle','\n'.join(lines))+'\n',newline='\n')
print('WROTE memory r1w3 '+str(len(outputs))+' raw output fields')
