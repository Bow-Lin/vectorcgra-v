"""Build test-only harnesses around the actual public interfaces and parameters."""
from pathlib import Path
import json
import re
import sys

sv = Path(__file__).resolve().parents[2]
root = Path(sys.argv[1])
manifest = json.loads((root / 'generated/manifest.json').read_text())
p = manifest['parameters']; widths = manifest['widths']
module = 'cgra_multi_template' if manifest['top'] == 'multi' else 'cgra_system'
source = (sv / 'rtl/cgra' / (module + '.sv')).read_text()
ports = re.search(r'\) \(\n(.*?)\n\);', source, re.S).group(1)
declarations = []; drives = []
for line in ports.splitlines():
  text = line.strip().rstrip(',')
  if not text:
    continue
  direction, rest = text.split(' ', 1)
  assert direction in {'input', 'output'}, text
  declarations.append('  ' + rest + ';')
  if direction == 'input':
    names = re.sub(r'^logic\s*(\[[^]]+\])?\s*', '', rest)
    for token in names.split(','):
      name = token.strip().split()[0]
      value = "'{default:'0}" if '[' in token else ("1'b1" if name == 'reset' else "'0")
      if name == 'address_upper':value = str(p['BANK_DEPTH'] * p['NUM_BANKS'] - 1)
      drives.append(f'  assign {name}={value};')
lines = ['`timescale 1ns/1ps', '`include "cgra_profile_defs.svh"', '`include "cgra_fu_catalog.svh"',
    'module tb_config_elaboration;', '  `include "architecture.svh"']
lines += [f'  localparam int {k}=CFG_{k};' for k in sorted(dict(p, **widths))]
lines += declarations + drives
lines += [f'  {module} #(', '    `include "bindings.svh"', '  ) dut(.*);',
     '  config_profile_probe #(' + ','.join(f'.{k}(CFG_{k})' for k in sorted(p)) + ') probe();',
     '  initial begin #2;$display("CGRA_CONFIG_ELAB_PASS host_bits=%0d cgras=%0d",CFG_HOST_BITS,CFG_NUM_CGRAS);$finish;end', 'endmodule',
     'module config_profile_probe #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS) ();',
     '  `include "architecture.svh"', '  `include "cgra_profile.svh"', '  initial begin']
for k in widths:
  lines.append(f'    if({k}!=CFG_{k})$fatal(1,"CONFIG_WIDTH {k}");')
for t, width in [('data_t', 'DATA_BITS'), ('ctrl_t', 'CTRL_BITS'), ('payload_t', 'PAYLOAD_BITS'), ('host_packet_t', 'HOST_BITS'), ('noc_packet_t', 'NOC_BITS'), ('mem_request_t', 'MEM_BITS'), ('mem_write_request_t', 'WR_MEM_BITS')]:
  lines.append(f'    if($bits({t})!={width})$fatal(1,"CONFIG_STRUCT_WIDTH {t}");')
lines += ['  end', 'endmodule']
(root / 'tb_config_elaboration.sv').write_text('\n'.join(lines) + '\n')
