#!/usr/bin/env python3
"""Compare the working CrossbarRTL with a pinned source revision, cycle by cycle.

Run from any directory with the repository's custom PyMTL3 environment::

  python sys_lib/verify_crossbar.py --translate

The comparison includes every output val/rdy/message bit (even invalid messages)
and the persistent counter/multicast state, before and after every clock edge.
Directed protocol scenarios complement deterministic pin-level random stress.
The latter intentionally also changes controls while stalled, so it checks a
superset of normal control-memory traffic without assuming a particular kernel.
This is differential simulation, not a formal proof of all possible executions.
"""

import argparse
import hashlib
import importlib.metadata
import importlib.util
import json
import os
import random
import subprocess
import sys
from collections import Counter, deque
from dataclasses import asdict, dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE = "41cb0c0e94d9373dbb967cb69baa38990d0f402e"
sys.path.insert(0, str(ROOT.parent))

from pymtl3 import DefaultPassGroup
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.lib.messages import mk_ctrl, mk_data
from VectorCGRA.lib.opt_type import OPT_ADD, OPT_START


@dataclass(frozen=True)
class Case:
  name: str
  inputs: int
  outputs: int
  ctrl_size: int
  local_base: int


CASES = (
  Case("routing8x8", 8, 8, 8, 4),
  Case("fu2x8", 2, 8, 8, 4),
  Case("single1x1", 1, 1, 2, 0),
  Case("irregular3x5", 3, 5, 6, 2),
  Case("narrow4x3", 4, 3, 4, 3),
  Case("wide9x10", 9, 10, 5, 4),
)


def load_reference(revision, output_dir):
  """Use a real source file: PyMTL's inspect/AST passes need its source lines."""
  source = subprocess.check_output(
    ["git", "show", f"{revision}:noc/CrossbarRTL.py"], cwd=ROOT)
  reference_dir = output_dir / "reference"
  reference_dir.mkdir(parents=True, exist_ok=True)
  path = reference_dir / "CrossbarRTL_reference.py"
  path.write_bytes(source)
  name = "VectorCGRA.noc._crossbar_verification_reference"
  spec = importlib.util.spec_from_file_location(name, path)
  module = importlib.util.module_from_spec(spec)
  sys.modules[name] = module
  spec.loader.exec_module(module)
  return module.CrossbarRTL, hashlib.sha256(source).hexdigest(), path


def load_candidate(output_dir):
  # Freeze the working source for the entire run. Another task may edit the
  # worktree while we are simulating; inspect must see the code we imported.
  source = (ROOT / "noc" / "CrossbarRTL.py").read_bytes()
  path = output_dir / "reference" / "CrossbarRTL_candidate.py"
  path.write_bytes(source)
  name = "VectorCGRA.noc._crossbar_verification_candidate"
  spec = importlib.util.spec_from_file_location(name, path)
  module = importlib.util.module_from_spec(spec)
  sys.modules[name] = module
  spec.loader.exec_module(module)
  return module.CrossbarRTL, hashlib.sha256(source).hexdigest(), path


def make_model(cls, case, data_type, ctrl_type):
  return cls(data_type, ctrl_type,
             num_inports=case.inputs, num_outports=case.outputs,
             num_cgras=4, num_tiles=16, ctrl_mem_size=case.ctrl_size,
             outport_towards_local_base_id=case.local_base)


def blank_stimulus(case, rng, payload_bits):
  return {
    "reset": 0, "clear": 0, "opt_val": 1, "operation": int(OPT_ADD),
    "compute_done": 0, "ctrl_addr": 0, "cgra_id": 0, "tile_id": 0,
    "crossbar_id": 0,
    "routes": [0] * case.outputs,
    "input_valid": [1] * case.inputs,
    "input_messages": [
      [rng.getrandbits(payload_bits), rng.randrange(2),
       rng.randrange(2), rng.randrange(2)] for _ in range(case.inputs)],
    "output_ready": [1] * case.outputs,
    "prologue_counts": [[0] * case.inputs for _ in range(case.ctrl_size)],
  }


def drive(model, stim, data_type, ctrl_type):
  model.reset @= stim["reset"]
  model.clear @= stim["clear"]
  model.cgra_id @= stim["cgra_id"]
  model.tile_id @= stim["tile_id"]
  model.crossbar_id @= stim["crossbar_id"]
  model.compute_done @= stim["compute_done"]
  model.ctrl_addr_inport @= stim["ctrl_addr"]
  model.recv_opt.val @= stim["opt_val"]
  control = ctrl_type()
  control.operation = type(control.operation)(stim["operation"])
  model.recv_opt.msg @= control
  for i, message in enumerate(stim["input_messages"]):
    model.recv_data[i].val @= stim["input_valid"][i]
    model.recv_data[i].msg @= data_type(*message)
  for j, route in enumerate(stim["routes"]):
    model.crossbar_outport[j] @= route
    model.send_data[j].rdy @= stim["output_ready"][j]
  for addr, counts in enumerate(stim["prologue_counts"]):
    for i, count in enumerate(counts):
      model.prologue_count_inport[addr][i] @= count


