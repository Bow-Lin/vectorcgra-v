"""Check regression omissions, failure propagation and cached-build identity."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SV = Path(__file__).resolve().parents[2]


def module(name):
  spec = importlib.util.spec_from_file_location(name, SV/'scripts'/f'{name}.py')
  value = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(value)
  return value


R = module('regression')
B = module('build_stamp')


class RegressionTests(unittest.TestCase):
  def test_catalog_rejects_omitted_target(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      (root/'scripts').mkdir()
      (root/'scripts/regression.json').write_text((SV/'scripts/regression.json').read_text())
      (root/'Makefile').write_text((SV/'Makefile').read_text() + '\nnative-new-feature:\n\ttrue\n')
      with self.assertRaisesRegex(ValueError, 'native-new-feature'):
        R.catalog(root)

  def test_catalog_rejects_duplicates(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      (root/'scripts').mkdir()
      data = R.catalog()
      data['shards']['duplicate'] = ['current']
      (root/'scripts/regression.json').write_text(json.dumps(data))
      (root/'Makefile').write_text((SV/'Makefile').read_text())
      with self.assertRaisesRegex(ValueError, 'multiple shards'):
        R.catalog(root)

  def test_failed_target_stops_and_records_remaining(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      fake = root/'make'
      fake.write_text('#!/bin/sh\necho intentional-target-failure\nexit 23\n')
      fake.chmod(0o755)
      with patch.object(R, 'versions', return_value={'test': 'stub'}), patch.object(R, 'fingerprint', return_value={'a': 'hash'}):
        self.assertEqual(R.run_shard('test', ['first', 'second'], root/'logs', make=str(fake)), 1)
      result = json.loads((root/'logs/result.json').read_text())
      self.assertEqual(result['status'], 'failed')
      self.assertEqual(result['steps'][0]['exit_code'], 23)
      self.assertEqual(result['not_run'], ['second'])
      self.assertFalse((root/'logs/second.log').exists())

  def test_source_change_prevents_success(self):
    with tempfile.TemporaryDirectory() as folder:
      with patch.object(R, 'versions', return_value={'test': 'stub'}), patch.object(R, 'fingerprint', side_effect=[{'a': 'before'}, {'a': 'after'}]):
        self.assertEqual(R.run_shard('test', [], Path(folder)), 1)
      result = json.loads((Path(folder)/'result.json').read_text())
      self.assertEqual(result['status'], 'source_changed_during_run')
      self.assertEqual(result['changed_inputs'], ['a'])

  def test_build_identity_covers_memory_mode_and_filelist(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      for name in ['rtl', 'filelists', 'scripts']:
        (root/name).mkdir()
      for name in ['rtl/dut.sv', 'rtl/types.svh', 'filelists/native.f', 'scripts/toolchain.sh', 'scripts/build_stamp.py']:
        (root/name).write_text('original')
      version = type('Version', (), {'stdout': 'tool 1.0\n', 'stderr': ''})()
      with patch.object(B, 'SV', root), patch.object(B, '__file__', str(root/'scripts/build_stamp.py')), patch.object(B.subprocess, 'run', return_value=version):
        before = B.stamp([], ['MEM_COMBINATIONAL=1'])
        self.assertNotEqual(before, B.stamp([], ['MEM_COMBINATIONAL=0']))
        (root/'filelists/native.f').write_text('changed order')
        self.assertNotEqual(before, B.stamp([], ['MEM_COMBINATIONAL=1']))

  def test_unused_reference_changes_do_not_rebuild_native_dut(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      for name in ['rtl/dut.sv', 'reference/gold.sv', 'tests/legacy/rtl/old.sv',
                   'filelists/native.f', 'scripts/toolchain.sh', 'scripts/build_stamp.py']:
        path = root/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('original')
      version = type('Version', (), {'stdout': 'tool 1.0\n', 'stderr': ''})()
      with patch.object(B, 'SV', root), patch.object(B, '__file__', str(root/'scripts/build_stamp.py')), patch.object(B.subprocess, 'run', return_value=version):
        native = B.stamp([], [])
        differential = B.stamp(['reference/gold.sv'], [])
        (root/'reference/gold.sv').write_text('changed reference')
        (root/'tests/legacy/rtl/old.sv').write_text('changed historical DUT')
        self.assertEqual(native, B.stamp([], []))
        self.assertNotEqual(differential, B.stamp(['reference/gold.sv'], []))


if __name__ == '__main__':
  unittest.main()
