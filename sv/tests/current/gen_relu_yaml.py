#!/usr/bin/env python3
"""Prepare a 32-word signed ReLU check from the user's mapped 4x4 YAML."""
import argparse
import importlib.util
import json
from pathlib import Path

SV = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('yaml_frontend', SV/'tools/cgra_yaml.py')
Y = importlib.util.module_from_spec(spec)
spec.loader.exec_module(Y)


def prepare(source, output, values=None, memory=1):
  document = Y.load_yaml(source)
  cols, rows, ii, _ = Y.validate(document)
  Y.require((cols, rows, ii) == (4, 4, 5), 'ReLU runner requires a 4x4, II=5 mapping')
  if values is None:
    values = list(range(-16, 16))
  Y.require(isinstance(values, list) and len(values) == 32, 'input must contain exactly 32 signed integers')
  for v in values:
    Y.integer(v, 'input value', -(1 << 31), (1 << 31)-1)
  doc, config, program = Y.compile_yaml(document, 170, memory)
  P = Y.P
  returns = [p for p in program['packets'] if p['payload']['cmd'] == P.COMMANDS['CONFIG']
             and p['payload']['ctrl']['operation'] == P.OPCODES['RET_VOID']]
  Y.require(len(returns) == 1, 'ReLU runner requires exactly one RETURN_VOID')
  ret = returns[0]
  schema = P.layouts(config)['host']
  expected_return = dict(src=ret['dst'], dst=16,
      payload=dict(cmd=P.COMMANDS['COMPLETE'], ctrl=ret['payload']['ctrl']))
  program['packets'][:0] = [P.host_command(config, 'STORE_REQUEST',
      address=i, data=P.data_value(v)) for i, v in enumerate(values)]
  extras = {
      'input.json': json.dumps(values)+'\n',
      'expected.hex': ''.join(f'{i} {max(0, v):08x}\n' for i, v in enumerate(values)),
      'stores.txt': ''.join(f'{i} 1\n' for i in range(32)),
      'return.hex': f'{P.pack(schema, expected_return):x}\n',
  }
  return Y.write_outputs(output, source, doc, config, program, extras)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--yaml', type=Path, required=True)
  parser.add_argument('--output', type=Path, required=True)
  parser.add_argument('--input', type=Path, help='JSON array of 32 signed int32 values; default -16..15')
  parser.add_argument('--memory', type=int, choices=[0, 1], default=1)
  args = parser.parse_args()
  try:
    values = Y.P.configuration.load_json(args.input) if args.input else None
    meta = prepare(args.yaml, args.output, values, args.memory)
    print(f'RELU_YAML_PREPARED packets={meta["packet_count"]} words=32')
  except (Y.ConfigError, OSError, json.JSONDecodeError) as error:
    parser.exit(2, f'RELU_YAML_ERROR: {error}\n')


if __name__ == '__main__':
  main()
