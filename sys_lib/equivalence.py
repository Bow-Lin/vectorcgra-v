#!/usr/bin/env python3
"""Check translated Crossbar pairs with sv2v and Yosys equivalence passes.

Generate the manifest first (using the custom PyMTL3 environment)::

  python sys_lib/verify_crossbar.py --translate-only
  python sys_lib/equivalence.py

The two designs retain matching counter and multicast state names. equiv_make
therefore compares those state bits as well as interfaces and common internal
wires. No input assumptions, traffic traces, memory blackboxes, or clock/latency
changes are introduced. The proof uses equiv_simple -undef and equiv_induct
-undef, followed by equiv_status -assert. Induction assumes corresponding
state/observation points have synchronized; differential reset tests accompany
this check. All scripts, tool versions, source hashes, and logs are retained.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def yosys_path(path):
  return '"' + str(path.resolve()).replace("\\", "/").replace('"', '\\"') + '"'


def run_logged(command, log_path, env, timeout):
  start = time.perf_counter()
  with log_path.open("w", encoding="utf-8") as stream:
    result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                            stderr=subprocess.STDOUT, timeout=timeout)
  if result.returncode:
    tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-35:]
    raise RuntimeError(f"Command failed ({result.returncode}); log={log_path}\n" +
                       "\n".join(tail))
  return time.perf_counter() - start


def state_matches(design, case):
  module = design["modules"]["equiv"]
  equivalent = [cell for cell in module["cells"].values()
                if cell["type"] == "$equiv"]
  matched_pairs = {(tuple(cell["connections"]["A"]),
                    tuple(cell["connections"]["B"])) for cell in equivalent}
  summary = {}
  for base in ("prologue_counter", "send_accepted"):
    gold_names = [name for name in module["netnames"] if
                  name == base + "_gold" or
                  (name.startswith(base + "[") and name.endswith("_gold"))]
    if not gold_names:
      raise AssertionError(f"Missing shared persistent state: {base}")
    summary[base] = 0
    for gold_name in gold_names:
      gold = module["netnames"][gold_name]
      gate = module["netnames"].get(gold_name[:-5] + "_gate")
      if gate is None or len(gold["bits"]) != len(gate["bits"]):
        raise AssertionError(f"Persistent state width changed: {gold_name}")
      matching = sum(((a,), (b,)) in matched_pairs or ((b,), (a,)) in matched_pairs
                     or a == b for a, b in zip(gold["bits"], gate["bits"]))
      if matching != len(gold["bits"]):
        raise AssertionError(f"State bits not individually matched: {gold_name}: "
                             f"{matching}/{len(gold['bits'])}")
      summary[base] += matching
  expected = {"prologue_counter": case["ctrl_size"] * case["inputs"] * 3,
              "send_accepted": case["outputs"]}
  if summary != expected:
    raise AssertionError(f"State coverage mismatch: {summary} != {expected}")
  return {"equiv_cells_before_proof": len(equivalent),
          "persistent_state_bits_matched": summary}


def check_case(entry, args, env):
  case = entry["case"]
  case_dir = args.output_dir / case["name"]
  case_dir.mkdir(parents=True, exist_ok=True)
  translated = {item["label"]: item for item in entry["translations"]}
  paths = {}
  files = {}
  for label in ("reference", "candidate"):
    item = translated[label]
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", item["module"]):
      raise ValueError(f"Unsupported module name: {item['module']!r}")
    source = Path(item["file"]).resolve()
    target = case_dir / f"{label}.v"
    error_log = case_dir / f"sv2v_{label}.log"
    with target.open("w", encoding="utf-8") as out, \
         error_log.open("w", encoding="utf-8") as err:
      result = subprocess.run([str(args.sv2v), str(source)], cwd=ROOT,
                              env=env, stdout=out, stderr=err,
                              timeout=args.timeout)
    if result.returncode:
      raise RuntimeError(f"sv2v failed: {error_log}")
    paths[label] = target
    files[label] = {"system_verilog": str(source),
                    "system_verilog_sha256": sha256(source),
                    "verilog": str(target), "verilog_sha256": sha256(target)}

  before = case_dir / "equiv_before.json"
  after = case_dir / "equiv_after.json"
  script = case_dir / "equivalence.ys"
  lines = []
  for label, design_name in (("reference", "gold"), ("candidate", "gate")):
    top = translated[label]["module"]
    lines.extend([
      f"read_verilog {yosys_path(paths[label])}",
      f"prep -top {top} -flatten",
      "memory_map",
      "opt_clean",
      f"rename {top} {design_name}",
      f"design -stash {design_name}",
    ])
  lines.extend([
    "design -copy-from gold -as gold gold",
    "design -copy-from gate -as gate gate",
    "equiv_make gold gate equiv",
    "hierarchy -top equiv",
    f"write_json {yosys_path(before)}",
    "equiv_simple -undef -short",
    "equiv_simple -undef",
    f"equiv_induct -undef -seq {args.depth}",
    "equiv_status -assert",
    f"write_json {yosys_path(after)}",
  ])
  script.write_text("\n".join(lines) + "\n", encoding="utf-8")
  print(f"PROVING {case['name']} ...", flush=True)
  elapsed = run_logged([str(args.yosys), "-Q", "-T", "-s", str(script)],
                       case_dir / "yosys.log", env, args.timeout)
  state = state_matches(json.loads(before.read_text(encoding="utf-8")), case)
  if state["equiv_cells_before_proof"] == 0:
    raise AssertionError("No equivalence points were created")
  final = json.loads(after.read_text(encoding="utf-8"))
  cells = final["modules"]["equiv"]["cells"].values()
  unproven = [cell for cell in cells if cell["type"] == "$equiv"
              and cell["connections"]["A"] != cell["connections"]["B"]]
  if unproven:
    raise AssertionError(f"{len(unproven)} unproven equivalence points remain")
  result = {"case": case, "status": "proved", "elapsed_seconds": elapsed,
            "induction_depth": args.depth, "undef_modeling": True,
            "input_assumptions": [], "files": files,
            "yosys_script": str(script), "yosys_log": str(case_dir / "yosys.log"),
            **state}
  print(f"PROVED {case['name']}: {state['equiv_cells_before_proof']} points; "
        f"state={state['persistent_state_bits_matched']}; {elapsed:.2f}s", flush=True)
  return result


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--manifest", type=Path,
                      default=ROOT / "sys_lib" / "build" / "crossbar_translation.json")
  parser.add_argument("--case", action="append")
  parser.add_argument("--output-dir", type=Path,
                      default=ROOT / "sys_lib" / "build" / "equivalence")
  parser.add_argument("--yosys", type=Path,
                      default=ROOT / "sys_lib" / "tools" / "oss-cad-suite" / "bin" / "yosys.exe")
  parser.add_argument("--sv2v", type=Path,
                      default=ROOT / "sys_lib" / "tools" / "sv2v-v0.0.13" / "sv2v-Windows" / "sv2v.exe")
  parser.add_argument("--depth", type=int, default=4)
  parser.add_argument("--timeout", type=int, default=300)
  args = parser.parse_args()
  if args.depth < 1 or args.timeout < 1:
    parser.error("--depth and --timeout must be positive")
  args.yosys, args.sv2v = args.yosys.resolve(), args.sv2v.resolve()
  args.output_dir = args.output_dir.resolve()
  args.output_dir.mkdir(parents=True, exist_ok=True)
  env = os.environ.copy()
  env["PATH"] = os.pathsep.join((str(args.yosys.parent),
                                str(args.yosys.parent.parent / "lib"),
                                env.get("PATH", "")))
  manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
  report = {"manifest": str(args.manifest.resolve()),
            "baseline_revision": manifest["baseline_revision"],
            "baseline_sha256": manifest["baseline_sha256"],
            "candidate_sha256": manifest["candidate_sha256"],
            "tools": {}, "cases": []}
  for name, executable, option in (("yosys", args.yosys, "-V"),
                                    ("sv2v", args.sv2v, "--version")):
    result = subprocess.run([str(executable), option], env=env,
                            capture_output=True, text=True, check=True)
    report["tools"][name] = {"path": str(executable),
                             "version": result.stdout.strip(),
                             "sha256": sha256(executable)}
  entries = [entry for entry in manifest["cases"]
             if not args.case or entry["case"]["name"] in args.case]
  if not entries:
    parser.error("No cases selected from the translation manifest")
  report_path = args.output_dir / "equivalence_report.json"
  try:
    for entry in entries:
      report["cases"].append(check_case(entry, args, env))
    report["status"] = "proved"
  except Exception as exc:
    report["status"], report["error"] = "failed", str(exc)
    raise
  finally:
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
  print(f"PROVED {len(entries)} cases; report={report_path}", flush=True)


if __name__ == "__main__":
  main()
