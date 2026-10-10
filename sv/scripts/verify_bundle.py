#!/usr/bin/env python3
"""Verify an unpacked standalone bundle without Git or project Python."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath


def verify(root):
  manifest = json.loads((root/'BUNDLE_MANIFEST.json').read_text())
  for forbidden in ['.git', 'lib', 'cgra', 'tile', 'multi_cgra', 'fu', 'mem', 'noc']:
    if (root/forbidden).exists():
      raise ValueError('Original checkout directory is present: ' + forbidden)
  for name, expected in manifest['files'].items():
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts:
      raise ValueError('Invalid manifest path: ' + name)
    target = root/path
    if target.is_symlink() or not target.is_file():
      raise ValueError('Bundle file missing or symlinked: ' + name)
    data = target.read_bytes()
    if len(data) != expected['bytes'] or hashlib.sha256(data).hexdigest() != expected['sha256']:
      raise ValueError('Bundle file SHA256 mismatch: ' + name)
  for line in (root/'sv/filelists/native.f').read_text().splitlines():
    if line and not line.startswith('+') and not (root/'sv'/line).is_file():
      raise ValueError('Native filelist input missing: ' + line)
  print(f'STANDALONE_BUNDLE_VERIFIED files={len(manifest["files"])} commit={manifest["source_commit"]} dirty={manifest["dirty_source"]}')
  return manifest


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
  args = parser.parse_args()
  verify(args.root.resolve())


if __name__ == '__main__':
  main()
