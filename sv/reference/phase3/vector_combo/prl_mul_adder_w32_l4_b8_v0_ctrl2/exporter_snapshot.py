"""Migration-only frozen ac96 references for vector/composite FUs.

Native SV build/test runners consume these artifacts without invoking Python.
Existing successful references are never overwritten.
"""
import argparse
import configparser
import hashlib
import importlib
import inspect
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import traceback

from reference_model import ROOT, BASELINE, type_schema
from pymtl3 import mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass, VerilogPlaceholderPass
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt

CLASSES = {
  'vector_adder': ('vector.VectorAdderRTL', 'cgra_vector_adder'),
  'vector_mul': ('vector.VectorMulRTL', 'cgra_vector_mul'),
  'vector_adder_combo': ('vector.VectorAdderComboRTL', 'tile_vector_adder_combo'),
  'vector_mul_combo': ('vector.VectorMulComboRTL', 'tile_vector_mul_combo'),
  'vector_all_reduce': ('vector.VectorAllReduceRTL', 'tile_vector_all_reduce'),
  'seq_mul_adder': ('double.SeqMulAdderRTL', 'tile_seq_mul_adder'),
  'seq_mul_shifter': ('double.SeqMulShifterRTL', 'tile_seq_mul_shifter'),
  'prl_mul_adder': ('double.PrlMulAdderRTL', 'tile_prl_mul_adder'),
  'three_mul_adder_shifter': ('triple.ThreeMulAdderShifterRTL', 'tile_three_mul_adder_shifter'),
  'four_inc_cmp_not_grant': ('quadra.FourIncCmpNotGrantRTL', 'tile_four_inc_cmp_not_grant'),
  'alu_gen_mac': ('fused_alu_fixedp.AluGenMacRTL', 'tile_alu_gen_mac'),
  'alu_gen_mac_wrapper': ('fused_alu_fixedp.AluGenMacWrapperRTL', 'cgra_alu_gen_mac'),
}


class PortablePlaceholderPass(VerilogPlaceholderPass):
  """Host-only correction: upstream's POSIX '/' walk never ends on Windows."""
  def _get_auto_prefix(self, component):
    parent = Path(inspect.getfile(component.__class__)).resolve().parent
    current = parent
    while not (current / 'pymtl.ini').exists():
      if current.parent == current:
        return ''
      current = current.parent
    config = configparser.ConfigParser()
    config.read(current / 'pymtl.ini')
    if config.getboolean('placeholder', 'auto_prefix', fallback=False):
      if current == parent:
        return parent.name + '_'
      return '_'.join(parent.relative_to(current).parts) + '_'
    return ''


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, obj):
  path.write_text(json.dumps(obj, indent=2) + '\n', newline='\n')


