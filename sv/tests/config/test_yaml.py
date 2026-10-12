"""Mapped YAML lowering checks, including independent frozen Python packets."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SV = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('yaml_frontend', SV/'tools/cgra_yaml.py')
Y = importlib.util.module_from_spec(spec)
spec.loader.exec_module(Y)
SOURCE = SV/'examples/yaml/relu_neura_pass.yaml'


class YamlTests(unittest.TestCase):
  def setUp(self):
    self.document = Y.load_yaml(SOURCE)

  def compile(self):
    _, config, program = Y.compile_yaml(self.document)
    types, words, _ = Y.P.compile_program(config, program)
    return [Y.P.unpack(types['host'], v) for v in words]

  def test_original_python_packets(self):
    source = SV/'reference/current/kernels/relu4x4'
    meta = json.loads((source/'manifest.json').read_text())
    p = dict(Y.P.configuration.DEFAULTS, **meta['parameters'])
    p.update(MAX_COLS=4, MAX_ROWS=4, MEM_PORTS=7, MEM_WRITE_PORTS=7, MAX_MEM_PORTS=7)
    schema = Y.P.layouts(dict(parameters=p, widths=Y.P.configuration.profile_widths(p)))['host']
    old = [Y.P.unpack(schema, int(v, 16)) for v in (source/'program.hex').read_text().splitlines()]
    self.assertTrue(all(p['payload']['cmd'] == 12 for p in old[:32]))
    self.assertEqual(self.compile(), old[32:])

  def test_constant_and_store_order(self):
    packets = self.compile()
    constants = [p['payload']['data']['payload'] for p in packets if p['dst'] == 10 and p['payload']['cmd'] == 13]
    self.assertEqual(constants, [1, 32])
    store = next(p['payload']['ctrl'] for p in packets if p['dst'] == 1 and
                 p['payload']['cmd'] == 3 and p['payload']['ctrl_addr'] == 3)
    self.assertEqual(store['fu_in'], [2, 1, 0, 0])  # address from NORTH, data from bank0
    self.assertEqual(store['routing_xbar_outport'], [0, 0, 0, 0, 0, 1, 0, 0])

  def test_changed_yaml_changes_program(self):
    original = self.compile()
    op = self.document['array_config']['cores'][2]['entries'][0]['instructions'][0]['operations'][0]
    self.assertEqual(op['opcode'], 'ICMP_SGE')
    op['src_operands'][1]['operand'] = '#7'
    changed = self.compile()
    differences = [(a, b) for a, b in zip(original, changed) if a != b]
    self.assertEqual(len(differences), 1)
    self.assertEqual(differences[0][1]['payload']['data']['payload'], 7)

  def test_schema_rejections(self):
    base = copy.deepcopy(self.document)
    mutations = [
      (lambda a: a.update(columns=True), 'columns'),
      (lambda a: a['cores'][0].update(core_id='2'), 'core_id'),
      (lambda a: a['cores'].append(copy.deepcopy(a['cores'][0])), 'duplicate core'),
      (lambda a: a['cores'][0]['entries'].append(copy.deepcopy(a['cores'][0]['entries'][0])), 'one entry'),
      (lambda a: a['cores'][0].update(unknown=0), 'unknown keys'),
    ]
    for mutate, message in mutations:
      with self.subTest(message=message):
        self.document = copy.deepcopy(base)
        mutate(self.document['array_config'])
        with self.assertRaisesRegex(Y.ConfigError, message):
          self.compile()

  def test_operation_rejections(self):
    base = copy.deepcopy(self.document)
    mutations = [
      (lambda o: o.update(opcode='DIV'), 'unsupported opcode'),
      (lambda o: o.update(time_step=5), 'disagree'),
      (lambda o: o.update(invalid_iterations=0), 'disagree'),
      (lambda o: o.update(src_operands=[]), 'source operands'),
      (lambda o: o['src_operands'][0].update(operand='NORTHEAST'), 'unsupported operand'),
      (lambda o: o['src_operands'][0].update(operand='$32'), 'register'),
      (lambda o: o['src_operands'][0].update(color='BLUE'), 'RED'),
      (lambda o: o['src_operands'][0].update(operand='#0'), 'unsupported immediate'),
    ]
    for mutate, message in mutations:
      with self.subTest(message=message):
        self.document = copy.deepcopy(base)
        op = self.document['array_config']['cores'][0]['entries'][0]['instructions'][0]['operations'][0]
        mutate(op)
        with self.assertRaisesRegex(Y.ConfigError, message):
          self.compile()

  def test_resource_conflicts(self):
    def op(code, src, dst):
      return dict(opcode=code, src=[Y.operand(dict(operand=x)) for x in src],
                  dst=[Y.operand(dict(operand=x)) for x in dst], time=0, invalid=0)
    for ops, message in [
      ([op('ADD', ['$0', '$1'], ['EAST'])], 'register read'),
      ([op('DATA_MOV', ['NORTH'], ['EAST']), op('ADD', ['$0', '$8'], ['EAST'])], 'output collision'),
      ([op('DATA_MOV', ['NORTH'], ['$0']), op('ADD', ['$0', '$8'], ['$1'])], 'register write'),
    ]:
      with self.subTest(message=message), self.assertRaisesRegex(Y.ConfigError, message):
        Y.lower_instruction(ops)

  def test_duplicate_keys_and_unsafe_yaml(self):
    with tempfile.TemporaryDirectory() as directory:
      p = Path(directory)/'bad.yaml'
      for data in ['array_config: {}\narray_config: {}\n', '!!python/object/apply:os.system ["false"]']:
        p.write_text(data)
        with self.assertRaises(Y.ConfigError):
          Y.load_yaml(p)

  def test_no_overwrite(self):
    doc, config, program = Y.compile_yaml(self.document)
    with tempfile.TemporaryDirectory() as directory:
      with self.assertRaisesRegex(Y.ConfigError, 'already exists'):
        Y.write_outputs(Path(directory), SOURCE, doc, config, program)


if __name__ == '__main__':
  unittest.main(verbosity=2)
