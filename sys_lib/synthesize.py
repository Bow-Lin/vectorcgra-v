"""Reproducible NanGate45 Yosys area and ABC combinational-delay estimates."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent


def find_tool(name, explicit):
  if explicit:
    return Path(explicit).resolve()
  found = shutil.which(name)
  if found:
    return Path(found)
  candidates = sorted((HERE / "tools").rglob(name + ".exe"))
  if not candidates:
    raise FileNotFoundError(f"{name} not on PATH or under {HERE / 'tools'}")
  return candidates[0]


def quote(path):
  return '"' + str(path).replace("\\", "/") + '"'


def run(command, log, cwd):
  print("Running: " + " ".join(map(str, command)), flush=True)
  start = time.monotonic()
  with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run(list(map(str, command)), cwd=cwd,
                            stdout=stream, stderr=subprocess.STDOUT)
  if result.returncode:
    raise RuntimeError(f"Command failed ({result.returncode}): {log}\n"
                       + log.read_text(errors="replace")[-6000:])
  return time.monotonic() - start


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--input", type=Path, required=True,
                      help="Directory containing manifest.json and translated RTL")
  parser.add_argument("--mode", choices=["hierarchical", "flat", "both"], default="hierarchical")
  parser.add_argument("--yosys")
  parser.add_argument("--sv2v")
  parser.add_argument("--liberty", type=Path,
                      default=HERE / "lib/NangateOpenCellLibrary_typical.lib")
  args = parser.parse_args()
  source = args.input.resolve()
  manifest = json.loads((source / "manifest.json").read_text())
  rtl = source / manifest["rtl"]
  lib = args.liberty.resolve()
  yosys = find_tool("yosys", args.yosys)
  sv2v = find_tool("sv2v", args.sv2v)
  os.environ["PATH"] = str(yosys.parent) + os.pathsep + str(yosys.parent.parent / "lib") + os.pathsep + os.environ.get("PATH", "")
  verilog = source / "design.v"
  conversion_hash = source / "converted.sha256"
  rtl_hash = hashlib.sha256(rtl.read_bytes()).hexdigest()
  # sv2v stdout is the actual converted design; diagnostics go to a separate file.
  if not (verilog.exists() and conversion_hash.exists() and
          conversion_hash.read_text() == rtl_hash):
    with verilog.open("w", encoding="utf-8") as output, \
         (source / "sv2v.log").open("w", encoding="utf-8") as errors:
      subprocess.run([str(sv2v), str(rtl)], stdout=output, stderr=errors, check=True)
    conversion_hash.write_text(rtl_hash)
  modes = ["hierarchical", "flat"] if args.mode == "both" else [args.mode]
  versions = {"yosys": subprocess.check_output([str(yosys), "-V"], text=True).strip(),
              "sv2v": subprocess.check_output([str(sv2v), "--version"], text=True).strip()}
  for mode in modes:
    output_dir = source / mode
    output_dir.mkdir(exist_ok=True)
    constraints = output_dir / "abc.constr"
    constraints.write_text("set_driving_cell BUF_X1\nset_load 5.0\n")
    script = output_dir / "run.ys"
    script.write_text("\n".join([
      f"read_verilog {quote(verilog)}",
      f"hierarchy -check -top {manifest['top']}",
      f"synth -top {manifest['top']} -noabc" + (" -flatten" if mode == "flat" else ""),
      f"dfflibmap -liberty {quote(lib)}",
      f"abc -liberty {quote(lib)} -constr {quote(constraints)}",
      "clean",
      f"tee -o {quote(output_dir / 'stat.txt')} stat -liberty {quote(lib)} -top {manifest['top']}",
      f"tee -o {quote(output_dir / 'stat.json')} stat -json -liberty {quote(lib)} -top {manifest['top']}",
      f"write_json {quote(output_dir / 'mapped.json')}",
      f"write_verilog -noattr {quote(output_dir / 'mapped.v')}",
      f"read_liberty -lib -nooverwrite {quote(lib)}",
      f"tee -o {quote(output_dir / 'check.txt')} check -mapped -assert",
      "",
    ]))
    elapsed = run([yosys, "-T", "-s", script], output_dir / "yosys.log", output_dir)
    log = (output_dir / "yosys.log").read_text(errors="replace")
    delays = [float(x) for x in re.findall(r"ABC:.*?Delay\s*=\s*([0-9.]+)", log)]
    checks = re.findall(r"Found and reported (\d+) problems", log)
    summary = {
      "mode": mode, "versions": versions, "elapsed_seconds": elapsed,
      "liberty_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
      "rtl_sha256": hashlib.sha256(rtl.read_bytes()).hexdigest(),
      "abc_driving_cell": "BUF_X1", "abc_load_ff": 5.0,
      "abc_delay_ps": delays[0] if mode == "flat" and len(delays) == 1 else None,
      "abc_partition_delays_ps": delays,
      "frequency_proxy_mhz": 1e6 / delays[0] if mode == "flat" and len(delays) == 1 and delays[0] else None,
      "final_check_problems": int(checks[-1]) if checks else None,
      "timing_scope": ("Per-module ABC partition diagnostics; no complete-design delay in this summary. "
                       "Use mapped_timing.py for timing across module boundaries." if mode == "hierarchical" else
                      "Full flattened combinational graph, including top I/O and flop D/Q cutpoints. "
                      "ABC Liberty estimate, uniform BUF_X1 drive and 5 fF endpoint load; "
                      "not sequential setup/clock-to-Q or routed STA/Fmax."),
      "area_scope": "Complete CGRA, all behavioral memories mapped to standard cells; "
                    + ("hierarchy preserved for additive attribution." if mode == "hierarchical" else "flattened before optimization/mapping."),
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
  main()
