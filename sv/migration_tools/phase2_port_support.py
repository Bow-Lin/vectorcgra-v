"""One-time controller porting aid, never called by the native HDL build.

Extracts ac96 combinational/sequential blocks, substitutes shared parameter
types and reusable queues, and preserves the disabled-feature branches.
The resulting checked-in HDL is maintained directly after this migration.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'reference/legacy/cgra_2x2_core.sv').read_text()
TYPE_NAMES = re.findall(r'^} (Fixed2x2_\w+);', SOURCE, re.M)
LOCAL_NAMES = ['data_t', 'ctrl_t', 'payload_t', 'noc_packet_t', 'host_packet_t',
               'dma_cmd_t', 'dma_done_t', 'dma_read_req_t', 'dma_write_req_t',
               'dma_read_resp_t', 'controller_xbar_t', 'mem_request_t', 'mem_response_t']
WIDTHS = dict(zip(LOCAL_NAMES, ['DATA_BITS', 'CTRL_BITS', 'PAYLOAD_BITS', 'NOC_BITS',
    'HOST_BITS', '139', '8', '32', '68', '32', '(NOC_BITS+1)', 'MEM_BITS', 'MEM_BITS']))


def extract(stem):
  return re.search(r'module Fixed2x2_' + stem + r'__\w+\b.*?endmodule', SOURCE, re.S)[0]


def native_shell(text, name):
  text = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//'))
  for old, new in zip(TYPE_NAMES, LOCAL_NAMES):
    text = re.sub(r'\b' + old + r'\b', new, text)
  header, body = text.split('\n);', 1)
  header = re.sub(r'^module \w+\s*\(', f'module {name} #(\n  `CGRA_PROFILE_PARAMETERS\n) (', header)
  aliases = []
  for direction, typ, port, shape in re.findall(r'\b(input|output) (\w+_t) (\w+)([^,\n]*)', header):
    shape = shape.strip()
    header = re.sub(r'\b' + direction + ' ' + typ + ' ' + port + r'\b',
                    f'{direction} logic [{WIDTHS[typ]}-1:0] {port}', header)
    body = re.sub(r'\b' + port + r'\b', 'p_' + port, body)
    aliases.append(f'  {typ} p_{port} {shape};')
    lhs, rhs = (('p_' + port, port) if direction == 'input' else (port, 'p_' + port))
    aliases.append(f'  assign {lhs} = {rhs};')
  # Replace all-zero aggregate constructors with a size-correct zero.
  lines = []
  for line in body.splitlines():
    m = re.search(r'((?:<=|=) )({.*})(;)', line)
    if m and re.fullmatch(r"[\s{},0-9'db]+", m[2]):
      values = re.findall(r"\d+'[db](\d+)", m[2])
      if values and all(int(x) == 0 for x in values):
        line = line[:m.start(2)] + "'0" + line[m.end(2):]
    lines.append(line)
  body = '\n'.join(lines)
  text = ('`include "cgra_profile_defs.svh"\n'
          f'// Native parameterized {name}; control flow derived from ac96 {name}.\n'
          '// Disabled DMA/im2col declarations and undriven inputs retain baseline semantics.\n'
          + header + '\n);\n  `include "cgra_profile.svh"\n' + '\n'.join(aliases) + '\n' + body)
  text = text.replace('__const__', '').replace('__tmpvar__', '')
  return re.sub(r'\n\s*\n\s*\n', '\n\n', text) + '\n'


def replace_instances(text, callback):
  def change(match):
    mod, inst, port_text = match.groups()
    ports = re.findall(r'\.(\w+)\(\s*(.*?)\s*\)', port_text)
    newmod, params, extra, remap = callback(mod, inst)
    connections = [f'.{remap.get(port, port)}({signal})' for port, signal in ports]
    connections += extra
    return f'  {newmod} #({params}) {inst} (\n    ' + ',\n    '.join(connections) + '\n  );'
  return re.sub(r'  (Fixed2x2_\w+) (\w+)\s*\((.*?)\n  \);', change, text, flags=re.S)


def controller_children(mod, inst):
  rename = {f'{a}__{b}': f'{a}_{b}' for a in ['recv', 'send'] for b in ['msg', 'rdy', 'val']}
  if 'XbarRTL' in mod:
    return 'cgra_xbar', '.WIDTH(NOC_BITS+1), .INPUTS(7), .OUTPUTS(1), .DST_LSB(NOC_BITS), .DST_WIDTH(1), .INPUT_BYPASS(0)', [], rename
  if 'GlobalReduce' in mod:
    return 'cgra_global_reduce', '`CGRA_PROFILE_BIND', [], {}
  width = 'HOST_BITS' if ('cpu' in inst or 'im2col' in inst) else 'NOC_BITS'
  if 'NormalQueue' in mod:
    return 'cgra_queue', f'.WIDTH({width}), .DEPTH(2), .BYPASS(0)', [".clear(1'b0)"], rename
  return 'cgra_channel', f'.WIDTH({width}), .LATENCY(1)', [".clear(1'b0)"], rename


def port_controller():
  text = replace_instances(extract('ControllerRTL'), controller_children)
  text = native_shell(text, 'cgra_controller')
  text = re.sub(r'localparam logic \[2:0\] num_tiles_at_update_received_msg\s*= 3\'d4;',
                'localparam int num_tiles_at_update_received_msg = NUM_TILES;', text)
  text = text.replace("3'( num_tiles_at_update_received_msg )", "TILE_ID_W'( num_tiles_at_update_received_msg )")
  text = text.replace("2'd0, 8'd0, 2'd0,", "MEM_PORT_W'(0), 8'd0, 2'd0,")
  text = text.replace("7'd0, 119'd0, 3'd0", "GLOBAL_ADDR_W'(0), CTRL_BITS'(0), CTRL_ADDR_W'(0)")
  text = text.replace("{ 24 { 1'b0 } }", "{ (DATA_W-8) { 1'b0 } }")
  text = text.replace("{ 25 { 1'b0 } }", "{ (32-GLOBAL_ADDR_W) { 1'b0 } }")
  text = re.sub(r'localparam logic \[2:0\] addr_offset_nbits_at_capture_addr_dst_id\s*= 3\'d5;',
                'localparam int addr_offset_nbits_at_capture_addr_dst_id = $clog2(NUM_BANKS*BANK_DEPTH);', text)
  text = text.replace("3'( addr_offset_nbits_at_capture_addr_dst_id )", 'addr_offset_nbits_at_capture_addr_dst_id')
  text = text.replace('addr2controller_lut [0:3]', 'addr2controller_lut [0:(1<<GLOBAL_ADDR_W)/(NUM_BANKS*BANK_DEPTH)-1]')
  return text


def port_reduce():
  def child(mod, inst):
    rename = {f'{a}__{b}': f'{a}_{b}' for a in ['recv', 'send'] for b in ['msg', 'rdy', 'val']}
    return 'cgra_queue', '.WIDTH(NOC_BITS), .DEPTH(16)', [".clear(1'b0)"], rename
  text = native_shell(replace_instances(extract('GlobalReduceUnitRTL'), child), 'cgra_global_reduce')
  text = re.sub(r"\b32'd(\d+)", r"DATA_W'(\1)", text)
  return text


def port_memory():
  raw = extract('DataMemControllerRTL')
  # Replace the elaborated pair of banks with a true NUM_BANKS generate loop.
  raw = re.sub(r'  Fixed2x2_DataMemWrapperRTL__\w+ memory_wrapper__\d+\s*\(.*?\n  \);', '', raw, flags=re.S)
  raw = '\n'.join(line for line in raw.splitlines() if not (
      'memory_wrapper__' in line and (line.strip().startswith('assign ') or ';' in line)))
  def child(mod, inst):
    response = inst == 'response_crossbar'
    inp, out = ('NUM_BANKS+1', 'MEM_PORTS+1') if response else ('MEM_PORTS+1', 'NUM_BANKS+1')
    dst_w, src_w = ('MEM_PORT_W', 'BANK_PORT_W') if response else ('BANK_PORT_W', 'MEM_PORT_W')
    rename = {f'{a}__{b}': f'{a}_{b}' for a in ['recv', 'send'] for b in ['msg', 'rdy', 'val']}
    return ('cgra_xbar', f'.WIDTH(MEM_BITS), .INPUTS({inp}), .OUTPUTS({out}), '
            f'.DST_LSB(MEM_BITS-{src_w}-{dst_w}), .DST_WIDTH({dst_w}), .INPUT_BYPASS(1)', [], rename)
  text = native_shell(replace_instances(raw, child), 'cgra_data_memory')
  lines = []
  for line in text.splitlines():
    if '[0:2]' in line:
      bound = 'NUM_BANKS' if ('read_crossbar__send' in line or 'write_crossbar__send' in line or 'response_crossbar__recv' in line) else 'MEM_PORTS-1'
      line = line.replace('[0:2]', f'[0:{bound}]')
    line = line.replace('[0:3]', '[0:MEM_PORTS]')
    # Address paths and target bank selection derive from their own dimensions.
    if 'logic [6:0]' in line:
      line = line.replace('logic [6:0]', 'logic [GLOBAL_ADDR_W-1:0]')
    if 'logic [1:0]' in line:
      w = 'BANK_PORT_W' if 'bank_index_' in line else 'MEM_PORT_W'
      line = line.replace('logic [1:0]', f'logic [{w}-1:0]')
    if 'logic [2:0]' in line and 'from_tile_id' in line:
      line = line.replace('logic [2:0]', 'logic [TILE_ID_W-1:0]')
    lines.append(line)
  text = '\n'.join(lines)
  replacements = {
    'num_xbar_in_rd_ports': 'MEM_PORTS+1', 'num_xbar_in_wr_ports': 'MEM_PORTS+1',
    'num_rd_tiles': 'MEM_PORTS', 'num_wr_tiles': 'MEM_PORTS',
    'num_banks_per_cgra': 'NUM_BANKS', 'per_bank_addr_nbits': 'BANK_ADDR_W'}
  for stem, val in replacements.items():
    text = re.sub(r'localparam logic \[[^]]+\] (' + stem + r'_at_\w+)\s*= \d+\'d\d+;',
                  r'localparam int \1 = ' + val + ';', text)
  text = re.sub(r"i < \d+'\( (\w+) \)", r'i < \1', text)
  text = re.sub(r"\[\d+'\( (\w+) \)\]", r'[\1]', text)
  text = text.replace("[2'(i)]", '[i]')
  text = text.replace("2'(i)", "MEM_PORT_W'(i)")
  for stem in ['num_rd_tiles', 'num_wr_tiles']:
    text = re.sub(r"2'\( (" + stem + r"_at_\w+) \)", r"MEM_PORT_W'(\1)", text)
  text = re.sub(r"2'\( (num_banks_per_cgra_at_\w+) \)", r"BANK_PORT_W'(\1)", text)
  text = text.replace("3'( per_bank_addr_nbits_at_assemble_xbar_pkt )", 'BANK_ADDR_W')
  text = re.sub(r"2'\((\s*\(.*?\) >> BANK_ADDR_W\s*)\)", r"BANK_PORT_W'(\1)", text)
  text = text.replace("7'd0, 119'd0, 3'd0", "GLOBAL_ADDR_W'(0), CTRL_BITS'(0), CTRL_ADDR_W'(0)")
  text = text.replace("119'd0, 3'd0", "CTRL_BITS'(0), CTRL_ADDR_W'(0)")
  text = text.replace("3'd0", "TILE_ID_W'(0)")
  text = text.replace("7'd0", "GLOBAL_ADDR_W'(0)").replace("35'd0", "DATA_BITS'(0)").replace("32'd0", "DATA_W'(0)")
  text = text.replace("2'd0, 8'd0, 2'd0,", "MEM_PORT_W'(0), 8'd0, 2'd0,")
  text = text.replace(", 2'd0 };", ", MEM_PORT_W'(0) };")
  # Request constructors retain distinct source and destination widths.
  text = text.replace("MEM_PORT_W'(i), 2'd0,", "MEM_PORT_W'(i), BANK_PORT_W'(0),")
  text = text.replace("7'(p_recv_from_controller_spm_rd_req__msg.addr)", "GLOBAL_ADDR_W'(p_recv_from_controller_spm_rd_req__msg.addr)")
  text = text.replace("7'(p_recv_from_controller_spm_wr_req__msg.addr)", "GLOBAL_ADDR_W'(p_recv_from_controller_spm_wr_req__msg.addr)")
  text = text.replace("[2'( MEM_PORT_W'(i) )]", '[i]')
  text = re.sub(r'(bank_index_\w+ = )2\'d2;', r"\1BANK_PORT_W'(NUM_BANKS);", text)
  text = re.sub(r'(dma_\w+_idx = )2\'d3;', r"\1MEM_PORT_W'(MEM_PORTS);", text)
  bank = '''
  for (genvar bank = 0; bank < NUM_BANKS; bank++) begin : banks
    cgra_data_bank #(`CGRA_PROFILE_BIND) memory (
      .clk(clk), .reset(reset),
      .recv_rd__msg(read_crossbar__send__msg[bank]),
      .recv_rd__val(read_crossbar__send__val[bank]),
      .recv_rd__rdy(read_crossbar__send__rdy[bank]),
      .recv_wr__msg(write_crossbar__send__msg[bank]),
      .recv_wr__val(write_crossbar__send__val[bank]),
      .recv_wr__rdy(write_crossbar__send__rdy[bank]),
      .send__msg(response_crossbar__recv__msg[bank]),
      .send__val(response_crossbar__recv__val[bank]),
      .send__rdy(response_crossbar__recv__rdy[bank])
    );
  end
'''
  return text.replace('endmodule', bank + 'endmodule\n')


if __name__ == '__main__':
  out = ROOT / 'rtl/controller'
  out.mkdir(exist_ok=True)
  for name, text in [('cgra_controller', port_controller()), ('cgra_global_reduce', port_reduce())]:
    (out / (name + '.sv')).write_text(text, newline='\n')
    print(name, len(text.splitlines()), 'lines')
  out = ROOT / 'rtl/mem'
  out.mkdir(exist_ok=True)
  (out / 'cgra_data_memory.sv').write_text(port_memory(), newline='\n')
