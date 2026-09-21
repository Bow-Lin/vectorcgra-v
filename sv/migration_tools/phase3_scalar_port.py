"""One-time scalar migration aid. Native HDL is maintained directly thereafter."""
import json
from pathlib import Path
import re
from phase3_scalar_export import ROOT, write, sha


def snake(name):
  return re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower()


def port(record, directory):
  raw = (directory / record['rtl']).read_text(encoding='utf-8')
  text = re.search(r'^module ' + record['top'] + r'\b.*?^endmodule', raw, re.M | re.S)[0]
  text = '\n'.join(l.rstrip() for l in text.splitlines() if not l.lstrip().startswith('//'))
  types = {}
  for body, name in re.findall(r'typedef struct packed\s*\{(.*?)\}\s*(\w+);', raw, re.S):
    typ = 'ctrl_t' if ' operation;' in body else 'payload_t' if ' cmd;' in body else 'data_t'
    types[name] = typ
  for old, new in types.items():
    text = re.sub(r'\b' + old + r'\b', new, text)
  header, body = text.split('\n);', 1)
  name = 'scalar_' + snake(record['module'])
  pipeline = record['module'] in ('InclusiveDiv', 'ExclusiveDiv')
  latency = 2 if record['module'] == 'InclusiveDiv' else 4
  extra = f',\n  parameter int LATENCY = {latency}' if pipeline else ''
  header = re.sub(r'^module\s+\w+\s*\(', f'module {name} #(\n  `CGRA_PROFILE_PARAMETERS,\n  parameter int VECTOR_FACTOR_POWER = 0{extra}\n) (', header)
  aliases = []
  widths = dict(data_t='DATA_BITS', ctrl_t='CTRL_BITS', payload_t='PAYLOAD_BITS')
  for direction, typ, signal, shape in re.findall(r'\b(input|output) (\w+_t) (\w+)([^,\n]*)', header):
    header = re.sub(r'\b'+direction+' '+typ+' '+signal+r'\b', f'{direction} logic [{widths[typ]}-1:0] {signal}', header)
    body = re.sub(r'\b'+signal+r'\b', signal+'_typed', body)
    aliases.append(f'  {typ} {signal}_typed {shape.strip()};')
    a,b = (signal+'_typed', signal) if direction=='input' else (signal, signal+'_typed')
    aliases.append(f'  assign {a} = {b};')
  header = re.sub(r'\[2:0\](\s+ctrl_addr_inport)', r'[CTRL_ADDR_W-1:0]\1', header)
  header = re.sub(r'\[6:0\](\s+to_mem_[rw]addr__msg)', r'[GLOBAL_ADDR_W-1:0]\1', header)
  body = body.replace('__const__', '').replace('__tmpvar__', '')
  # Explicit zero aggregates are equivalent for any field widths.
  lines = []
  for line in body.splitlines():
    m = re.search(r'((?:<=|=) )({.*})(;)', line)
    if m and re.fullmatch(r"[\s{},0-9'db]+", m[2]):
      values = re.findall(r"\d+'[db](\d+)", m[2])
      if values and all(int(v)==0 for v in values):
        line = line[:m.start(2)] + "'0" + line[m.end(2):]
    if 'sign_flip' in line and 'localparam' in line:
      param=re.search(r'\b(sign_flip\w*)\s*=',line)[1]
      line = f"  localparam logic [DATA_W-1:0] {param} = DATA_W'(1) << (DATA_W-1);"
    line = line.replace('logic [31:0]', 'logic [DATA_W-1:0]')
    line = re.sub(r"\b32'd(\d+)", r"DATA_W'(\1)", line)
    line = line.replace("32'(", "DATA_W'(")
    line = line.replace('{ 31 {', '{ (DATA_W-1) {')
    line = line.replace("119'd0", "CTRL_BITS'(0)")
    line = line.replace("35'd0", "DATA_BITS'(0)")
    if 'send_to_ctrl_mem__msg_typed =' in line and '{' in line:
      line = line.replace("7'd0", "GLOBAL_ADDR_W'(0)")
      line = re.sub(r"3'd0(\s*};)", r"CTRL_ADDR_W'(0)\1", line)
    if 'to_mem_' in line and '__msg' in line:
      line = line.replace("7'd0", "GLOBAL_ADDR_W'(0)")
    if 'logic [2:0]' in line and ('ctrl_addr' in line or re.search(r'\b\w*_addr;',line)):
      line = line.replace('logic [2:0]', 'logic [CTRL_ADDR_W-1:0]')
    if record['module'] in ('Ret', 'Phi', 'LoopCounter'):
      line = line.replace('[0:7]', '[0:CTRL_SLOTS-1]')
      line = re.sub(r'localparam logic \[[^]]+\] (ctrl_mem_size_\w+)\s*=.*?;', r'localparam int \1 = CTRL_SLOTS;',line)
      line = re.sub(r"4'\( (ctrl_mem_size_\w+) \)",r'\1',line)
      line = line.replace("2'd2 ** 2'd3", 'CTRL_SLOTS')
      if record['module'] == 'Ret':
        line = line.replace("3'(i) == ctrl_addr_inport", "CTRL_ADDR_W'(i) == ctrl_addr_inport")
      if any(st in line for st in ('first[','already_done[','leaf_', 'shadow_')):
        line = line.replace("[3'(i)]", "[CTRL_ADDR_W'(i)]")
      line = line.replace("3'd0", "CTRL_ADDR_W'(0)") if 'target_ctrl_addr =' in line else line
    if 'assign vector_factor_power =' in line:
      line = "  assign vector_factor_power = 3'(VECTOR_FACTOR_POWER);"
    lines.append(line)
  body = '\n'.join(lines)
  if pipeline:
    body = re.sub(r'\bDiv__WIDTH_32__CYCLE_\d+ div\s*\(', 'scalar_div_pipeline #(.WIDTH(32), .CYCLE(LATENCY)) div (',body)
    # These original datapath wires are fixed by the baseline WIDTH=32.
    body = re.sub(r'logic \[DATA_W-1:0\] (div__\w+);', r'logic [31:0] \1;',body)
    body = re.sub(r'localparam logic \[[^]]+\] (latency_at_\w+)\s*=.*?;',r'localparam int \1 = LATENCY;',body)
    body = re.sub(r'logic \[[^]]+\] latency;', 'logic [$clog2(LATENCY+1)-1:0] latency;',body)
    body = re.sub(r'logic \[[^]]+\] cur_cycle;', 'logic [$clog2(LATENCY):0] cur_cycle;',body)
    body = re.sub(r"[23]'\( (latency_at_\w+) \)",r"($clog2(LATENCY)+1)'( \1 )",body)
    body = body.replace("2'd3", "($clog2(LATENCY)+1)'(LATENCY-1)") if record['module']=='ExclusiveDiv' else body
    guard = '  initial if (DATA_W != 32 || LATENCY < 1) $fatal(1, "ac96 pipeline divider requires DATA_W=32 and positive LATENCY");\n'
  else:
    guard = ''
  result = ('`include "cgra_profile_defs.svh"\n'
    f'// Native {record["module"]}RTL migration from ac96; original state/handshake semantics.\n'
    + header + '\n);\n  `include "cgra_profile.svh"\n'
    + '  localparam int CTRL_SLOTS = 1 << CTRL_ADDR_W;\n' + guard
    + '\n'.join(aliases) + '\n' + body + '\n')
  result = re.sub(r'\n\s*\n\s*\n', '\n\n',result)
  path = ROOT / 'sv/rtl/fu/scalar' / (name+'.sv')
  write(path,result)
  return dict(module=record['module'], native=name, path=path.relative_to(ROOT).as_posix(),sha256=sha(path))


def main():
  directory = ROOT/'sv/reference/phase3/scalar/w32'
  manifest = json.loads((directory/'manifest.json').read_text(encoding='utf-8'))
  records = [port(r,directory) for r in manifest['modules']]
  source=(ROOT/'fu/single/division.v').read_text(encoding='utf-8')
  source=re.sub(r'\bdivision\b','scalar_div_stage',source)
  source=re.sub(r'\bpipeline_division\b','scalar_div_pipeline',source)
  # Preserve pipeline partitioning (including the baseline unused remainder).
  write(ROOT/'sv/rtl/fu/scalar/scalar_div_pipeline.sv', source)
  write(ROOT/'sv/reference/phase3/scalar/native_port_manifest.json', json.dumps(records,indent=2)+'\n')


if __name__=='__main__':
  main()
