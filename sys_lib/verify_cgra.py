#!/usr/bin/env python3
"""Record/replay complete 4x4 CGRA interfaces against a pinned Git baseline.

  python sys_lib/verify_cgra.py --output-dir sys_lib/build/cgra_stage_b

Baseline and candidate run in fresh processes from separate Python-source
snapshots, including pinned submodules. The baseline records every top-level
input and output before and after every clock edge. The candidate replays the
identical inputs and compares every output bit, including messages with val=0.
JSON summaries contain hashes/counts; gzip traces retain exact replay evidence.
The first mismatch is saved separately with its inputs and recent context.

The hardware parameters match sys_lib/generate.py/test_vector_mesh_4x4. Tests
exercise independent INC, four directional streams across the entire mesh,
boundary multicast with backpressure, and configured prologue behavior. These
are finite integration tests, not proof of every legal configuration.
"""

import argparse
import gzip
import hashlib
import io
import json
import os
import random
import subprocess
import sys
import tarfile
import time
from collections import Counter, deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE = "41cb0c0e94d9373dbb967cb69baa38990d0f402e"
SIDES = ("north", "south", "west", "east")
SCENARIOS = ("inc", "boundary", "boundary_prologue")
KEY_RTL_SOURCES = ("cgra/CgraRTL.py", "noc/CrossbarRTL.py", "noc/StaticSwitchUnitRTL.py")


def canonical(value):
  return json.dumps(value, sort_keys=True, separators=(",", ":"))


def write_json(path, value):
  path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def git(*args, cwd=ROOT):
  return subprocess.check_output(["git", *args], cwd=cwd)


def extract_python_archive(repository, revision, destination):
  names = git("ls-tree", "-r", "--name-only", revision, cwd=repository).decode().splitlines()
  if not any(name.endswith(".py") for name in names):
    return
  data = git("archive", "--format=tar", revision, "--", "*.py", cwd=repository)
  with tarfile.open(fileobj=io.BytesIO(data)) as archive:
    for item in archive:
      if not item.isfile():
        continue
      target = (destination / item.name).resolve()
      if not target.is_relative_to(destination.resolve()):
        raise ValueError(f"Archive member escapes snapshot: {item.name}")
      target.parent.mkdir(parents=True, exist_ok=True)
      target.write_bytes(archive.extractfile(item).read())


def snapshot_sources(output_dir, baseline, include_reference=True):
  records = {}
  baseline_tree = git("ls-tree", "-r", baseline).decode().splitlines()
  submodules = [(line.split()[2], line.split("\t", 1)[1])
                for line in baseline_tree if line.startswith("160000 ")]
  for label in (("reference", "candidate") if include_reference else ("candidate",)):
    destination = output_dir / "sources" / label / "VectorCGRA"
    if destination.exists():
      raise FileExistsError(f"Use a fresh output directory; snapshot exists: {destination}")
    destination.mkdir(parents=True)
    if label == "reference":
      extract_python_archive(ROOT, baseline, destination)
    else:
      names = git("ls-files", "-z", "--cached", "--others", "--exclude-standard",
                  "--", "*.py").decode().split("\0")
      for name in sorted(set(names)):
        if name and (ROOT / name).is_file():
          target = destination / name
          target.parent.mkdir(parents=True, exist_ok=True)
          target.write_bytes((ROOT / name).read_bytes())
    submodule_records = []
    for pinned_revision, name in submodules:
      repository = ROOT / name
      revision = pinned_revision if label == "reference" else \
        git("rev-parse", "HEAD", cwd=repository).decode().strip()
      extract_python_archive(repository, revision, destination / name)
      submodule_records.append({"path": name, "revision": revision})
    files = {}
    for path in sorted(destination.rglob("*.py")):
      files[path.relative_to(destination).as_posix()] = \
        hashlib.sha256(path.read_bytes()).hexdigest()
    records[label] = {
      "root": str(destination), "python_file_count": len(files),
      "source_tree_sha256": hashlib.sha256(canonical(files).encode()).hexdigest(),
      "files": files, "submodules": submodule_records,
    }
  write_json(output_dir / "source_manifest.json", records)
  return records


