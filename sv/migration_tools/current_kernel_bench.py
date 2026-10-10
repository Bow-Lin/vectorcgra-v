"""Emit a native replay bench from a frozen current-kernel manifest."""
import argparse
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--kernel',required=True)
ap.add_argument('--prefix-check',action='store_true',help='Compare an explicitly incomplete trace without claiming kernel completion')
a=ap.parse_args()
out=ROOT/'sv/reference/current/kernels'/a.kernel
m=json.loads((out/'manifest.json').read_text())
assert m['status']=='passed' or (a.prefix_check and m['status']=='incomplete'),m.get('error')
assert m['cycles'] > 0, 'No recorded cycles to compare'
source=(ROOT/'sv/rtl/cgra/cgra_system.sv').read_text()
ports=source[source.index(') (')+4:source.index(');')]
decl=[];zeros=[]
for line in ports.splitlines():
  match=re.match(r'\s*(input|output)\s+(.+?)\s*,?\s*$',line)
  if not match: continue
  side,definition=match.groups(); definition=definition.rstrip(',')
  decl.append('  '+definition+';')
  name=re.search(r'(\w+)\s*(\[0:([^\]]+)\])?$',definition)
  if side=='input':
    if name[2]: zeros.append(f"    for(int p=0;p<={name[3]};p++) {name[1]}[p]='0;")
    else: zeros.append(f"    {name[1]}='0;")
params=[f'-G{k}={v}' for k,v in m['parameters'].items()]
fu=m['fu_kinds'];packed=sum(v<<(i*8) for i,v in enumerate(fu))
params.extend([f'-GFU_COUNT={len(fu)}',f"-GFU_KINDS={len(fu)*8}'h{packed:x}"])
(out/('prefix-verilator.args' if a.prefix_check else 'verilator.args')).write_text('\n'.join(params)+'\n')
ins=m['inputs'];outs=m['outputs'];ib=sum(w for n,w in ins);ob=sum(w for n,w in outs)
s=['`timescale 1ns/1ps','`include "cgra_profile_defs.svh"','`include "cgra_fu_catalog.svh"',
   'module tb_current_kernel #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS);']+decl
s += ['  cgra_system #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND, .IS_MULTI(0)) dut(.*);',
      f'  logic [{ib-1}:0] stimulus;',f'  logic [{ob-1}:0] expected,actual;',
      '  int fd,rc,cycle=0,events=0;',
      '  assign actual={'+','.join(n for n,w in outs)+'};','  initial begin','    clk=0;']+zeros
s += [f'    fd=$fopen("reference/current/kernels/{a.kernel}/cycles.txt","r");',
      '    if(!fd)$fatal(1,"Missing kernel trace");','    while(!$feof(fd)) begin',
      '      rc=$fscanf(fd,"%h %h\\n",stimulus,expected);','      if(rc!=2)$fatal(1,"Malformed kernel trace");',
      '      {'+','.join(n for n,w in ins)+'}=stimulus;','      #5;',
      '      if($test$plusargs("NEGATIVE") && cycle==20) expected^=1;',
      f'      if(actual!==expected)$fatal(1,"CURRENT_KERNEL_MISMATCH kernel={a.kernel} cycle=%0d actual=%h expected=%h",cycle,actual,expected);',
      '      if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) events++;',
      '      clk=1;#5;clk=0;cycle++;','    end',
      f'    if(cycle!={m["cycles"]} || events!={len(m["events"])})$fatal(1,"Incomplete kernel replay");',
      f'    $display("CURRENT_KERNEL_PASS kernel={a.kernel} cycles=%0d host_events=%0d",cycle,events);',
      '    $finish;','  end','endmodule']
if a.prefix_check:
  s=[line.replace('tb_current_kernel','tb_current_kernel_prefix').replace('CURRENT_KERNEL_PASS','CURRENT_KERNEL_PREFIX_PASS') for line in s]
(out/('tb_current_kernel_prefix.sv' if a.prefix_check else 'tb_current_kernel.sv')).write_text('\n'.join(s)+'\n')
