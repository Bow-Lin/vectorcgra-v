"""Emit SV-only full-CGRA replay benches and independent expected outputs."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--kind',choices=['context','streaming'],required=True)
ap.add_argument('--label',default='cgra-pyreplay');a=ap.parse_args();stream=a.kind=='streaming'
folder=f'{a.kind}-{a.label}'
m=json.loads((ROOT/'sv/reference/phase3/tile_variants'/folder/'manifest.json').read_text())
header=(ROOT/'sv/tests/legacy/rtl/cgra/cgra_programmable.sv').read_text().split(') (',1)[1].split('\n);',1)[0]
s=['`timescale 1ns/1ps',f'module tb_cgra_{a.kind};',
f'  localparam COLS=2, ROWS=2, DATA_W=32, DATA_BITS=35, TILE_PORTS={8 if stream else 4}, GLOBAL_ADDR_W=7, CTRL_ADDR_W=3, REG_ADDR_W=4, TILE_ID_W=3;',
f'  localparam ROUTING_OUTPUTS={12 if stream else 8}, ROUTING_SEL_W=4, CTRL_BITS={143 if stream else 119}, PAYLOAD_BITS={194 if stream else 170}, HOST_BITS={215 if stream else 191}, NOC_BITS={218 if stream else 194}, MEM_PORT_W=2, BANK_PORT_W=2;',
'  `include "cgra_profile.svh"']
names=[]
for line in header.splitlines():
  match=re.search(r'(?:input|output)\s+logic\s*(\[[^]]+\])?\s+(.+)',line)
  if not match:continue
  width=match[1] or ''
  for item in match[2].strip().rstrip(',').split(','):
    s.append(f'  logic {width} {item.strip()};');names.append(item.strip().split()[0])
fu_kinds="{8'd3,8'd32,8'd1,8'd0}" if stream else "{8'd3,8'd2,8'd1,8'd0,8'd9}"
s.append(f'  cgra_programmable #(.TILE_PORTS(TILE_PORTS),.TILE_VARIANT({2 if stream else 1}),.FU_COUNT({4 if stream else 5}),.FU_KINDS({fu_kinds})) dut(.*);')
ib=sum(w for _,w in m['inputs']);ob=sum(w for _,w in m['outputs'])
s.extend([f'  logic [{ib-1}:0] stimulus;',f'  logic [{ob-1}:0] expected, actual;',
'  host_packet_t response; data_t west_data;',
'  assign response=send_to_cpu_pkt__msg; assign west_data=send_data_on_boundary_west__msg[1];',
'  integer fd,rc,cycle=0,west_events=0,completions=0,reads=0;',
'  logic [31:0] expected_west[0:9];',
'  assign actual={'+','.join(name for name,_ in m['outputs'])+'};',
'  initial begin','    clk=0;'])
expect=[v for scenario in m['scenarios'] for v in scenario['expected']]
for i,v in enumerate(expect):s.append(f"    expected_west[{i}]=32'h{v:08x};")
s.extend([f'    fd=$fopen("reference/phase3/tile_variants/{folder}/cycles.txt","r");',
'    if(!fd) $fatal(1,"missing full CGRA Python replay");',
'    while(!$feof(fd)) begin',
'      rc=$fscanf(fd,"%h %h\\n",stimulus,expected);',
'      if(rc!=2) $fatal(1,"bad CGRA replay row");',
'      {'+','.join(name for name,_ in m['inputs'])+'}=stimulus;',
'      #4;',
'      if($test$plusargs("EXPECT_FAILURE") && cycle==20) expected[0]=~expected[0];',
'      if(actual!==expected) $fatal(1,"CGRA replay mismatch cycle=%0d actual=%h expected=%h xor=%h",cycle,actual,expected,actual^expected);',
'      if(send_data_on_boundary_west__val[1] && send_data_on_boundary_west__rdy[1]) begin',
f'        if(west_events>={len(expect)} || west_data.payload!==expected_west[west_events] || west_data.predicate!==1) $fatal(1,"independent CGRA arithmetic mismatch");',
'        west_events++;','      end',
'      if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin',
'        if(response.payload.cmd==14) completions++;',
'        else if(response.payload.cmd==11) reads++;',
'        else $fatal(1,"unexpected CPU response");','      end',
'      clk=1; #1; clk=0; #1; cycle++;','    end',
f'    if(cycle!={m["cycles"]} || west_events!={len(expect)} || completions!=8 || reads!=4) $fatal(1,"incomplete full CGRA coverage");',
f'    $display("CGRA_{a.kind.upper()}_PASS cycles=%0d outputs=%0d complete=%0d reads=%0d",cycle,west_events,completions,reads);',
'    $finish;','  end','endmodule'])
(ROOT/f'sv/tests/phase3/tile_variants/tb_cgra_{a.kind}.sv').write_text('\n'.join(s)+'\n',newline='\n')
