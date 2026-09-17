"""Translate the hardware parameters of test_vector_mesh_4x4, without its harness."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from pymtl3 import clog2, mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.cgra.CgraRTL import CgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.LogicRTL import LogicRTL
from VectorCGRA.fu.single.ShifterRTL import ShifterRTL
from VectorCGRA.fu.single.PhiRTL import PhiRTL
from VectorCGRA.fu.single.CompRTL import CompRTL
from VectorCGRA.fu.single.GrantRTL import GrantRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.SelRTL import SelRTL
from VectorCGRA.fu.vector.VectorMulComboRTL import VectorMulComboRTL
from VectorCGRA.fu.vector.VectorAdderComboRTL import VectorAdderComboRTL
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload

FU_LIST = [AdderRTL, MulRTL, LogicRTL, ShifterRTL, PhiRTL, CompRTL,
           GrantRTL, MemUnitRTL, SelRTL, VectorMulComboRTL, VectorAdderComboRTL]


def make_design():
  data_type = mk_data(32, 1)
  ctrl_type = mk_ctrl(4, 2, 4, 4, 16)
  payload_type = mk_cgra_payload(data_type, mk_bits(clog2(128)), ctrl_type,
                                mk_bits(clog2(6)))
  return CgraRTL(payload_type, 1, 4, 4, 4, 6, 128, 16, 2, 16, 6, 6,
                 True, FlexibleFuRTL, FU_LIST, "Mesh",
                 {i: [i * 32, (i + 1) * 32 - 1] for i in range(4)},
                 {i: [i, 0] for i in range(4)}, is_multi_cgra=False)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--output", type=Path, required=True)
  args = parser.parse_args()
  output = args.output.resolve()
  output.mkdir(parents=True, exist_ok=True)
  if (output / "VectorCGRA4x4__pickled.v").exists():
    parser.error("Output already contains a translated design; use a new experiment directory.")
  os.chdir(output)
  dut = make_design()
  dut.elaborate()
  dut.set_metadata(VerilogTranslationPass.enable, True)
  dut.set_metadata(VerilogTranslationPass.explicit_module_name, "VectorCGRA4x4")
  dut.apply(VerilogTranslationPass())
  rtl_path = Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
  manifest = {
    "baseline_test": "cgra/test/CgraRTL_test.py::test_vector_mesh_4x4",
    "git_commit": subprocess.check_output(
      ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "top": "VectorCGRA4x4", "rtl": rtl_path.name,
    "rtl_sha256": hashlib.sha256(rtl_path.read_bytes()).hexdigest(),
    "crossbar_sha256": hashlib.sha256((ROOT / "noc/CrossbarRTL.py").read_bytes()).hexdigest(),
    "cgra_sha256": hashlib.sha256((ROOT / "cgra/CgraRTL.py").read_bytes()).hexdigest(),
    "working_tree_diff_sha256": hashlib.sha256(subprocess.check_output(
      ["git", "diff", "--binary", "HEAD"], cwd=ROOT)).hexdigest(),
    "parameters": {
      "width": 4, "height": 4, "topology": "Mesh", "data_bitwidth": 32,
      "data_type_nbits": mk_data(32, 1).nbits, "num_fu_inports": 4, "num_fu_outports": 2,
      "ctrl_mem_size": 6, "data_mem_size_global": 128,
      "data_mem_size_per_bank": 16, "num_banks_per_cgra": 2,
      "num_registers_per_reg_bank": 16, "num_ctrl": 6, "total_steps": 6,
      "multi_cgra_rows": 1, "multi_cgra_columns": 4, "is_multi_cgra": False,
      "has_ctrl_ring": True, "has_im2col_engine": False,
      "mem_access_is_combinational": True,
      "functional_units": [fu.__name__ for fu in FU_LIST],
    },
    "boundary": "All DUT ports remain ports; no test-harness constants/configuration are synthesized.",
    "memory_mapping": "Behavioral memories map to standard-cell registers/muxes; no SRAM blackboxes.",
  }
  (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
  print(f"Translated {rtl_path} ({rtl_path.stat().st_size:,} bytes)", flush=True)


if __name__ == "__main__":
  main()
