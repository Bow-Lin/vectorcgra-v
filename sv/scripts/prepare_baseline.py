#!/usr/bin/env python3
"""Restore verified baseline sources before overlaying portable test runners."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

SV = Path(__file__).resolve().parents[1]
BASELINE = 'cd7aad878915e389cecf8cc01ff6987d156bd019'


def source_archive(sv=SV):
  directory = sv/'reference/baseline'
  if (directory/'source.tar.gz').is_file():
    info = json.loads((directory/'manifest.json').read_text())
    data = (directory/'source.tar.gz').read_bytes()
    if info['commit'] != BASELINE or hashlib.sha256(data).hexdigest() != info['sha256']:
      raise ValueError('Packaged baseline identity mismatch')
    return data
  return subprocess.check_output(['git', '-C', str(sv.parent), 'archive', BASELINE, 'sv'])


def restore(destination, data):
  sources = {}
  with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
    for member in archive.getmembers():
      path = PurePosixPath(member.name)
      if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != 'sv':
        raise ValueError('Unsafe baseline archive path: ' + member.name)
      if member.isdir():
        continue
      if not member.isfile():
        raise ValueError('Baseline archive must contain regular files only')
      content = archive.extractfile(member).read()
      target = destination/path
      # Do not follow a stale snapshot symlink when restoring original sources.
      if any(parent.is_symlink() for parent in [target, *target.parents]):
        raise ValueError('Baseline destination contains a symlink')
      target.parent.mkdir(parents=True, exist_ok=True)
      target.write_bytes(content)
      target.chmod(member.mode & 0o777)
      digest = hashlib.sha256(content).hexdigest()
      if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        raise ValueError('Baseline extraction mismatch: ' + member.name)
      sources[member.name] = digest
  record = dict(schema=1, commit=BASELINE, archive_sha256=hashlib.sha256(data).hexdigest(),
                source_sha256=sources, status='verified_before_runner_overlay')
  (destination/'baseline-sources.json').write_text(json.dumps(record, indent=2)+'\n')
  print(f'BASELINE_SOURCES_VERIFIED commit={BASELINE} files={len(sources)}')
  return record


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--destination', type=Path, required=True)
  args = parser.parse_args()
  args.destination.mkdir(parents=True, exist_ok=True)
  restore(args.destination.resolve(), source_archive())


if __name__ == '__main__':
  main()
