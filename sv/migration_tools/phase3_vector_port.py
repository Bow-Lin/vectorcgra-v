"""One-time porting aid; output is maintained SV, never a native-build input."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / 'sv/reference/phase3/vector_combo'
RTL = ROOT / 'sv/rtl/fu'


def load(case, width=32, suffix=''):
  directory = REF / f'{case}_w{width}_l4_b8_v0{suffix}'
  manifest = json.loads((directory/'manifest.json').read_text())
  source = (directory/'reference.v').read_text()
  raw = re.search(r'\bmodule\s+'+manifest['top']+r'\b.*?endmodule', source, re.S)[0]
  raw = '\n'.join(line for line in raw.splitlines() if not line.lstrip().startswith('//'))
  for typ in re.findall(r'^}\s+(\w+);', source, re.M):
    mapped = 'data_t' if typ.startswith('CgraData_') else 'ctrl_t' if typ.startswith('CGRAConfig_') else 'payload_t'
    raw = re.sub(r'\b'+typ+r'\b',mapped,raw)
  return raw


def shell(raw, name, extra=''):
  head, body = raw.split('\n);',1)
  head = re.sub(r'^module\s+\w+\s*\(', f'module {name} #(\n  `CGRA_PROFILE_PARAMETERS{extra}\n) (',head)
  aliases = []
  widths = {'data_t':'DATA_BITS','ctrl_t':'CTRL_BITS','payload_t':'PAYLOAD_BITS'}
  for direction, typ, port, shape in re.findall(r'\b(input|output)\s+(\w+_t)\s+(\w+)([^,\n]*)',head):
    head = re.sub(r'\b'+direction+r'\s+'+typ+r'\s+'+port+r'\b',f'{direction} logic [{widths[typ]}-1:0] {port}',head)
    body = re.sub(r'(?<!\.)\b'+port+r'\b','p_'+port,body)
    aliases.append(f'  {typ} p_{port} {shape.strip()};')
    lhs,rhs = ('p_'+port,port) if direction=='input' else (port,'p_'+port)
    aliases.append(f'  assign {lhs} = {rhs};')
  # Original all-zero constructors; leave partial assignments untouched.
  def zero(m):
    return "'0" if all(int(n)==0 for n in re.findall(r"\d+'[db](\d+)",m[0])) else m[0]
  body = re.sub(r"\{\s*\d+'[db]\d+(?:\s*,\s*\d+'[db]\d+)+\s*\}",zero,body)
  text = '`include "cgra_profile_defs.svh"\n// ac96 behavior preserved, including undriven fields and original handshake rules.\n'+head+'\n);\n  `include "cgra_profile.svh"\n'+'\n'.join(aliases)+'\n'+body
  text = text.replace('__const__','').replace('__tmpvar__','')
  text = re.sub(r'logic \[2:0\] (\w*ctrl_addr_inport)',r'logic [CTRL_ADDR_W-1:0] \1',text)
  text = re.sub(r'logic \[6:0\] (\w*to_mem_[rw]addr__msg)',r'logic [GLOBAL_ADDR_W-1:0] \1',text)
  text = text.replace("7'd0;", "GLOBAL_ADDR_W'(0);")
  return re.sub(r'\n\s*\n\s*\n','\n\n',text)+'\n'


def save(path,text):
  target=RTL/path
  target.parent.mkdir(parents=True,exist_ok=True)
  target.write_text(text,newline='\n')


def leaf(case):
  name='cgra_'+case
  t=shell(load(case),name,',\n  parameter int LANE_W = 8')
  if case=='vector_adder':
    t=t.replace('logic [8:0]','logic [LANE_W:0]')
    t=re.sub(r"\b9'd(\d+)",r"(LANE_W+1)'(\1)",t)
    t=re.sub(r"localparam logic \[3:0\] bw_at_comb_logic\s*= 4'd8;",'localparam int bw_at_comb_logic = LANE_W;',t)
    t=re.sub(r"\[4'd8:4'\( bw_at_comb_logic \)\]",'[LANE_W]',t)
    t=t.replace("carry_in_temp[4'd0]",'carry_in_temp[0]')
    t=t.replace('  logic [LANE_W:0] carry_in_temp;', '  // Only bit 0 was driven by ac96; high bits deliberately remain undriven.\n  logic [LANE_W:0] carry_in_temp;')
  else:
    t=t.replace('logic [15:0]','logic [2*LANE_W-1:0]')
    t=re.sub(r"\b16'd(\d+)",r"(2*LANE_W)'(\1)",t)
  save(Path('vector')/(name+'.sv'),t)


def combo(case):
  raw=load(case,suffix='_ctrl2' if case=='prl_mul_adder' else '')
  names={'MulRTL':'tile_multiplier','AdderRTL':'tile_adder','ShifterRTL':'scalar_shifter',
    'CompRTL':'scalar_comp','LogicRTL':'scalar_logic','GrantRTL':'scalar_grant'}
  for old,new in names.items():
    raw=re.sub(r'\b'+old+r'__\w+\s+(Fu\d+)\s*\(', new+r' #(`CGRA_PROFILE_BIND) \1 (',raw)
  if case=='prl_mul_adder':
    # First two inputs/first output are the exact original child topology.
    # Standard child ports 2/3 and output1 are deliberately left unused.
    raw=re.sub(r'(Fu\d+__recv_in__\w+) \[0:1\]',r'\1 [0:3]',raw)
    raw=re.sub(r'(Fu\d+__send_out__\w+) \[0:0\]',r'\1 [0:1]',raw)
  save(Path('combo')/('tile_'+case+'.sv'),shell(raw,'tile_'+case))


def alu():
  raw=load('alu_gen_mac',16)
  raw=raw.replace('AluGenMacWrapperRTL_noparam fALU','cgra_alu_gen_mac fALU')
  t=shell(raw,'tile_alu_gen_mac')
  t=t.replace('  `include "cgra_profile.svh"','  `include "cgra_profile.svh"\n  initial if (DATA_W != 16) $fatal(1,"ALUgenMAC requires DATA_W=16");',1)
  save(Path('combo/tile_alu_gen_mac.sv'),t)
  save(Path('combo/cgra_alu_gen_mac.sv'),'''// Existing 16-bit fixed-point IP, no added state or handshake adaptation.
module cgra_alu_gen_mac (
  input logic clk, reset,
  input logic [15:0] rhs_0, rhs_1, rhs_1b,
  input logic [5:0] rhs_2,
  output logic [15:0] lhs_0
);
  cgra_alu_gen_mac_core core (.rhs_0,.rhs_1,.rhs_1b,.rhs_2,.lhs_0);
endmodule
''')
  for source in ['svsrc/ALUgenMAC.sv','dp_fpfma/DW02_multp.v']:
    save(Path('combo/vendor')/source,(ROOT/'fu/fused_alu_fixedp'/source).read_text())


if __name__=='__main__':
  for case in ['vector_adder','vector_mul']: leaf(case)
  for case in ['seq_mul_adder','seq_mul_shifter','prl_mul_adder','three_mul_adder_shifter','four_inc_cmp_not_grant']: combo(case)
  alu()