def load_hardware(source):
  sys.path.insert(0, str(source.parent))
  from pymtl3 import DefaultPassGroup, InPort, OutPort, Interface, mk_bits, clog2
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
  from VectorCGRA.lib import cmd_type, opt_type
  from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt

  data_type = mk_data(32, 1)
  ctrl_type = mk_ctrl(4, 2, 4, 4, 16)
  payload_type = mk_cgra_payload(data_type, mk_bits(clog2(128)),
                                ctrl_type, mk_bits(clog2(6)))
  packet_type = mk_intra_cgra_pkt(4, 1, 16, payload_type)
  fu_list = [AdderRTL, MulRTL, LogicRTL, ShifterRTL, PhiRTL, CompRTL,
             GrantRTL, MemUnitRTL, SelRTL, VectorMulComboRTL, VectorAdderComboRTL]
  dut = CgraRTL(payload_type, 1, 4, 4, 4, 6, 128, 16, 2, 16, 6, 6,
                 True, FlexibleFuRTL, fu_list, "Mesh",
                 {i: [i * 32, (i + 1) * 32 - 1] for i in range(4)},
                 {i: [i, 0] for i in range(4)}, is_multi_cgra=False)
  print("Elaborating complete 4x4 CGRA ...", flush=True)
  started = time.perf_counter()
  dut.elaborate()
  input_ports, output_ports = {}, {}

  def visit(value, path, tokens):
    if isinstance(value, (InPort, OutPort)):
      ports = input_ports if isinstance(value, InPort) else output_ports
      ports[path] = (tokens, value.get_type())
    elif isinstance(value, list):
      for i, child in enumerate(value):
        visit(child, f"{path}[{i}]", tokens + (i,))
    elif isinstance(value, Interface):
      for name, child in vars(value).items():
        if not name.startswith("_"):
          visit(child, f"{path}.{name}", tokens + (name,))

  for name, value in vars(dut).items():
    if not name.startswith("_"):
      visit(value, name, (name,))
  dut.apply(DefaultPassGroup())
  setup_seconds = time.perf_counter() - started
  print(f"Ready: {len(input_ports)} input ports, {len(output_ports)} output ports; "
        f"setup {setup_seconds:.2f}s", flush=True)
  return {"dut": dut, "inputs": input_ports, "outputs": output_ports,
          "data": data_type, "control": ctrl_type, "payload": payload_type,
          "packet": packet_type, "commands": cmd_type, "operations": opt_type,
          "mk_bits": mk_bits, "setup_seconds": setup_seconds}


def resolve(dut, tokens):
  value = dut
  for token in tokens:
    value = value[token] if isinstance(token, int) else getattr(value, token)
  return value


def drive(hw, values):
  for name, (tokens, value_type) in hw["inputs"].items():
    bits = values[name]
    if hasattr(value_type, "__bitstruct_fields__"):
      value = value_type.from_bits(hw["mk_bits"](value_type.nbits)(bits))
    else:
      value = value_type(bits)
    resolve(hw["dut"], tokens).__imatmul__(value)


def outputs(hw):
  result = {}
  for name, (tokens, _) in hw["outputs"].items():
    value = resolve(hw["dut"], tokens)
    result[name] = int(value.to_bits()) if hasattr(value, "to_bits") else int(value)
  return result


def blank_inputs(hw):
  result = {name: 0 for name in hw["inputs"]}
  result["address_upper"] = 31
  return result


def make_control(hw):
  # Same independent INC operand/output wiring as CgraRTL_test.init_param.
  control = hw["control"]()
  control.operation = type(control.operation)(hw["operations"].OPT_INC)
  control.fu_in[0] = type(control.fu_in[0])(1)
  control.fu_xbar_outport[4] = type(control.fu_xbar_outport[4])(1)
  control.read_reg_towards[0] = type(control.read_reg_towards[0])(1)
  control.read_reg_idx[0] = type(control.read_reg_idx[0])(2)
  return control


