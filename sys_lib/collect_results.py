"""Archive compact, reviewable synthesis results without copying large netlists."""

import argparse
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent


def read_optional(path):
  return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--input", type=Path, required=True)
  parser.add_argument("--name", required=True)
  parser.add_argument("--source-commit", help="Commit containing the exact measured RTL")
  args = parser.parse_args()
  if not args.name.replace("-", "").replace("_", "").isalnum():
    parser.error("name must contain only letters, digits, hyphens or underscores")
  source = args.input.resolve()
  mapped = source / "hierarchical"
  area = read_optional(mapped / "area.json")
  if area is None:
    parser.error("Run area_report.py first to create hierarchical/area.json")
  manifest = read_optional(source / "manifest.json")
  result = {
    "experiment": args.name, "source_commit": args.source_commit,
    "manifest": manifest, "synthesis": read_optional(mapped / "summary.json"),
    "area": {"total": area["total"], "denominator_note": area["denominator_note"],
             "categories": [{key: row[key] for key in
               ("category", "label", "area", "percent", "cell_count")}
               for row in area["categories"]]},
    "timing": read_optional(mapped / "timing/timing.json"),
    "artifact_hashes": {},
  }
  diagnostic = mapped / "timing_diagnostics/check.log"
  if diagnostic.exists():
    counts = re.findall(r"Found and reported (\d+) problems", diagnostic.read_text(errors="replace"))
    result["library_aware_post_mapping_check"] = {
      "problems": int(counts[-1]) if counts else None,
      "log_sha256": hashlib.sha256(diagnostic.read_bytes()).hexdigest(),
      "note": "Separate check after read_json and read_liberty; does not remap the design.",
    }
  for relative in ("manifest.json", "design.v", "hierarchical/mapped.json",
                   "hierarchical/stat.json", "hierarchical/run.ys",
                   "hierarchical/summary.json", "hierarchical/area.json"):
    path = source / relative
    if path.exists():
      with path.open("rb") as stream:
        result["artifact_hashes"][relative] = hashlib.file_digest(stream, "sha256").hexdigest()
  output = HERE / "results"
  output.mkdir(exist_ok=True)
  target = output / (args.name + ".json")
  target.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
  for extension in ("csv", "md"):
    src = mapped / ("area." + extension)
    if src.exists():
      (output / f"{args.name}-area.{extension}").write_bytes(src.read_bytes())
  print(target)


if __name__ == "__main__":
  main()