def snapshot(model, case):
  values = {"recv_opt.rdy": int(model.recv_opt.rdy),
            "send_accepted": int(model.send_accepted)}
  for i in range(case.inputs):
    values[f"recv_data[{i}].rdy"] = int(model.recv_data[i].rdy)
  for j in range(case.outputs):
    values[f"send_data[{j}].val"] = int(model.send_data[j].val)
    values[f"send_data[{j}].msg"] = int(model.send_data[j].msg.to_bits())
  for addr in range(case.ctrl_size):
    for i in range(case.inputs):
      values[f"prologue_counter[{addr}][{i}]"] = \
        int(model.prologue_counter[addr][i])
  return values


class Comparison:
  def __init__(self, reference_cls, candidate_cls, case, args, output_dir):
    self.case, self.args, self.output_dir = case, args, output_dir
    self.data_type = mk_data(args.payload_bits, 1)
    self.ctrl_type = mk_ctrl(4, 2, 4, 4)
    self.models = [make_model(cls, case, self.data_type, self.ctrl_type)
                   for cls in (reference_cls, candidate_cls)]
    for model in self.models:
      model.elaborate()
      model.apply(DefaultPassGroup())
      model.sim_reset()
    self.cycles = 0
    self.events = Counter()
    self.levels = set()
    self.addresses = set()
    self.selectors = set()
    self.history = deque(maxlen=4)
    self.last_counts = None
    self.last_counters = None
    self.compare("after-initial-reset", {})

  def compare(self, phase, stim):
    snapshots = [snapshot(model, self.case) for model in self.models]
    for name, reference_value in snapshots[0].items():
      candidate_value = snapshots[1][name]
      if reference_value != candidate_value:
        failure = {
          "case": asdict(self.case), "seed": self.args.seed,
          "cycle": self.cycles, "phase": phase, "signal": name,
          "reference": reference_value, "candidate": candidate_value,
          "stimulus": stim, "recent_stimuli": list(self.history),
        }
        path = self.output_dir / f"{self.case.name}_failure.json"
        path.write_text(json.dumps(failure, indent=2) + "\n", encoding="utf-8")
        raise AssertionError(
          f"{self.case.name} cycle {self.cycles} {phase}: {name}: "
          f"reference={reference_value}, candidate={candidate_value}; {path}")

  def step(self, stim, label):
    for model in self.models:
      drive(model, stim, self.data_type, self.ctrl_type)
      model.sim_eval_combinational()
    self.compare(f"{label}:before-edge", stim)
    model = self.models[0]
    self.events[label] += 1
    self.events["opt_handshake"] += int(model.recv_opt.rdy & model.recv_opt.val)
    self.events["opt_invalid"] += int(not stim["opt_val"])
    self.events["opt_start"] += int(stim["operation"] == int(OPT_START))
    self.events["compute_done"] += stim["compute_done"]
    self.events["clear"] += stim["clear"]
    self.events["reset"] += stim["reset"]
    self.events["partial_multicast_state"] += int(
      0 < int(model.send_accepted) < (1 << self.case.outputs) - 1)
    self.events["output_stall"] += int(any(
      int(model.send_data[j].val) and not stim["output_ready"][j]
      for j in range(self.case.outputs)))
    self.events["invalid_message_checks"] += sum(
      not int(model.send_data[j].val) for j in range(self.case.outputs))
    counts = tuple(tuple(row) for row in stim["prologue_counts"])
    self.events["prologue_configuration_changes"] += int(
      self.last_counts is not None and self.last_counts != counts)
    self.last_counts = counts
    self.levels.update(value for row in counts for value in row)
    self.addresses.add(stim["ctrl_addr"])
    self.selectors.update(stim["routes"])
    for model in self.models:
      model.sim_tick()
    self.compare(f"{label}:after-edge", stim)
    counters = [int(value) for row in self.models[0].prologue_counter
                for value in row]
    if self.last_counters is not None:
      self.events["counter_increments"] += sum(
        new > old for old, new in zip(self.last_counters, counters))
    self.last_counters = counters
    self.history.append({"cycle": self.cycles, "label": label,
                         "stimulus": json.loads(json.dumps(stim))})
    self.cycles += 1

  def report(self):
    return {"case": asdict(self.case), "cycles": self.cycles,
            "comparisons": 2 * self.cycles + 1,
            "events": dict(sorted(self.events.items())),
            "prologue_levels": sorted(self.levels),
            "ctrl_addresses": sorted(self.addresses),
            "selector_values": sorted(self.selectors)}


