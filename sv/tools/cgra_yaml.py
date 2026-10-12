#!/usr/bin/env python3
"""Lower an already mapped scalar YAML schedule to native CGRA host packets.

This is a bounded frontend, not a placer/scheduler. PyYAML is optional for the
other tools; this module never imports the original Python RTL or ScriptFactory.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('program', HERE / 'cgra_program.py')
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)
require, integer, keys = P.require, P.integer, P.keys
ConfigError = P.ConfigError
PORTS = dict(NORTH=0, SOUTH=1, WEST=2, EAST=3)
# Only the operations needed by the mapped scalar ReLU are accepted initially.
# (native opcode, source count, constant opcode). GEP addresses are WORD indices.
OPS = dict(DATA_MOV=('PAS', 1, None), ADD=('ADD', 2, 'ADD_CONST'),
           GEP=('ADD', 2, 'ADD_CONST'), ICMP_EQ=('EQ', 2, 'EQ_CONST'),
           ICMP_SGE=('GTE', 2, 'GTE_CONST'), NOT=('NOT', 1, None),
           SEL=('SEL', 3, None), LOAD=('LD', 1, None), STORE=('STR', 2, None),
           GRANT_ONCE=('GRT_ONCE', 1, 'GRT_ONCE_CONST'),
           GRANT_PREDICATE=('GRT_PRED', 2, None),
           PHI_START=('PHI_START', 2, None), RETURN_VOID=('RET_VOID', 1, None))
FUS = 'ADDER MUL LOGIC SHIFTER PHI COMP GRANT MEM SEL RET NAH'.split()


def load_yaml(path):
  try:
    import yaml
  except ImportError as error:
    raise ConfigError('YAML input needs PyYAML (python3 -m pip install PyYAML)') from error
  class UniqueLoader(yaml.SafeLoader):
    pass
  def mapping(loader, node):
    result = {}
    for key, value in node.value:
      key = loader.construct_object(key, deep=True)
      require(isinstance(key, str), 'YAML mapping keys must be strings')
      require(key not in result, f'duplicate YAML key: {key}')
      result[key] = loader.construct_object(value, deep=True)
    return result
  UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
  try:
    return yaml.load(path.read_text(encoding='utf-8'), Loader=UniqueLoader)
  except yaml.YAMLError as error:
    raise ConfigError(f'invalid YAML: {error}') from error


def operand(value):
  keys(value, {'operand', 'color'}, 'operand')
  require(value.get('color', 'RED') == 'RED', 'only RED scalar operands are supported')
  name = value.get('operand')
  require(isinstance(name, str), 'operand must be a string')
  if name in PORTS:
    return ('port', PORTS[name])
  if re.fullmatch(r'\$\d+', name):
    return ('reg', integer(int(name[1:]), 'register', 0, 31))
  if re.fullmatch(r'#-?\d+', name):
    return ('imm', integer(int(name[1:]), 'immediate', -(1 << 31), (1 << 31) - 1))
  raise ConfigError(f'unsupported operand: {name!r}')


def uses_fu(op):
  if op['opcode'] != 'DATA_MOV':
    return True
  return not (op['src'][0][0] == 'port' or
              (op['src'][0][0] == 'reg' and all(t == 'port' for t, _ in op['dst'])))


def validate(document):
  keys(document, {'array_config'}, 'YAML')
  a = document.get('array_config')
  keys(a, {'columns', 'rows', 'compiled_ii', 'cores'}, 'array_config')
  cols = integer(a.get('columns'), 'columns', 2, 4)
  rows = integer(a.get('rows'), 'rows', 2, 4)
  ii = integer(a.get('compiled_ii'), 'compiled_ii', 1, 64)
  require(isinstance(a.get('cores'), list) and a['cores'], 'cores: nonempty list required')
  cores = {}; ids = set()
  for raw in a['cores']:
    keys(raw, {'column', 'row', 'core_id', 'entries'}, 'core')
    x = integer(raw.get('column'), 'column', 0, cols - 1)
    y = integer(raw.get('row'), 'row', 0, rows - 1)
    tile = y * cols + x
    require(str(raw.get('core_id')) == str(tile), 'core_id must equal row * columns + column')
    require(tile not in cores, f'duplicate core {tile}')
    entries = raw.get('entries')
    require(isinstance(entries, list) and len(entries) == 1, 'exactly one entry per core is supported')
    keys(entries[0], {'entry_id', 'instructions'}, 'entry')
    require(entries[0].get('entry_id') == 'entry0', 'only entry0 is supported')
    insns = entries[0].get('instructions')
    require(isinstance(insns, list) and insns, 'instructions: nonempty list required')
    schedule = {}
    for insn in insns:
      keys(insn, {'index_per_ii', 'operations'}, 'instruction')
      pc = integer(insn.get('index_per_ii'), 'index_per_ii', 0, ii - 1)
      require(pc not in schedule, f'duplicate instruction core={tile} pc={pc}')
      operations = insn.get('operations')
      require(isinstance(operations, list) and operations, 'operations: nonempty list required')
      ops = []
      for op in operations:
        keys(op, {'opcode', 'id', 'time_step', 'invalid_iterations', 'src_operands', 'dst_operands'}, 'operation')
        code = op.get('opcode')
        require(isinstance(code, str) and code in OPS, f'unsupported opcode: {code!r}')
        ident = integer(op.get('id'), 'operation.id')
        require(ident not in ids, f'duplicate operation id: {ident}')
        ids.add(ident)
        time = integer(op.get('time_step'), 'time_step', 0, 2047)
        invalid = integer(op.get('invalid_iterations'), 'invalid_iterations', 0, 255)
        require(time % ii == pc and time // ii == invalid,
                f'core={tile} pc={pc}: time_step and invalid_iterations disagree')
        src, dst = op.get('src_operands', []), op.get('dst_operands', [])
        require(isinstance(src, list) and isinstance(dst, list), 'operands must be lists')
        require(len(src) == OPS[code][1], f'{code}: expected {OPS[code][1]} source operands')
        src, dst = [operand(v) for v in src], [operand(v) for v in dst]
        require(all(t != 'imm' for t, _ in dst), 'immediate destination is invalid')
        require(bool(dst) == (code not in {'STORE', 'RETURN_VOID'}), f'{code}: invalid destinations')
        const = [v for t, v in src if t == 'imm']
        require(len(const) <= 1 and (not const or OPS[code][2]), f'{code}: unsupported immediate operands')
        # GTE_CONST compares variable >= constant; swapping it reverses meaning.
        if const and code == 'ICMP_SGE':
          require(src[1][0] == 'imm', 'ICMP_SGE requires its immediate on the right')
        ops.append(dict(opcode=code, src=src, dst=dst, time=time, invalid=invalid))
      require(sum(uses_fu(op) for op in ops) <= 1, f'core={tile} pc={pc}: multiple FU operations')
      schedule[pc] = ops
    cores[tile] = schedule
  return cols, rows, ii, cores


def lower_instruction(ops):
  """Reserve routing moves first, then fixed register banks, then port lanes."""
  c = dict(operation=P.OPCODES['NAH'], fu_in=[0]*4, routing_xbar_outport=[0]*8,
           fu_xbar_outport=[0]*8, write_reg_from=[0]*4, write_reg_idx=[0]*4,
           read_reg_towards=[0]*4, read_reg_idx=[0]*4)
  lanes = [None]*4
  def assign(field, index, value):
    require(c[field][index] in (0, value), f'conflicting {field}[{index}]')
    c[field][index] = value
  def read_reg(reg, toward):
    bank, idx = divmod(reg, 8)
    require(lanes[bank] in (None, ('reg', reg)), f'conflicting register read bank {bank}')
    lanes[bank] = ('reg', reg)
    c['read_reg_idx'][bank] = idx
    c['read_reg_towards'][bank] |= toward
    return bank
  def write_reg(reg, source):
    bank, idx = divmod(reg, 8)
    require(not c['write_reg_from'][bank] or
            (c['write_reg_idx'][bank] == idx and c['write_reg_from'][bank] == source),
            f'conflicting register write bank {bank}')
    c['write_reg_from'][bank] = source
    c['write_reg_idx'][bank] = idx
    return bank
  constants = []
  for op in sorted(ops, key=uses_fu):
    src, dst = op['src'][:], op['dst']
    if not uses_fu(op):
      kind, value = src[0]
      selector = value + 1 if kind == 'port' else read_reg(value, 2) + 5
      for typ, v in dst:
        port = v if typ == 'port' else write_reg(v, 1) + 4
        assign('routing_xbar_outport', port, selector)
      continue
    code = op['opcode']
    immediate = [v for typ, v in src if typ == 'imm']
    c['operation'] = P.OPCODES[OPS[code][2 if immediate else 0]]
    constants += [(op['time'], value) for value in immediate]
    if code == 'STORE':
      src.reverse()  # YAML: data,address. Mem FU: address,data.
    src = [v for v in src if v[0] != 'imm']
    for index, (typ, value) in sorted(enumerate(src), key=lambda x: x[1][0] != 'reg'):
      if typ == 'reg':
        lane = read_reg(value, 1)
      else:
        available = [i for i in range(4) if lanes[i] in (None, ('port', value)) and
                     c['routing_xbar_outport'][i+4] in (0, value+1)]
        require(available, 'no free FU input lane')
        lane = available[0]
        lanes[lane] = ('port', value)
        c['routing_xbar_outport'][lane+4] = value+1
      c['fu_in'][index] = lane+1
    for typ, value in dst:
      port = value if typ == 'port' else write_reg(value, 2)+4
      require(not c['routing_xbar_outport'][port] or typ == 'reg', 'routing/FU output collision')
      assign('fu_xbar_outport', port, 1)
  return c, constants


def compile_yaml(document, total_steps=170, memory=1):
  cols, rows, ii, cores = validate(document)
  integer(total_steps, 'total_steps', 1, 2047)
  integer(memory, 'memory', 0, 1)
  config_doc = dict(schema=1, top='system', default_fus=FUS,
                    parameters=dict(CTRL_DEPTH=max(6, ii), REG_DEPTH=8,
                                    NUM_CTRL=ii, TOTAL_STEPS=total_steps,
                                    MEM_COMBINATIONAL=memory),
                    architectures=[dict(cols=cols, rows=rows)])
  config = P.configuration.normalize(config_doc)
  packets = []
  for tile, schedule in cores.items():
    controls, constants, prologues = {}, [], []
    def command(name, **kwargs):
      return P.host_command(config, name, tile=tile, **kwargs)
    for pc, ops in sorted(schedule.items()):
      control, const = lower_instruction(ops)
      controls[pc] = P.program_control(config, P.layouts(config)['ctrl'], control)
      constants += const
      fu = [op for op in ops if uses_fu(op)]
      count = fu[0]['invalid'] if fu else max(op['invalid'] for op in ops)
      if count:
        for name in ['CONFIG_PROLOGUE_FU', 'CONFIG_PROLOGUE_FU_CROSSBAR']:
          prologues.append(command(name, pc=pc, data=P.data_value(count)))
      sources = {}
      for op in ops:
        for typ, value in op['src']:
          if typ == 'port' or (typ == 'reg' and not uses_fu(op)):
            selector = value+1 if typ == 'port' else value//8+5
            require(selector not in sources or sources[selector] == op['invalid'],
                    'conflicting prologue counts for routing source')
            sources[selector] = op['invalid']
      for op in ops:
        if op['opcode'] == 'PHI_START' and op['src'][1][0] == 'port':
          sources[op['src'][1][1]+1] += 1
      for selector, count in sources.items():
        if count:
          prologues.append(command('CONFIG_PROLOGUE_ROUTING_CROSSBAR', pc=pc,
              data=P.data_value(count), control=dict(routing_xbar_outport={'0': selector})))
    packets += [command('CONST', data=P.data_value(v)) for _, v in sorted(constants)]
    packets += [command('CONFIG_COUNT_PER_ITER', data=P.data_value(ii)),
                command('CONFIG_TOTAL_CTRL_COUNT', data=P.data_value(total_steps))]
    for pc in range(ii):
      packets.append(command('CONFIG', pc=pc, control=controls.get(pc,
          dict(operation=P.OPCODES['NAH'], fu_in=[1, 2, 3, 4]))))
    packets += prologues + [command('LAUNCH')]
  program = dict(schema=1, packets=packets)
  P.compile_program(config, program)
  return config_doc, config, program


def write_outputs(path, source, config_doc, config, program, extras=None):
  require(not path.exists(), 'output directory already exists; choose a fresh directory')
  outputs, metadata = P.encode_outputs(config, program)
  outputs.update({'config.json': json.dumps(config_doc, indent=2)+'\n',
                  'program.json': json.dumps(program, indent=2)+'\n'})
  p = config['parameters']
  flags = [f'-G{k}={v}' for k, v in p.items()]
  kinds = [P.configuration.FU_KINDS[n] for n in FUS]
  flags.append(f"-GFU_KINDS={8*len(kinds)}'h{P.configuration.packed(kinds, 8):x}")
  outputs['verilator.args'] = '\n'.join(flags)+'\n'
  outputs.update(extras or {})
  sha = lambda b: hashlib.sha256(b).hexdigest()
  metadata.update(schema=1, input_yaml_sha256=sha(source.read_bytes()),
                  parameters=p, legacy_python=False,
                  tool_sha256={n: sha((HERE/n).read_bytes()) for n in
                               ['cgra_yaml.py', 'cgra_program.py', 'cgra_config.py', 'abi.json']},
                  output_sha256={n: sha(v.encode()) for n, v in outputs.items()})
  path.mkdir(parents=True)
  for name, text in outputs.items():
    (path/name).write_text(text, encoding='utf-8')
  (path/'manifest.json').write_text(json.dumps(metadata, indent=2)+'\n')
  return metadata


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--yaml', type=Path, required=True)
  parser.add_argument('--output', type=Path, required=True)
  parser.add_argument('--total-steps', type=int, required=True)
  args = parser.parse_args()
  try:
    doc, config, program = compile_yaml(load_yaml(args.yaml), args.total_steps)
    meta = write_outputs(args.output, args.yaml, doc, config, program)
    print(f'CGRA_YAML_PASS packets={meta["packet_count"]} controls={meta["control_count"]}')
  except (ConfigError, OSError) as error:
    parser.exit(2, f'CGRA_YAML_ERROR: {error}\n')


if __name__ == '__main__':
  main()
