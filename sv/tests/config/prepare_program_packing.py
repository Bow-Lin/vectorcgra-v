"""Cross-check packed Python values by assigning individual actual SV struct fields."""
import importlib.util
from pathlib import Path
import sys

sv = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('cgra_program', sv / 'tools/cgra_program.py')
p = importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
source = Path(sys.argv[1]);out = Path(sys.argv[2]);out.mkdir(parents=True, exist_ok=True)
c = p.configuration.normalize(p.configuration.load_json(source))
layouts = p.layouts(c)
lines = ['`timescale 1ns/1ps', '`include "cgra_profile_defs.svh"', '`include "cgra_fu_catalog.svh"',
         'module tb_program_packing #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS);',
         '  `include "cgra_profile.svh"', '  `include "architecture.svh"',
         '  data_t data;ctrl_t ctrl;payload_t payload;host_packet_t host;noc_packet_t noc;',
         '  int fd,rc,checks=0;', '  logic [NOC_BITS-1:0] expected;',
         '  task automatic check(input logic [NOC_BITS-1:0] actual);',
         '    rc=$fscanf(fd,"%h\\n",expected);if(rc!=1)$fatal(1,"PROGRAM_PACKING_VECTOR");',
         '    if(checks==0 && $test$plusargs("EXPECT_FAILURE"))expected^=1;',
         '    if(actual!==expected)$fatal(1,"PROGRAM_PACKING_MISMATCH check=%0d actual=%h expected=%h",checks,actual,expected);',
         '    checks++;', '  endtask', '  initial begin', '    string vectors;',
         '    if(!$value$plusargs("VECTORS=%s",vectors))$fatal(1,"VECTORS required");',
         '    fd=$fopen(vectors,"r");if(!fd)$fatal(1,"Missing packing vectors");']
vectors = []
for name, node in layouts.items():
  lines.append(f'    if($bits({name})!=CFG_{dict(data="DATA_BITS",ctrl="CTRL_BITS",payload="PAYLOAD_BITS",host="HOST_BITS",noc="NOC_BITS")[name]})$fatal(1,"PROGRAM_TYPE_WIDTH");')
  for field in p.layout_fields(node):
    path = field['field'];tokens = path.replace('[', '.').replace(']', '').split('.')
    lines += [f'    for(int bit_index=0;bit_index<$bits({name}.{path});bit_index++)begin',
              f"      {name}='0;{name}.{path}=1;{name}.{path}={name}.{path}<<bit_index;check(NOC_BITS'({name}));", '    end']
    for bit in range(field['nbits']):
      value = {};here = value
      for token in tokens[:-1]:
        here[token] = {};here = here[token]
      here[tokens[-1]] = 1 << bit
      vectors.append(format(p.pack(node, value), f'0{(c["widths"]["NOC_BITS"]+3)//4}x'))
lines += ['    rc=$fscanf(fd,"%h",expected);',
          f'    if(checks!={len(vectors)} || rc>0 || !$feof(fd))$fatal(1,"PROGRAM_PACKING_COUNT checks=%0d expected={len(vectors)} rc=%0d eof=%0d",checks,rc,$feof(fd));',
          '    $fclose(fd);$display("PROGRAM_PACKING_PASS checks=%0d host_bits=%0d",checks,HOST_BITS);$finish;', '  end', 'endmodule']
(out / 'tb_program_packing.sv').write_text('\n'.join(lines) + '\n')
(out / 'vectors.txt').write_text('\n'.join(vectors) + '\n')
(out / 'params.txt').write_text('\n'.join(f'-G{k}={v}' for k,v in c['parameters'].items()) + '\n')
print('PROGRAM_PACKING_VECTORS', len(vectors))
