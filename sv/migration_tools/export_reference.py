"""Explicit migration-time export; normal SV builds never invoke this script."""

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from reference_model import (ROOT, BASELINE, TOP, PARAMETERS, DataType, CtrlType,
  PayloadType, HostPacketType, NocPacketType, make_design, type_schema)
from pymtl3.passes.backends.verilog import VerilogTranslationPass


def digest(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--output", type=Path, default=ROOT / "sv/reference")
  args = parser.parse_args()
  output = args.output.resolve()
  output.mkdir(parents=True, exist_ok=True)
  if (output / f"{TOP}.v").exists():
    parser.error("Reference already exists; use a fresh --output directory.")
  git = lambda *args: subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
  # A later migration commit is allowed; committed baseline Python must remain exact.
  changed = git("diff", "--name-only", BASELINE, "--", "*.py")
  changed = [name for name in changed.splitlines() if not name.startswith("sv/")]
  if changed:
    raise RuntimeError(f"Baseline Python sources changed: {changed}")
  imported = sys.modules["VectorCGRA.cgra.CgraRTL"].__file__
  assert Path(imported).resolve() == (ROOT / "cgra/CgraRTL.py").resolve(), imported
  os.chdir(output)
  dut = make_design()
  dut.elaborate()
  dut.set_metadata(VerilogTranslationPass.enable, True)
  dut.set_metadata(VerilogTranslationPass.explicit_module_name, TOP)
  dut.apply(VerilogTranslationPass())
  emitted = Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
  rtl = output / f"{TOP}.v"
  emitted.rename(rtl)
  text = rtl.read_text()
  header = re.search(r"module " + TOP + r"\s*\((.*?)\n\);", text, re.S).group(1)
  submodules = {}
  for path in ["noc/PyOCN", "fu/pymtl3_hardfloat", "fu/fused_alu_fixedp/dp_fpfma"]:
    expected = git("ls-tree", BASELINE, path).split()[2]
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT / path, text=True).strip()
    assert actual == expected, (path, actual, expected)
    submodules[path] = actual
  sources = {}
  for module in list(sys.modules.values()):
    path = getattr(module, "__file__", None)
    if path and Path(path).suffix == ".py":
      try:
        relative = Path(path).resolve().relative_to(ROOT)
      except ValueError:
        continue
      sources[relative.as_posix()] = digest(Path(path))
  manifest = {
    "schema_version": 1, "baseline_commit": BASELINE,
    "export_checkout_commit": git("rev-parse", "HEAD"),
    "source_root": str(ROOT), "source_import": imported,
    "top": TOP, "rtl_file": rtl.name, "rtl_sha256": digest(rtl),
    "module_count": len(re.findall(r"^module\s", text, re.M)),
    "parameters": PARAMETERS, "submodules": submodules,
    "python_version": sys.version, "python_executable": sys.executable,
    "pymtl3_version": importlib.metadata.version("pymtl3"),
    "pymtl3_direct_url": importlib.metadata.distribution("pymtl3").read_text("direct_url.json"),
    "types": {name: type_schema(Type) for name, Type in
              [("data", DataType), ("control", CtrlType), ("payload", PayloadType),
               ("host_packet", HostPacketType), ("noc_packet", NocPacketType)]},
    "top_port_declarations": header.strip().splitlines(),
    "source_sha256": dict(sorted(sources.items())),
    "semantics": {
      "baseline_rtl_modified": False,
      "runtime_count_configuration": "num_ctrl=8 permits 1..8 words; workload sets each tile's counts explicitly",
      "inactive_ports": ["recv_from_inter_cgra_noc.rdy", "send_to_inter_cgra_noc.val", "send_to_inter_cgra_noc.msg"],
      "inactive_port_reason": "is_multi_cgra=False uses an internal bypass queue; these declared ports are unused in baseline",
      "boundary": "Raw CgraRTL ports preserved, including cgra_id/address bounds and inactive inter-CGRA ports; the SV wrapper preserves all ports without ties or omitted ports",
    },
  }
  (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
  (output / "top_ports.txt").write_text(header.strip() + "\n")
  print(json.dumps({"rtl": str(rtl), "rtl_sha256": digest(rtl), "types":
    {k: v["nbits"] for k, v in manifest["types"].items()}, "modules": manifest["module_count"]}))


if __name__ == "__main__":
  main()
