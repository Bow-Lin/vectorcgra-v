"""Keep historical DUTs and golden references outside the native source boundary."""
import hashlib
import json
from pathlib import Path
import unittest

SV = Path(__file__).resolve().parents[2]


class RtlLayoutTests(unittest.TestCase):
  def test_relocations_preserve_bytes_without_core_duplicates(self):
    layout = json.loads((SV/'tests/legacy/relocations.json').read_text())
    for entry in layout['files']:
      with self.subTest(path=entry['new']):
        self.assertFalse((SV/entry['old']).exists())
        self.assertEqual(hashlib.sha256((SV/entry['new']).read_bytes()).hexdigest(), entry['sha256'])

  def test_native_filelist_contains_only_maintained_sources(self):
    for line in (SV/'filelists/native.f').read_text().splitlines():
      with self.subTest(line=line):
        path = line.removeprefix('+incdir+')
        self.assertTrue(path.startswith('rtl/'), line)
        self.assertTrue((SV/path).exists(), line)

  def test_historical_filelists_resolve_relocated_sources(self):
    for name in ['rtl.f', 'phase3.f', 'phase4.f']:
      for line in (SV/'filelists'/name).read_text().splitlines():
        with self.subTest(filelist=name, line=line):
          self.assertTrue((SV/line.removeprefix('+incdir+')).exists())


if __name__ == '__main__':
  unittest.main()
