"""Attribute mapped CGRA standard-cell area without double-counting hierarchy.

Preferred input is Yosys ``write_json`` after hierarchy-preserving mapping::

  python sys_lib/area_report.py mapped.json --liberty cells.lib \
    --top VectorCGRA4x4 --output build/baseline/area

The output prefix produces .json, .csv, and .md files. This is a diagnostic
denominator: a separately flattened and mapped netlist can have a different
total area because synthesis can optimize across hierarchy boundaries.

``stat -json`` input also works with --liberty. Since stat discards instance
names, pass --hierarchy mapped.json to retain exact routing/FU crossbar
attribution. Without it, unknown crossbars stay in tile_other and a warning is
emitted; they are never guessed from potentially identical module parameters.
Only Python's standard library is required.
"""

import argparse
import csv
from collections import Counter, defaultdict
from decimal import Decimal
import json
from pathlib import Path
import re


CATEGORIES = {
  "tile_fu_compute": "Tile FU compute",
  "routing_crossbar": "Tile routing crossbar",
  "fu_crossbar": "Tile FU crossbar",
  "tile_channels_linkor": "Tile input channels / output LinkOr",
  "register_cluster": "Tile register cluster",
  "ctrl_mem": "Tile control memory",
  "const_mem": "Tile constant memory",
  "tile_other": "Tile other logic",
  "ctrl_ring": "CGRA control ring",
  "data_mem": "CGRA data memory",
  "controller": "CGRA controller",
  "top_other": "CGRA top / other logic",
}
TILE_CATEGORIES = tuple(CATEGORIES)[:8]
ZERO = Decimal(0)
NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
# Strings and comments are tokens so their braces cannot alter nesting.
LIB_TOKEN = re.compile(
  r'"(?:\\.|[^"\\])*"|/\*.*?\*/|//[^\n]*|[{}]|'
  r"\barea\s*:\s*(" + NUMBER + r")\s*;", re.DOTALL)
CELL_START = re.compile(
  r'\bcell\s*\(\s*(?:"((?:\\.|[^"\\])*)"|([^()]+?))\s*\)\s*\{')


def unescape(name):
  """Yosys JSON versions differ on whether identifiers have leading '\\'."""
  return str(name).lstrip("\\").rstrip()


def load_yosys_json(path):
  """Accept a clean JSON file or JSON embedded in a tee'd Yosys stat log."""
  text = Path(path).read_text(encoding="utf-8-sig")
  decoder = json.JSONDecoder(parse_float=Decimal)
  try:
    result = decoder.decode(text)
  except json.JSONDecodeError:
    result = None
    for match in re.finditer(r"\{", text):
      try:
        candidate, _ = decoder.raw_decode(text, match.start())
      except json.JSONDecodeError:
        continue
      if isinstance(candidate, dict) and isinstance(candidate.get("modules"), dict):
        result = candidate
    if result is None:
      raise ValueError(f"No Yosys JSON object with modules found in {path}")
  if not isinstance(result, dict) or not isinstance(result.get("modules"), dict):
    raise ValueError(f"Expected a Yosys JSON object with modules in {path}")
  result["modules"] = {unescape(key): value for key, value in result["modules"].items()}
  return result


def liberty_areas(path):
  """Read cell-level area attributes, ignoring nested attributes and comments."""
  source = Path(path).read_text(encoding="utf-8-sig")
  # Preserve quoted strings while removing comments before finding cell blocks.
  clean = re.sub(r'"(?:\\.|[^"\\])*"|/\*.*?\*/|//[^\n]*',
                 lambda match: match.group() if match.group().startswith('"') else " ",
                 source, flags=re.DOTALL)
  areas = {}
  for match in CELL_START.finditer(clean):
    name = unescape(match.group(1) or match.group(2))
    depth = 1
    area = None
    for token in LIB_TOKEN.finditer(clean, match.end()):
      if token.group() == "{":
        depth += 1
      elif token.group() == "}":
        depth -= 1
        if depth == 0:
          break
      elif token.group(1) is not None and depth == 1:
        area = Decimal(token.group(1))
    if depth != 0:
      raise ValueError(f"Unclosed Liberty cell block: {name}")
    if area is None:
      raise ValueError(f"Liberty cell {name} has no area attribute")
    if area < 0:
      raise ValueError(f"Liberty cell {name} has negative area")
    if name in areas and areas[name] != area:
      raise ValueError(f"Conflicting Liberty areas for cell {name}")
    areas[name] = area
  if not areas:
    raise ValueError(f"No Liberty cells with area found in {path}")
  return areas


