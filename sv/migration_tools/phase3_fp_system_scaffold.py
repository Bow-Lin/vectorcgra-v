"""One-time migration scaffold for the full-array FP test, not a build dependency."""
from pathlib import Path
import re

SV = Path(__file__).resolve().parents[1]
source = (SV / 'migration_tools/phase3_logic_export.py').read_text()
source = source[:source.index('  # Reconstruct a fresh model:')]
source = source.replace('five-FU list and a bitwise-NOT', 'floating-point FU list and an arithmetic')
source = source.replace('phase3/system/logic', 'phase3/system/float').replace('Phase3LogicReference', 'Phase3FloatReference')
source = source.replace('from VectorCGRA.fu.single.LogicRTL import LogicRTL',
    'from phase3_float_export import WindowsPlaceholderPass\nfrom VectorCGRA.fu.float.FpAddRTL import FpAddRTL\nfrom VectorCGRA.fu.float.FpMulRTL import FpMulRTL')
source = source.replace('[AdderRTL, MulRTL, MemUnitRTL, LogicRTL, NahRTL]', '[FpAddRTL, FpMulRTL, MemUnitRTL, NahRTL]')
source = source.replace("['AdderRTL', 'MulRTL', 'MemUnitRTL', 'LogicRTL', 'NahRTL']", "['FpAddRTL', 'FpMulRTL', 'MemUnitRTL', 'NahRTL']")
source = source.replace('  dut.elaborate()\n', '  dut.elaborate()\n  dut.apply(WindowsPlaceholderPass())\n')
source = source.replace('ctrl(43 if i == 1 else (29 if i == 2 else 25)', 'ctrl(42 if i == 2 else 39')
source = source.replace('constants[tile] = [5 if i == 1 else (3 if i == 2 else (-8 & mask))]',
                        'constants[tile] = [fp(5 if i == 1 else (3 if i == 2 else -8))]')
source = source.replace('  scenarios = ', '''  def fp(value):
    if value == 0: return 0
    mag = abs(value)
    exponent = mag.bit_length() - 1
    return (int(value < 0) << 31) | ((255 + exponent) << 22) | ((mag << (22-exponent)) & ((1 << 22)-1))

  scenarios = ''')
# The integer encoder must precede constant generation.
start = source.index('  def fp(value):')
end = source.index('  scenarios = ', start)
encoder = source[start:end]
source = source[:start] + source[end:]
source = source.replace('  programs = ', encoder + '  programs = ')
source = source.replace("'input': 7", "'input': fp(7), 'integer_input': 7").replace("'input': -6 & mask", "'input': fp(-6), 'integer_input': -6")
source = source.replace("s['expected'] = (((~s['input']) * 3) - 8 * (ntiles - 3)) & mask", "s['expected'] = fp((s['integer_input']+5)*3-8*(ntiles-3))")
source = source.replace('bitwise-NOT, mul3', 'FPadd5, FPmul3').replace('add(-8) at every', 'FPadd(-8) at every')
source += '''  # The placeholder IP is checked in HDL, not a fabricated pure-Python trace.
  raw = rtl.read_text()
  names = set(re.findall(r'(?m)^\\s*module\\s+(\\w+)', raw))
  names.update(re.findall(r'}\\s+(\\w+)\\s*;', raw))
  names.update(re.findall(r'`define\\s+(\\w+)', raw))
  mapping = {n: 'GoldFpSystem_' + n for n in sorted(names)}
  pattern = re.compile(r'\\b(' + '|'.join(map(re.escape, sorted(names, key=len, reverse=True))) + r')\\b')
  renamed = pattern.sub(lambda m: mapping[m[0]], raw)
  reverse = {v:k for k,v in mapping.items()}
  assert re.sub(r'\\b('+'|'.join(map(re.escape, reverse))+r')\\b', lambda m: reverse[m[0]], renamed) == raw
  portable = re.sub(r'(?m)^(`line[^\\n]*)$', lambda m:m[0].replace(chr(92), '/'), renamed)
  (ref/'gold_portable.v').write_text(portable, newline='\\n')
  save(ref/'namespace.json', dict(mapping=mapping, roundtrip_verified=True,
    original_sha256=sha(rtl), portable_sha256=sha(ref/'gold_portable.v'),
    adaptation='Namespace plus diagnostic-only line path separators; no RTL changes.',
    reference_kind='Unmodified ac96 translated HDL including HardFloat. No Python simulation trace claimed.'))
  print('FP_SYSTEM_REFERENCE_PASS', flush=True)

if __name__ == '__main__':
  main()
'''
(SV/'migration_tools/phase3_fp_system_export.py').write_text(source, newline='\n')

