"""Test against frozen bit layouts and packets, not the packer's own outputs."""
import copy
import importlib.util
import json
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
import unittest

SV = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('cgra_program', SV / 'tools/cgra_program.py')
program = importlib.util.module_from_spec(spec);spec.loader.exec_module(program)


def config(name='system'):
  return program.configuration.normalize(program.configuration.load_json(SV / f'examples/config/{name}.json'))


def source():
  return program.configuration.load_json(SV / 'examples/program/heterogeneous.json')


class ProgramTests(unittest.TestCase):
  def rejected(self, document, pattern, name='system'):
    with self.assertRaisesRegex(program.ConfigError, pattern):
      program.encode_outputs(config(name), document)

  def test_frozen_program_and_counts(self):
    output, metadata = program.encode_outputs(config('heterogeneous'), source())
    self.assertEqual(output['program.hex'], (SV / 'tests/phase4/template/heterogeneous/program.hex').read_text())
    self.assertEqual((metadata['packet_count'], metadata['control_count'], metadata['constant_count'], metadata['store_count']), (124, 25, 20, 8))
    self.assertEqual(output['barriers.txt'], '116 21\n')
    self.assertEqual(len(output['constants.hex'].splitlines()), 20)
    self.assertEqual(output['preload.hex'].splitlines()[:4], ['@f', '00000003c', '@10', '6f56df77c'])

  def test_original_measured_layouts(self):
    for name, path, mapping in [
        ('system', 'reference/manifest.json', {'data':'data','ctrl':'control','payload':'payload','host':'host_packet','noc':'noc_packet'}),
        ('heterogeneous', 'reference/phase4/template/heterogeneous/manifest.json', {'ctrl':'ctrl','host':'host','noc':'noc'})]:
      manifest = json.loads((SV / path).read_text())
      layouts = program.layouts(config(name))
      for current, frozen in mapping.items():
        measured = manifest['types'][frozen]
        self.assertEqual(program.width(layouts[current]), measured['nbits'])
        self.assertEqual(program.layout_fields(layouts[current]), measured['fields'])

  def test_abi_catalog(self):
    for key, name in [('opcodes','cgra_opcodes.svh'), ('native_opcodes','cgra_native_extensions.svh')]:
      header = (SV / 'rtl/common' / name).read_text()
      values = {n:int(v) for n,v in re.findall(r"`define CGRA_OPT_(\w+) 7'd(\d+)", header)}
      self.assertEqual(program.ABI[key], values)
    self.assertEqual(len(program.COMMANDS), 59)
    self.assertEqual(set(program.COMMANDS.values()), set(range(59)))
    self.assertEqual(program.OPCODES['GEP'], 92)
    self.assertEqual(program.OPCODES['PHI_N'], 104)
    self.assertNotIn('PHI_N', program.ABI['opcodes'])

  def test_signed_data_and_array_order(self):
    layouts = program.layouts(config())
    self.assertEqual(program.pack(layouts['data'], {'payload':-1, 'predicate':1}), 0x7fffffffc)
    self.assertEqual(program.pack(layouts['data'], {'payload':'0xdeadbeef', 'predicate':1}), 0x6f56df77c)
    ctrl = layouts['ctrl']
    field = next(f for f in program.layout_fields(ctrl) if f['field']=='fu_in[3]')
    self.assertEqual(program.pack(ctrl, {'fu_in':{'3':4}}), 4 << field['lsb'])
    self.assertEqual(program.pack(ctrl, {'operation':'OPT_ADD_CONST'}), 25 << 112)
    rng = random.Random(2049)
    for name in ['system','context64','streaming','ring','heterogeneous']:
      for node in program.layouts(config(name)).values():
        for _ in range(20):
          bits = rng.getrandbits(program.width(node))
          self.assertEqual(program.pack(node, program.unpack(node, bits)), bits)

  def test_bad_wire_values(self):
    node = program.layouts(config())['ctrl']
    for value, pattern in [({'typo':1}, 'unknown keys'), ({'operation':'ICMP_UNKNOWN'}, 'unknown symbol'),
                          ({'fu_in':[1]}, '4 array elements'), ({'fu_in':{'4':1}}, 'expected integer'),
                          ({'fu_in':{'01':1}}, 'decimal strings'), ({'fu_in':[8,0,0,0]}, 'fit 3 bits'),
                          ({'vector_factor_power':True}, 'expected integer'), ({'operation':-1}, 'fit 7 bits')]:
      with self.subTest(value=value), self.assertRaisesRegex(program.ConfigError, pattern):
        program.pack(node, value)
    for value in [-2147483649, 4294967296, 1.5, '$(touch /tmp/never)', '1e3']:
      with self.assertRaises(program.ConfigError):
        program.pack(program.layouts(config())['data'], {'payload':value})

  def test_program_bounds_and_selectors(self):
    base = dict(schema=1, steps=[dict(kind='program', words=[dict(operation='NAH')])])
    for updates, pattern in [({'tile':4}, 'tile'), ({'cgra':1}, 'cgra'), ({'words':[]}, 'nonempty'),
                             ({'start':8}, 'start'), ({'start':1}, 'Context'),
                             ({'period':9}, 'period'), ({'total_steps':2048}, 'total_steps'),
                             ({'words':[{'operation':'NAH'}]*9}, 'control storage')]:
      doc = copy.deepcopy(base);doc['steps'][0].update(updates);self.rejected(doc, pattern)
    for control, pattern in [({'operation':127}, 'undefined'), ({'fu_in':{'0':5}}, 'four FU'),
                             ({'routing_xbar_outport':{'0':9}}, 'available inputs'),
                             ({'fu_xbar_outport':{'0':3}}, 'two FU outputs')]:
      doc = copy.deepcopy(base);doc['steps'][0]['words'] = [dict(operation='NAH', **{k:v for k,v in control.items() if k!='operation'})]
      doc['steps'][0]['words'][0].update(control);self.rejected(doc, pattern)
    doc = copy.deepcopy(base);doc['steps'][0]['words'][0]['read_reg_towards'] = {'0':2}
    self.rejected(doc, 'no register-to-routing', 'streaming')
    doc = copy.deepcopy(base);doc['steps'][0].update(start=3,period=2)
    encoded = program.compile_program(config('context64'), doc)[1]
    packet = program.unpack(program.layouts(config('context64'))['host'], encoded[0])
    self.assertEqual(packet['payload']['cmd'], 9);self.assertEqual(packet['payload']['data']['payload'], 3)

  def test_constants_capacity_is_not_freed_by_execution(self):
    doc = dict(schema=1, steps=[dict(kind='constants', values=list(range(8))),
                              dict(kind='command',cmd='LAUNCH'),
                              dict(kind='barrier',completions=1),
                              dict(kind='constants',values=[9])])
    self.rejected(doc, 'cumulative constants')
    context = config('context64');capacity = 26
    doc['steps'][0]['values'] = list(range(capacity))
    doc['steps'][1]['cmd'] = 'TERMINATE'
    program.compile_program(context, doc)
    doc['steps'][1]['cmd'] = 'LAUNCH'
    with self.assertRaisesRegex(program.ConfigError, 'cumulative constants'):
      program.compile_program(context, doc)

  def test_preload_barriers_and_structure(self):
    for steps, pattern in [([dict(kind='preload',address=31,values=[1,2])], 'mapped memory'),
                           ([dict(kind='preload',address=0,values=[])], 'nonempty'),
                           ([dict(kind='command',cmd=63)], 'undefined command'),
                           ([dict(kind='command',cmd='LAUNCH',ctrl=[])], 'expected object'),
                           ([dict(kind='barrier',completions=2),dict(kind='barrier',completions=1)], 'nondecreasing'),
                           ([dict(kind='execute_dag')], 'unknown kind')]:
      self.rejected(dict(schema=1,steps=steps), pattern)
    self.rejected(dict(schema=1,steps=[],packets=[]), 'exactly one')
    self.rejected(dict(schema=1,steps=[]), 'no host packets')

  def test_isolated_cli(self):
    with tempfile.TemporaryDirectory() as temp:
      root = Path(temp)
      for name in ['cgra_program.py','cgra_config.py','abi.json']:
        (root / name).write_bytes((SV / 'tools' / name).read_bytes())
      (root / 'config.json').write_bytes((SV / 'examples/config/heterogeneous.json').read_bytes())
      (root / 'program.json').write_bytes((SV / 'examples/program/heterogeneous.json').read_bytes())
      command = [sys.executable,'-I','-S',str(root/'cgra_program.py'),'--config',str(root/'config.json'),'--program',str(root/'program.json')]
      for name in ['a','b']:
        result = subprocess.run(command+['--output',str(root/name)],text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
      for path in (root/'a').iterdir():
        self.assertEqual(path.read_bytes(),(root/'b'/path.name).read_bytes())
      result = subprocess.run(command+['--output',str(root/'a')],text=True,capture_output=True)
      self.assertEqual(result.returncode,2);self.assertIn('already exists',result.stderr)


if __name__ == '__main__':
  unittest.main(verbosity=2)
