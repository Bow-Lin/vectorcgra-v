"""Export the complete mapped CGRA as structural timing cutpoints.

This tool does not synthesize, remap, time, or change the hardware design.
Every undefined sink receives a separate disclosed virtual input. Register
outputs and non-clock inputs become launch and endpoint pins. Kahn ordering
retains every original gate, including dangling gates, and every repeated PO.
"""

import argparse
from array import array
from collections import Counter, deque
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import sys
import time

# Works both in this staging package and after installation under sys_lib/.
SYS_LIB = next(parent for parent in Path(__file__).resolve().parents
               if (parent / "mapped_timing.py").is_file())
sys.path.insert(0, str(SYS_LIB))
from mapped_timing import (HierarchyNets, attribute, liberty_cells, select_top,
                          SINGLE_CGRA_INACTIVE_OUTPUTS)


def sha256(path):
  digest = hashlib.sha256()
  with Path(path).open("rb") as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
      digest.update(chunk)
  return digest.hexdigest()


def write_json(path, value):
  Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def export_cut_netlist(design, top, cells, output, inactive_outputs=()):
  """Stream unchanged mapped gates after resolving all hierarchical aliases."""
  hierarchy = HierarchyNets(design, top, cells)
  inputs, endpoints = {}, []
  clock_domains, sequential_types, combinational_types = set(), Counter(), Counter()
  counts = Counter()
  constants = set()
  used_bits = bytearray(len(hierarchy.parents))
  driven_bits = bytearray(len(hierarchy.parents))
  problems = []
  undefined_sinks = []
  inactive_report = []
  missing_inactive = set(inactive_outputs) - set(design["modules"][top]["ports"])
  if missing_inactive:
    raise ValueError(f"Requested inactive output ports do not exist: {missing_inactive}")

  virtual_inputs = []

  def net(bit, label="unlabeled"):
    if bit >= 4:
      return f"n{bit}"
    if bit in (0, 1):
      constants.add(str(bit))
      return "const" + str(bit)
    # Explicit diagnostic hypothesis: every x/z sink gets an independent virtual
    # source. This preserves all real cells/arcs; it is not a hardware netlist fix.
    name = f"virtual_{'01xz'[bit]}_{len(virtual_inputs)}"
    item = {"net": name, "label": label, "kind": "virtual_undefined_inputs",
            "original_constant": "01xz"[bit]}
    virtual_inputs.append(item)
    inputs[-len(virtual_inputs)] = item
    return name

  def driven(bit, label):
    if bit < 4:
      problems.append(f"Cell/primary-input driver tied to constant at {label}")
    elif driven_bits[bit]:
      problems.append(f"Multiple drivers at {label}, net n{bit}")
    else:
      driven_bits[bit] = 1

  def launch(bit, label, kind):
    if bit < 4:
      raise ValueError(f"Constant launch point: {label}")
    if bit not in inputs:
      inputs[bit] = {"net": net(bit), "label": label, "kind": kind}
      driven(bit, label)
    elif kind != "primary_inputs":
      problems.append(f"Aliased sequential output/other driver at {label}, net n{bit}")
    counts[kind] += 1

  def endpoint(bit, label, kind):
    # Constant endpoints have no timing path and must not add a fake launch.
    if bit in (0, 1):
      counts["constant_endpoints"] += 1
      return
    if bit in (2, 3):
      undefined_sinks.append({"kind": kind, "label": label, "constant": "01xz"[bit]})
    endpoints.append({"net": net(bit, label), "label": label, "kind": kind})
    if bit >= 4:
      used_bits[bit] = 1
    counts[kind] += 1

  for name, port in design["modules"][top]["ports"].items():
    if name in inactive_outputs:
      resolved = [hierarchy.resolve(hierarchy.top_base, bit) for bit in port["bits"]]
      if port["direction"] != "output" or any(bit != 2 for bit in resolved):
        raise ValueError(f"Inactive-output exception requires an entire output port of x bits: {name}")
      inactive_report.append({"port": name, "bit_count": len(resolved), "verified_all_bits_x": True,
                              "reason": "is_multi_cgra=false: CgraRTL uses the internal bypass queue instead of this unimplemented inter-CGRA output"})
      counts["inactive_primary_output_bits"] += len(resolved)
      continue
    for index, bit in enumerate(port["bits"]):
      bit = hierarchy.resolve(hierarchy.top_base, bit)
      label = f"{name}[{index}]"
      if port["direction"] == "input":
        launch(bit, label, "primary_inputs")
      elif port["direction"] == "output":
        endpoint(bit, label, "primary_outputs")
      else:
        raise ValueError(f"Inout top port unsupported: {name}")

  def leaf_cells():
    for module_name, path, base in hierarchy.instances:
      for name, cell in design["modules"][module_name]["cells"].items():
        if cell["type"] in cells or cell["type"] == "$scopeinfo":
          yield path + "/" + name, cell, base

  gates_file = output.with_suffix(".gates")
  gate_stream = gates_file.open("w", encoding="utf-8")
  for name, cell, base in leaf_cells():
    typ = cell["type"]
    if typ == "$scopeinfo":
      counts["scope_metadata_cells"] += 1
      continue
    if typ not in cells:
      raise ValueError(f"Unmapped, hierarchical or unknown cell {name}: {typ}")
    definition = cells[typ]
    pins = definition["pins"]
    connections = {pin: [hierarchy.resolve(base, bit) for bit in bits]
                   for pin, bits in cell["connections"].items()}
    if set(connections) != set(pins):
      raise ValueError(f"Unexpected pin set on {name} ({typ}): "
                       f"netlist={sorted(connections)}, library={sorted(pins)}")
    if any(len(bits) != 1 for bits in connections.values()):
      raise ValueError(f"Non-scalar standard-cell pin on {name}")
    if definition["latch"]:
      raise ValueError(f"Latch timing unsupported: {name} ({typ})")
    if definition["ff"]:
      if len(definition["ff"]) != 1:
        raise ValueError(f"Multiple FF groups unsupported: {typ}")
      ff = definition["ff"][0][1]
      clock_expression = attribute(ff, "clocked_on")
      match = re.fullmatch(r"\s*(!?)\s*([A-Za-z_][A-Za-z_0-9]*)\s*", clock_expression or "")
      if not match:
        raise ValueError(f"Unsupported clock expression on {typ}: {clock_expression}")
      clock = match.group(2)
      if pins.get(clock) != "input":
        raise ValueError(f"Clock pin is not a library input: {typ}.{clock}")
      clock_bit = connections[clock][0]
      if clock_bit < 4:
        raise ValueError(f"Constant/undefined clock on {name}")
      clock_domains.add((clock_bit, "negative" if match.group(1) else "positive"))
      expression_inputs = set()
      for attr in ("next_state", "clear", "preset"):
        expression_inputs.update(re.findall(r"[A-Za-z_][A-Za-z_0-9]*", attribute(ff, attr) or ""))
      data_pins = {pin for pin, direction in pins.items() if direction == "input" and pin != clock}
      if expression_inputs != data_pins:
        raise ValueError(f"Unrecognized sequential inputs on {typ}: "
                         f"expressions={expression_inputs}, input pins={data_pins}")
      for pin, direction in pins.items():
        bit = connections[pin][0]
        if direction == "output":
          launch(bit, f"{name}.{pin}", "sequential_output_pins")
        elif direction == "input" and pin != clock:
          endpoint(bit, f"{name}.{pin}", "sequential_input_pins")
        elif direction != "input":
          raise ValueError(f"Invalid sequential pin direction: {typ}.{pin}")
      sequential_types[typ] += 1
    else:
      if sum(direction == "output" for direction in pins.values()) != 1:
        raise ValueError(f"Multi-output or non-combinational cell unsupported: {name} ({typ})")
      gate_stream.write(".gate " + typ + " " + " ".join(
        f"{pin}={net(bits[0], name + chr(46) + pin)}" for pin, bits in connections.items()) + "\n")
      for pin, bits in connections.items():
        if pins[pin] == "input":
          if bits[0] >= 4:
            used_bits[bits[0]] = 1
          elif bits[0] in (2, 3):
            undefined_sinks.append({"kind": "combinational_input_pins", "label": f"{name}.{pin}",
                                    "constant": "01xz"[bits[0]], "cell_type": typ})
        elif pins[pin] == "output":
          driven(bits[0], f"{name}.{pin}")
        else:
          raise ValueError(f"Invalid combinational direction: {typ}.{pin}")
      combinational_types[typ] += 1
  gate_stream.close()
  if len(clock_domains) > 1:
    raise ValueError(f"Multiple clock domains/edges unsupported: {sorted(clock_domains)}")
  undriven = [index for index, used in enumerate(used_bits) if used and not driven_bits[index]]
  if undriven:
    problems.append(f"Undriven mapped nets ({len(undriven)} total): {undriven[:20]}")
  assert len(virtual_inputs) == len(undefined_sinks)
  # Unknown sinks are not hidden: each is an explicit independent virtual PI.
  coverage = {
    "mapped_cells": sum(combinational_types.values()) + sum(sequential_types.values()),
    "combinational_cells": sum(combinational_types.values()),
    "sequential_cells": sum(sequential_types.values()),
    "combinational_cell_types": dict(combinational_types),
    "sequential_cell_types": dict(sequential_types),
    "clock_domains": [{"net": net(bit), "edge": edge} for bit, edge in sorted(clock_domains)],
    "unique_launch_nets": len(inputs), "endpoint_pins": len(endpoints),
    "constant_sources": sorted(constants), **dict(counts),
    "hierarchical_module_instances": len(hierarchy.instances),
    "hierarchical_constant_connections": dict(hierarchy.boundary_constants),
    "active_undefined_constants": len(undefined_sinks), "active_undriven_nets": len(undriven),
    "undefined_sink_kinds": dict(Counter(item["kind"] for item in undefined_sinks)),
    "undefined_sinks": undefined_sinks, "virtual_undefined_inputs": virtual_inputs, "problems": problems,
    "inactive_outputs": inactive_report,
    "inactive_output_verification": "Each inactive port is entirely x. All other x sinks are individually disclosed virtual inputs, not constants or skipped arcs.",
    "logical_flattening": "All module port aliases unified; every mapped leaf cell preserved once per instance",
  }
  (output.parent / "coverage.json").write_text(json.dumps(coverage, indent=2) + "\n")
  if problems:
    raise ValueError("\n".join(problems[:20]))
  # ABC cannot mix .names aliases with .gate library cells. Its own constant
  # pseudo-cells retain a mapped network, and add no real cells or delays.
  with output.open("w", encoding="utf-8") as stream:
    stream.write(".model complete_mapped_cut\n.inputs " + " ".join(item["net"] for item in inputs.values()) + "\n")
    stream.write(".outputs " + " ".join(item["net"] for item in endpoints) + "\n")
    for bit in sorted(constants):
      stream.write(f".gate _const{bit}_ z=const{bit}\n")
    with gates_file.open(encoding="utf-8") as gates:
      shutil.copyfileobj(gates, stream)
    stream.write(".end\n")
  return coverage, list(inputs.values()), endpoints


