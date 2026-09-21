"""One-time derivative of the reviewed programmable system reference/test driver."""
from pathlib import Path
import hashlib
import re

ROOT=Path(__file__).resolve().parents[2]


def write(path,text):
  path.parent.mkdir(parents=True,exist_ok=True)
  path.write_text(text,encoding='utf-8',newline='\n')


def replace(text,old,new):
  assert old in text,old
  return text.replace(old,new)


def main():
  src=ROOT/'sv/migration_tools/phase3_logic_export.py'
  text=src.read_text()
  text=replace(text,'a five-FU list and a bitwise-NOT whole-array workload','VectorAdderCombo/Mul/Mem/Nah and a four-lane whole-array workload')
  text=replace(text,'from VectorCGRA.fu.single.LogicRTL import LogicRTL','from VectorCGRA.fu.vector.VectorAdderComboRTL import VectorAdderComboRTL')
  text=replace(text,'Phase3Logic','Phase3Vector')
  text=replace(text,'phase3/system/logic','phase3/system/vector')
  text=replace(text,'[(32, 8, 16), (64, 16, 8)]','[(32, 8, 16)]')
  text=replace(text,'assert (cols, rows) in [(2, 2), (4, 4), (3, 2)], "Only the three reviewed geometries are exported"','assert (cols, rows) == (2, 2), "This vector system workload is fixed to the reviewed four-tile chain"')
  text=replace(text,'[AdderRTL, MulRTL, MemUnitRTL, LogicRTL, NahRTL]','[VectorAdderComboRTL, MulRTL, MemUnitRTL, NahRTL]')
  text=replace(text,"['AdderRTL', 'MulRTL', 'MemUnitRTL', 'LogicRTL', 'NahRTL']","['VectorAdderComboRTL', 'MulRTL', 'MemUnitRTL', 'NahRTL']")
  text=replace(text,"combinational_memory=True, cgra_id=0, address_lower=0, address_upper=31,","combinational_memory=True, cgra_id=0, address_lower=0, address_upper=31, vector_lanes=4, lane_width=8,")
  text=replace(text,'43 if i == 1 else (29 if i == 2 else 25)','52 if i == 1 else (29 if i == 2 else 54)')
  text=replace(text,'5 if i == 1 else (3 if i == 2 else (-8 & mask))','0x05040302 if i == 1 else (3 if i == 2 else 0x08070605)')
  text=replace(text,"scenarios = [{'name': 'positive', 'input': 7}, {'name': 'negative_after_reset', 'input': -6 & mask}]","""def lane_add(value):
    return sum(((((value >> (8*i)) & 255) + ((0x05040302 >> (8*i)) & 255)) & 255) << (8*i) for i in range(4))

  def lane_sub(value):
    return sum(((((value >> (8*i)) & 255) - ((0x08070605 >> (8*i)) & 255)) & 255) << (8*i) for i in range(4))

  def link_value(value,index):
    if index == 0: return value
    if index == 1: return lane_add(value)
    if index == 2: return (lane_add(value)*3) & mask
    return lane_sub((lane_add(value)*3) & mask)

  scenarios = [{'name': 'positive', 'input': 0x7ffeff01}, {'name': 'negative_after_reset', 'input': 0xff01027f}]""")
  text=replace(text,'load[15], bitwise-NOT, mul3, add(-8) at every remaining Tile, store[16]; last Tile multicasts west[1]','load[15], four independent 8-bit lane add 0x05040302, scalar mul3 modulo32, four independent lane sub 0x08070605, store[16]; Tile2 multicasts west[1]')
  text=replace(text,"s['expected'] = (((~s['input']) * 3) - 8 * (ntiles - 3)) & mask","s['expected'] = link_value(s['input'],3)\n    s['expected_chain'] = [link_value(s['input'],i) for i in range(4)]")
  text=replace(text,"value = scenario['input'] if index == 0 else ((~scenario['input']) if index == 1 else ((~scenario['input']) * 3 - 8 * (index - 2)))","value = link_value(scenario['input'],index)")
  # Fresh copies are explicitly LF; direct source Python and old assets remain unchanged.
  text=text.replace('.write_text(','.write_text(')
  text=re.sub(r'\.write_text\(([^\n]*)\)',lambda m:'.write_text('+m[1]+', encoding="utf-8", newline="\\n")',text)
  text='# Derived test scaffold SHA256 '+hashlib.sha256(src.read_bytes()).hexdigest()+'\n'+text
  write(ROOT/'sv/migration_tools/phase3_vector_system_export.py',text)
  src=ROOT/'sv/tests/phase3/system/tb_programmable_logic.sv'
  tb=src.read_text().replace('tb_programmable_logic','tb_programmable_vector').replace('Phase3Logic','Phase3Vector').replace('PROGRAMMABLE_LOGIC','PROGRAMMABLE_VECTOR').replace('phase3/system/logic','phase3/system/vector')
  old="""  function automatic logic [DATA_W-1:0] result_for(input logic [DATA_W-1:0] value);
    return ((~value)*DATA_W'(3))-DATA_W'(8*(NUM_TILES-3));
  endfunction"""
  new="""  // Independent per-lane arithmetic; no native FU/reference internal signals.
  function automatic logic [31:0] lane_add(input logic [31:0] value);
    logic [31:0] result,constant_word;
    constant_word=32'h05040302;
    for(int i=0;i<4;i++) result[8*i+:8]=value[8*i+:8]+constant_word[8*i+:8];
    return result;
  endfunction
  function automatic logic [31:0] lane_sub(input logic [31:0] value);
    logic [31:0] result,constant_word;
    constant_word=32'h08070605;
    for(int i=0;i<4;i++) result[8*i+:8]=value[8*i+:8]-constant_word[8*i+:8];
    return result;
  endfunction
  function automatic logic [DATA_W-1:0] result_for(input logic [DATA_W-1:0] value);
    return lane_sub(lane_add(value)*32'd3);
  endfunction"""
  tb=replace(tb,old,new)
  tb=replace(tb,"position==1 ? 7'd43 : position==2 ? 7'd29 : 7'd25","position==1 ? 7'd52 : position==2 ? 7'd29 : 7'd54")
  tb=replace(tb,'.FU_COUNT(5),','.FU_COUNT(4), .VECTOR_LANES(4),')
  tb=replace(tb,'{`CGRA_FU_NAH,`CGRA_FU_LOGIC,`CGRA_FU_MEM,`CGRA_FU_MUL,`CGRA_FU_ADDER}','{`CGRA_FU_NAH,`CGRA_FU_MEM,`CGRA_FU_MUL,`CGRA_FU_VECTOR_ADDER}')
  tb=replace(tb,"expected_value=i==0 ? scenario_input : i==1 ? (~scenario_input) :\n          ((~scenario_input))*DATA_W'(3)-DATA_W'(8*(i-2));","expected_value=i==0 ? scenario_input : i==1 ? lane_add(scenario_input) :\n          i==2 ? lane_add(scenario_input)*32'd3 : result_for(scenario_input);")
  tb=replace(tb,"position==1 ? DATA_W'(5) : position==2 ? DATA_W'(3) : DATA_W'(-8)","position==1 ? 32'h05040302 : position==2 ? 32'd3 : 32'h08070605")
  tb=replace(tb,"run_scenario(0, DATA_W'(7));","run_scenario(0, 32'h7ffeff01);")
  tb=replace(tb,"run_scenario(1, DATA_W'(-6));","run_scenario(1, 32'hff01027f);")
  tb=replace(tb,'  logic clk = 0;', '  initial if(COLS!=2 || ROWS!=2 || DATA_W!=32 || CTRL_DEPTH!=8 || REG_DEPTH!=16) $fatal(1,"VECTOR_SYSTEM_PROFILE requires 2x2/32/8/16");\n  logic clk = 0;')
  write(ROOT/'sv/tests/phase3/system/tb_programmable_vector.sv',tb)
  runner=(ROOT/'sv/tests/phase3/system/run_logic.sh').read_text().replace('logic','vector').replace('Phase3Logic','Phase3Vector').replace('PROGRAMMABLE_LOGIC','PROGRAMMABLE_VECTOR')
  runner+='''set +e
"$out/system_test.exe" "+VECTORS=$PWD/vectors/phase3/system/vector/2x2" +EXPECT_FAILURE >"$out/negative.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q 'intentional negative control: West result mismatch' "$out/negative.log"; then
  cat "$out/negative.log"; echo VECTOR_SYSTEM_NEGATIVE_FAILED >&2; exit 1
fi
printf 'VECTOR_SYSTEM_NEGATIVE_PASS exit=%s\\n' "$status"
set +e
"$out/system_test.exe" "+VECTORS=$PWD/vectors/phase3/system/vector/2x2" +STALL_FOREVER +MAX_CYCLES=200 >"$out/timeout.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q 'TIMEOUT scenario=' "$out/timeout.log"; then
  cat "$out/timeout.log"; echo VECTOR_SYSTEM_TIMEOUT_FAILED >&2; exit 1
fi
printf 'VECTOR_SYSTEM_TIMEOUT_PASS exit=%s\\n' "$status"
'''
  write(ROOT/'sv/tests/phase3/system/run_vector.sh',runner)
  print('VECTOR_SYSTEM_SCAFFOLD_READY')


if __name__=='__main__': main()