def directed(comparison, rng, args):
  case = comparison.case
  # Every control address and all eight prologue levels, followed by staggered
  # multicast delivery. The same input must be consumed only after all outputs.
  for addr in range(case.ctrl_size):
    for count in range(8):
      stim = blank_stimulus(case, rng, args.payload_bits)
      stim["clear"], stim["opt_val"] = 1, 0
      comparison.step(stim, "directed_clear")
      stim["clear"], stim["opt_val"] = 0, 1
      stim["ctrl_addr"] = addr
      selected = addr % case.inputs
      stim["routes"] = [selected + 1] * case.outputs
      stim["prologue_counts"][addr][selected] = count
      stim["output_ready"] = [0] * case.outputs
      for _ in range(count):
        comparison.step(stim, "directed_prologue_blocked_outputs")
      for j in range(case.outputs):
        stim["output_ready"] = [int(j == k) for k in range(case.outputs)]
        comparison.step(stim, "directed_staggered_multicast")

  # Local compute completion, unavailable operands, unused outputs, START and
  # invalid controls while partial multicast state is present.
  for stop_kind in ("clear", "reset", "opt_invalid", "opt_start"):
    stim = blank_stimulus(case, rng, args.payload_bits)
    stim["clear"], stim["opt_val"] = 1, 0
    comparison.step(stim, "directed_clear")
    stim["clear"], stim["opt_val"] = 0, 1
    stim["routes"] = [1] * case.outputs
    stim["output_ready"] = [1] + [0] * (case.outputs - 1)
    comparison.step(stim, "directed_partial_before_stop")
    if stop_kind in ("reset", "clear"):
      stim[stop_kind] = 1
    elif stop_kind == "opt_invalid":
      stim["opt_val"] = 0
    else:
      stim["operation"] = int(OPT_START)
    comparison.step(stim, f"directed_{stop_kind}_during_partial")
    stim["reset"], stim["clear"], stim["opt_val"] = 0, 0, 1
    stim["operation"] = int(OPT_ADD)
    stim["compute_done"] = 1
    stim["output_ready"] = [int(j < case.local_base)
                            for j in range(case.outputs)]
    comparison.step(stim, "directed_compute_done_local_blocked")
    stim["input_valid"] = [0] * case.inputs
    comparison.step(stim, "directed_missing_input")
    stim["routes"] = [0] * case.outputs
    comparison.step(stim, "directed_no_routes")

  # Updating a configured limit after the counter has advanced checks that a
  # saturating count-up implementation preserves runtime reconfiguration.
  stim = blank_stimulus(case, rng, args.payload_bits)
  stim["clear"], stim["opt_val"] = 1, 0
  comparison.step(stim, "directed_clear")
  stim["clear"], stim["opt_val"] = 0, 1
  stim["routes"] = [1] * case.outputs
  stim["output_ready"] = [0] * case.outputs
  for count in (7, 7, 7, 1, 5, 5, 0, 7, 7, 7, 7):
    stim["prologue_counts"][0][0] = count
    comparison.step(stim, "directed_runtime_prologue_reconfiguration")


def random_stress(comparison, rng, args):
  case = comparison.case
  counts = [[rng.randrange(8) for _ in range(case.inputs)]
            for _ in range(case.ctrl_size)]
  selectors = list(range(case.inputs + 1))
  if args.include_alias_selectors:
    index_bits = max(1, (case.inputs - 1).bit_length())
    selector_bits = case.inputs.bit_length()
    selectors.extend(value for value in range(case.inputs + 1, 1 << selector_bits)
                     if ((value - 1) & ((1 << index_bits) - 1)) < case.inputs)
  for cycle in range(args.cycles):
    stim = blank_stimulus(case, rng, args.payload_bits)
    if cycle % 7 == 0:
      counts[rng.randrange(case.ctrl_size)][rng.randrange(case.inputs)] = \
        rng.randrange(8)
    stim["prologue_counts"] = [row[:] for row in counts]
    stim["ctrl_addr"] = rng.randrange(case.ctrl_size)
    stim["reset"] = int(cycle % 251 == 250)
    stim["clear"] = int(rng.randrange(80) == 0)
    stim["opt_val"] = int(rng.randrange(8) != 0)
    stim["operation"] = rng.choice((int(OPT_START), int(OPT_ADD), 1, 31, 127))
    stim["compute_done"] = rng.randrange(2)
    stim["cgra_id"] = rng.randrange(4)
    stim["tile_id"] = rng.randrange(16)
    stim["crossbar_id"] = rng.randrange(2)
    if cycle % 4 == 0:
      stim["routes"] = [rng.choice(selectors)] * case.outputs
    else:
      stim["routes"] = [rng.choice(selectors) for _ in range(case.outputs)]
    stim["input_valid"] = [int(rng.randrange(4) != 0)
                           for _ in range(case.inputs)]
    stim["output_ready"] = [rng.randrange(2) for _ in range(case.outputs)]
    comparison.step(stim, "random_pin_stress")