def is_true(value):
  return value in (1, True, "1") or (isinstance(value, str) and
                                    bool(re.fullmatch(r"0*1", value)))


def classify(name, module_type, inherited):
  """Return category at a named hierarchy boundary, otherwise inherit it."""
  # Once within a component, its internal names do not change ownership.
  if inherited not in ("top_other", "tile_other"):
    return inherited
  name = unescape(name).lower()
  kind = unescape(module_type).lower()
  if inherited == "top_other":
    if re.match(r"^tile(?:_|\[|$)", name) or "tilertl" in kind or \
        "tilewithcontextswitchrtl" in kind or "tilewithstreamingloadrtl" in kind:
      return "tile_other"
    if name == "ctrl_ring" or "ringnetworkrtl" in kind:
      return "ctrl_ring"
    if name == "data_mem" or "datamemcontrollerrtl" in kind:
      return "data_mem"
    if name == "controller" or "controllerrtl" in kind:
      return "controller"
    return inherited
  if name == "routing_crossbar":
    return "routing_crossbar"
  if name == "fu_crossbar":
    return "fu_crossbar"
  if name == "element" or "flexiblefurtl" in kind:
    return "tile_fu_compute"
  if name.startswith(("tile_in_channel", "tile_out_or_link")) or \
      "channelrtl" in kind or "linkorrtl" in kind:
    return "tile_channels_linkor"
  if name == "register_cluster" or "registerclusterrtl" in kind:
    return "register_cluster"
  if name == "ctrl_mem" or "ctrlmem" in kind:
    return "ctrl_mem"
  if name == "const_mem" or "constqueue" in kind:
    return "const_mem"
  return inherited


def decimal_text(value):
  return format(value, "f")


def area_fields(area, total):
  return {
    "area": float(area),
    "area_exact": decimal_text(area),
    "percent": float(area * 100 / total) if total else 0.0,
  }


