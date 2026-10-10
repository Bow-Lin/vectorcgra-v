#!/usr/bin/env python3
"""Package current native SV, frozen inputs and a pinned historical baseline."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASELINE = 'cd7aad878915e389cecf8cc01ff6987d156bd019'


def git(*args):
  return subprocess.check_output(['git', '-C', str(ROOT), *args])


def pack(files):
  result = io.BytesIO()
  with gzip.GzipFile(fileobj=result, mode='wb', filename='', mtime=0) as compressed:
    with tarfile.open(fileobj=compressed, mode='w', format=tarfile.PAX_FORMAT) as archive:
      for name, (data, mode) in sorted(files.items()):
        member = tarfile.TarInfo(name)
        member.size = len(data)
        member.mode = mode
        member.mtime = member.uid = member.gid = 0
        member.uname = member.gname = ''
        archive.addfile(member, io.BytesIO(data))
  return result.getvalue()


def baseline():
  data = git('archive', BASELINE, 'sv')
  files = {}
  with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
    for member in archive.getmembers():
      if member.isfile():
        files[member.name] = (archive.extractfile(member).read(), member.mode)
      elif not member.isdir():
        raise ValueError('Unexpected non-regular baseline source')
  normalized = pack(files)
  return normalized, dict(schema=1, commit=BASELINE, files=len(files),
                         sha256=hashlib.sha256(normalized).hexdigest())


def export(output, allow_dirty=False):
  commit = git('rev-parse', 'HEAD').decode().strip()
  dirty = bool(git('status', '--porcelain', '--untracked-files=all', '--', 'sv'))
  if dirty and not allow_dirty:
    raise ValueError('SV tree is dirty; commit first, or use --allow-dirty for a clearly labelled validation snapshot')
  names = set(git('ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', 'sv').decode().split('\0')) - {''}
  files = {}
  for name in sorted(names):
    path = ROOT/name
    if path.is_symlink() or not path.is_file():
      raise ValueError('Standalone input is missing or not a regular file: ' + name)
    files[name] = (path.read_bytes(), 0o755 if path.stat().st_mode & 0o111 else 0o644)
  data, info = baseline()
  files['sv/reference/baseline/source.tar.gz'] = (data, 0o644)
  files['sv/reference/baseline/manifest.json'] = ((json.dumps(info, indent=2)+'\n').encode(), 0o644)
  readme = '''# VectorCGRA native SystemVerilog bundle

Verify: `python3 sv/scripts/verify_bundle.py`.
Build instructions and exact coverage: `sv/STANDALONE.md`, `sv/REGRESSION.md`.
The ordinary native build uses no original project Python or PyMTL.
Source audit/export generators retained as provenance are separate workflows.
Original dependency notices remain applicable; see `sv/DEPENDENCIES.md`.
In particular, ALUgenMAC / DW02_multp and their native renditions are not
covered solely by the repository BSD license.
'''
  files['README.md'] = (readme.encode(), 0o644)
  manifest = dict(schema=1, source_commit=commit, dirty_source=dirty,
                  baseline_commit=BASELINE, python_target=BASELINE,
                  files={name:dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
                         for name,(data,mode) in sorted(files.items())})
  files['BUNDLE_MANIFEST.json'] = ((json.dumps(manifest, indent=2)+'\n').encode(), 0o644)
  output.parent.mkdir(parents=True, exist_ok=True)
  archive = pack(files)
  output.write_bytes(archive)
  checksum = hashlib.sha256(archive).hexdigest()
  output.with_suffix(output.suffix+'.sha256').write_text(checksum+'  '+output.name+'\n')
  print(f'STANDALONE_EXPORTED path={output} files={len(files)} bytes={len(archive)} sha256={checksum} dirty={dirty}')
  return manifest


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output', type=Path, default=ROOT/'sv/build/standalone/vectorcgra-native.tar.gz')
  parser.add_argument('--allow-dirty', action='store_true')
  args = parser.parse_args()
  export(args.output.resolve(), args.allow_dirty)


if __name__ == '__main__':
  main()
