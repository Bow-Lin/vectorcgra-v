#!/usr/bin/env python3
"""Exercise uploaded-style YAML with independent ReLU data and negative controls."""
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile
import time

SV = Path(__file__).resolve().parents[2]


def main():
  if os.name == 'posix':
    import resource
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
  base = SV/'build/current/yaml-relu'
  base.mkdir(parents=True, exist_ok=True)
  root = Path(tempfile.mkdtemp(prefix='regression-', dir=base))
  source = SV/'examples/yaml/relu_neura_pass.yaml'
  records = []
  def run(name, command, marker, *, negative=False, env=None):
    log = root/(name+'.log')
    with log.open('w') as stream:
      status = subprocess.run(command, cwd=SV, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
    text = log.read_text()
    if (status != 0) != negative or marker not in text:
      raise RuntimeError(f'{name}: exit={status}\n{text[-5000:]}')
    records.append(dict(name=name, negative=negative, exit_code=status, marker=marker,
                        log=str(log.relative_to(SV)), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
    print('YAML_RELU_CHECK_PASS '+name, flush=True)

  run('frontend', ['python3', 'tests/config/test_yaml.py'], 'OK')
  rng = random.Random(721)
  inputs = dict(original=list(range(-16, 16)),
                boundaries=[-(1 << 31), -1, 0, 1, (1 << 31)-1, -17, 17, -(1 << 31)+1]*4,
                random=[rng.randrange(-(1 << 31), 1 << 31) for _ in range(32)],
                zero=[0]*32)
  for memory in [1]:
    for name, values in inputs.items():
      input_path = root/(name+'.json')
      input_path.write_text(json.dumps(values)+'\n')
      directory = root/f'memory{memory}-{name}'
      run(f'memory{memory}-{name}', ['bash', 'tests/current/run_relu_yaml.sh', str(source),
          str(directory), str(input_path)], 'RELU_YAML_PASS', env=dict(os.environ, RELU_MEMORY=str(memory)))
    fixture = root/f'memory{memory}-original'
    exe = SV/f'build/current/yaml-relu/memory{memory}/obj/Vtb_native_kernel{os.environ.get("EXEEXT", "")}'
    common = [str(exe), f'+PROGRAM={fixture}', f'+STORE_COUNTS={fixture}/stores.txt']
    run(f'memory{memory}-wrong-result', common+['+EXPECT_FAILURE'], 'KERNEL_MATH', negative=True)
    run(f'memory{memory}-timeout', common+['+STALL_FOREVER', '+MAX_CYCLES=2000'], 'NATIVE_KERNEL_TIMEOUT', negative=True)
    excess = root/'excess-stores.txt'
    excess.write_text((fixture/'stores.txt').read_text().replace('0 1\n', '0 2\n', 1))
    run(f'memory{memory}-early-return', [str(exe), f'+PROGRAM={fixture}', f'+STORE_COUNTS={excess}'],
        'KERNEL_EARLY_RETURN', negative=True)
    # A well-formed but wrong comparison must reach the RTL and fail math.
    # This detects a runner that ignores the supplied YAML in favor of a fixture.
    mutated = root/'wrong-comparison.yaml'
    mutated.write_text(source.read_text().replace('"ICMP_SGE"', '"ICMP_EQ"'))
    assert mutated.read_text() != source.read_text()
    changed = root/f'memory{memory}-changed-yaml'
    subprocess.run(['python3', 'tests/current/gen_relu_yaml.py', '--yaml', str(mutated),
                    '--output', str(changed), '--memory', str(memory)], cwd=SV, check=True)
    run(f'memory{memory}-changed-yaml', [str(exe), f'+PROGRAM={changed}', f'+STORE_COUNTS={changed}/stores.txt'],
        'KERNEL_MATH', negative=True)
  # The source map returns from core9 independently of core1's final STORE.
  # A registered memory response exposes an early return (31/32 stores). Keep
  # this as a failing counterexample, not a supported positive configuration.
  run('registered-memory-early-return', ['bash', 'tests/current/run_relu_yaml.sh', str(source),
      str(root/'registered-memory')], 'KERNEL_EARLY_RETURN', negative=True,
      env=dict(os.environ, RELU_MEMORY='0'))
  paths = ['tools/cgra_yaml.py', 'tools/cgra_program.py', 'tools/cgra_config.py', 'tools/abi.json',
           'tests/current/gen_relu_yaml.py', 'tests/current/run_relu_yaml.sh',
           'tests/current/run_yaml_relu_tests.py', 'tests/current/tb_native_kernel.sv',
           'tests/config/test_yaml.py', 'examples/yaml/relu_neura_pass.yaml']
  report = dict(schema=1, status='passed', at_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                mathematical_runs=8, checked_words=256, negative_runs=5,
                source_sha256={p: hashlib.sha256((SV/p).read_bytes()).hexdigest() for p in paths}, checks=records)
  (root/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
  print(f'YAML_RELU_REGRESSION_PASS report={root}/validation.json')


if __name__ == '__main__':
  main()