def program(hw, scenario, seed):
  cmd = hw["commands"]
  packets = []

  def packet(tile, command, count=0, addr=0, control=None):
    value = hw["packet"](0, tile, payload=hw["payload"](
      command, ctrl_addr=addr, data=hw["data"](count, 0),
      ctrl=control if control is not None else hw["control"]()))
    packets.append(int(value.to_bits()))

  routes = ((2, 3), (3, 2), (1, 0), (0, 1))
  for tile in range(16):
    length = 1 if scenario == "inc" else 4
    packet(tile, cmd.CMD_CONFIG_TOTAL_CTRL_COUNT,
           length * (2 if scenario == "boundary_prologue" else 1))
    packet(tile, cmd.CMD_CONFIG_COUNT_PER_ITER, length)
    for addr in range(length):
      control = make_control(hw)
      if scenario != "inc":
        src, dst = routes[addr]
        control.routing_xbar_outport[dst] = type(control.routing_xbar_outport[dst])(src + 1)
        at_source_boundary = ((src == 2 and tile % 4 == 0) or
                              (src == 3 and tile % 4 == 3) or
                              (src == 1 and tile // 4 == 0) or
                              (src == 0 and tile // 4 == 3))
        if at_source_boundary:
          control.routing_xbar_outport[src] = type(control.routing_xbar_outport[src])(src + 1)
      packet(tile, cmd.CMD_CONFIG, addr=addr, control=control)
      if scenario == "boundary_prologue":
        prologue = hw["control"]()
        prologue.routing_xbar_outport[0] = type(prologue.routing_xbar_outport[0])(src + 1)
        packet(tile, cmd.CMD_CONFIG_PROLOGUE_ROUTING_CROSSBAR,
               count=1, addr=addr, control=prologue)
  # Configure every tile before launching any tile; preserve the packet format.
  for tile in range(16):
    packet(tile, cmd.CMD_LAUNCH)

  rng = random.Random(seed)
  boundary_inputs, expected_outputs = {}, {}
  for side in SIDES:
    for lane in range(4):
      message = hw["data"](rng.getrandbits(32), rng.randrange(2), 1, 1)
      boundary_inputs[f"{side}[{lane}]"] = int(message.to_bits())
  if scenario != "inc":
    # Routing preserves payload/predicate and sets the two unused fields to zero.
    for side in SIDES:
      for lane in range(4):
        origins = ("west", "east") if side in ("west", "east") else ("south", "north")
        values = []
        for origin in origins:
          message = hw["data"].from_bits(
            hw["mk_bits"](hw["data"].nbits)(boundary_inputs[f"{origin}[{lane}]"]))
          values.append(int(hw["data"](message.payload, message.predicate, 0, 0).to_bits()))
        expected_outputs[f"{side}[{lane}]"] = values
  return packets, boundary_inputs, expected_outputs


def record(hw, args):
  digest = hashlib.sha256()
  stats = []
  global_cycle = 0
  header = {"kind": "header", "baseline": args.baseline, "seed": args.seed,
            "source": str(args.source), "inputs": {k: t.nbits for k, (_, t) in hw["inputs"].items()},
            "outputs": {k: t.nbits for k, (_, t) in hw["outputs"].items()},
            "scenarios": args.scenario}
  with gzip.open(args.trace, "wt", encoding="utf-8", newline="\n") as trace:
    trace.write(canonical(header) + "\n")

    def step(stimulus, scenario, local_cycle):
      nonlocal global_cycle
      drive(hw, stimulus)
      hw["dut"].sim_eval_combinational()
      before = outputs(hw)
      hw["dut"].sim_tick()
      after = outputs(hw)
      row = {"kind": "cycle", "cycle": global_cycle, "scenario": scenario,
             "local_cycle": local_cycle, "inputs": stimulus,
             "before": before, "after": after}
      encoded = canonical(row)
      digest.update(encoded.encode())
      trace.write(encoded + "\n")
      global_cycle += 1
      return before

    for scenario_index, scenario in enumerate(args.scenario):
      started = time.perf_counter()
      packets, boundary_messages, expected = program(hw, scenario, args.seed + scenario_index)
      initial_cycle = global_cycle
      for i in range(3):
        stimulus = blank_inputs(hw)
        stimulus["reset"] = 1
        step(stimulus, scenario, i - 3)
      packet_index, pending, completed, settled = 0, False, set(), 0
      input_sent, received = set(), {name: [] for name in expected}
      events = Counter()
      for local_cycle in range(args.max_cycles):
        stimulus = blank_inputs(hw)
        if packet_index < len(packets):
          pending = pending or local_cycle % 7 != 0
          stimulus["recv_from_cpu_pkt.val"] = int(pending)
          stimulus["recv_from_cpu_pkt.msg"] = packets[packet_index]
        stimulus["send_to_cpu_pkt.rdy"] = int(local_cycle % 11 not in (0, 1, 2))
        for side_index, side in enumerate(SIDES):
          for lane in range(4):
            name = f"{side}[{lane}]"
            stimulus[f"send_data_on_boundary_{name}.rdy"] = int(
              (local_cycle + side_index * 3 + lane) % 9 not in (0, 1, 2))
            stimulus[f"recv_data_on_boundary_{name}.msg"] = boundary_messages[name]
            stimulus[f"recv_data_on_boundary_{name}.val"] = int(
              scenario != "inc" and name not in input_sent)
        observed = step(stimulus, scenario, local_cycle)
        if stimulus["recv_from_cpu_pkt.val"] and observed["recv_from_cpu_pkt.rdy"]:
          packet_index += 1
          pending = False
          events["cpu_input_handshakes"] += 1
        if observed["send_to_cpu_pkt.val"]:
          if not stimulus["send_to_cpu_pkt.rdy"]:
            events["cpu_output_stall_cycles"] += 1
          else:
            response = hw["packet"].from_bits(hw["mk_bits"](hw["packet"].nbits)(
              observed["send_to_cpu_pkt.msg"]))
            if int(response.payload.cmd) != int(hw["commands"].CMD_COMPLETE):
              raise AssertionError(f"Unexpected CPU response: {response}")
            if int(response.src) in completed:
              raise AssertionError(f"Duplicate COMPLETE from tile {int(response.src)}")
            completed.add(int(response.src))
            events["complete_handshakes"] += 1
        for side in SIDES:
          for lane in range(4):
            name = f"{side}[{lane}]"
            recv, send = f"recv_data_on_boundary_{name}", f"send_data_on_boundary_{name}"
            if stimulus[recv + ".val"] and observed[recv + ".rdy"]:
              input_sent.add(name)
              events["boundary_input_handshakes"] += 1
            if observed[send + ".val"]:
              if not stimulus[send + ".rdy"]:
                events["boundary_output_stall_cycles"] += 1
              else:
                if name not in expected:
                  raise AssertionError(f"Unexpected boundary output in {scenario}: {name}")
                received[name].append(observed[send + ".msg"])
                if received[name] != expected[name][:len(received[name])]:
                  raise AssertionError(f"Wrong/duplicate boundary data at {name}: {received[name]}")
                events["boundary_output_handshakes"] += 1
        complete = packet_index == len(packets) and completed == set(range(16)) and \
          (scenario == "inc" or (len(input_sent) == 16 and received == expected))
        settled = settled + 1 if complete else 0
        if local_cycle % 100 == 0:
          print(f"RECORD {scenario} cycle={local_cycle}, configs={packet_index}/{len(packets)}, "
                f"complete={len(completed)}/16", flush=True)
        if settled >= 8:
          break
      else:
        raise TimeoutError(f"Baseline {scenario} did not finish within {args.max_cycles} cycles: "
                           f"configs={packet_index}/{len(packets)}, complete={sorted(completed)}, "
                           f"received={received}")
      stats.append({"scenario": scenario, "cycles": global_cycle - initial_cycle,
                    "elapsed_seconds": time.perf_counter() - started,
                    "events": dict(events), "complete_tiles": sorted(completed),
                    "boundary_input_ports": sorted(input_sent),
                    "boundary_output_counts": {name: len(values) for name, values in received.items()}})
      print(f"RECORDED {scenario}: {stats[-1]['cycles']} cycles", flush=True)
  return {"status": "recorded", "cycles": global_cycle, "snapshots": global_cycle * 2,
          "trace_sha256": digest.hexdigest(), "scenarios": stats}


def replay(hw, args):
  digest, history, cycles = hashlib.sha256(), deque(maxlen=3), 0
  with gzip.open(args.trace, "rt", encoding="utf-8") as trace:
    header = json.loads(next(trace))
    for direction in ("inputs", "outputs"):
      actual = {k: t.nbits for k, (_, t) in hw[direction].items()}
      if actual != header[direction]:
        raise AssertionError(f"Top-level {direction} interface changed")
    for line in trace:
      row = json.loads(line)
      drive(hw, row["inputs"])
      hw["dut"].sim_eval_combinational()
      candidate = dict(row)
      for phase in ("before", "after"):
        if phase == "after":
          hw["dut"].sim_tick()
        actual = outputs(hw)
        for name, expected in row[phase].items():
          if actual[name] != expected:
            failure = {"cycle": row["cycle"], "scenario": row["scenario"],
                       "local_cycle": row["local_cycle"], "phase": phase,
                       "signal": name, "reference": expected, "candidate": actual[name],
                       "inputs": row["inputs"], "recent_cycles": list(history)}
            write_json(args.output_dir / "first_difference.json", failure)
            raise AssertionError(f"Cycle {row['cycle']} {phase}: {name}: "
                                 f"reference={expected}, candidate={actual[name]}")
        candidate[phase] = actual
      digest.update(canonical(candidate).encode())
      history.append(row)
      cycles += 1
      if cycles % 100 == 0:
        print(f"REPLAY compared {cycles} complete cycles", flush=True)
  return {"status": "passed", "cycles": cycles, "snapshots": cycles * 2,
          "trace_sha256": digest.hexdigest()}


def worker(args):
  started = time.perf_counter()
  result = {"source": str(args.source), "mode": args.mode,
            "python": sys.version, "pid": os.getpid()}
  write_json(args.output_dir / "worker_process.json", {
    "pid": os.getpid(), "source": str(args.source), "mode": args.mode})
  try:
    hw = load_hardware(args.source)
    result["setup_seconds"] = hw["setup_seconds"]
    result.update(record(hw, args) if args.mode == "record" else replay(hw, args))
  except Exception as exc:
    result["status"], result["error"] = "failed", repr(exc)
    raise
  finally:
    result["elapsed_seconds"] = time.perf_counter() - started
    write_json(args.output_dir / "summary.json", result)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--baseline", default=BASELINE)
  parser.add_argument("--output-dir", type=Path,
                      default=ROOT / "sys_lib" / "build" / "cgra_cycle_equivalence")
  parser.add_argument("--scenario", choices=SCENARIOS, action="append")
  parser.add_argument("--seed", type=int, default=20260917)
  parser.add_argument("--max-cycles", type=int, default=800)
  parser.add_argument("--prepare-only", action="store_true")
  parser.add_argument("--record-only", action="store_true",
                      help="Prepare and record baseline stimuli for later candidate replay")
  parser.add_argument("--reference-run", type=Path,
                      help="Reuse a completed reference recording from a prior run directory")
  parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
  parser.add_argument("--mode", choices=("record", "replay"), help=argparse.SUPPRESS)
  parser.add_argument("--source", type=Path, help=argparse.SUPPRESS)
  parser.add_argument("--trace", type=Path, help=argparse.SUPPRESS)
  args = parser.parse_args()
  if args.record_only and args.reference_run:
    parser.error("--record-only cannot be combined with --reference-run")
  if args.reference_run:
    args.reference_run = args.reference_run.resolve()
    with gzip.open(args.reference_run / "reference_trace.jsonl.gz", "rt", encoding="utf-8") as stream:
      prior_header = json.loads(next(stream))
    if prior_header["baseline"] != args.baseline or prior_header["seed"] != args.seed:
      parser.error("The reused reference baseline and seed must match")
    if args.scenario and args.scenario != prior_header["scenarios"]:
      parser.error("The reused reference scenario list must match")
    args.scenario = prior_header["scenarios"]
  args.scenario = args.scenario or list(SCENARIOS)
  args.output_dir = args.output_dir.resolve()
  args.output_dir.mkdir(parents=True, exist_ok=True)
  if args.worker:
    worker(args)
    return
  snapshots = snapshot_sources(args.output_dir, args.baseline, not args.reference_run)
  reference_summary = None
  if args.reference_run:
    prior_manifest = json.loads((args.reference_run / "source_manifest.json").read_text(encoding="utf-8"))
    snapshots["reference"] = prior_manifest["reference"]
    reference_summary = json.loads((args.reference_run / "reference" / "summary.json").read_text(encoding="utf-8"))
    if reference_summary["status"] != "recorded":
      parser.error("The reference recording did not complete successfully")
    write_json(args.output_dir / "source_manifest.json", snapshots)
  if args.prepare_only:
    print(f"Prepared isolated source snapshots: {args.output_dir}")
    return
  report = {"baseline_revision": args.baseline, "seed": args.seed,
            "scenarios": args.scenario, "comparison": "all top-level output bits before/after each edge, including invalid messages",
            "reference_source_sha256": snapshots["reference"]["source_tree_sha256"],
            "candidate_source_sha256": snapshots["candidate"]["source_tree_sha256"],
            "event_units": {"boundary_output_stall_cycles": "port-cycles",
                            "cpu_output_stall_cycles": "cycles"},
            "rtl_source_sha256": {
              label: {name: snapshots[label]["files"].get(name) for name in KEY_RTL_SOURCES}
              for label in ("reference", "candidate")},
            "workers": {}}
  trace = (args.reference_run or args.output_dir) / "reference_trace.jsonl.gz"
  if reference_summary:
    report["workers"]["reference"] = reference_summary
    report["reference_run"] = str(args.reference_run)
  try:
    for label, mode in (("reference", "record"), ("candidate", "replay")):
      if label == "reference" and reference_summary:
        continue
      if label == "candidate" and args.record_only:
        continue
      directory = args.output_dir / label
      directory.mkdir()
      command = [sys.executable, str(Path(__file__).resolve()), "--worker", "--mode", mode,
                 "--source", snapshots[label]["root"], "--output-dir", str(directory),
                 "--trace", str(trace), "--baseline", args.baseline,
                 "--seed", str(args.seed), "--max-cycles", str(args.max_cycles)]
      for scenario in args.scenario:
        command.extend(("--scenario", scenario))
      print(f"START {label}: {mode}; log={directory / 'worker.log'}", flush=True)
      with (directory / "worker.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=directory, stdout=log, stderr=subprocess.STDOUT)
      summary_path = directory / "summary.json"
      if summary_path.exists():
        report["workers"][label] = json.loads(summary_path.read_text(encoding="utf-8"))
      if result.returncode:
        tail = (directory / "worker.log").read_text(encoding="utf-8", errors="replace").splitlines()[-25:]
        raise RuntimeError(f"{label} worker failed ({result.returncode}):\n" + "\n".join(tail))
    reference = report["workers"]["reference"]
    if args.record_only:
      report["status"] = "recorded"
    else:
      candidate = report["workers"]["candidate"]
      if reference["trace_sha256"] != candidate["trace_sha256"] or reference["cycles"] != candidate["cycles"]:
        raise AssertionError("Final trace hash/count differs despite cycle comparisons")
      report["status"] = "passed"
    print(f"{report['status'].upper()} {reference['cycles']} cycles, {reference['snapshots']} complete snapshots; "
          f"report={args.output_dir / 'verification_report.json'}", flush=True)
  except Exception as exc:
    report["status"], report["error"] = "failed", repr(exc)
    raise
  finally:
    write_json(args.output_dir / "verification_report.json", report)


if __name__ == "__main__":
  main()
