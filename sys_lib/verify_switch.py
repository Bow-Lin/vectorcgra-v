"""Compare StaticSwitchUnitRTL with the unchanged PyOCN implementation.

Retains cycle-differential results, translated RTL, sv2v/Yosys logs, formal
coverage, and optional hierarchy-preserving local mapping area. Run with the
custom PyMTL3 environment: python sys_lib/verify_switch.py --synth.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from pymtl3 import mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.noc.PyOCN.pymtl3_net.router.SwitchUnitRTL import SwitchUnitRTL
from VectorCGRA.noc.StaticSwitchUnitRTL import StaticSwitchUnitRTL
from VectorCGRA.noc.test.StaticSwitchUnitRTL_test import control_packet_type, differential_switch

from area_report import load_yosys_json
from synthesize import find_tool, quote


def sha256(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(command, path, env, timeout=300):
  start = time.monotonic()
  with path.open("w", encoding="utf-8") as log:
    result = subprocess.run([str(item) for item in command], cwd=path.parent,
                            env=env, stdout=log, stderr=subprocess.STDOUT,
                            timeout=timeout)
  if result.returncode:
    raise RuntimeError(f"Command failed ({result.returncode}); {path}\n" +
                       path.read_text(errors="replace")[-3500:])
  return time.monotonic() - start


def translate(cls, packet_type, ports, label, output):
  output.mkdir(parents=True, exist_ok=True)
  previous = Path.cwd()
  try:
    os.chdir(output)
    model = cls(packet_type, ports)
    model.elaborate()
    module = f"Switch_{label}_{ports}x{packet_type.nbits}"
    model.set_metadata(VerilogTranslationPass.enable, True)
    model.set_metadata(VerilogTranslationPass.explicit_module_name, module)
    model.apply(VerilogTranslationPass())
    path = Path(model.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
    return {"module": module, "file": str(path), "sha256": sha256(path)}
  finally:
    os.chdir(previous)


def formal_coverage(before, after, ports, packet_bits):
  module = json.loads(before.read_text())["modules"]["equiv"]
  equiv = [cell for cell in module["cells"].values() if cell["type"] == "$equiv"]
  pairs = {(tuple(cell["connections"]["A"]), tuple(cell["connections"]["B"]))
           for cell in equiv}
  if not pairs:
    raise AssertionError("Formal proof contains no equivalence points")

  def matched(gold_name):
    gold = module["netnames"][gold_name]["bits"]
    gate = module["netnames"][gold_name[:-5] + "_gate"]["bits"]
    if len(gold) != len(gate):
      raise AssertionError(f"Changed width: {gold_name}")
    if not all(a == b or ((a,), (b,)) in pairs or ((b,), (a,)) in pairs
               for a, b in zip(gold, gate)):
      raise AssertionError(f"Unmatched proof bits: {gold_name}")
    return len(gold)

  outputs = {name: matched(name + "_gold")
             for name in ("send__msg", "send__val", "recv__rdy")}
  if sum(outputs.values()) != packet_bits + 1 + ports:
    raise AssertionError(f"Unexpected output coverage: {outputs}")
  priority = [name for name in module["netnames"]
              if name.endswith("priority_reg.out_gold")]
  if len(priority) != 1 or matched(priority[0]) != ports:
    raise AssertionError(f"Priority state not fully paired: {priority}")
  final = json.loads(after.read_text())["modules"]["equiv"]
  unproven = [cell for cell in final["cells"].values() if cell["type"] == "$equiv"
              and cell["connections"]["A"] != cell["connections"]["B"]]
  if unproven:
    raise AssertionError(f"{len(unproven)} unproven equivalence points remain")
  return {"equivalence_points": len(equiv), "matched_output_bits": outputs,
          "matched_priority_bits": ports, "unproven": 0}


def prove_case(packet_type, ports, output, args, env):
  output.mkdir(parents=True, exist_ok=True)
  entry = {"name": output.name, "packet_bits": packet_type.nbits, "inputs": ports}
  if not args.skip_sim:
    entry["differential"] = differential_switch(packet_type, ports, random_cycles=1800)
  translations = {}
  for label, cls in (("reference", SwitchUnitRTL), ("candidate", StaticSwitchUnitRTL)):
    item = translate(cls, packet_type, ports, label, output / label)
    converted = output / label / "design.v"
    with converted.open("w", encoding="utf-8") as target, \
         (output / label / "sv2v.log").open("w", encoding="utf-8") as errors:
      subprocess.run([str(args.sv2v), item["file"]], env=env, stdout=target,
                      stderr=errors, check=True, timeout=300)
    item["verilog"] = str(converted)
    item["verilog_sha256"] = sha256(converted)
    translations[label] = item
  entry["translations"] = translations
  script = output / "equivalence.ys"
  before, after = output / "equiv_before.json", output / "equiv_after.json"
  lines = []
  for label, design in (("reference", "gold"), ("candidate", "gate")):
    item = translations[label]
    lines.extend([f"read_verilog {quote(item['verilog'])}",
                  f"prep -top {item['module']} -flatten", "memory_map", "opt_clean",
                  f"rename {item['module']} {design}", f"design -stash {design}"])
  lines.extend(["design -copy-from gold -as gold gold", "design -copy-from gate -as gate gate",
                "equiv_make gold gate equiv", "hierarchy -top equiv",
                f"write_json {quote(before)}", "equiv_simple -undef -short",
                "equiv_simple -undef", "equiv_induct -undef -seq 4",
                "equiv_status -assert", f"write_json {quote(after)}", ""])
  script.write_text("\n".join(lines))
  entry["formal_seconds"] = run([args.yosys, "-Q", "-T", "-s", script],
                                output / "equivalence.log", env)
  entry["formal"] = formal_coverage(before, after, ports, packet_type.nbits)
  entry["formal"].update({"status": "proved", "input_assumptions": [],
                          "undef_modeling": True, "induction_depth": 4,
                          "scope": "All output bits, including invalid messages, and matching "
                                   "priority register state. Induction assumes synchronized "
                                   "matching points; differential tests include reset."})
  print(f"PROVED {output.name}: {entry['formal']['equivalence_points']} points, "
        f"{ports} priority bits; {entry['formal_seconds']:.2f}s", flush=True)
  if args.synth:
    entry["local_mapping"] = {}
    for label, item in translations.items():
      directory = output / label
      constraint = directory / "abc.constr"
      constraint.write_text("set_driving_cell BUF_X1\nset_load 5.0\n")
      script = directory / "synthesis.ys"
      script.write_text("\n".join([
        f"read_verilog {quote(item['verilog'])}",
        f"synth -top {item['module']} -noabc",
        f"dfflibmap -liberty {quote(args.liberty)}",
        f"abc -liberty {quote(args.liberty)} -constr {quote(constraint)}", "clean",
        f"tee -o {quote(directory / 'stat.json')} stat -json -liberty {quote(args.liberty)} -top {item['module']}",
        f"write_json {quote(directory / 'mapped.json')}",
        f"read_liberty -lib -nooverwrite {quote(args.liberty)}", "check -mapped -assert", ""]))
      elapsed = run([args.yosys, "-Q", "-T", "-s", script], directory / "synthesis.log", env)
      stat = load_yosys_json(directory / "stat.json")["design"]
      entry["local_mapping"][label] = {
        "area_exact": str(stat["area"]), "cells": stat["num_cells"],
        "elapsed_seconds": elapsed, "scope": "Complete switch, hierarchy-preserving mapping",
        "stat_file": str(directory / "stat.json"), "script": str(script)}
      print(f"MAPPED {output.name}/{label}: {stat['area']} area, "
            f"{stat['num_cells']} cells; {elapsed:.2f}s", flush=True)
  return entry


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--output", type=Path, default=ROOT / "sys_lib/build/switch")
  parser.add_argument("--yosys")
  parser.add_argument("--sv2v")
  parser.add_argument("--liberty", type=Path,
                      default=ROOT / "sys_lib/lib/NangateOpenCellLibrary_typical.lib")
  parser.add_argument("--skip-sim", action="store_true")
  parser.add_argument("--synth", action="store_true")
  parser.add_argument("--case", choices=["control6x199", "bits3x32", "bits8x32"], action="append")
  args = parser.parse_args()
  args.output, args.liberty = args.output.resolve(), args.liberty.resolve()
  args.yosys, args.sv2v = find_tool("yosys", args.yosys), find_tool("sv2v", args.sv2v)
  args.output.mkdir(parents=True, exist_ok=True)
  env = os.environ.copy()
  env["PATH"] = os.pathsep.join([str(args.yosys.parent),
                                 str(args.yosys.parent.parent / "lib"), env.get("PATH", "")])
  report = {"started_utc": datetime.now(timezone.utc).isoformat(), "cases": [],
            "baseline_tools_commit": "14ce5bc", "source_hashes": {
              "reference": sha256(ROOT / "noc/PyOCN/pymtl3_net/router/SwitchUnitRTL.py"),
              "candidate": sha256(ROOT / "noc/StaticSwitchUnitRTL.py"),
              "cgra": sha256(ROOT / "cgra/CgraRTL.py"),
              "liberty": sha256(args.liberty)}, "tools": {}}
  for name, executable, option in (("yosys", args.yosys, "-V"), ("sv2v", args.sv2v, "--version")):
    report["tools"][name] = {
      "sha256": sha256(executable), "version": subprocess.check_output(
        [str(executable), option], env=env, text=True).strip()}
  try:
    for name, typ, ports in (("control6x199", control_packet_type(), 6),
                              ("bits3x32", mk_bits(32), 3), ("bits8x32", mk_bits(32), 8)):
      if not args.case or name in args.case:
        report["cases"].append(prove_case(typ, ports, args.output / name, args, env))
    report["status"] = "passed"
  except Exception as error:
    report["status"], report["error"] = "failed", str(error)
    raise
  finally:
    report["finished_utc"] = datetime.now(timezone.utc).isoformat()
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
  main()
