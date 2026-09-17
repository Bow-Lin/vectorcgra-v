"""Time the complete mapped CGRA with the ABC shipped alongside Yosys.

The netlist is only flattened, never remapped. Sequential outputs become
launch points and non-clock sequential inputs become endpoints. This is a
combinational delay / reciprocal-frequency proxy, not sequential STA.
"""

import argparse
from array import array
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
SINGLE_CGRA_INACTIVE_OUTPUTS = {
  "recv_from_inter_cgra_noc__rdy",
  "send_to_inter_cgra_noc__val",
  "send_to_inter_cgra_noc__msg",
}


def groups(text, keyword):
  """Return named Liberty groups, respecting braces inside quoted strings."""
  pattern = re.compile(r"\b" + re.escape(keyword) + r"\s*\(([^)]*)\)\s*\{")
  for match in pattern.finditer(text):
    depth, quoted, escaped = 1, False, False
    start = match.end()
    for pos in range(start, len(text)):
      char = text[pos]
      if escaped:
        escaped = False
      elif char == "\\" and quoted:
        escaped = True
      elif char == '"':
        quoted = not quoted
      elif not quoted:
        depth += (char == "{") - (char == "}")
        if depth == 0:
          yield match.group(1).strip().strip('"'), text[start:pos]
          break
    else:
      raise ValueError(f"Unterminated Liberty {keyword} group")


def attribute(text, name):
  match = re.search(r"\b" + re.escape(name) + r'\s*:\s*("[^"]*"|[^;]+);', text)
  return match.group(1).strip().strip('"') if match else None


def liberty_cells(path):
  text = path.read_text(encoding="utf-8")
  text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
  cells = {}
  for name, body in groups(text, "cell"):
    pins = {pin: attribute(pin_body, "direction")
            for pin, pin_body in groups(body, "pin")}
    ff = list(groups(body, "ff"))
    latch = list(groups(body, "latch"))
    cells[name] = {"pins": pins, "ff": ff, "latch": latch,
                   "area": float(attribute(body, "area") or 0)}
  if not cells:
    raise ValueError("Liberty file has no cells")
  return cells


def quote(path):
  return '"' + str(path).replace("\\", "/").replace('"', '\\"') + '"'


def find_yosys(explicit=None):
  if explicit:
    return Path(explicit).resolve()
  executable = shutil.which("yosys")
  if executable:
    return Path(executable).resolve()
  candidates = sorted((HERE / "tools").rglob("yosys.exe"))
  if not candidates:
    raise FileNotFoundError("yosys not found; pass --yosys")
  return candidates[0].resolve()


def run(command, log, cwd, env):
  with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run([str(x) for x in command], cwd=cwd, env=env,
                            stdout=stream, stderr=subprocess.STDOUT)
  contents = log.read_text(errors="replace")
  if result.returncode:
    raise RuntimeError(f"Tool failed ({result.returncode}); see {log}\n{contents[-3000:]}")
  return contents


def select_top(design, explicit=None):
  modules = design["modules"]
  if explicit:
    if explicit not in modules:
      raise ValueError(f"Unknown top module {explicit}")
    return explicit
  tops = [name for name, module in modules.items()
          if str(module.get("attributes", {}).get("top", "0")).lstrip("0") == "1"]
  if len(tops) != 1:
    raise ValueError(f"Expected one marked top, found {tops}; pass --top")
  return tops[0]


