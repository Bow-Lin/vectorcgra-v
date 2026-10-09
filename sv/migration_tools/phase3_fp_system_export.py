"""Freeze ac96 CGRA with a floating-point FU list and an arithmetic whole-array workload.

Migration-only: invoke separately for each geometry so PyMTL caches stay isolated.
Normal SV targets consume the frozen output and never execute this script.
"""

import argparse
from collections import Counter
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from reference_model import ROOT, BASELINE, type_schema, hex_bits
from pymtl3 import DefaultPassGroup, mk_bits, clog2
from pymtl3.passes.backends.verilog import VerilogTranslationPass
from VectorCGRA.cgra.CgraRTL import CgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from phase3_float_export import WindowsPlaceholderPass
from VectorCGRA.fu.float.FpAddRTL import FpAddRTL
from VectorCGRA.fu.float.FpMulRTL import FpMulRTL
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt, mk_inter_cgra_pkt

DIRECTIONS = ["north", "south", "west", "east"]


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
  path.write_text(json.dumps(value, indent=2) + "\n")


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--cols", type=int, required=True)
  parser.add_argument("--rows", type=int, required=True)
  parser.add_argument("--data-width", type=int, default=32)
  parser.add_argument("--ctrl-depth", type=int, default=8)
  parser.add_argument("--reg-depth", type=int, default=16)
  parser.add_argument("--max-cycles", type=int, default=3000)
  parser.add_argument("--reference-root", type=Path, default=ROOT / "sv/reference/phase3/system/float")
  parser.add_argument("--vectors-root", type=Path, default=ROOT / "sv/vectors/phase3/system/float")
  args = parser.parse_args()
  cols, rows = args.cols, args.rows
  data_w, ctrl_depth, reg_depth = args.data_width, args.ctrl_depth, args.reg_depth
  assert (data_w, ctrl_depth, reg_depth) in [(32, 8, 16), (64, 16, 8)]
  mask = (1 << data_w) - 1
  assert (cols, rows) in [(2, 2), (4, 4), (3, 2)], "Only the three reviewed geometries are exported"
  ntiles = cols * rows
  label = f"{cols}x{rows}"
  top = f"Phase3FloatReference{label}"
  if (data_w, ctrl_depth, reg_depth) != (32, 8, 16):
    label += f"-w{data_w}-c{ctrl_depth}-r{reg_depth}"
    top += f"W{data_w}C{ctrl_depth}R{reg_depth}"
  ref = args.reference_root.resolve() / label
  out = args.vectors_root.resolve() / label
  if ref.exists() or out.exists():
    parser.error("Use fresh reference/vector directories; frozen artifacts are not overwritten")
  git = lambda *items: subprocess.check_output(["git", *items], cwd=ROOT, text=True).strip()
  changed = [p for p in git("diff", "--name-only", BASELINE, "--", "*.py").splitlines() if not p.startswith("sv/")]
  assert not changed, changed
  assert Path(sys.modules['VectorCGRA.cgra.CgraRTL'].__file__).resolve() == ROOT / 'cgra/CgraRTL.py'
  submodules = {}
  for path in ["noc/PyOCN", "fu/pymtl3_hardfloat", "fu/fused_alu_fixedp/dp_fpfma"]:
    expected = git("ls-tree", BASELINE, path).split()[2]
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT / path, text=True).strip()
    assert expected == actual, path
    submodules[path] = actual
  ref.mkdir(parents=True)
  out.mkdir(parents=True)
  (ref / 'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  Data = mk_data(data_w, 1)
  Ctrl = mk_ctrl(4, 2, 4, 4, reg_depth)
  Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(clog2(ctrl_depth)))
  Host = mk_intra_cgra_pkt(1, 1, ntiles, Payload)
  Noc = mk_inter_cgra_pkt(1, 1, ntiles, cols + rows - 1, Payload)

  def design():
    return CgraRTL(Payload, 1, 1, cols, rows, ctrl_depth, 128, 16, 2, reg_depth, 8, 8,
      True, FlexibleFuRTL, [FpAddRTL, FpMulRTL, MemUnitRTL, NahRTL], "Mesh",
      {0: [0, 31]}, {0: [0, 0]}, is_multi_cgra=False, has_ctrl_ring=True, has_im2col_engine=False)

  os.chdir(ref)
  dut = design()
  dut.elaborate()
  dut.apply(WindowsPlaceholderPass())
  dut.set_metadata(VerilogTranslationPass.enable, True)
  dut.set_metadata(VerilogTranslationPass.explicit_module_name, top)
  dut.apply(VerilogTranslationPass())
  generated = Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve()
  rtl = ref / f"{top}.v"
  generated.rename(rtl)
  header = re.search(r"module " + top + r"\s*\((.*?)\n\);", rtl.read_text(), re.S).group(1)
  sources = {}
  for module in list(sys.modules.values()):
    path = getattr(module, "__file__", None)
    if not path or Path(path).suffix != '.py':
      continue
    try:
      relative = Path(path).resolve().relative_to(ROOT)
    except ValueError:
      continue
    sources[relative.as_posix()] = sha(path)
  params = dict(COLS=cols, ROWS=rows, DATA_W=data_w, CTRL_DEPTH=ctrl_depth, REG_DEPTH=reg_depth,
    BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8, TOTAL_STEPS=8)
  reference = dict(baseline_commit=BASELINE, export_checkout_commit=git('rev-parse', 'HEAD'),
    export_script_snapshot=dict(file='exporter_snapshot.py', sha256=sha(__file__)),
    top=top, rtl=rtl.name, rtl_sha256=sha(rtl), parameters=params,
    submodules=submodules, source_sha256=dict(sorted(sources.items())),
    python_executable=sys.executable, python_version=sys.version,
    pymtl3_version=importlib.metadata.version('pymtl3'),
    pymtl3_direct_url=importlib.metadata.distribution('pymtl3').read_text('direct_url.json'),
    types={name: type_schema(Type) for name, Type in [('data', Data), ('control', Ctrl),
      ('payload', Payload), ('host_packet', Host), ('noc_packet', Noc)]},
    top_port_declarations=header.strip().splitlines(),
    fixed_options=dict(single_cgra=True, ring=True, im2col=False, dma=False,
      combinational_memory=True, cgra_id=0, address_lower=0, address_upper=31,
      functional_units=['FpAddRTL', 'FpMulRTL', 'MemUnitRTL', 'NahRTL']))
  save(ref / 'manifest.json', reference)
  (ref / 'top_ports.txt').write_text(header.strip() + '\n')
  print('REFERENCE ' + json.dumps({'geometry': label, 'top': top, 'host_bits': Host.nbits, 'noc_bits': Noc.nbits}), flush=True)

  # Hamiltonian cycle: snake through columns 1..COLS-1, return via column 0.
  chain = [0]
  for y in range(rows):
    xs = range(1, cols) if y % 2 == 0 else range(cols - 1, 0, -1)
    chain.extend(y * cols + x for x in xs)
  chain.extend(y * cols for y in range(rows - 1, 0, -1))
  assert sorted(chain) == list(range(ntiles)) and chain[-1] == cols

  def direction(src, dst):
    delta = (dst % cols - src % cols, dst // cols - src // cols)
    return {(0, 1): 0, (0, -1): 1, (-1, 0): 2, (1, 0): 3}[delta]

  def ctrl(op, incoming=None, outgoing=()):
    route, crossbar = [mk_bits(4)(0) for _ in range(8)], [mk_bits(2)(0) for _ in range(8)]
    if incoming is not None:
      route[4] = mk_bits(4)(incoming + 1)
    for port in outgoing:
      crossbar[port] = mk_bits(2)(1)
    return Ctrl(operation=op, fu_in=[mk_bits(3)(i) for i in [1, 2, 3, 4]],
      routing_xbar_outport=route, fu_xbar_outport=crossbar)

  def packet(cmd, tile=0, value=0, pred=0, addr=0, control=None, pc=0):
    return Host(src=0, dst=tile, payload=Payload(cmd=cmd,
      data=Data(value & mask, pred), data_addr=addr,
      ctrl=Ctrl() if control is None else control, ctrl_addr=pc))

  def fp(value):
    if value == 0: return 0
    mag = abs(value)
    exponent = mag.bit_length() - 1
    return (int(value < 0) << 31) | ((255 + exponent) << 22) | ((mag << (22-exponent)) & ((1 << 22)-1))

  programs = {0: [ctrl(28, outgoing=[3]), ctrl(58, incoming=0)]}
  constants = {0: [15, 16]}
  for i, tile in enumerate(chain[1:], 1):
    outputs = [direction(tile, chain[(i + 1) % ntiles])]
    if i == ntiles - 1:
      outputs.append(2)
    programs[tile] = [ctrl(42 if i == 2 else 39, direction(tile, chain[i - 1]), outputs)]
    constants[tile] = [fp(5 if i == 1 else (3 if i == 2 else -8))]

  def configuration(value):
    packets = [packet(12, value=value, pred=1, addr=15), packet(12, value=0xdeadbeef, pred=1, addr=16)]
    for tile in range(ntiles):
      packets.extend(packet(13, tile, value=k, pred=1) for k in constants[tile])
      packets.extend(packet(cmd, tile, value=len(programs[tile])) for cmd in [8, 7])
      packets.extend(packet(3, tile, control=c, pc=pc) for pc, c in enumerate(programs[tile]))
    packets.extend(packet(0, tile) for tile in reversed(chain))
    queries = [packet(10, addr=16), packet(10, addr=15)]
    assert len(packets) == 5 * ntiles + 4
    return packets, queries

  scenarios = [{'name': 'positive', 'input': fp(7), 'integer_input': 7}, {'name': 'negative_after_reset', 'input': fp(-6), 'integer_input': -6}]
  config = {'parameters': params, 'chain': chain, 'program': 'load[15], FPadd5, FPmul3, FPadd(-8) at every remaining Tile, store[16]; last Tile multicasts west[1]', 'scenarios': []}
  for s in scenarios:
    s['expected'] = fp((s['integer_input']+5)*3-8*(ntiles-3))
    packets, queries = configuration(s['input'])
    words = [hex_bits(p) for p in packets + queries]
    (out / (s['name'] + '_packets.hex')).write_text('\n'.join(words) + '\n')
    config['scenarios'].append({**s, 'configuration_count': len(packets), 'packet_hex': words})
  save(out / 'configuration.json', config)

  # The placeholder IP is checked in HDL, not a fabricated pure-Python trace.
  raw = rtl.read_text()
  names = set(re.findall(r'(?m)^\s*module\s+(\w+)', raw))
  names.update(re.findall(r'}\s+(\w+)\s*;', raw))
  names.update(re.findall(r'`define\s+(\w+)', raw))
  mapping = {n: 'GoldFpSystem_' + n for n in sorted(names)}
  pattern = re.compile(r'\b(' + '|'.join(map(re.escape, sorted(names, key=len, reverse=True))) + r')\b')
  renamed = pattern.sub(lambda m: mapping[m[0]], raw)
  reverse = {v:k for k,v in mapping.items()}
  assert re.sub(r'\b('+'|'.join(map(re.escape, reverse))+r')\b', lambda m: reverse[m[0]], renamed) == raw
  portable = re.sub(r'(?m)^(`line[^\n]*)$', lambda m:m[0].replace(chr(92), '/'), renamed)
  (ref/'gold_portable.v').write_text(portable, newline='\n')
  save(ref/'namespace.json', dict(mapping=mapping, roundtrip_verified=True,
    original_sha256=sha(rtl), portable_sha256=sha(ref/'gold_portable.v'),
    adaptation='Namespace plus diagnostic-only line path separators; no RTL changes.',
    reference_kind='Unmodified ac96 translated HDL including HardFloat. No Python simulation trace claimed.'))
  print('FP_SYSTEM_REFERENCE_PASS', flush=True)

if __name__ == '__main__':
  main()
