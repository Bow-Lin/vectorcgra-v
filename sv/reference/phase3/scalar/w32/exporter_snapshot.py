"""Migration-only: freeze untouched ac96 scalar FU HDL and provenance.

The checked-in native build does not run this exporter. Each profile is exported
independently, and namespace copies only rename HDL identifiers for joint tests.
"""
import argparse
import hashlib
import importlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT.parent))
BASELINE = "ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b"
MODULES = ["Const", "Comp", "Logic", "Shifter", "Sel", "Phi", "Grant", "Gep",
           "ExtractPredicate", "Ret", "LoopCounter", "LoopControl", "Div",
           "InclusiveDiv", "ExclusiveDiv"]


def write(path, text):
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(text, encoding="utf-8", newline="\n")


def sha(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
  from pymtl3 import mk_bits, clog2
  from pymtl3.passes.backends.verilog import VerilogTranslationPass, VerilogPlaceholderPass
  from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt
  import VectorCGRA.lib.opt_type as opts
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--profile", choices=["w32", "w64"], default="w32")
  parser.add_argument("--modules", nargs="+", choices=MODULES, default=MODULES)
  args = parser.parse_args()
  git = lambda *a: subprocess.check_output(["git", *a], cwd=ROOT, text=True).strip()
  changes = [p for p in git("diff", "--name-only", BASELINE, "--", "fu", "lib").splitlines() if p.endswith(('.py', '.v'))]
  assert not changes, changes
  dw, cd, rd = (32, 8, 16) if args.profile == "w32" else (64, 16, 8)
  Data = mk_data(dw, 1)
  Ctrl = mk_ctrl(4, 2, 4, 4, rd)
  Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(clog2(cd)))
  Packet = mk_intra_cgra_pkt(1, 1, 4, Payload)
  out = ROOT / "sv/reference/phase3/scalar" / args.profile
  if out.exists():
    parser.error("Frozen profile exists; use a new profile directory, never overwrite reference evidence")
  out.mkdir(parents=True)
  write(out / "exporter_snapshot.py", Path(__file__).read_text(encoding="utf-8"))
  records, failures = [], []
  for name in args.modules:
    if dw != 32 and name in ("InclusiveDiv", "ExclusiveDiv"):
      failures.append(dict(module=name, status="unsupported_baseline_width", reason="ac96 instantiates Div(WIDTH=32), independent of payload width"))
      continue
    source = ROOT / f"fu/single/{name}RTL.py"
    cls = getattr(importlib.import_module(f"VectorCGRA.fu.single.{name}RTL"), name + "RTL")
    top = f"ScalarRef{name}{args.profile}"
    module_dir = out / name
    module_dir.mkdir()
    os.chdir(module_dir)
    try:
      dut = cls(Packet, 4, 2)
      dut.elaborate()
      dut.apply(VerilogPlaceholderPass())
      dut.set_metadata(VerilogTranslationPass.enable, True)
      dut.set_metadata(VerilogTranslationPass.explicit_module_name, top)
      dut.apply(VerilogTranslationPass())
      generated = Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
      raw = generated.read_text(encoding="utf-8")
      # New evidence is consistently LF; translation text is otherwise intact.
      rtl = module_dir / f"{top}.v"
      write(rtl, raw)
      if generated != rtl:
        generated.unlink()
      names = re.findall(r"^module\s+(\w+)", raw, re.M) + re.findall(r"^}\s+(\w+);", raw, re.M)
      mapping = {n: f"Gold{name}_" + n for n in names if n != top}
      packed = re.sub(r"\b(?:" + "|".join(map(re.escape, mapping)) + r")\b", lambda m: mapping[m[0]], raw) if mapping else raw
      write(module_dir / "namespaced.sv", packed)
      operations = sorted(set(re.findall(r"\bOPT_[A-Z0-9_]+\b", source.read_text(encoding="utf-8"))) - {"OPT_SYMBOL_DICT"})
      records.append(dict(module=name, top=top, rtl=f"{name}/{rtl.name}", rtl_sha256=sha(rtl),
        namespaced=f"{name}/namespaced.sv", namespaced_sha256=sha(module_dir / "namespaced.sv"),
        namespace_map=mapping, source=source.relative_to(ROOT).as_posix(), source_sha256=sha(source),
        operations={op: int(getattr(opts, op)) for op in operations},
        types={"data": Data.__name__, "ctrl": Ctrl.__name__, "payload": Payload.__name__}))
      print(f"SCALAR_REFERENCE_PASS {args.profile} {name}", flush=True)
    except Exception as e:
      import traceback
      failure = traceback.format_exc()
      write(module_dir / "export_failure.log", failure)
      failures.append(dict(module=name, status="export_failed", exception=str(e)))
      print(f"SCALAR_REFERENCE_FAIL {args.profile} {name}: {e}", flush=True)
  sources = {}
  for mod in list(sys.modules.values()):
    p = getattr(mod, "__file__", None)
    if not p or not str(p).endswith('.py'):
      continue
    try:
      path = Path(p).resolve(); relative = path.relative_to(ROOT)
    except ValueError:
      continue
    sources[relative.as_posix()] = sha(path)
  manifest = dict(baseline_commit=BASELINE, checkout_commit=git('rev-parse','HEAD'), profile=args.profile,
    parameters=dict(COLS=2, ROWS=2, DATA_W=dw, CTRL_DEPTH=cd, REG_DEPTH=rd,
      GLOBAL_ADDR_W=7, NUM_INPUTS=4, NUM_OUTPUTS=2, VECTOR_FACTOR_POWER=0),
    exporter_sha256=sha(out / 'exporter_snapshot.py'), source_sha256=sources,
    pymtl3_version=importlib.metadata.version('pymtl3'),
    pymtl3_direct_url=importlib.metadata.distribution('pymtl3').read_text('direct_url.json'),
    python=sys.version, modules=records, failures=failures,
    notes=["Namespace copies rename only module/typedef identifiers; original LF translation retained.",
      "No Python simulation claimed for VerilogPlaceholder pipeline dividers."])
  write(out/'manifest.json', json.dumps(manifest, indent=2)+'\n')
  if any(f['status']=='export_failed' for f in failures):
    raise SystemExit(1)


if __name__ == '__main__':
  main()
