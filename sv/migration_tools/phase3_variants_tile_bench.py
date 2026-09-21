"""Emit native SV replay benches from frozen unmodified Python port manifests."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--kind',choices=['context','streaming'],required=True)
ap.add_argument('--label',default='tile-pyreplay');a=ap.parse_args()
folder=f'{a.kind}-{a.label}'
m=json.loads((ROOT/'sv/reference/phase3/tile_variants'/folder/'manifest.json').read_text())
n=m['parameters']['TILE_PORTS']; stream=a.kind=='streaming'
header=(ROOT/'sv/rtl/tile/variants/tile_variant_core.sv').read_text().split(') (',1)[1].split('\n);',1)[0]
s=['`timescale 1ns/1ps',f'module tb_tile_{a.kind};',
f'  localparam TILE_PORTS={n}, DATA_BITS=35, TILE_ID_W=3, CTRL_ADDR_W=3, GLOBAL_ADDR_W=7, HOST_BITS={215 if stream else 191};']
for line in header.splitlines():
  match=re.search(r'(?:input|output)\s+logic\s+(\[[^]]+\])\s*(\w+)\s*(\[[^]]+\])?',line)
  if match:s.append(f'  logic {match[1]} {match[2]} {match[3] or ""};')
fu_count=4 if stream else 5
fu_kinds="{8'd3,8'd32,8'd1,8'd0}" if stream else "{8'd3,8'd2,8'd1,8'd0,8'd9}"
s.append(f'  tile_{a.kind} #(.TILE_PORTS({n}),.NUM_CTRL({2 if stream else 1}),.TOTAL_STEPS({2 if stream else 6}),.FU_COUNT({fu_count}),.FU_KINDS({fu_kinds})) dut(.*);')
ib=sum(w for _,w in m['inputs']);ob=sum(w for _,w in m['outputs'])
s.extend([f'  logic [{ib-1}:0] stimulus;',f'  logic [{ob-1}:0] expected, actual;',
  '  integer fd, rc, cycle=0, outputs_seen=0, completions=0, requests=0;',
  '  integer expected_value[0:5];',
  '  assign actual={'+','.join(name for name,_ in m['outputs'])+'};',
  '  initial begin',
  '    clk=0; expected_value[0]=4; expected_value[1]=12; expected_value[2]=0; expected_value[3]=0; expected_value[4]=20; expected_value[5]=28;',
  f'    fd=$fopen("reference/phase3/tile_variants/{folder}/cycles.txt","r");',
  '    if(!fd) $fatal(1,"missing frozen tile reference");',
  '    while(!$feof(fd)) begin',
  '      rc=$fscanf(fd,"%h %h\\n",stimulus,expected);',
  '      if(rc!=2) $fatal(1,"malformed tile trace");',
  '      {'+','.join(name for name,_ in m['inputs'])+'}=stimulus;',
  '      #4;',
  '      if($test$plusargs("EXPECT_FAILURE") && cycle==20) expected[0]=~expected[0];',
  '      if(actual!==expected) $fatal(1,"tile replay mismatch cycle=%0d actual=%h expected=%h xor=%h",cycle,actual,expected,actual^expected);',
  '      if(send_data__val[0] && send_data__rdy[0]) begin'])
if stream:s.extend(['        if(send_data__msg[0] !== 35\'((((10+2*(outputs_seen%5))*7+1)<<3)|4)) $fatal(1,"independent streaming Tile output");'])
else:s.extend(['        if(cycle<95 && send_data__msg[0] !== 35\'(expected_value[outputs_seen])) $fatal(1,"independent context Tile output");'])
s.extend(['        outputs_seen++;','      end','      if(send_to_controller_pkt__val && send_to_controller_pkt__rdy) completions++;',
'      if(to_mem_raddr__val && to_mem_raddr__rdy) begin',
'        if(to_mem_raddr__msg !== 7\'(10+2*(requests%5))) $fatal(1,"independent streaming Tile request");',
'        requests++;','      end'])
if not stream and m['cycles']>190:s.extend([
'      if(cycle==193) for(int i=0;i<TILE_PORTS;i++) if(recv_data__rdy[i]!==0) $fatal(1,"clear setup requires full channels");',
'      if(cycle==195) for(int i=0;i<TILE_PORTS;i++) if(recv_data__rdy[i]!==1) $fatal(1,"TERMINATE failed to clear channels");'])
s.extend([
'      clk=1; #1; clk=0; #1; cycle++;','    end',
f'    if(cycle!={m["cycles"]} || outputs_seen!={10 if stream else 12} || completions!=2 || requests!={10 if stream else 0})',
'      $fatal(1,"incomplete Tile coverage cycles=%0d outputs=%0d complete=%0d req=%0d",cycle,outputs_seen,completions,requests);',
f'    $display("TILE_{a.kind.upper()}_PASS cycles=%0d outputs=%0d complete=%0d requests=%0d",cycle,outputs_seen,completions,requests);',
'    $finish;','  end','endmodule'])
(ROOT/f'sv/tests/phase3/tile_variants/tb_tile_{a.kind}.sv').write_text('\n'.join(s)+'\n',newline='\n')