def translate(reference_cls, candidate_cls, case, args, output_dir):
  entries = []
  for label, cls in (("reference", reference_cls), ("candidate", candidate_cls)):
    name = f"Crossbar_{label}_{case.name}"
    model = make_model(cls, case, mk_data(args.payload_bits, 1), mk_ctrl(4, 2, 4, 4))
    model.elaborate()
    model.set_metadata(VerilogTranslationPass.enable, True)
    model.set_metadata(VerilogTranslationPass.explicit_module_name, name)
    # This fork writes explicit_file_name twice, whose second os.rename fails
    # on Windows. Use its default generated filename in our output directory.
    generated = output_dir / f"{name}__pickled.v"
    if generated.exists():
      generated.unlink()
    previous_dir = Path.cwd()
    try:
      os.chdir(output_dir)
      model.apply(VerilogTranslationPass())
    finally:
      os.chdir(previous_dir)
    entries.append({"label": label, "module": name,
                    "file": str(generated)})
  return entries


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--baseline", default=BASELINE)
  parser.add_argument("--seed", type=int, default=20260917)
  parser.add_argument("--cycles", type=int, default=3000,
                      help="Random stress cycles per case, in addition to directed tests")
  parser.add_argument("--payload-bits", type=int, default=32)
  parser.add_argument("--case", action="append", choices=[case.name for case in CASES])
  parser.add_argument("--translate", action="store_true",
                      help="Also emit reference/candidate SystemVerilog for each case")
  parser.add_argument("--translate-only", action="store_true",
                      help="Emit SystemVerilog without running differential simulation")
  parser.add_argument("--include-alias-selectors", action="store_true",
                      help="Also check out-of-range selectors that alias a valid input")
  parser.add_argument("--output-dir", type=Path, default=ROOT / "sys_lib" / "build")
  args = parser.parse_args()
  if args.cycles < 0 or args.payload_bits < 1:
    parser.error("--cycles must be nonnegative and --payload-bits must be positive")
  output_dir = args.output_dir.resolve()
  output_dir.mkdir(parents=True, exist_ok=True)
  reference_cls, baseline_hash, reference_path = load_reference(args.baseline, output_dir)
  candidate_cls, candidate_hash, candidate_path = load_candidate(output_dir)
  report = {
    "baseline_revision": args.baseline, "baseline_sha256": baseline_hash,
    "candidate_sha256": candidate_hash,
    "candidate_source": str(candidate_path),
    "reference_source": str(reference_path), "seed": args.seed,
    "python": sys.version, "pymtl3": importlib.metadata.version("pymtl3"),
    "payload_bits": args.payload_bits, "random_cycles_per_case": args.cycles,
    "include_alias_selectors": args.include_alias_selectors,
    "comparison": "All output bits, including invalid messages, plus persistent state; before and after each edge",
    "cases": [],
  }
  for index, case in enumerate(CASES):
    if args.case and case.name not in args.case:
      continue
    rng = random.Random(args.seed + index * 1009)
    if args.translate_only:
      result = {"case": asdict(case), "cycles": 0,
                "simulation": "not run (--translate-only)"}
    else:
      comparison = Comparison(reference_cls, candidate_cls, case, args, output_dir)
      directed(comparison, rng, args)
      random_stress(comparison, rng, args)
      result = comparison.report()
      print(f"PASS {case.name}: {result['cycles']} cycles; "
            f"{result['comparisons']} complete snapshots; "
            f"prologue levels {result['prologue_levels']}", flush=True)
    if args.translate or args.translate_only:
      result["translations"] = translate(
        reference_cls, candidate_cls, case, args, output_dir)
      print(f"TRANSLATED {case.name}: reference and candidate", flush=True)
    report["cases"].append(result)
  report["total_cycles"] = sum(case["cycles"] for case in report["cases"])
  report["status"] = "translated" if args.translate_only else "passed"
  report_name = "crossbar_translation.json" if args.translate_only else "crossbar_verification.json"
  path = output_dir / report_name
  path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
  print(f"{report['status'].upper()} total={report['total_cycles']} cycles; report={path}", flush=True)


if __name__ == "__main__":
  main()
