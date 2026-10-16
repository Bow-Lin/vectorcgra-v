#!/usr/bin/env python3
"""Reject cached simulations when compile inputs, arguments or tools change."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

SV = Path(__file__).resolve().parents[1]


def stamp(sources, arguments):
  # rtl/ contains maintained hardware and its headers/vendor dependencies only.
  # Test-only historical RTL and frozen references are outside this tree; a
  # caller that actually compiles them must name them in sources explicitly.
  paths = {path for path in (SV/'rtl').rglob('*') if path.is_file()}
  paths.update(SV/path for path in sources)
  paths.update([SV/'filelists/native.f', SV/'scripts/toolchain.sh', Path(__file__)])
  result = dict(schema=1, arguments=arguments,
                source_sha256={str(p.relative_to(SV)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)},
                tools={})
  for name, variable, fallback in [('verilator', 'VERILATOR', 'verilator'), ('cxx', 'CXX', 'c++')]:
    command = os.environ.get(variable, fallback)
    process = subprocess.run([command, '--version'], text=True, capture_output=True, check=True)
    result['tools'][name] = dict(command=command, version=(process.stdout or process.stderr).splitlines()[0])
  return result


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('mode', choices=['write', 'check'])
  parser.add_argument('--path', type=Path, required=True)
  parser.add_argument('--source', action='append', default=[])
  parser.add_argument('--argument', action='append', default=[])
  args = parser.parse_args()
  current = stamp(args.source, args.argument)
  if args.mode == 'write':
    temporary = args.path.with_suffix('.tmp')
    temporary.write_text(json.dumps(current, indent=2)+'\n')
    temporary.replace(args.path)
  else:
    if not args.path.is_file() or json.loads(args.path.read_text()) != current:
      raise SystemExit('BUILD_STAMP_MISMATCH: compile inputs, parameters or tools changed; rebuild before run')
  print('BUILD_STAMP_' + args.mode.upper() + '_PASS')


if __name__ == '__main__':
  main()
