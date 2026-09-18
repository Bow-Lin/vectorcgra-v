"""Independent, class-aware NLDM diagnostic; never modifies mapped gates.

This follows ABC sclLib.h lookup/driver rules and sclLoad.c pin-load sums.
The stock ABC tool cannot directly report these path classes. The code must be
cross-checked against ABC on identical graphs before its estimates are used.
"""
import argparse
from array import array
from bisect import bisect_right
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in (HERE, *HERE.parents) if (p / "sys_lib/mapped_timing.py").is_file())
sys.path.insert(0, str(ROOT / "sys_lib"))
from mapped_timing import groups, attribute

PROTOTYPE_SCRIPT_SHA256 = "a947b19d363e90a3fc7fbeef77152cfc1cc5a83a98aa66ceb1b5ef9bbeff2737"
ENGINE_MATH_SHA256 = "858d1ddc3c9f4d7adc2807df7561991db115b49a37614b22f8d5d9f8824db781"

CLASSES = {"primary_inputs": 0, "sequential_output_pins": 1, "virtual_undefined_inputs": 2}
CLASS_NAMES = ["PI", "FF", "VIRTUAL"]
NEG = float("-inf")

def nums(text):
  return [float(x) for x in re.findall(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", text)]

def vector(body, keyword):
  found = re.search(r"\b" + keyword + r"\s*\((.*?)\)\s*;", body, re.S)
  if not found:
    raise ValueError(f"Missing {keyword}")
  return nums(found.group(1))

def table(body, name):
  matches = list(groups(body, name))
  if len(matches) != 1:
    raise ValueError(f"Expected one {name} table, got {len(matches)}")
  _, text = matches[0]
  x, y, values = vector(text, "index_1"), vector(text, "index_2"), vector(text, "values")
  assert len(values) == len(x) * len(y)
  return (x, y, values)

def lookup(tab, slew, load):
  x, y, values = tab
  if len(x) < 2 or len(y) < 2:
    raise ValueError("This experiment supports only the observed 2-D NLDM tables")
  i = min(max(bisect_right(x, slew)-1, 0), len(x)-2)
  j = min(max(bisect_right(y, load)-1, 0), len(y)-2)
  sf = (slew-x[i])/(x[i+1]-x[i])
  lf = (load-y[j])/(y[j+1]-y[j])
  p = i*len(y)+j
  a = values[p] + lf*(values[p+1]-values[p])
  p += len(y)
  b = values[p] + lf*(values[p+1]-values[p])
  return a + sf*(b-a)

def library(path):
  text = re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)
  assert attribute(text, "time_unit") == "1ns"
  assert re.search(r"capacitive_load_unit\s*\(\s*1\s*,\s*ff\s*\)", text)
  out = {}
  for typ, body in groups(text, "cell"):
    if list(groups(body, "ff")) or list(groups(body, "latch")):
      continue
    pins = dict(groups(body, "pin"))
    ins = [p for p,b in pins.items() if attribute(b,"direction") == "input"]
    outs = [p for p,b in pins.items() if attribute(b,"direction") == "output"]
    if len(outs) != 1 or not ins:
      continue
    op = outs[0]
    if attribute(pins[op], "three_state"):
      continue
    arcs = defaultdict(list)
    for _, timing in groups(pins[op], "timing"):
      related = attribute(timing, "related_pin")
      if related not in ins:
        raise ValueError((typ, related))
      names = ["cell_rise", "cell_fall", "rise_transition", "fall_transition"]
      if not list(groups(timing, "cell_rise")):
        continue
      arcs[related].append((attribute(timing,"timing_sense"), [table(timing,n) for n in names]))
    if set(arcs) != set(ins):
      continue
    merged = []
    for pin in ins:
      choices = arcs[pin]
      # ABC merges conditional tables pointwise, keeping the first sense.
      sense = choices[0][0]
      # Match the current ABC Liberty reader: it chooses the first condition's
      # sense and merges all conditional tables pointwise. Record the limitation.
      mixed_senses = sorted({c[0] for c in choices})
      pairs = {"positive_unate": ((0,0),(1,1)), "negative_unate": ((1,0),(0,1)),
               "non_unate": ((0,0),(1,1),(1,0),(0,1))}[sense]
      tabs = []
      for k in range(4):
        base = choices[0][1][k]
        assert all(c[1][k][:2] == base[:2] for c in choices)
        tabs.append((base[0],base[1],[max(c[1][k][2][i] for c in choices) for i in range(len(base[2]))]))
      cap = float(attribute(pins[pin], "capacitance") or 0)
      caps = [float(attribute(pins[pin], n) or 0) or cap for n in ("rise_capacitance", "fall_capacitance")]
      merged.append({"pin": pin, "caps": caps, "pairs": pairs, "tabs": tabs,
                     "conditional_senses": mixed_senses, "abc_selected_sense": sense})
    out[typ] = {"name": typ, "inputs": ins, "output": op, "arcs": merged,
                "area": float(attribute(body,"area") or 0)}
  return out

def analyze(blif, cuts, lib, absolute_driver=False, all_only=False, retain_reachable_only=False):
  began = time.monotonic()
  models = library(lib)
  cut = json.loads(cuts.read_text())
  index, names, source_class = {}, [], []
  types, starts, fanins = array("i"), array("I"), array("I")
  models_list, model_index = [], {}
  in_records = {item["net"]: item for item in cut["inputs"]}
  def add_net(net, cls=-1, typ=-1):
    assert net not in index, net
    nid = len(names)
    index[net] = nid
    names.append(net)
    source_class.append(cls)
    types.append(typ)
    starts.append(len(fanins))
    return nid
  gate_counts = Counter()
  with blif.open() as f:
    for line in f:
      if line.startswith(".inputs "):
        for net in line.split()[1:]:
          add_net(net, CLASSES[in_records[net]["kind"]])
      elif line.startswith(".gate "):
        tok = line.split()
        typ, pins = tok[1], dict(x.split("=",1) for x in tok[2:])
        if typ.startswith("_const"):
          add_net(pins["z"], -2, -2)
          continue
        model = models[typ]
        if typ not in model_index:
          model_index[typ] = len(models_list)
          models_list.append(model)
        output = pins.pop(model["output"])
        assert set(pins) == set(model["inputs"]), typ
        add_net(output, -1, model_index[typ])
        for pin in model["inputs"]:
          if pins[pin] not in index:
            raise ValueError(f"Graph is not topological at {output}: {pins[pin]}")
          fanins.append(index[pins[pin]])
        gate_counts[typ] += 1
  n = len(names)
  output_ids = [index[item["net"]] for item in cut["outputs"]]
  active = bytearray([1])*n
  if retain_reachable_only:
    # ABC topo drops every node outside an endpoint cone. This mode is only
    # for matching that explicitly pruned diagnostic, never the final full graph.
    active = bytearray(n)
    stack = output_ids.copy()
    while stack:
      i = stack.pop()
      if active[i]:
        continue
      active[i] = 1
      if types[i] >= 0:
        m = models_list[types[i]]
        stack.extend(fanins[starts[i]:starts[i]+len(m["inputs"])])
  loads = [array("d", [0.0])*n for _ in range(2)]
  for i in range(n):
    if types[i] < 0 or not active[i]:
      continue
    for k,arc in enumerate(models_list[types[i]]["arcs"]):
      src = fanins[starts[i]+k]
      loads[0][src] += arc["caps"][0]
      loads[1][src] += arc["caps"][1]
  for oid in output_ids:
    loads[0][oid] += 5.0
    loads[1][oid] += 5.0
  slew = [array("d", [0.0])*n for _ in range(2)]
  arrival = [array("d", [0.0])*n for _ in range(2)]
  predall = [array("q", [-1])*n for _ in range(2)]
  classarr = [] if all_only else [array("d", [NEG])*n for _ in range(6)]
  pred = [] if all_only else [array("q", [-1])*n for _ in range(6)]
  driver = models["BUF_X1"]["arcs"][0]
  driver0 = [max(0.0, lookup(driver["tabs"][p], 0.0, 0.0)) for p in range(2)]
  extrapolations = Counter()
  for i in range(n):
    if not active[i]:
      continue
    cls = source_class[i]
    if cls >= 0:
      for p in range(2):
        delay = max(0.0,lookup(driver["tabs"][p],0.0,loads[p][i]))
        if not absolute_driver:
          delay -= driver0[p]
        arrival[p][i] = delay
        slew[p][i] = max(0.0,lookup(driver["tabs"][p+2],0.0,loads[p][i]))
        if not all_only:
          classarr[cls*2+p][i] = delay
      continue
    if types[i] < 0:
      continue
    model = models_list[types[i]]
    for k,arc in enumerate(model["arcs"]):
      src = fanins[starts[i]+k]
      for ip,op in arc["pairs"]:
        st, load = slew[ip][src], loads[op][i]
        tab = arc["tabs"][op]
        if st < tab[0][0] or st > tab[0][-1]:
          extrapolations["arc_delay_slew_outside_table"] += 1
        if load < tab[1][0] or load > tab[1][-1]:
          extrapolations["arc_delay_load_outside_table"] += 1
        delay = lookup(tab,st,load)
        out_slew = lookup(arc["tabs"][op+2],st,load)
        if out_slew > slew[op][i]:
          slew[op][i] = out_slew
        a = arrival[ip][src]+delay
        if a > arrival[op][i]:
          arrival[op][i], predall[op][i] = a, 2*src+ip
        if not all_only:
          for c in range(3):
            row = 2*c+op
            a = classarr[2*c+ip][src]+delay
            if a > classarr[row][i]:
              classarr[row][i], pred[row][i] = a, 2*src+ip
    if i % 200000 == 0:
      print(f"Timed {i}/{n} graph nodes; {time.monotonic()-began:.1f}s", flush=True)
  def path(oid, p, c=None):
    steps = []
    node = oid
    while types[node] >= 0:
      code = predall[p][node] if c is None else pred[2*c+p][node]
      if code < 0:
        break
      src, ip = divmod(code,2)
      model = models_list[types[node]]
      pins = [model["inputs"][k] for k in range(len(model["inputs"])) if fanins[starts[node]+k] == src]
      steps.append({"output_net": names[node], "type": model["name"],
                    "output_polarity": ["rise","fall"][p], "input_net": names[src],
                    "input_polarity": ["rise","fall"][ip], "candidate_input_pins": pins})
      node,p = src,ip
    return {"startpoint": in_records.get(names[node], {"net": names[node], "kind": "constant_or_zero_floor"}),
            "gate_count": len(steps), "gates_source_to_sink": list(reversed(steps))}
  result = {"created_utc": datetime.now(timezone.utc).isoformat(),
    "method": "Independent Python class-aware NLDM propagation on unchanged logically flattened mapped gates; class-independent worst-rise/fall slew, per-class arrival times",
    "absolute_driver": absolute_driver, "reference_only_pruned_to_endpoint_cones": retain_reachable_only,
    "mapped_combinational_cells": sum(gate_counts.values()),
    "timed_combinational_cells": sum(1 for i in range(n) if active[i] and types[i]>=0),
    "constant_pseudocells": source_class.count(-2), "cutpoint_inputs": len(cut["inputs"]), "cutpoint_outputs": len(cut["outputs"]),
    "node_count": n, "elapsed_seconds": time.monotonic()-began,
    "graph_sha256": hashlib.sha256(blif.read_bytes()).hexdigest(),
    "liberty_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
    "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "out_of_table_queries": dict(extrapolations),
    "abc_conditional_sense_policy": [{"cell": m["name"], "pin": arc["pin"], "senses": arc["conditional_senses"],
                                      "selected_first": arc["abc_selected_sense"]} for m in models_list for arc in m["arcs"]
                                     if len(arc["conditional_senses"]) > 1],
    "limitations": ["Diagnostic structural timing model, not functional sensitization proof or signoff Fmax", "No wire delay, FF clock-to-Q/setup, clock uncertainty or IO constraints", "Independent per-x-sink virtual inputs; whole mapped gate graph and every endpoint pin load retained", "Python binary64 arithmetic versus ABC binary32; must compare numerical tolerances", "Arrival path classes share the unconditional worst-case slew at every net; conservative path correlation assumptions"]}
  maximum = max((arrival[p][oid],k,oid,p) for k,oid in enumerate(output_ids) for p in range(2))
  a,k,oid,p = maximum
  result["all_sources"] = {"delay_ps": a*1000, "endpoint": cut["outputs"][k], **path(oid,p)}
  if not all_only:
    result["path_classes"] = {}
    for c in range(3):
      for endkind,ename in (("sequential_input_pins","FF"),("primary_outputs","PO")):
        choices = [(classarr[2*c+p][oid], k,oid,p) for k,oid in enumerate(output_ids)
                    if cut["outputs"][k]["kind"] == endkind for p in range(2)]
        if not choices:
          continue
        a,k,oid,p = max(choices)
        result["path_classes"][CLASS_NAMES[c]+"_to_"+ename] = {
          "delay_ps": a*1000 if math.isfinite(a) else None,
          "comb_reciprocal_mhz": 1000/a if math.isfinite(a) and a>0 else None,
          "endpoint": cut["outputs"][k], **(path(oid,p,c) if math.isfinite(a) else {})}
  return result

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--blif", type=Path, required=True)
  parser.add_argument("--cutpoints", type=Path, required=True)
  parser.add_argument("--output", type=Path, required=True)
  parser.add_argument("--liberty", type=Path, default=ROOT/"sys_lib/lib/NangateOpenCellLibrary_typical.lib")
  parser.add_argument("--absolute-driver", action="store_true")
  parser.add_argument("--all-only", action="store_true")
  parser.add_argument("--abc-pruned-reference", action="store_true")
  args = parser.parse_args()
  result = analyze(args.blif,args.cutpoints,args.liberty,
                   args.absolute_driver,args.all_only,args.abc_pruned_reference)
  result.update({"engine_math_sha256": ENGINE_MATH_SHA256, "prototype_script_sha256": PROTOTYPE_SCRIPT_SHA256})
  args.output.parent.mkdir(parents=True, exist_ok=True)
  args.output.write_text(json.dumps(result,indent=2)+"\n")
  print(json.dumps({"result":str(args.output),"all_sources_delay_ps":result["all_sources"]["delay_ps"],
    "path_classes":{k:v["delay_ps"] for k,v in result.get("path_classes",{}).items()},
    "timed_combinational_cells": result["timed_combinational_cells"],
    "elapsed_seconds":result["elapsed_seconds"]},indent=2),flush=True)

if __name__ == "__main__":
  main()
