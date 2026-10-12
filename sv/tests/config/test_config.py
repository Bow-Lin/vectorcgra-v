"""Independent format, rejection, reproducibility and isolation checks."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

SV = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('cgra_config', SV / 'tools/cgra_config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


def example(name='system'):
  return json.loads((SV / 'examples/config' / (name + '.json')).read_text())


class ConfigTests(unittest.TestCase):
  def rejected(self, value, text):
    with self.assertRaisesRegex(config.ConfigError, text):
      config.normalize(value)

  def test_frozen_heterogeneous_tables(self):
    output = config.emit(config.normalize(example('heterogeneous')))['architecture.svh']
    frozen = (SV / 'tests/phase4/template/heterogeneous/architecture.svh').read_text()
    for line in frozen.splitlines()[1:]:
      self.assertIn(line, output)
    manifest = json.loads((SV / 'reference/phase4/template/heterogeneous/manifest.json').read_text())
    normalized = config.normalize(example('heterogeneous'))
    for name, field in [('HOST_BITS', 'host'), ('NOC_BITS', 'noc'), ('CTRL_BITS', 'ctrl')]:
      self.assertEqual(normalized['widths'][name], manifest['types'][field]['nbits'])

  def test_packing_agrees_with_catalog(self):
    header = (SV / 'rtl/common/cgra_fu_catalog.svh').read_text()
    kinds = dict((n, int(v)) for n, v in re.findall(r"`define CGRA_FU_(\w+) 8'd(\d+)", header))
    self.assertEqual(config.FU_KINDS, kinds)
    value = example();value['default_fus'] = ['LOGIC', 'NAH', 'ADDER']
    normalized = config.normalize(value)
    self.assertEqual(normalized['architectures'][0]['fu_names'][0], ['LOGIC', 'NAH', 'ADDER'])
    output = config.emit(normalized)['architecture.svh']
    # Four ordered 24-bit slots; highest slot is zero-valued ADDER.
    self.assertIn("ARCH_FUS=96'h306000306000306000306;", output)

  def test_regular_geometry_and_memory_order(self):
    normalized = config.normalize(example('context64'))
    a = normalized['architectures'][0]
    self.assertEqual(a['read_ports'], [0, 3, 1, 2])
    self.assertEqual(a['boundary_in'], [6, 2, 10, 5, 1, 9])
    self.assertIn(dict(src=0, dst=4, sp=5, dp=7, enabled=1), a['links'])
    self.assertNotIn(dict(src=2, dst=3, sp=3, dp=2, enabled=1), a['links'])
    for name in ['system', 'context64', 'streaming', 'ring', 'heterogeneous']:
      config.emit(config.normalize(example(name)))

  def test_invalid_parameters(self):
    for key, value, message in [
        ('TILE_PORTS', 5, 'TILE_PORTS'), ('CTRL_DEPTH', 1, 'control'),
        ('NUM_CTRL', 9, 'control'), ('REG_DEPTH', 1, 'register'),
        ('TOTAL_STEPS', 2048, 'total steps'), ('NUM_BANKS', 3, 'power of two'),
        ('BANK_DEPTH', 1, 'power of two'), ('GLOBAL_ADDR_W', 4, 'memory windows'),
        ('GLOBAL_ADDR_W', 33, 'payload/address'), ('DATA_W', 10, 'payload/address'),
        ('VECTOR_FACTOR_POWER', 1, 'VECTOR_FACTOR_POWER'),
        ('MEM_PORTS', 2, 'port tables'), ('MEM_WRITE_PORTS', 2, 'port tables'),
        ('MAX_MEM_PORTS', 2, 'MAX_MEM_PORTS'), ('MAX_COLS', 1, 'shared geometry'),
        ('FU_COUNT', 3, 'tile catalog'), ('COLS', 3, 'largest declared'),
        ('DATA_W', True, 'expected integer'), ('MEM_COMBINATIONAL', 2, 'expected integer')]:
      with self.subTest(key=key, value=value):
        doc = example();doc['parameters'] = {key: value}
        self.rejected(doc, message)
    doc = example('context64');doc['parameters']['HAS_DMA'] = 1
    self.rejected(doc, '32-bit')

  def test_graph_conflicts(self):
    base = example();a = base['architectures'][0]
    a.update(links=[dict(src=0, dst=1, sp=3, dp=2, enabled=1)])
    for edge in [dict(src=0, dst=3, sp=3, dp=1), dict(src=2, dst=1, sp=3, dp=2)]:
      doc = copy.deepcopy(base);doc['architectures'][0]['links'].append(edge)
      self.rejected(doc, 'physical port')
    for key, value in [('src', 4), ('dst', -1), ('sp', 4), ('dp', '2')]:
      doc = copy.deepcopy(base);doc['architectures'][0]['links'][0][key] = value
      self.rejected(doc, 'expected integer')
    # Disabled duplicate edges do not drive or claim a physical port.
    doc = copy.deepcopy(base);doc['architectures'][0]['links'].append(dict(a['links'][0], enabled=0))
    self.assertEqual(len(config.normalize(doc)['architectures'][0]['links']), 2)
    doc = copy.deepcopy(base);doc['architectures'][0]['links'][0].update(sp=2)
    self.rejected(doc, 'boundary and internal')
    for name in ['boundary_in', 'boundary_out']:
      doc = example();doc['architectures'][0][name] = [1, 0, 0, 0]
      self.rejected(doc, 'exterior cardinal')
      doc['architectures'][0][name] = [0, 0, 0, 0, 1]
      self.rejected(doc, 'padding')

  def test_memory_and_catalog_rejections(self):
    for name in ['read_ports', 'write_ports']:
      for ports, message in [([0, 0], 'multiple memory'), ([4], 'out of range'), ([-1], 'expected integer')]:
        doc = example();doc['architectures'][0][name] = ports
        self.rejected(doc, message)
    for fus, message in [([], 'nonempty'), (['ADDER'], 'exactly one NAH'),
        (['NAH', 'NAH'], 'exactly one NAH'), (['NAH', 'MEM', 'MEM'], 'only one'),
        (['NAH', 'UNKNOWN'], 'unknown FU'), (['NAH', 0], 'must be strings'),
        (['NAH', 'STREAMING_MEM'], 'incompatible')]:
      doc = example();doc['default_fus'] = fus;self.rejected(doc, message)
    for variant, wrong in [('context', 'STREAMING_MEM'), ('streaming', 'MEM')]:
      doc = example();doc.update(variant=variant, default_fus=['NAH', wrong], parameters={'TILE_PORTS':8})
      self.rejected(doc, 'incompatible')
      doc['default_fus'] = ['NAH', 'ADDER'];config.normalize(doc)
    doc = example('streaming');doc['default_fus'] = ['StreamingMemUnitRTL', 'NahRTL']
    self.assertEqual(config.normalize(doc)['architectures'][0]['fu_names'][0], ['STREAMING_MEM', 'NAH'])
    doc = example('streaming');doc['parameters']['TILE_PORTS'] = 4
    self.rejected(doc, 'eight ports')
    doc = example();doc['architectures'][0]['fu_names'] = [['NAH']]
    self.rejected(doc, 'every tile')
    doc = example();doc['architectures'][0]['read_ports'] = [None, 0, None]
    self.assertEqual(config.normalize(doc)['architectures'][0]['read_ports'], [0xffffffff, 0, 0xffffffff])

  def test_vector_and_float_boundaries(self):
    for fu, lanes, legacy, valid in [('VECTOR_ADDER', 3, 0, False),
        ('VECTOR_ADDER', 8, 0, True), ('VECTOR_REDUCE', 2, 0, False),
        ('VECTOR_REDUCE', 8, 0, True), ('VECTOR_MUL', 8, 0, False),
        ('VECTOR_MUL', 8, 1, True), ('VECTOR_MUL', 4, 0, True)]:
      doc = example();doc.update(default_fus=[fu, 'NAH'], parameters={'VECTOR_LANES':lanes, 'VECTOR_LEGACY_PYTHON':legacy})
      if valid:config.normalize(doc)
      else:self.rejected(doc, 'lanes')
    doc = example('context64');doc['default_fus'] = ['FP_ADD', 'NAH']
    self.rejected(doc, 'FP format')
    doc['parameters'].update(FP_EXP_W=11, FP_SIG_W=52)
    config.normalize(doc)

  def test_multi_topology_and_maps(self):
    doc = example('ring');doc['parameters']['MULTI_ROWS'] = 2
    self.rejected(doc, 'architectures count')
    doc = example('ring');doc['topology'] = 'mesh'
    self.rejected(doc, 'Mesh requires')
    doc = example('ring');doc['parameters']['HAS_IM2COL'] = 1
    self.rejected(doc, 'peripheral ports')
    doc = example('ring');doc['address_map'] = [0, 1, 2, 2]
    self.rejected(doc, 'permutation')
    doc['address_map'] = [0, 1, 2, 4]
    self.rejected(doc, 'expected integer')
    for field in ['top', 'variant', 'topology']:
      doc = example();doc[field] = []
      self.rejected(doc, 'expected')
    doc = example();doc['parameters'] = {'FU_INPUTS':8}
    self.rejected(doc, 'unknown keys')

  def test_isolated_cli_and_no_overwrite(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp);tool = root / 'config.py';tool.write_bytes((SV / 'tools/cgra_config.py').read_bytes())
      source = root / 'input.json';source.write_text(json.dumps(example('heterogeneous')))
      cmd = [sys.executable, '-I', '-S', str(tool), str(source)]
      for name in ['a', 'b']:
        result = subprocess.run(cmd + ['--output', str(root / name)], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
      for name in ['architecture.svh', 'bindings.svh', 'manifest.json']:
        self.assertEqual((root / 'a' / name).read_bytes(), (root / 'b' / name).read_bytes())
      before = (root / 'a/manifest.json').read_bytes()
      result = subprocess.run(cmd + ['--output', str(root / 'a')], text=True, capture_output=True)
      self.assertEqual(result.returncode, 2);self.assertIn('already exists', result.stderr)
      self.assertEqual(before, (root / 'a/manifest.json').read_bytes())
      source.write_text('{"schema":1,"schema":1}')
      result = subprocess.run(cmd + ['--check'], text=True, capture_output=True)
      self.assertEqual(result.returncode, 2);self.assertIn('duplicate JSON key', result.stderr)
      self.assertFalse((root / 'failed').exists())


if __name__ == '__main__':
  unittest.main(verbosity=2)
