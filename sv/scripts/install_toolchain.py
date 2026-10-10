#!/usr/bin/env python3
"""Install SHA-verified native HDL tools on Linux x86_64; stdlib plus curl/tar/unzip."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess


def sha256(path):
  digest = hashlib.sha256()
  with path.open('rb') as stream:
    for block in iter(lambda: stream.read(1024*1024), b''):
      digest.update(block)
  return digest.hexdigest()


def run(command):
  return subprocess.run(command, check=True, text=True, capture_output=True).stdout.strip()


def install(destination, archives, lock):
  if platform.system() != 'Linux' or platform.machine() not in ['x86_64', 'amd64']:
    raise ValueError('Automatic install supports Linux x86_64; other platforms can set VERILATOR, YOSYS and SV2V manually')
  destination.mkdir(parents=True, exist_ok=True)
  archives.mkdir(parents=True, exist_ok=True)
  for name, filename in [('oss_cad_suite', 'oss-cad-suite.tgz'), ('sv2v', 'sv2v.zip')]:
    config = lock[name]
    archive = archives / filename
    if not archive.exists() or sha256(archive) != config['sha256']:
      partial = archive.with_suffix('.partial')
      subprocess.run(['curl', '-fL', '--retry', '3', '--max-time', '600', config['url'], '-o', str(partial)], check=True)
      if sha256(partial) != config['sha256']:
        raise ValueError('Archive SHA256 mismatch: ' + name)
      partial.replace(archive)
    print('TOOL_ARCHIVE_VERIFIED ' + name + ' ' + config['sha256'], flush=True)
    if filename.endswith('.tgz'):
      subprocess.run(['tar', '-xzf', str(archive), '-C', str(destination)], check=True)
    else:
      subprocess.run(['unzip', '-q', '-o', str(archive), '-d', str(destination)], check=True)
  environment = {
    'VERILATOR': str(destination / 'oss-cad-suite/bin/verilator'),
    'YOSYS': str(destination / 'oss-cad-suite/bin/yosys'),
    'SV2V': str(destination / 'sv2v-Linux/sv2v'),
    'YOSYS_SIMCELLS': str(destination / 'oss-cad-suite/share/yosys/simcells.v'),
  }
  versions = {
    'verilator': run([environment['VERILATOR'], '--version']),
    'yosys': run([environment['YOSYS'], '-V']),
    'sv2v': run([environment['SV2V'], '--version']),
  }
  if ('Verilator ' + lock['oss_cad_suite']['verilator']) not in versions['verilator']:
    raise ValueError('Installed Verilator does not match the lock')
  if ('Yosys ' + lock['oss_cad_suite']['yosys']) not in versions['yosys']:
    raise ValueError('Installed Yosys does not match the lock')
  if lock['sv2v']['release'][1:] not in versions['sv2v']:
    raise ValueError('Installed sv2v does not match the lock')
  (destination/'env.sh').write_text(''.join(f'export {key}={shlex.quote(value)}\n' for key,value in environment.items()))
  (destination/'versions.json').write_text(json.dumps(versions, indent=2)+'\n')
  print('TOOLCHAIN_READY ' + str(destination/'env.sh'), flush=True)
  return environment


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1]/'build/toolchain')
  parser.add_argument('--archives', type=Path)
  parser.add_argument('--github-env', action='store_true')
  args = parser.parse_args()
  destination = args.destination.resolve()
  lock = json.loads(Path(__file__).with_name('toolchain.lock.json').read_text())
  environment = install(destination, (args.archives or destination/'archives').resolve(), lock)
  if args.github_env:
    with open(os.environ['GITHUB_ENV'], 'a') as stream:
      for key,value in environment.items():
        if '\n' in value or '\r' in value:
          raise ValueError('Invalid tool path for GitHub environment')
        stream.write(f'{key}={value}\n')


if __name__ == '__main__':
  main()