def build_report(data, areas, top, flow_label, hierarchy=None):
  """Walk each instance once; charge only mapped leaf cells to their owners."""
  top = unescape(top)
  stat_mode = not any("cells" in module for module in data["modules"].values())
  modules = (hierarchy or data)["modules"]
  named_instances = not stat_mode or hierarchy is not None
  if top not in modules:
    raise ValueError(f"Top module {top!r} not found")
  if hierarchy is not None and not any("cells" in item for item in modules.values()):
    raise ValueError("--hierarchy must be Yosys write_json, not stat JSON")
  category_cells = {key: Counter() for key in CATEGORIES}
  owners = {}
  module_instances = []
  warnings = set()

  def children(module):
    if named_instances:
      for name, cell in module.get("cells", {}).items():
        yield unescape(name), unescape(cell["type"]), 1
    else:
      counts = module.get("num_cells_by_type", module.get("cell_types", {}))
      if not isinstance(counts, dict):
        raise ValueError("stat module needs a num_cells_by_type or cell_types mapping")
      for kind, count in counts.items():
        count = int(count.get("count", count.get("num_cells", 0))) if isinstance(count, dict) else int(count)
        if count < 0:
          raise ValueError(f"Negative cell count for {kind}")
        if count:
          yield unescape(kind), unescape(kind), count

  def walk(module_type, path, inherited, owner_path, multiplicity, ancestors):
    if module_type in ancestors:
      raise ValueError(f"Recursive module hierarchy at {path}: {module_type}")
    module = modules[module_type]
    attributes = module.get("attributes", {})
    if is_true(attributes.get("blackbox", 0)) or is_true(attributes.get("whitebox", 0)):
      raise ValueError(f"Unmapped blackbox/whitebox {module_type!r} at {path}")
    if owner_path not in owners:
      owners[owner_path] = {
        "path": owner_path, "module_type": module_type, "category": inherited,
        "instance_count": multiplicity, "area": ZERO, "cell_count": 0,
      }
    local_area = ZERO
    local_cells = 0
    total_area = ZERO
    total_cells = 0
    for name, kind, count in children(module):
      effective_count = multiplicity * count
      if kind in areas:
        area = areas[kind] * effective_count
        local_area += area
        local_cells += effective_count
        category_cells[inherited][kind] += effective_count
        owners[owner_path]["area"] += area
        owners[owner_path]["cell_count"] += effective_count
      elif kind in modules:
        category = classify(name, kind, inherited)
        child_path = path + "/" + name
        child_owner = child_path if category != inherited else owner_path
        if not named_instances and inherited == "tile_other" and "crossbarrtl" in kind.lower():
          warnings.add("stat JSON omits instance names: ambiguous tile CrossbarRTL "
                       "area remains in tile_other; supply --hierarchy mapped.json.")
        child_area, child_cells = walk(kind, child_path, category, child_owner,
                                       effective_count, ancestors + (module_type,))
        total_area += child_area
        total_cells += child_cells
      else:
        raise ValueError(f"Unknown/unmapped cell type {kind!r} at {path}/{name}; "
                         "refusing to silently assign zero area")
    total_area += local_area
    total_cells += local_cells
    module_instances.append({
      "path": path, "module_type": module_type, "category": inherited,
      "instance_count": multiplicity, "local_area_exact": decimal_text(local_area),
      "local_cell_count": local_cells,
      "subtree_area_exact": decimal_text(total_area), "subtree_cell_count": total_cells,
    })
    return total_area, total_cells

  total, total_cells = walk(top, top, "top_other", top, 1, ())
  categories = []
  for key, label in CATEGORIES.items():
    cells = category_cells[key]
    area = sum((areas[kind] * count for kind, count in cells.items()), ZERO)
    categories.append({
      "category": key, "label": label, **area_fields(area, total),
      "cell_count": sum(cells.values()), "cell_types": dict(sorted(cells.items())),
    })
  category_total = sum((Decimal(row["area_exact"]) for row in categories), ZERO)
  if total != category_total or total_cells != sum(row["cell_count"] for row in categories):
    raise AssertionError("Area/category accounting is not additive")
  group_definitions = {"tiles": TILE_CATEGORIES}
  group_definitions.update({key: (key,) for key in ("ctrl_ring", "data_mem", "controller", "top_other")})
  category_by_name = {row["category"]: row for row in categories}
  groups = []
  for name, members in group_definitions.items():
    area = sum((Decimal(category_by_name[key]["area_exact"]) for key in members), ZERO)
    groups.append({"group": name, "categories": list(members), **area_fields(area, total),
                   "cell_count": sum(category_by_name[key]["cell_count"] for key in members)})
  instance_rows = []
  representatives = defaultdict(list)
  for owner in sorted(owners.values(), key=lambda row: row["path"]):
    area = owner["area"]
    item = {**owner, **area_fields(area, total)}
    instance_rows.append(item)
    if area or owner["cell_count"]:
      representatives[(owner["category"], owner["module_type"])].append(owner)
  if sum((Decimal(row["area_exact"]) for row in instance_rows), ZERO) != total:
    raise AssertionError("Instance ownership accounting is not additive")
  representative_rows = []
  for (category, kind), entries in sorted(representatives.items()):
    area = sum((row["area"] for row in entries), ZERO)
    per_instance = [row["area"] / row["instance_count"] for row in entries]
    representative_rows.append({
      "category": category, "module_type": kind,
      "instance_count": sum(row["instance_count"] for row in entries),
      "example_path": entries[0]["path"], **area_fields(area, total),
      "min_instance_area": float(min(per_instance)),
      "max_instance_area": float(max(per_instance)),
    })
  stat_design = data.get("design", {}) if stat_mode else {}
  reported_area = stat_design.get("area", stat_design.get("chip_area"))
  stat_check = None
  if reported_area is not None:
    reported_area = Decimal(str(reported_area))
    difference = total - reported_area
    stat_check = {
      "reported_area_exact": decimal_text(reported_area),
      "leaf_sum_minus_reported_exact": decimal_text(difference),
    }
    # stat commonly rounds decimal area. Its display precision is not an error.
    if abs(difference) > max(Decimal("0.001"), abs(total) * Decimal("0.000001")):
      warnings.add("The Liberty leaf sum differs from stat's reported design area; "
                   "check that stat, hierarchy JSON and Liberty come from the same run.")
  if not named_instances:
    warnings.add("Instance paths are synthetic module-type paths because stat JSON "
                 "does not retain instance names; instance_count carries multiplicity.")
  if total == ZERO:
    warnings.add("Top has zero mapped standard-cell area.")
  if not any(row["cell_count"] for row in categories[:8]):
    warnings.add("No tile hierarchy was identified. Use hierarchy-preserving mapping "
                 "for a component breakdown; a flattened netlist has only top_other.")
  return {
    "schema_version": 1, "top": top, "flow_label": flow_label,
    "input_format": "stat" if stat_mode else "write_json",
    "named_instances": named_instances,
    "area_unit": "Liberty area units",
    "denominator_note": "All percentages use this netlist's complete top-level leaf-cell "
                        "area. A separately flattened mapping is a separate measurement.",
    "accounting_note": "Categories are disjoint and sum to total. Parent groups also sum "
                       "to total; do not add parent groups to categories. Instance owner "
                       "areas are disjoint; module_instances subtree areas overlap.",
    "total": {**area_fields(total, total), "cell_count": total_cells},
    "exact_category_sum": decimal_text(category_total),
    "categories": categories, "parent_groups": groups,
    "instance_owners": instance_rows, "representatives": representative_rows,
    "module_instances": module_instances,
    "stat_area_check": stat_check, "warnings": sorted(warnings),
  }


