"""Replay the isolated Crossbar mapping used for C1/C2/C3 screening."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sys_lib"))
from area_report import load_yosys_json
from synthesize import find_tool, quote, run


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--manifest", type=Path, required=True)
  parser.add_argument("--output", type=Path, required=True)
  parser.add_argument("--case", action="append")
  parser.add_argument("--label", choices=["reference", "candidate"], action="append")
  args = parser.parse_args()
  args.manifest, args.output = args.manifest.resolve(), args.output.resolve()
  if (args.output / "report.json").exists():
    parser.error("Use a fresh output directory; an existing report must not be overwritten")
  manifest = json.loads(args.manifest.read_text())
  yosys, sv2v = find_tool("yosys", None), find_tool("sv2v", None)
  lib = ROOT / "sys_lib/lib/NangateOpenCellLibrary_typical.lib"
  os.environ["PATH"] = os.pathsep.join([str(yosys.parent), str(yosys.parent.parent / "lib"),
                                       os.environ.get("PATH", "")])
  args.output.mkdir(parents=True, exist_ok=True)
  report = {"scope": "Isolated crossbar; see each case for exact control-memory size",
            "manifest": str(args.manifest),
            "manifest_sha256": hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
            "liberty_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
            "tool_sha256": {"yosys": hashlib.sha256(yosys.read_bytes()).hexdigest(),
                            "sv2v": hashlib.sha256(sv2v.read_bytes()).hexdigest()},
            "abc_driving_cell": "BUF_X1", "abc_load_ff": 5.0, "cases": []}
  for entry in manifest["cases"]:
    if args.case and entry["case"]["name"] not in args.case:
      continue
    for item in entry["translations"]:
      if args.label and item["label"] not in args.label:
        continue
      directory = args.output / entry["case"]["name"] / item["label"]
      directory.mkdir(parents=True, exist_ok=True)
      verilog = directory / "design.v"
      with verilog.open("w") as out, (directory / "sv2v.log").open("w") as err:
        subprocess.run([str(sv2v), item["file"]], stdout=out, stderr=err, check=True)
      constraint = directory / "abc.constr"
      constraint.write_text("set_driving_cell BUF_X1\nset_load 5.0\n")
      script = directory / "run.ys"
      script.write_text("\n".join([
        f"read_verilog {quote(verilog)}", f"synth -top {item['module']} -noabc",
        f"dfflibmap -liberty {quote(lib)}",
        f"abc -liberty {quote(lib)} -constr {quote(constraint)}", "clean",
        f"tee -o {quote(directory / 'stat.json')} stat -json -liberty {quote(lib)} -top {item['module']}",
        f"write_json {quote(directory / 'mapped.json')}",
        f"read_liberty -lib -nooverwrite {quote(lib)}", "check -mapped -assert", ""]))
      elapsed = run([yosys, "-Q", "-T", "-s", script], directory / "yosys.log", directory)
      stat = load_yosys_json(directory / "stat.json")["design"]
      delays = [float(value) for value in re.findall(
        r"ABC:.*?Delay\s*=\s*([0-9.]+)", (directory / "yosys.log").read_text())]
      result = {"case": entry["case"], "label": item["label"],
                "system_verilog_sha256": hashlib.sha256(Path(item["file"]).read_bytes()).hexdigest(),
                "verilog_sha256": hashlib.sha256(verilog.read_bytes()).hexdigest(),
                "area_exact": str(stat["area"]), "cells": stat["num_cells"],
                "sequential_area_exact": str(stat["sequential_area"]),
                "abc_partition_delays_ps": delays, "elapsed_seconds": elapsed,
                "script": str(script)}
      report["cases"].append(result)
      (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
      print(json.dumps(result), flush=True)


if __name__ == "__main__":
  main()