def order_all_gates(source, output, cells):
  """Apply a deterministic Kahn permutation without dropping gates or ports."""
  start = time.monotonic()
  output_pins = {}
  for typ, item in cells.items():
    if item["ff"] or item["latch"]:
      continue
    outputs = [pin for pin, direction in item["pins"].items()
               if direction == "output"]
    if len(outputs) == 1:
      output_pins[typ] = outputs[0]
  output_pins.update({"_const0_": "z", "_const1_": "z"})
  headers, gates = [], []
  end_line = ".end\n"
  primary_inputs, primary_outputs = [], []
  with source.open(encoding="utf-8", newline="") as stream:
    for line in stream:
      if line.startswith(".gate "):
        gates.append(line)
      elif line.startswith(".end"):
        end_line = line
      elif not line.startswith(".end"):
        headers.append(line)
        if line.startswith(".inputs "):
          primary_inputs.extend(line.split()[1:])
        elif line.startswith(".outputs "):
          primary_outputs.extend(line.split()[1:])

  def parse(line):
    tokens = line.split()
    typ = tokens[1]
    if typ not in output_pins:
      raise ValueError(f"Unsupported gate in ordering input: {typ}")
    ports = dict(token.split("=", 1) for token in tokens[2:])
    gate_output = ports.pop(output_pins[typ])
    return gate_output, ports.values()

  drivers = {}
  for index, line in enumerate(gates):
    gate_output, _ = parse(line)
    if gate_output in drivers:
      raise ValueError(f"Multiple gate drivers for {gate_output}")
    drivers[gate_output] = index
  if len(set(primary_inputs)) != len(primary_inputs):
    raise ValueError("Duplicate launch nets in ordering input")
  inputs = set(primary_inputs)
  if inputs.intersection(drivers):
    raise ValueError("Gate output aliases a primary input")
  n = len(gates)
  heads = array("i", [-1]) * n
  indegree = bytearray(n)
  targets, nexts = array("I"), array("i")
  for index, line in enumerate(gates):
    _, fanins = parse(line)
    for fanin in fanins:
      driver = drivers.get(fanin)
      if driver is not None:
        indegree[index] += 1
        targets.append(index)
        nexts.append(heads[driver])
        heads[driver] = len(targets) - 1
      elif fanin not in inputs:
        raise ValueError(f"Undriven input net in ordering input: {fanin}")
  for net in primary_outputs:
    if net not in drivers and net not in inputs:
      raise ValueError(f"Undriven endpoint net in ordering input: {net}")
  ready = deque(index for index, value in enumerate(indegree) if value == 0)
  order = array("I")
  while ready:
    index = ready.popleft()
    order.append(index)
    edge = heads[index]
    while edge != -1:
      target = targets[edge]
      indegree[target] -= 1
      if indegree[target] == 0:
        ready.append(target)
      edge = nexts[edge]
  report = {
    "input": str(source.resolve()), "input_sha256": sha256(source),
    "gate_statements": n, "intergate_edges": len(targets),
    "ordered_gate_statements": len(order),
    "unprocessed_cyclic_or_cycle_fanout_nodes": n - len(order),
    "primary_input_nets": len(primary_inputs),
    "endpoint_pins": len(primary_outputs),
    "unique_endpoint_nets": len(set(primary_outputs)),
    "repeated_endpoint_pins": len(primary_outputs) - len(set(primary_outputs)),
    "change": "Permutation only; every original gate line and primary port line is preserved byte-for-byte",
  }
  report_file = output.with_suffix(".order.json")
  if len(order) != n:
    report["remaining_examples"] = [line.rstrip() for index, line in enumerate(gates)
                                    if indegree[index]][:20]
    report["elapsed_seconds"] = time.monotonic() - start
    write_json(report_file, report)
    raise ValueError(f"Kahn ordering left {n - len(order)} cyclic or cycle-fanout gates")
  with output.open("w", encoding="utf-8", newline="") as stream:
    stream.writelines(headers)
    for index in order:
      stream.write(gates[index])
    stream.write(end_line)
  report["output_sha256"] = sha256(output)
  report["elapsed_seconds"] = time.monotonic() - start
  write_json(report_file, report)
  return report