tb = (SV/'tests/phase3/system/tb_programmable_base.sv').read_text()
tb = tb.replace('tb_programmable_base', 'tb_programmable_float').replace('Phase2Reference2x2', 'GoldFpSystem_Phase3FloatReference2x2')
tb = tb.replace('PHASE3_PROGRAMMABLE_BASE_PASS', 'PHASE3_PROGRAMMABLE_FLOAT_PASS')
tb = tb.replace('cgra_programmable #(`CGRA_PROFILE_BIND)', "cgra_programmable #(`CGRA_PROFILE_BIND, .FU_COUNT(4), .FU_KINDS({8'd3,8'd2,8'd29,8'd28}))")
tb = tb.replace("position==2 ? 7'd29 : 7'd25", "position==2 ? 7'd42 : 7'd39")
tb = tb.replace("return ((value+DATA_W'(5))*DATA_W'(3))-DATA_W'(8*(NUM_TILES-3));", 'return fp((fp_integer(value)+5)*3-8*(NUM_TILES-3));')
pos = tb.index('  function automatic logic [DATA_W-1:0] result_for')
tb = tb[:pos] + '''  // Baseline HardFloat format: 1 sign, 9 exponent, 22 fraction bits.
  // Inputs/intermediates here are small exact integers; this oracle uses integer math.
  function automatic logic [31:0] fp(input int value);
    int mag, exponent;
    if(value==0) return 0;
    mag=value<0 ? -value : value; exponent=0;
    while((mag >> (exponent+1)) != 0) exponent++;
    return (32'(value<0)<<31) | (32'(255+exponent)<<22) | ((32'(mag)<<(22-exponent)) & 32'h3fffff);
  endfunction
  function automatic int fp_integer(input logic [31:0] value);
    int mag, exponent;
    if(value[30:0]==0) return 0;
    exponent=int'(value[30:22])-255;
    mag=int'({1'b1,value[21:0]}) >> (22-exponent);
    return value[31] ? -mag : mag;
  endfunction
''' + tb[pos:]
tb = tb.replace("position==1 ? DATA_W'(5) : position==2 ? DATA_W'(3) : DATA_W'(-8)", 'fp(position==1 ? 5 : position==2 ? 3 : -8)')
tb = tb.replace("expected_value=i==0 ? scenario_input : i==1 ? scenario_input+DATA_W'(5) :\n          (scenario_input+DATA_W'(5))*DATA_W'(3)-DATA_W'(8*(i-2));", 'expected_value=i==0 ? scenario_input : i==1 ? fp(fp_integer(scenario_input)+5) :\n          fp((fp_integer(scenario_input)+5)*3-8*(i-2));')
tb = tb.replace("run_scenario(0, DATA_W'(7));", 'run_scenario(0, fp(7));').replace("run_scenario(1, DATA_W'(-6));", 'run_scenario(1, fp(-6));')
# Remove the Python trace machinery entirely. Full HDL gold comparison stays active.
start = tb.index('  // Frozen PyMTL samples')
end = tb.index('  task automatic compare_signal', start)
tb = tb[:start] + tb[end:]
tb = tb.replace('    compare_pymtl();\n', '')
start = tb.index('      meta_fd=$fopen')
end = tb.index('    if ($value$plusargs("MAX_CYCLES', start)
tb = tb[:start] + '      expected_cycles=64; expected_samples=134;\n    end\n' + tb[end:]
tb = tb.replace(' || pymtl_compared_cycles != expected_samples', '')
tb = tb.replace('int pymtl_compared_cycles = 0;', 'int pymtl_compared_cycles = 0; // No Python trace for placeholder IP.')
tb = tb.replace('sv/vectors/phase2/2x2', 'sv/vectors/phase3/system/float/2x2')
(SV/'tests/phase3/system/tb_programmable_float.sv').write_text(tb, newline='\n')
run = (SV/'tests/phase3/system/run_base.sh').read_text()
run = run.replace('system/base', 'system/float').replace('tb_programmable_base', 'tb_programmable_float')
run = run.replace('reference/phase2/2x2/Phase2Reference2x2.v', 'reference/phase3/system/float/2x2/gold_portable.v')
run = run.replace('vectors/phase2/2x2', 'vectors/phase3/system/float/2x2').replace('PHASE3_PROGRAMMABLE_BASE_PASS', 'PHASE3_PROGRAMMABLE_FLOAT_PASS')
(SV/'tests/phase3/system/run_float.sh').write_text(run, newline='\n')