def markdown(report):
  total = report["total"]
  lines = [f"# {report['top']} mapped area breakdown", "",
           f"Flow: {report['flow_label']}", "",
           f"Total area: **{total['area_exact']}** Liberty area units; "
           f"mapped cells: **{total['cell_count']:,}**.", "",
           report["denominator_note"], "", report["accounting_note"], "",
           "## Disjoint component categories", "",
           "| Component | Area | Share | Mapped cells |",
           "|---|---:|---:|---:|"]
  for row in report["categories"]:
    lines.append(f"| {row['label']} | {row['area_exact']} | "
                 f"{row['percent']:.3f}% | {row['cell_count']:,} |")
  lines.extend([f"| **Total** | **{total['area_exact']}** | **100%** | "
                f"**{total['cell_count']:,}** |", "",
                "## Parent groups (alternative aggregation)", "",
                "| Group | Area | Share | Mapped cells |", "|---|---:|---:|---:|"])
  for row in report["parent_groups"]:
    lines.append(f"| {row['group']} | {row['area_exact']} | "
                 f"{row['percent']:.3f}% | {row['cell_count']:,} |")
  lines.extend(["", "## Representative component instances", "",
                "Equal module types are grouped. Area ranges describe owned logic per "
                "instance; tile_other and top_other exclude separately attributed children.", "",
                "| Component | Instances | Total area | Per-instance area range | Example |",
                "|---|---:|---:|---:|---|"])
  for row in report["representatives"]:
    lines.append(f"| {row['category']} | {row['instance_count']} | {row['area_exact']} | "
                 f"{row['min_instance_area']:.6f}–{row['max_instance_area']:.6f} | "
                 f"`{row['example_path']}` |")
  if report["warnings"]:
    lines.extend(["", "## Attribution limitations", ""])
    lines.extend("- " + warning for warning in report["warnings"])
  lines.append("")
  return "\n".join(lines)


def main():
  parser = argparse.ArgumentParser(description=__doc__,
                                   formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("input", type=Path, help="Yosys write_json or stat -json file")
  parser.add_argument("--liberty", type=Path, required=True)
  parser.add_argument("--top", default="VectorCGRA4x4")
  parser.add_argument("--hierarchy", type=Path,
                      help="Mapped write_json companion when input is stat -json")
  parser.add_argument("--output", type=Path, required=True, help="Output file prefix")
  parser.add_argument("--flow-label", default="Hierarchy-preserving diagnostic mapping")
  args = parser.parse_args()
  try:
    report = build_report(load_yosys_json(args.input), liberty_areas(args.liberty),
                          args.top, args.flow_label,
                          load_yosys_json(args.hierarchy) if args.hierarchy else None)
  except (ValueError, KeyError) as error:
    parser.error(str(error))
  report["sources"] = {"input": str(args.input.resolve()),
                       "liberty": str(args.liberty.resolve()),
                       "hierarchy": str(args.hierarchy.resolve()) if args.hierarchy else None}
  args.output.parent.mkdir(parents=True, exist_ok=True)
  Path(str(args.output) + ".json").write_text(
    json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
  Path(str(args.output) + ".md").write_text(markdown(report), encoding="utf-8")
  with Path(str(args.output) + ".csv").open("w", encoding="utf-8", newline="") as output:
    fields = ["category", "label", "area_exact", "percent", "cell_count"]
    writer = csv.DictWriter(output, fields, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(report["categories"])
  print(f"{report['top']}: {report['total']['area_exact']} Liberty area units, "
        f"{report['total']['cell_count']:,} mapped cells")
  for warning in report["warnings"]:
    print("WARNING: " + warning)
  print(f"Wrote {args.output}.json, {args.output}.csv, {args.output}.md")


if __name__ == "__main__":
  main()