class HierarchyNets:
  """Resolve port aliases without materializing millions of cell dictionaries.

  Each instance owns a range of numeric net IDs. Union/find identifies the
  *same wire* on the two sides of every port. No logic optimization is done.
  IDs 0/1/2/3 represent Liberty/JSON constants 0/1/x/z respectively.
  """

  def __init__(self, design, top, cells):
    self.modules = design["modules"]
    self.cells = cells
    self.parents = array("I", range(4))
    self.instances = []
    self.boundary_constants = Counter()
    self.sizes = {}
    for name, module in self.modules.items():
      bits = (bit for port in module.get("ports", {}).values() for bit in port["bits"])
      maximum = max((bit for bit in bits if isinstance(bit, int)), default=0)
      for cell in module.get("cells", {}).values():
        for conn in cell["connections"].values():
          maximum = max(maximum, max((b for b in conn if isinstance(b, int)), default=0))
      self.sizes[name] = maximum + 1
    self.top_base = self.add_instance(top, top, (), None)

  def find(self, value):
    parents = self.parents
    while parents[value] != value:
      parents[value] = parents[parents[value]]
      value = parents[value]
    return value

  def union(self, first, second):
    first, second = self.find(first), self.find(second)
    if first == second:
      return
    if first < 4 and second < 4:
      raise ValueError(f"Conflicting constant aliases: {first}, {second}")
    # Choosing the lower ID keeps parent-interface IDs stable and prioritizes
    # constants. All equivalences are wiring aliases, never Boolean inference.
    self.parents[max(first, second)] = min(first, second)

  @staticmethod
  def local(base, bit):
    return base + bit if isinstance(bit, int) else "01xz".index(bit)

  def add_instance(self, module_name, path, ancestors, port_bindings):
    if module_name in ancestors:
      raise ValueError(f"Recursive module hierarchy at {path}")
    module = self.modules[module_name]
    if module.get("attributes", {}).get("blackbox") or module.get("attributes", {}).get("whitebox"):
      raise ValueError(f"Unknown non-library blackbox {path} ({module_name})")
    base = len(self.parents)
    self.parents.extend(range(base, base + self.sizes[module_name]))
    self.instances.append((module_name, path, base))
    if port_bindings is not None:
      if set(port_bindings) != set(module["ports"]):
        raise ValueError(f"Hierarchical pin-set mismatch at {path}")
      for pin, port in module["ports"].items():
        bound = port_bindings[pin]
        if len(bound) != len(port["bits"]):
          raise ValueError(f"Hierarchical width mismatch at {path}.{pin}")
        for inside, outside in zip(port["bits"], bound):
          if outside < 4:
            self.boundary_constants["01xz"[outside]] += 1
          self.union(self.local(base, inside), outside)
    for name, cell in module["cells"].items():
      typ = cell["type"]
      if typ in self.cells or typ == "$scopeinfo":
        continue
      if typ not in self.modules:
        raise ValueError(f"Unknown cell {path}/{name} ({typ})")
      bindings = {pin: [self.local(base, bit) for bit in bits]
                  for pin, bits in cell["connections"].items()}
      self.add_instance(typ, path + "/" + name, ancestors + (module_name,), bindings)
    return base

  def resolve(self, base, bit):
    return self.find(self.local(base, bit))


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

  def net(bit):
    if bit >= 4:
      return f"n{bit}"
    if bit in (0, 1):
      constants.add(str(bit))
      return "const" + str(bit)
    # A placeholder is written only into a staging file. Any active undefined
    # sink prevents final BLIF creation and ABC execution below.
    return "undefined_" + "01xz"[bit]

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
    endpoints.append({"net": net(bit), "label": label, "kind": kind})
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
        f"{pin}={net(bits[0])}" for pin, bits in connections.items()) + "\n")
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
  if undefined_sinks:
    problems.append(f"{len(undefined_sinks)} active sinks have undefined constants; see coverage.json")
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
    "undefined_sinks": undefined_sinks, "problems": problems,
    "inactive_outputs": inactive_report,
    "inactive_output_verification": "Each explicitly named port is entirely x; no x may reach any mapped gate input, FF input, or enabled top output",
    "logical_flattening": "All module port aliases unified; every mapped leaf cell preserved once per instance",
  }
  (output.parent / "coverage.json").write_text(json.dumps(coverage, indent=2) + "\n")
  if problems:
    raise ValueError("\n".join(problems[:20]))
  # ABC cannot mix .names aliases with .gate library cells. Its own constant
  # pseudo-cells retain a mapped network, and add no real cells or delays.
  with output.open("w", encoding="utf-8") as stream:
    stream.write(".model complete_mapped_cut\n.inputs " + " ".join(net(bit) for bit in inputs) + "\n")
    stream.write(".outputs " + " ".join(item["net"] for item in endpoints) + "\n")
    for bit in sorted(constants):
      stream.write(f".gate _const{bit}_ z=const{bit}\n")
    with gates_file.open(encoding="utf-8") as gates:
      shutil.copyfileobj(gates, stream)
    stream.write(".end\n")
  return coverage, list(inputs.values()), endpoints


