"""Check reproducible packaging, corruption detection and baseline extraction."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

SV = Path(__file__).resolve().parents[2]


def load(name):
  spec = importlib.util.spec_from_file_location(name, SV/'scripts'/f'{name}.py')
  value = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(value)
  return value


E = load('export_standalone')
V = load('verify_bundle')
B = load('prepare_baseline')


class StandaloneTests(unittest.TestCase):
  def test_archive_is_independent_of_input_order(self):
    a = E.pack({'b': (b'two', 0o644), 'a': (b'one', 0o755)})
    b = E.pack({'a': (b'one', 0o755), 'b': (b'two', 0o644)})
    self.assertEqual(a, b)
    with tarfile.open(fileobj=io.BytesIO(a), mode='r:gz') as archive:
      self.assertEqual(archive.getnames(), ['a', 'b'])
      self.assertTrue(all(m.mtime == m.uid == m.gid == 0 for m in archive.getmembers()))

  def test_bundle_rejects_corrupted_rtl(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      files = {'sv/rtl/dut.sv': b'module dut; endmodule\n', 'sv/filelists/native.f': b'rtl/dut.sv\n'}
      for name, data in files.items():
        path = root/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
      info = dict(source_commit='test', dirty_source=False,
                  files={name:dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest()) for name,data in files.items()})
      (root/'BUNDLE_MANIFEST.json').write_text(json.dumps(info))
      V.verify(root)
      (root/'sv/rtl/dut.sv').write_text('corrupted')
      with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
        V.verify(root)

  def test_baseline_restores_bytes_and_rejects_escape(self):
    with tempfile.TemporaryDirectory() as folder:
      root = Path(folder)
      record = B.restore(root, E.pack({'sv/rtl/dut.sv': (b'original', 0o644)}))
      self.assertEqual((root/'sv/rtl/dut.sv').read_bytes(), b'original')
      self.assertEqual(record['source_sha256']['sv/rtl/dut.sv'], hashlib.sha256(b'original').hexdigest())
      with self.assertRaisesRegex(ValueError, 'Unsafe baseline archive path'):
        B.restore(root, E.pack({'../outside': (b'invalid', 0o644)}))


if __name__ == '__main__':
  unittest.main()
