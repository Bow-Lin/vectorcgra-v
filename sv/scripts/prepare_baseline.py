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


def stage_relocated_sources(destination, record, layout):
  """Give updated runners new paths to the original, verified baseline bytes.

  Original archive paths remain untouched for its Makefile and filelists. Never
  copy current RTL into this snapshot: its semantics may differ from the baseline.
  """
  staged = {}
  for entry in layout['files']:
    paths = [PurePosixPath(entry[key]) for key in ['old', 'new']]
    if any(p.is_absolute() or '..' in p.parts or not p.parts for p in paths):
      raise ValueError('Unsafe relocation path')
    old, new = ['sv/' + p.as_posix() for p in paths]
    source, target = destination/old, destination/new
    if old not in record['source_sha256']:
      raise ValueError('Relocation source absent from baseline: ' + old)
    for path in [source, target]:
      if any(parent.is_symlink() for parent in [path, *path.parents]):
        raise ValueError('Baseline relocation contains a symlink')
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != record['source_sha256'][old]:
      raise ValueError('Baseline relocation source changed: ' + old)
    if new in record['source_sha256'] and new != old:
      raise ValueError('Relocation would overwrite a baseline source: ' + new)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    target.chmod(source.stat().st_mode & 0o777)
    staged[new] = dict(source=old, sha256=digest)
  (destination/'baseline-relocations.json').write_text(json.dumps(staged, indent=2)+'\n')
  print(f'BASELINE_RELOCATIONS_VERIFIED files={len(staged)}')
  return staged


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--destination', type=Path, required=True)
  parser.add_argument('--layout', type=Path, help='Give updated runners relocated baseline source paths')
  args = parser.parse_args()
  args.destination.mkdir(parents=True, exist_ok=True)
  destination = args.destination.resolve()
  record = restore(destination, source_archive())
  if args.layout:
    stage_relocated_sources(destination, record, json.loads(args.layout.read_text()))


if __name__ == '__main__':
  main()
