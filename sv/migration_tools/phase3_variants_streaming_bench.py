"""Emit a retained SV-only StreamingMem HDL differential/independent test."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
src=(ROOT/'sv/rtl/fu/streaming/tile_streaming_memory_fu.sv').read_text()
header=src[src.index(') (')+3:src.index('\n);')]
ports=[]
for line in header.splitlines():
  m=re.search(r'(input|output)\s+logic\s*(\[[^]]+\])?\s*(\w+)\s*(\[[^]]+\])?',line)
  if m: ports.append(m.groups())
s=['`timescale 1ns/1ps','`include "cgra_profile_defs.svh"','module tb_streaming_memory;',
'  localparam COLS=2, ROWS=2, DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16, BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8, TOTAL_STEPS=8, TILE_PORTS=8;',
'  localparam DATA_BITS=35, CTRL_ADDR_W=3, REG_ADDR_W=4, TILE_ID_W=3, ROUTING_OUTPUTS=12, ROUTING_SEL_W=4, CTRL_BITS=143, PAYLOAD_BITS=194, HOST_BITS=215, MEM_PORT_W=2, BANK_PORT_W=2, NOC_BITS=218;',
'  `include "cgra_profile.svh"']
for direction,width,name,array in ports:
  for prefix in (['d_','g_'] if direction=='output' else ['']):
    s.append(f'  logic {width or ""} {prefix}{name} {array or ""};')
for module,inst,prefix in [('tile_streaming_memory_fu #(.TILE_PORTS(8))','dut','d_'),('Phase3StreamingW32C8R16','gold','g_')]:
  s.append(f'  {module} {inst} (')
  s.append(',\n'.join(f'    .{name}({prefix if direction=="output" else ""}{name})' for direction,width,name,array in ports))
  s.append('  );')
s.extend(['  ctrl_t control; host_packet_t packet; data_t response;',
'  assign recv_opt__msg=control; assign recv_from_controller_pkt__msg=packet; assign from_mem_rdata__msg=response;',
'  integer cycle=0, requests=0, responses=0, completions=0, head=0, tail=0;',
'  integer request_time[0:31], request_address[0:31];',
'  bit finished=0; integer random_seed=31415926;',
'  task automatic tick;', '    #4;'])
for direction,width,name,array in ports:
  if direction!='output': continue
  if array:
    n=2 if 'send_out' in name else 4
    s.append(f'    for(int i=0;i<{n};i++) if(d_{name}[i] !== g_{name}[i]) $fatal(1,"stream mismatch {name} cycle=%0d index=%0d",cycle,i);')
  else:
    reference=f'(g_{name} ^ ($test$plusargs("EXPECT_FAILURE") && cycle==20))' if name=='from_mem_rdata__rdy' else f'g_{name}'
    s.append(f'    if(d_{name} !== {reference}) $fatal(1,"stream mismatch {name} cycle=%0d actual=%h expected=%h",cycle,d_{name},g_{name});')
s.extend(['    clk=1; #1; clk=0; #1; cycle++;','  endtask','  initial begin','    clk=0; reset=1; clear=0; ctrl_addr_inport=0; control=\'0; packet=\'0; response=\'0;'])
for direction,width,name,array in ports:
  if direction!='input' or name in ['clk','reset','clear','ctrl_addr_inport','recv_opt__msg','recv_from_controller_pkt__msg','from_mem_rdata__msg']: continue
  if array:
    n=2 if 'send_out' in name else 4
    s.append(f"    for(int i=0;i<{n};i++) {name}[i]='0;")
  else:s.append(f"    {name}='0;")
s.append('''    repeat(3) tick(); reset=0;
    recv_from_controller_pkt__val=1;
    packet.payload.cmd=23; packet.payload.data.payload=10; tick();
    packet.payload.cmd=24; packet.payload.data.payload=2; tick();
    packet.payload.cmd=25; packet.payload.data.payload=18; tick();
    recv_from_controller_pkt__val=0; tick();
    control.operation=88; recv_opt__val=1; ctrl_addr_inport=1; tick();
    for(int t=0;t<50;t++) begin
      to_mem_raddr__rdy=(t%3!=0); send_out__rdy[0]=(t%5!=1 && t%5!=2);
      clear=(t==5); reset=(t==9); // Neither clears the streaming cursors/config.
      recv_opt__val=!finished;
      from_mem_rdata__val=(head<tail && t>=request_time[head]+4);
      response='0;
      if(from_mem_rdata__val) begin
        response.payload=32'(request_address[head]*7+1); response.predicate=1;
        response.bypass=1; response.delay=1;
      end
      #1;
      if(d_to_mem_raddr__val && to_mem_raddr__rdy) begin
        if(d_to_mem_raddr__msg !== 7'(10+2*requests) || requests>=5)
          $fatal(1,"stream independent request ordering");
        request_time[tail]=t; request_address[tail]=int'(d_to_mem_raddr__msg); tail++; requests++;
      end
      if(d_send_out__val[0] && send_out__rdy[0]) begin
        if(d_send_out__msg[0] !== response || responses>=5)
          $fatal(1,"stream independent response payload");
        head++; responses++;
      end
      if(d_recv_opt__rdy && recv_opt__val) begin
        if(responses!=5) $fatal(1,"stream early completion");
        completions++; finished=1;
      end
      tick();
    end
    if(requests!=5 || responses!=5 || completions!=1 || !finished)
      $fatal(1,"stream missing events req=%0d rsp=%0d done=%0d",requests,responses,completions);
    // Randomized raw inputs exercise idle messages, operation changes, reset,
    // clear, malformed/non-stream opcodes and vector-factor state against HDL.
    for(int t=0;t<300;t++) begin
      reset=(t%79==0); clear=$random(random_seed)&1; ctrl_addr_inport=3'($random(random_seed));
      control='0; control.operation=(t%4==0)?7'd88:7'($random(random_seed));
      control.vector_factor_power=3'($random(random_seed)); control.is_last_ctrl=$random(random_seed)&1;
      recv_opt__val=$random(random_seed)&1; send_out__rdy[0]=$random(random_seed)&1;
      from_mem_rdata__val=$random(random_seed)&1;
      response={32'($random(random_seed)),3'($random(random_seed))};
      to_mem_raddr__rdy=$random(random_seed)&1;
      recv_from_controller_pkt__val=$random(random_seed)&1;
      packet.payload.cmd=6'(23+(t%3)); packet.payload.data.payload=32'($random(random_seed));
      tick();
    end
    $display("STREAMING_MEMORY_PASS cycles=%0d requests=%0d responses=%0d completions=%0d",cycle,requests,responses,completions);
    $finish;
  end
endmodule
''')
out=ROOT/'sv/tests/phase3/tile_variants/tb_streaming_memory.sv'
out.write_text('\n'.join(s),newline='\n')
