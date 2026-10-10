#!/usr/bin/env python3
"""Report effective Linux memory limits before expensive native synthesis."""
import argparse
import json
from pathlib import Path
import shutil


def resources():
  memory = int(next(row.split()[1] for row in Path('/proc/meminfo').read_text().splitlines()
                    if row.startswith('MemTotal:'))) * 1024
  limits = [memory]
  for name in ['/sys/fs/cgroup/memory.max', '/sys/fs/cgroup/memory/memory.limit_in_bytes']:
    path = Path(name)
    if path.is_file():
      value = path.read_text().strip()
      if value.isdecimal():
        limits.append(int(value))
  return dict(host_memory_bytes=memory, effective_memory_bytes=min(limits),
              disk_free_bytes=shutil.disk_usage('.').free)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--minimum-memory-gib', type=float, default=0)
  parser.add_argument('--output', type=Path)
  args = parser.parse_args()
  result = resources()
  result['minimum_memory_gib'] = args.minimum_memory_gib
  result['status'] = ('passed' if result['effective_memory_bytes'] >= args.minimum_memory_gib * 2**30 else 'insufficient_memory')
  content = json.dumps(result, indent=2) + '\n'
  if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(content)
  print(content, end='')
  return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
  raise SystemExit(main())