def library_metadata(path):
  """Read the Liberty identity and units without assuming timing semantics."""
  text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.S)
  name = re.search(r'\blibrary\s*\(\s*"?([^\s"()]+)"?\s*\)', text)
  time_unit = attribute(text, "time_unit")
  capacitance = re.search(
    r'\bcapacitive_load_unit\s*\(\s*([0-9.eE+-]+)\s*,\s*"?([a-zA-Z]+)"?\s*\)', text)
  if name is None or time_unit is None or capacitance is None:
    raise ValueError("Liberty must declare library name, time_unit and capacitive_load_unit")
  if float(capacitance[1]) <= 0:
    raise ValueError("Liberty capacitive load multiplier must be positive")
  return {"name": name[1], "time_unit": time_unit,
          "capacitive_load_multiplier": float(capacitance[1]),
          "capacitive_load_unit": capacitance[2]}


def prepare(mapped_json, manifest, output, liberty):
  """Create a fresh set of structural cutpoint artifacts and provenance."""
  mapped_json, manifest, output, liberty = map(
    lambda path: Path(path).resolve(), (mapped_json, manifest, output, liberty))
  if output.exists() and (not output.is_dir() or any(output.iterdir())):
    raise ValueError(f"Output must be a fresh or empty directory: {output}")
  output.mkdir(parents=True, exist_ok=True)
  start = time.monotonic()
  provenance = {
    "schema_version": 1, "status": "running",
    "started_utc": datetime.now(timezone.utc).isoformat(),
    "input": str(mapped_json), "manifest": str(manifest), "liberty": str(liberty),
    "tool": str(Path(__file__).resolve()), "tool_sha256": sha256(__file__),
    "mapped_timing_helper_sha256": sha256(SYS_LIB / "mapped_timing.py"),
    "python_version": platform.python_version(),
    "argv": sys.argv,
    "method": "Resolve hierarchy aliases, cut FF pins, disclose each x/z sink as an independent virtual PI, and Kahn-order all mapped gates without optimization",
    "limitation": "Structural timing hypothesis only: virtual inputs do not repair RTL or establish functional reachability. No delay or clock frequency is computed here.",
  }
  provenance_file = output / "provenance.json"
  write_json(provenance_file, provenance)
  try:
    provenance.update({"mapped_json_sha256": sha256(mapped_json),
                       "manifest_sha256": sha256(manifest),
                       "liberty_sha256": sha256(liberty)})
    design = json.loads(mapped_json.read_text(encoding="utf-8"))
    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    top = select_top(design)
    parameters = manifest_data.get("parameters", {})
    if manifest_data.get("top") != top or parameters.get("is_multi_cgra") is not False:
      raise ValueError("A matching marked top and manifest is_multi_cgra=false are required")
    declared_library_hash = manifest_data.get("liberty_sha256")
    if declared_library_hash is not None and declared_library_hash != provenance["liberty_sha256"]:
      raise ValueError("Manifest Liberty SHA256 does not match --liberty")
    fields = library_metadata(liberty)
    cells = liberty_cells(liberty)
    provenance.update({"top": top, "parameters": parameters,
                       "source_git_commit": manifest_data.get("git_commit"),
                       "mapped_json_creator": design.get("creator"),
                       "library_fields": fields,
                       "library_cells": len(cells),
                       "manifest_library_hash_verified": declared_library_hash is not None,
                       "inactive_outputs": sorted(SINGLE_CGRA_INACTIVE_OUTPUTS)})
    write_json(provenance_file, provenance)
    print("Exporting full mapped hierarchy and disclosed virtual inputs", flush=True)
    coverage, inputs, endpoints = export_cut_netlist(
      design, top, cells, output / "full.blif", sorted(SINGLE_CGRA_INACTIVE_OUTPUTS))
    del design
    write_json(output / "cutpoints.json", {"inputs": inputs, "outputs": endpoints})
    print("Ordering all gates with Kahn's algorithm; retaining dangling gates", flush=True)
    order = order_all_gates(output / "full.blif", output / "all_ordered.blif", cells)
    expected = coverage["combinational_cells"] + len(coverage["constant_sources"])
    if order["ordered_gate_statements"] != expected:
      raise ValueError("Ordered gate count differs from mapped combinational cells plus constant pseudo-cells")
    if order["endpoint_pins"] != len(endpoints) or order["primary_input_nets"] != len(inputs):
      raise ValueError("Ordering changed launch or endpoint counts")
    provenance.update({
      "status": "complete", "completed_utc": datetime.now(timezone.utc).isoformat(),
      "elapsed_seconds": time.monotonic() - start,
      "coverage": {key: value for key, value in coverage.items()
                   if key not in ("undefined_sinks", "virtual_undefined_inputs")},
      "input_classes": dict(Counter(item["kind"] for item in inputs)),
      "endpoint_classes": dict(Counter(item["kind"] for item in endpoints)),
      "order": order,
      "artifacts": {name: {"sha256": sha256(output / name),
                            "bytes": (output / name).stat().st_size}
                    for name in ("full.blif", "full.gates", "cutpoints.json", "coverage.json",
                                 "all_ordered.blif", "all_ordered.order.json")},
    })
    write_json(provenance_file, provenance)
    return provenance
  except Exception as error:
    provenance.update({"status": "failed", "reason": str(error),
                       "completed_utc": datetime.now(timezone.utc).isoformat(),
                       "elapsed_seconds": time.monotonic() - start})
    write_json(provenance_file, provenance)
    raise


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--input", type=Path, required=True, help="Hierarchical mapped Yosys JSON")
  parser.add_argument("--manifest", type=Path, required=True)
  parser.add_argument("--output", type=Path, required=True, help="Fresh or empty output directory")
  parser.add_argument("--liberty", type=Path,
                      default=SYS_LIB / "lib/NangateOpenCellLibrary_typical.lib")
  args = parser.parse_args()
  result = prepare(args.input, args.manifest, args.output, args.liberty)
  print(json.dumps({key: result[key] for key in (
    "status", "top", "mapped_json_sha256", "liberty_sha256", "input_classes", "endpoint_classes", "order")}, indent=2))


if __name__ == "__main__":
  main()