def analyze(mapped_json, liberty, yosys, output_dir, top=None, driver="BUF_X1", load_ff=5.0,
            inactive_outputs=(), manifest=None):
  start = time.monotonic()
  mapped_json, liberty, yosys = map(lambda p: Path(p).resolve(), (mapped_json, liberty, yosys))
  output_dir = Path(output_dir).resolve()
  output_dir.mkdir(parents=True, exist_ok=True)
  if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", driver) or load_ff < 0:
    raise ValueError("Invalid driving cell or endpoint load")
  abc = yosys.with_name("yosys-abc.exe" if yosys.suffix == ".exe" else "yosys-abc")
  if not abc.exists():
    raise FileNotFoundError(f"Companion ABC executable missing: {abc}")
  env = os.environ.copy()
  env["PATH"] = os.pathsep.join([str(yosys.parent), str(yosys.parent.parent / "lib"), env.get("PATH", "")])
  design = json.loads(mapped_json.read_text())
  top = select_top(design, top)
  manifest_data = None
  if inactive_outputs:
    if set(inactive_outputs) - SINGLE_CGRA_INACTIVE_OUTPUTS:
      raise ValueError("Only the three unimplemented single-CGRA inter-CGRA output ports can be declared inactive")
    if manifest is None:
      raise ValueError("--manifest is required with --inactive-output")
    manifest_data = json.loads(Path(manifest).read_text())
    if manifest_data.get("parameters", {}).get("is_multi_cgra") is not False or manifest_data.get("top") != top:
      raise ValueError("Inactive inter-CGRA outputs require a matching top manifest with is_multi_cgra=false")
  metadata = {
    "schema_version": 1, "started_utc": datetime.now(timezone.utc).isoformat(),
    "top": top, "method": "ABC stime over logically flattened, unchanged mapped cells with FF cutpoints",
    "input": str(mapped_json), "abc_driving_cell": driver, "abc_load_ff": load_ff,
    "abc_delay_ps": None, "frequency_proxy_mhz": None,
    "mapped_json_sha256": hashlib.sha256(mapped_json.read_bytes()).hexdigest(),
    "liberty_sha256": hashlib.sha256(liberty.read_bytes()).hexdigest(),
    "yosys_version": subprocess.check_output([str(yosys), "-V"], env=env, text=True).strip(),
    "abc_version": subprocess.check_output([str(abc), "-s", "-c", "version"], env=env, text=True).strip(),
    "timing_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "manifest_sha256": hashlib.sha256(Path(manifest).read_bytes()).hexdigest() if manifest else None,
    "parameters": manifest_data.get("parameters") if manifest_data else None,
    "explicit_inactive_outputs": sorted(inactive_outputs),
  }
  metadata_file = output_dir / "timing_metadata.json"
  metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")
  script = output_dir / "check.ys"
  script.write_text("\n".join([
    f"read_json {quote(mapped_json)}",
    f"read_liberty -lib -nooverwrite {quote(liberty)}",
    f"hierarchy -check -top {top}", "check", "",
  ]))
  check_log = run([yosys, "-Q", "-T", "-s", script], output_dir / "check.log", output_dir, env)
  checks = re.findall(r"Found and reported (\d+) problems", check_log)
  if len(checks) != 1 or int(checks[0]):
    raise RuntimeError(f"Mapped netlist check with Liberty did not pass: {output_dir / 'check.log'}")
  metadata["netlist_check_problems"] = int(checks[0])
  metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")
  cells = liberty_cells(liberty)
  if driver not in cells or cells[driver]["ff"] or cells[driver]["latch"]:
    raise ValueError(f"Invalid combinational driving cell {driver}")
  blif = output_dir / "timing_cut.blif"
  print("Exporting complete hierarchy to mapped BLIF without remapping", flush=True)
  coverage, inputs, endpoints = export_cut_netlist(design, top, cells, blif, inactive_outputs)
  (output_dir / "cutpoints.json").write_text(json.dumps({"inputs": inputs, "outputs": endpoints}, indent=2) + "\n")
  constraints = output_dir / "abc.constr"
  constraints.write_text(f"set_driving_cell {driver}\nset_load {load_ff}\n")
  abc_script = output_dir / "timing.abc"
  abc_script.write_text("\n".join([
    f"read_lib {quote(liberty)}", f"read_blif {quote(blif)}",
    f"read_constr {quote(constraints)}", "topo", "stime -p", "",
  ]))
  log = run([abc, "-s", "-f", abc_script], output_dir / "abc_timing.log", output_dir, env)
  matches = re.findall(r"Gates\s*=\s*(\d+).*?Delay\s*=\s*([0-9.]+)\s*ps", log)
  if len(matches) != 1:
    raise RuntimeError(f"ABC did not report one complete timing graph; see {output_dir / 'abc_timing.log'}\n{log[-3000:]}")
  timed_gates, delay = int(matches[0][0]), float(matches[0][1])
  if timed_gates != coverage["combinational_cells"]:
    raise RuntimeError(f"ABC cell coverage mismatch: {timed_gates} timed versus {coverage['combinational_cells']} exported")
  path_match = re.search(r"Start-point = pi(\d+)\.\s+End-point = po(\d+)\.", log)
  critical_path = {"abc_path_lines": [line for line in log.splitlines() if line.startswith("Path ")]}
  if path_match:
    pi_index, po_index = map(int, path_match.groups())
    critical_path.update({"input_index": pi_index, "output_index": po_index,
                          "startpoint": inputs[pi_index], "endpoint": endpoints[po_index]})
  result = {
    **metadata,
    "status": "complete", "completed_utc": datetime.now(timezone.utc).isoformat(),
    "elapsed_seconds": time.monotonic() - start,
    "abc_delay_ps": delay, "frequency_proxy_mhz": 1e6 / delay if delay else None,
    "abc_driving_cell": driver, "abc_load_ff": load_ff, "abc_timed_gates": timed_gates,
    "critical_path": critical_path,
    "coverage": coverage,
    "timing_scope": "All enabled top input/output and FF cutpoint paths across the complete CGRA. "
      "All FF data, reset, set and scan input pins are endpoints; only clock pins are excluded. "
      "Uniform driving cell and load apply to each endpoint pin, including repeated endpoint nets. "
      "No functional false-path exclusions or I/O arrival/required-time constraints. "
      "No sequential clock-to-Q/setup/recovery/removal, clock skew, or routed wire delays. "
      "The reciprocal is a combinational frequency proxy, not signoff Fmax.",
  }
  (output_dir / "timing.json").write_text(json.dumps(result, indent=2) + "\n")
  return result


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--input", "--mapped-json", type=Path, required=True, dest="mapped_json")
  parser.add_argument("--output", type=Path, required=True)
  parser.add_argument("--liberty", type=Path, default=HERE / "lib/NangateOpenCellLibrary_typical.lib")
  parser.add_argument("--yosys")
  parser.add_argument("--top")
  parser.add_argument("--driver", default="BUF_X1")
  parser.add_argument("--load-ff", type=float, default=5.0)
  parser.add_argument("--manifest", type=Path)
  parser.add_argument("--inactive-output", action="append", default=[],
                      help="Explicit, fully-x single-CGRA inter-CGRA output; requires matching --manifest")
  args = parser.parse_args()
  try:
    result = analyze(args.mapped_json, args.liberty, find_yosys(args.yosys),
                     args.output, args.top, args.driver, args.load_ff, args.inactive_output, args.manifest)
  except Exception as error:
    args.output.mkdir(parents=True, exist_ok=True)
    metadata = args.output / "timing_metadata.json"
    result = json.loads(metadata.read_text()) if metadata.exists() else {}
    result.update({"status": "blocked", "recorded_utc": datetime.now(timezone.utc).isoformat(),
              "input": str(args.mapped_json.resolve()), "reason": str(error),
              "abc_delay_ps": None, "frequency_proxy_mhz": None})
    coverage_file = args.output / "coverage.json"
    if coverage_file.exists():
      coverage = json.loads(coverage_file.read_text())
      # Keep timing.json compact; exhaustive pin lists remain in coverage.json.
      result["coverage"] = {key: value for key, value in coverage.items() if key != "undefined_sinks"}
    (args.output / "timing.json").write_text(json.dumps(result, indent=2) + "\n")
    raise
  print(json.dumps(result, indent=2))


if __name__ == "__main__":
  main()
