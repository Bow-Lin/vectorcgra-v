"""Shared file/ABI utilities; no DUT implementation or reference results."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SV = ROOT / 'sv'


def load_tool(name):
  spec = importlib.util.spec_from_file_location(name, SV / 'tools' / (name + '.py'))
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


program = load_tool('cgra_program')
configuration = program.configuration


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
  Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def rtl_hashes():
  return {str(p.relative_to(ROOT)): sha(p) for p in sorted((SV / 'rtl').rglob('*'))
          if p.is_file() and p.suffix in {'.sv', '.svh'}}


def python_hashes():
  pin = json.loads((SV / 'reference/current/target.json').read_text())
  for name, expected in pin['source_sha256'].items():
    assert sha(ROOT / name) == expected, 'Original Python changed: ' + name
  return pin
