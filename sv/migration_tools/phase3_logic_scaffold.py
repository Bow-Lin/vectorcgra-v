"""One-time derivation of a new whole-CGRA workload from the reviewed harness."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'migration_tools/phase2_export.py').read_text()
source=source.replace('Freeze one ac96 scalar geometry and execute a whole-array reference workload.',
    'Freeze ac96 CGRA with a five-FU list and a bitwise-NOT whole-array workload.')
source=source.replace('from VectorCGRA.fu.single.NahRTL import NahRTL',
    'from VectorCGRA.fu.single.NahRTL import NahRTL\nfrom VectorCGRA.fu.single.LogicRTL import LogicRTL')
source=source.replace('sv/reference/phase2','sv/reference/phase3/system/logic')
source=source.replace('sv/vectors/phase2','sv/vectors/phase3/system/logic')
source=source.replace('Phase2Reference','Phase3LogicReference')
source=source.replace('[AdderRTL, MulRTL, MemUnitRTL, NahRTL]','[AdderRTL, MulRTL, MemUnitRTL, LogicRTL, NahRTL]')
source=source.replace("['AdderRTL', 'MulRTL', 'MemUnitRTL', 'NahRTL']","['AdderRTL', 'MulRTL', 'MemUnitRTL', 'LogicRTL', 'NahRTL']")
source=source.replace('ctrl(29 if i == 2 else 25,','ctrl(43 if i == 1 else (29 if i == 2 else 25),')
source=source.replace("(((s['input'] + 5) * 3) - 8 * (ntiles - 3))", "(((~s['input']) * 3) - 8 * (ntiles - 3))")
source=source.replace("((scenario['input'] + 5) if index == 1 else ((scenario['input'] + 5) * 3 - 8 * (index - 2)))",
    "((~scenario['input']) if index == 1 else ((~scenario['input']) * 3 - 8 * (index - 2)))")
source=source.replace('load[15], add5, mul3, add(-8)', 'load[15], bitwise-NOT, mul3, add(-8)')
source=source.replace("  print('PASS ' + json.dumps", "  assert results[0]['cycles_after_reset'] == results[1]['cycles_after_reset']\n  (out / 'replay_meta.txt').write_text(f\"{results[0]['cycles_after_reset']} {len(trace)}\\n\")\n  print('PASS ' + json.dumps")
(ROOT/'migration_tools/phase3_logic_export.py').write_text(source,newline='\n')
tb=(ROOT/'tests/phase2_tb_cgra_scalar.sv').read_text()
tb=tb.replace('`include "cgra_profile_defs.svh"','`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"')
tb=tb.replace('Phase2Reference2x2','Phase3LogicReference2x2')
tb=tb.replace('module phase2_tb_cgra_scalar','module tb_programmable_logic')
tb=tb.replace('cgra_scalar #(`CGRA_PROFILE_BIND)',
    'cgra_programmable #(`CGRA_PROFILE_BIND, .FU_COUNT(5),\n    .FU_KINDS({`CGRA_FU_NAH,`CGRA_FU_LOGIC,`CGRA_FU_MEM,`CGRA_FU_MUL,`CGRA_FU_ADDER}))')
tb=tb.replace("((value+DATA_W'(5))*DATA_W'(3))", "((~value)*DATA_W'(3))")
tb=tb.replace("c.operation=position==2 ? 7'd29 : 7'd25;", "c.operation=position==1 ? 7'd43 : position==2 ? 7'd29 : 7'd25;")
tb=tb.replace("scenario_input+DATA_W'(5)", '(~scenario_input)')
tb=tb.replace('sv/vectors/phase2/2x2', 'sv/vectors/phase3/system/logic/2x2')
tb=tb.replace('PHASE2_CGRA_PASS','PHASE3_PROGRAMMABLE_LOGIC_PASS')
(ROOT/'tests/phase3/system/tb_programmable_logic.sv').write_text(tb,newline='\n')
runner=(ROOT/'tests/phase3/system/run_base.sh').read_text()
runner=runner.replace('/base','/logic').replace('tb_programmable_base','tb_programmable_logic')
runner=runner.replace('reference/phase2/2x2/Phase2Reference2x2.v','reference/phase3/system/logic/2x2/Phase3LogicReference2x2.v')
runner=runner.replace('vectors/phase2/2x2','vectors/phase3/system/logic/2x2')
runner=runner.replace('PHASE3_PROGRAMMABLE_BASE_PASS','PHASE3_PROGRAMMABLE_LOGIC_PASS')
(ROOT/'tests/phase3/system/run_logic.sh').write_text(runner,newline='\n')
print('LOGIC_SYSTEM_SCAFFOLD_PASS')
