"""Migration-only: namespace a frozen reference without changing RTL behavior.

The checked-in .sv result is compiled directly by normal builds. This script
is not a build dependency. Every transformation is reversible and recorded.
"""

import hashlib
import json
from pathlib import Path
import re


SV = Path(__file__).resolve().parents[1]
SOURCE = SV / "reference/VectorCGRA2x2Reference.v"
TARGET = SV / "rtl/fixed/cgra_2x2_core.sv"
HEADER = (
  "// Fixed 2x2 core frozen from ac96a7; see reference/core_provenance.json.\n"
  "// Only module/type identifiers were renamed. No RTL behavior was edited.\n"
  "// Maintained HDL input: normal builds do not run a Python generator.\n"
  "// General parameterization is a later migration stage.\n\n"
)


def sha(data):
  return hashlib.sha256(data).hexdigest()


def main():
  raw = SOURCE.read_bytes()
  source = raw.decode("utf-8")
  modules = re.findall(r"^module\s+(\w+)", source, re.M)
  types = re.findall(r"^}\s+(\w+);", source, re.M)
  assert len(modules) == len(set(modules))
  assert "VectorCGRA2x2Reference" in modules
  rename = {name: "Fixed2x2_" + name for name in modules + types}
  rename["VectorCGRA2x2Reference"] = "cgra_2x2_fixed"
  pattern = re.compile(r"\b(?:" + "|".join(map(re.escape, rename)) + r")\b")
  renamed = pattern.sub(lambda match: rename[match.group()], source)
  reverse = {new: old for old, new in rename.items()}
  reverse_pattern = re.compile(r"\b(?:" + "|".join(map(re.escape, reverse)) + r")\b")
  restored = reverse_pattern.sub(lambda match: reverse[match.group()], renamed)
  assert restored.encode("utf-8") == raw, "Identifier rewrite is not reversible"
  result = (HEADER + renamed).encode("utf-8")
  TARGET.parent.mkdir(parents=True, exist_ok=True)
  TARGET.write_bytes(result)
  manifest = {
    "source": SOURCE.relative_to(SV).as_posix(),
    "source_sha256": sha(raw),
    "target": TARGET.relative_to(SV).as_posix(),
    "target_sha256": sha(result),
    "top": "cgra_2x2_fixed",
    "module_count": len(modules),
    "type_count": len(types),
    "transformation": "Identifier namespaces only, plus provenance comment header",
    "inverse_rewrite_byte_identical": True,
    "identifiers": rename,
  }
  (SV / "reference/core_provenance.json").write_text(
    json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
  print(f"Frozen {len(modules)} modules / {len(types)} types: {sha(result)}")


if __name__ == "__main__":
  main()