def main():
  p = argparse.ArgumentParser(description=__doc__)
  p.add_argument('--case', choices=CLASSES, required=True)
  p.add_argument('--width', type=int, default=32)
  p.add_argument('--lanes', type=int, default=4)
  p.add_argument('--lane-width', type=int, default=8)
  p.add_argument('--vfp', type=int, default=0)
  p.add_argument('--ctrl-inputs', type=int, default=4, choices=[2,4])
  a = p.parse_args()
  label = f'{a.case}_w{a.width}_l{a.lanes}_b{a.lane_width}_v{a.vfp}'
  if a.ctrl_inputs != 4:
    label += f'_ctrl{a.ctrl_inputs}'
  out = ROOT / 'sv/reference/phase3/vector_combo' / label
  if (out / 'manifest.json').exists():
    prior = json.loads((out / 'manifest.json').read_text())
    if prior.get('status') == 'exported':
      print('SKIP ' + label, flush=True)
      return
  out.mkdir(parents=True, exist_ok=True)
  git = lambda *items: subprocess.check_output(['git', *items], cwd=ROOT, text=True).strip()
  changed = [x for x in git('diff', '--name-only', BASELINE, '--', '*.py').splitlines() if not x.startswith('sv/')]
  assert not changed, changed
  info = dict(status='exporting', baseline_commit=BASELINE, label=label, native_module=CLASSES[a.case][1],
    parameters=dict(DATA_W=a.width, LANES=a.lanes, LANE_W=a.lane_width, VECTOR_FACTOR_POWER=a.vfp),
    python_executable=sys.executable)
  info['control_fu_inputs'] = a.ctrl_inputs
  (out / 'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  try:
    module_path, native = CLASSES[a.case]
    module = importlib.import_module('VectorCGRA.fu.' + module_path)
    cls = getattr(module, module_path.split('.')[-1])
    assert Path(module.__file__).resolve().is_relative_to(ROOT)
    Data = mk_data(a.width, 1)
    Ctrl = mk_ctrl(a.ctrl_inputs, 2, 4, 4, 16)
    Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(3))
    Packet = mk_intra_cgra_pkt(1, 1, 4, Payload)
    if a.case in ('vector_adder', 'vector_mul'):
      dut = cls(a.lane_width, Packet, 4, 2)
    elif a.case in ('vector_adder_combo', 'vector_all_reduce'):
      dut = cls(Packet, 4, 2, a.vfp, a.lanes, a.width)
    elif a.case == 'vector_mul_combo':
      dut = cls(Packet, 4, 2, a.vfp, a.lanes)
    elif a.case == 'alu_gen_mac_wrapper':
      dut = cls()
    else:
      dut = cls(Packet, 4, 2)
    os.chdir(out)
    dut.elaborate()
    dut.apply(PortablePlaceholderPass())
    top = 'P3Vector_' + label
    dut.set_metadata(VerilogTranslationPass.enable, True)
    dut.set_metadata(VerilogTranslationPass.explicit_module_name, top)
    dut.apply(VerilogTranslationPass())
    generated = Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
    rtl = out / 'reference.v'
    generated.replace(rtl)
    source = rtl.read_text()
    header = re.search(r'\bmodule\s+' + top + r'\s*\((.*?)\n\);', source, re.S)[1]
    widths = {}
    for body, name in re.findall(r'typedef struct packed\s*\{(.*?)\}\s*(\w+)\s*;', source, re.S):
      width = 0
      for field in body.split(';'):
        field = re.sub(r'//[^\n]*', '', field).strip()
        if not field:
          continue
        typ = field.split()[0]
        bits = 1 if typ == 'logic' else widths[typ]
        for hi, lo in re.findall(r'\[(\d+):(\d+)\]', field):
          bits *= abs(int(hi)-int(lo))+1
        width += bits
      widths[name] = width
    ports = []
    for line in header.splitlines():
      m = re.match(r'\s*(input|output)\s+(\w+)\s*(\[\d+:\d+\])?\s*(\w+)\s*(\[\d+:\d+\])?', line)
      if not m:
        continue
      direction, typ, packed, name, shape = m.groups()
      nbits = widths.get(typ, 1)
      if packed:
        hi, lo = map(int, re.findall(r'\d+', packed));nbits *= abs(hi-lo)+1
      ports.append(dict(direction=direction, name=name, width=nbits, shape=shape or ''))
    sources = {}
    for imported in list(sys.modules.values()):
      path = getattr(imported, '__file__', None)
      if path and Path(path).suffix == '.py' and Path(path).resolve().is_relative_to(ROOT):
        sources[Path(path).resolve().relative_to(ROOT).as_posix()] = sha(path)
    info.update(status='exported', top=top, rtl='reference.v', rtl_sha256=sha(rtl), ports=ports,
      types={name:type_schema(Type) for name,Type in [('data',Data),('control',Ctrl),('payload',Payload)]},
      source_sha256=dict(sorted(sources.items())), exporter_sha256=sha(__file__))
    (out / 'top_ports.txt').write_text(header.strip()+'\n', newline='\n')
    print('EXPORTED '+label, flush=True)
  except Exception:
    info.update(status='baseline_export_failed', failure=traceback.format_exc())
    print('FAILED '+label+'\n'+info['failure'], flush=True)
  write_json(out/'manifest.json', info)
  if info['status'] != 'exported':
    sys.exit(1)


if __name__ == '__main__':
  main()
