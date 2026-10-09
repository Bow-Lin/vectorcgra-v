"""Freeze one ac96 scalar geometry and execute a whole-array reference workload.

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
  parser.add_argument("--max-cycles", type=int, default=3000)
  parser.add_argument("--reference-root", type=Path, default=ROOT / "sv/reference/phase2")
  parser.add_argument("--vectors-root", type=Path, default=ROOT / "sv/vectors/phase2")
  args = parser.parse_args()
  cols, rows = args.cols, args.rows
  assert (cols, rows) in [(2, 2), (4, 4), (3, 2)], "Only the three reviewed geometries are exported"
  ntiles = cols * rows
  label = f"{cols}x{rows}"
  top = f"Phase2Reference{label}"
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
  Data = mk_data(32, 1)
  Ctrl = mk_ctrl(4, 2, 4, 4, 16)
  Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(3))
  Host = mk_intra_cgra_pkt(1, 1, ntiles, Payload)
  Noc = mk_inter_cgra_pkt(1, 1, ntiles, cols + rows - 1, Payload)

  def design():
    return CgraRTL(Payload, 1, 1, cols, rows, 8, 128, 16, 2, 16, 8, 8,
      True, FlexibleFuRTL, [AdderRTL, MulRTL, MemUnitRTL, NahRTL], "Mesh",
      {0: [0, 31]}, {0: [0, 0]}, is_multi_cgra=False, has_ctrl_ring=True, has_im2col_engine=False)

  os.chdir(ref)
  dut = design()
  dut.elaborate()
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
  params = dict(COLS=cols, ROWS=rows, DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16,
    BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8, TOTAL_STEPS=8)
  reference = dict(baseline_commit=BASELINE, export_checkout_commit=git('rev-parse', 'HEAD'),
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
      functional_units=['AdderRTL', 'MulRTL', 'MemUnitRTL', 'NahRTL']))
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
      data=Data(value & 0xffffffff, pred), data_addr=addr,
      ctrl=Ctrl() if control is None else control, ctrl_addr=pc))

  programs = {0: [ctrl(28, outgoing=[3]), ctrl(58, incoming=0)]}
  constants = {0: [15, 16]}
  for i, tile in enumerate(chain[1:], 1):
    outputs = [direction(tile, chain[(i + 1) % ntiles])]
    if i == ntiles - 1:
      outputs.append(2)
    programs[tile] = [ctrl(29 if i == 2 else 25, direction(tile, chain[i - 1]), outputs)]
    constants[tile] = [5 if i == 1 else (3 if i == 2 else 0xfffffff8)]

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

  scenarios = [{'name': 'positive', 'input': 7}, {'name': 'negative_after_reset', 'input': 0xfffffffa}]
  config = {'parameters': params, 'chain': chain, 'program': 'load[15], add5, mul3, add(-8) at every remaining Tile, store[16]; last Tile multicasts west[1]', 'scenarios': []}
  for s in scenarios:
    s['expected'] = (((s['input'] + 5) * 3) - 8 * (ntiles - 3)) & 0xffffffff
    packets, queries = configuration(s['input'])
    words = [hex_bits(p) for p in packets + queries]
    (out / (s['name'] + '_packets.hex')).write_text('\n'.join(words) + '\n')
    config['scenarios'].append({**s, 'configuration_count': len(packets), 'packet_hex': words})
  save(out / 'configuration.json', config)

  # Reconstruct a fresh model: translation elaboration must not affect the oracle.
  dut = design()
  dut.elaborate()
  dut.apply(DefaultPassGroup())
  dut.cgra_id @= 0
  dut.address_lower @= 0
  dut.address_upper @= 31
  dut.recv_from_inter_cgra_noc.val @= 0
  dut.recv_from_inter_cgra_noc.msg @= Noc()
  dut.send_to_inter_cgra_noc.rdy @= 0
  for d in DIRECTIONS:
    for i in range(cols if d in ['north', 'south'] else rows):
      recv = getattr(dut, f'recv_data_on_boundary_{d}')[i]
      send = getattr(dut, f'send_data_on_boundary_{d}')[i]
      recv.val @= 0
      recv.msg @= Data()
      send.rdy @= 1

  widths = {}
  def snapshot():
    ins, outs = {}, {}
    def add(target, name, port):
      value = port.to_bits() if hasattr(port, 'to_bits') else port
      widths[name] = value.nbits
      target[name] = hex_bits(port) if name.endswith('__msg') else int(port)
    for name in ['reset', 'cgra_id', 'address_lower', 'address_upper']:
      add(ins, name, getattr(dut, name))
    for name, ifc, key, target in [('recv_from_cpu_pkt__val', dut.recv_from_cpu_pkt, 'val', ins),
      ('recv_from_cpu_pkt__msg', dut.recv_from_cpu_pkt, 'msg', ins),
      ('send_to_cpu_pkt__rdy', dut.send_to_cpu_pkt, 'rdy', ins),
      ('recv_from_cpu_pkt__rdy', dut.recv_from_cpu_pkt, 'rdy', outs),
      ('send_to_cpu_pkt__val', dut.send_to_cpu_pkt, 'val', outs),
      ('send_to_cpu_pkt__msg', dut.send_to_cpu_pkt, 'msg', outs)]:
      add(target, name, getattr(ifc, key))
    for d in DIRECTIONS:
      for i in range(cols if d in ['north', 'south'] else rows):
        recv, send = getattr(dut, f'recv_data_on_boundary_{d}')[i], getattr(dut, f'send_data_on_boundary_{d}')[i]
        for key in ['val', 'msg', 'rdy']:
          add(outs if key == 'rdy' else ins, f'recv_data_on_boundary_{d}__{i}__{key}', getattr(recv, key))
          add(ins if key == 'rdy' else outs, f'send_data_on_boundary_{d}__{i}__{key}', getattr(send, key))
    return ins, outs

  trace, results = [], []
  for sid, scenario in enumerate(scenarios):
    packets, queries = configuration(scenario['input'])
    pidx = qidx = host_hold = west_hold = 0
    completed, responses, west_events, links = [], [], [], []
    done = None
    dut.recv_from_cpu_pkt.val @= 0
    dut.recv_from_cpu_pkt.msg @= Host()
    dut.send_to_cpu_pkt.rdy @= 0
    dut.send_data_on_boundary_west[1].rdy @= 0
    dut.reset @= 1
    for cycle in [-3, -2, -1]:
      dut.sim_eval_combinational()
      ins, outs = snapshot()
      trace.append(dict(scenario=sid, cycle=cycle, inputs=ins, outputs=outs))
      dut.sim_tick()
    dut.reset @= 0
    for cycle in range(args.max_cycles):
      querying = pidx == len(packets) and len(completed) == ntiles
      active = packets[pidx] if pidx < len(packets) else (queries[qidx] if querying and qidx < 2 else None)
      dut.recv_from_cpu_pkt.val @= int(active is not None)
      dut.recv_from_cpu_pkt.msg @= Host() if active is None else active
      dut.send_to_cpu_pkt.rdy @= int(host_hold >= 6 and cycle % 7 >= 2)
      dut.send_data_on_boundary_west[1].rdy @= int(west_hold >= 8)
      dut.sim_eval_combinational()
      ins, outs = snapshot()
      trace.append(dict(scenario=sid, cycle=cycle, inputs=ins, outputs=outs))
      if active is not None and dut.recv_from_cpu_pkt.rdy:
        if querying: qidx += 1
        else: pidx += 1
      if dut.send_to_cpu_pkt.val:
        if host_hold < 6: host_hold += 1
        if dut.send_to_cpu_pkt.rdy:
          p = dut.send_to_cpu_pkt.msg
          if int(p.payload.cmd) == 14:
            tile = int(p.src)
            assert 0 <= tile < ntiles and tile not in completed and int(p.dst) == ntiles, str(p)
            completed.append(tile)
          else:
            assert int(p.payload.cmd) == 11 and len(responses) < 2, str(p)
            responses.append(dict(cycle=cycle, address=int(p.payload.data_addr), data=int(p.payload.data.payload), predicate=int(p.payload.data.predicate), hex=hex_bits(p)))
      west = dut.send_data_on_boundary_west[1]
      if west.val:
        assert int(west.msg.payload) == scenario['expected'] and int(west.msg.predicate) == 1, str(west.msg)
        if west_hold < 8: west_hold += 1
        if west.rdy: west_events.append(cycle)
      for d in DIRECTIONS:
        for i in range(cols if d in ['north', 'south'] else rows):
          if (d, i) != ('west', 1):
            assert not getattr(dut, f'send_data_on_boundary_{d}')[i].val, (d, i, cycle)
      for index, src in enumerate(chain):
        dst = chain[(index + 1) % ntiles]
        link = dut.tile[src].send_data[direction(src, dst)]
        if link.val & link.rdy:
          value = scenario['input'] if index == 0 else ((scenario['input'] + 5) if index == 1 else ((scenario['input'] + 5) * 3 - 8 * (index - 2)))
          assert int(link.msg.payload) == value & 0xffffffff and int(link.msg.predicate) == 1
          links.append(dict(cycle=cycle, src=src, dst=dst, data=int(link.msg.payload)))
      if len(completed) == ntiles and len(responses) == 2 and len(west_events) == 1:
        if done is None: done = cycle
        if cycle >= done + 8:
          dut.sim_tick()
          break
      dut.sim_tick()
    else:
      save(out / 'failure.json', dict(scenario=scenario, input_index=pidx, completed=completed,
        links=links, responses=responses, tiles=[t.line_trace() for t in dut.tile]))
      raise RuntimeError('Reference stalled; see failure.json')
    assert sorted(completed) == list(range(ntiles))
    assert [(r['address'], r['data'], r['predicate']) for r in responses] == [(16, scenario['expected'], 1), (15, scenario['input'], 1)]
    assert len(west_events) == 1
    assert Counter((x['src'], x['dst']) for x in links) == Counter((src, chain[(i + 1) % ntiles]) for i, src in enumerate(chain))
    result = dict(**scenario, cycles_after_reset=cycle + 1, completion_order=completed,
      responses=responses, west_cycles=west_events, links=links)
    results.append(result)
    print('SCENARIO ' + json.dumps(result), flush=True)
  tracepath = out / 'baseline_trace.jsonl'
  tracepath.write_text(''.join(json.dumps(row, separators=(',', ':')) + '\n' for row in trace))
  layouts = {}
  for side in ['inputs', 'outputs']:
    offset, fields, words = 0, [], []
    for name in trace[0][side]:
      width = widths[name]
      fields.append(dict(field=name, lsb=offset, msb=offset + width - 1, nbits=width))
      offset += width
    for row in trace:
      bits = 0
      for f in fields:
        raw = row[side][f['field']]
        value = int(raw, 16) if isinstance(raw, str) else raw
        bits |= value << f['lsb']
      words.append(format(bits, f'0{(offset + 3) // 4}x'))
    path = out / f'replay_{side}.hex'
    path.write_text('\n'.join(words) + '\n')
    layouts[side] = dict(file=path.name, nbits=offset, sha256=sha(path), fields=fields)
  save(out / 'replay_layout.json', dict(samples=len(trace), layouts=layouts,
    row_labels=[dict(scenario=r['scenario'], cycle=r['cycle']) for r in trace],
    sample_phase='Pre-rising-edge combinational observation',
    excluded_outputs=['recv_from_inter_cgra_noc__rdy', 'send_to_inter_cgra_noc__val', 'send_to_inter_cgra_noc__msg']))
  save(out / 'manifest.json', dict(baseline_commit=BASELINE, reference_rtl_sha256=sha(rtl),
    parameters=params, chain=chain, trace_rows=len(trace), trace_sha256=sha(tracepath),
    scenarios=results, status='python_reference_passed', script_sha256=sha(__file__),
    scope='All active input/output bits recorded including idle msg. HDL replay not yet claimed. Two-state reference; three externally inactive NoC outputs excluded.'))
  print('PASS ' + json.dumps(dict(geometry=label, trace_rows=len(trace), input_bits=layouts['inputs']['nbits'], output_bits=layouts['outputs']['nbits'])), flush=True)


if __name__ == '__main__':
  main()
