"""Measure structural path groups with stock Yosys ABC, without remapping.

Use structural_cutpoints.py to export and topologically order the entire mapped
design first. Analysis-only time markers isolate source/endpoint classes; they
are removed algebraically from reported delay and never count as design area.
See TIMING_COMPARISON.md for the electrical model and its limitations.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'sys_lib'))
from mapped_timing import groups, liberty_cells, quote


def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def number_list(text):
  return [float(x) for x in re.findall(r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?', text)]


def replace_values(body, offset):
  # Preserve row structure: ABC accepts the original separate row strings.
  def table(match):
    segment = match.group(0)
    return re.sub(r'"([^"]*)"', lambda row: '"' + ', '.join(format(v + offset, '.12g') for v in number_list(row.group(1))) + '"', segment)
  return re.sub(r'values\s*\(.*?\)\s*;', table, body, flags=re.S)


def make_library(liberty, output, offset_ns):
  text = liberty.read_text()
  clean = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
  if not re.search(r'time_unit\s*:\s*"1ns"', clean) or not re.search(r'capacitive_load_unit\s*\(\s*1\s*,\s*ff\s*\)', clean):
    raise ValueError('This measurement model requires 1 ns and 1 fF Liberty units')
  driver = next(body for name, body in groups(clean, 'cell') if name == 'BUF_X1')
  shifted = driver
  for keyword in ('cell_rise', 'cell_fall'):
    for _, body in groups(driver, keyword):
      shifted = shifted.replace(body, replace_values(body, offset_ns))
  # Same input cap as one original PO; no net after the marker can reach the DUT.
  def marker(name, value):
    tables = '\n'.join(f'{kind} (marker_table) {{ index_1 ("0, 1"); index_2 ("0, 1"); values ("{value if kind.startswith("cell_") else 0}, {value if kind.startswith("cell_") else 0}", "{value if kind.startswith("cell_") else 0}, {value if kind.startswith("cell_") else 0}"); }}' for kind in ('cell_rise', 'cell_fall', 'rise_transition', 'fall_transition'))
    return f'''cell ({name}) {{ area : 0; pin (A) {{ direction : input; capacitance : 5; rise_capacitance : 5; fall_capacitance : 5; }} pin (Z) {{ direction : output; function : "A"; timing () {{ related_pin : "A"; timing_sense : positive_unate; {tables} }} }} }}'''
  extra = '\nlu_table_template (marker_table) { variable_1 : input_net_transition; variable_2 : total_output_net_capacitance; index_1 ("0, 1"); index_2 ("0, 1"); }\n'
  extra += f'cell (MEASURE_LAUNCH) {{{driver}}}\ncell (MEASURE_SELECTED_LAUNCH) {{{shifted}}}\n'
  extra += marker('MEASURE_ENDPOINT', 0) + '\n' + marker('MEASURE_SELECTED_ENDPOINT', offset_ns) + '\n'
  pos = text.rfind('}')
  output.write_text(text[:pos] + extra + text[pos:])


def export(source, cutpoints, library, output, source_kind, endpoint_kind):
  cells = liberty_cells(library)
  points = json.loads(cutpoints.read_text())
  ins, outs = points['inputs'], points.get('endpoints', points.get('outputs'))
  used = set(x['net'] for x in outs)
  gate_outputs = []
  type_counts = Counter()
  # All source.gates must already be topologically ordered.
  with source.open() as stream:
    for line in stream:
      if not line.startswith('.gate '):
        continue
      parts = line.split()
      typ = parts[1]
      type_counts[typ] += 1
      for part in parts[2:]:
        pin, net = part.split('=')
        direction = 'output' if typ.startswith('_const') else cells[typ]['pins'][pin]
        if direction == 'input':
          used.add(net)
        else:
          gate_outputs.append(net)
  dangling = [net for net in gate_outputs if net not in used]
  source_matches = sum(source_kind == 'all' or x['kind'] == source_kind for x in ins)
  endpoint_matches = sum(endpoint_kind == 'all' or x['kind'] == endpoint_kind for x in outs)
  if not source_matches or not endpoint_matches:
    raise ValueError('Empty requested path group')
  with output.open('w') as stream:
    stream.write('.model grouped_mapped_timing\n.inputs ' + ' '.join('launch_' + str(i) for i in range(len(ins))) + '\n')
    stream.write('.outputs ' + ' '.join('endpoint_' + str(i) for i in range(len(outs))) + ' ' + ' '.join(dangling) + '\n')
    for i, item in enumerate(ins):
      typ = 'MEASURE_SELECTED_LAUNCH' if source_kind == 'all' or item['kind'] == source_kind else 'MEASURE_LAUNCH'
      stream.write(f'.gate {typ} A=launch_{i} Z={item["net"]}\n')
    with source.open() as src:
      for line in src:
        if line.startswith('.gate '):
          stream.write(line)
    for i, item in enumerate(outs):
      typ = 'MEASURE_SELECTED_ENDPOINT' if endpoint_kind == 'all' or item['kind'] == endpoint_kind else 'MEASURE_ENDPOINT'
      stream.write(f'.gate {typ} A={item["net"]} Z=endpoint_{i}\n')
    # Unused launch drivers themselves need anchors for stime's fanout check.
    stream.write('.end\n')
  return {'physical_gate_statements': sum(type_counts.values()), 'type_counts': dict(type_counts),
          'dummy_endpoint_count': len(dangling), 'launch_markers': len(ins), 'endpoint_markers': len(outs),
          'selected_launches': source_matches, 'selected_endpoints': endpoint_matches,
          'inputs': ins, 'endpoints': outs}


def analyze(source, cutpoints, liberty, abc, output, source_kind, endpoint_kind, offset_ns=100):
  if (output / 'result.json').exists():
    raise FileExistsError(f'Refusing to overwrite a completed result: {output}')
  if not 0 < offset_ns < 1000:
    raise ValueError('Use a positive offset below 1000 ns, then verify with a second offset')
  output.mkdir(parents=True, exist_ok=True)
  start = time.monotonic()
  marked_lib = output / 'measurement.lib'
  make_library(liberty, marked_lib, offset_ns)
  marked_blif = output / 'measurement.blif'
  audit = export(source, cutpoints, liberty, marked_blif, source_kind, endpoint_kind)
  # Avoid unconnected marker driver outputs, retaining every original launch.
  all_used = set()
  text = marked_blif.read_text()
  for line in text.splitlines():
    if line.startswith('.gate '):
      parts = line.split()
      for assignment in parts[2:]:
        pin, net = assignment.split('=')
        if pin == 'A' and parts[1].startswith('MEASURE_'):
          all_used.add(net)
        elif not parts[1].startswith('MEASURE_'):
          # Use original library pin directions for physical cells.
          if not parts[1].startswith('_const') and pin in liberty_cells_cached(liberty)[parts[1]]:
            all_used.add(net)
  anchors = [x['net'] for x in audit['inputs'] if x['net'] not in all_used]
  if anchors:
    text = re.sub(r'(?m)^\.outputs (.*)$', lambda m: m[0] + ' ' + ' '.join(anchors), text)
    marked_blif.write_text(text)
  audit['unused_launch_anchors'] = len(anchors)
  constr = output / 'timing.constr'
  constr.write_text('set_load 5\n')
  script = output / 'timing.abc'
  readback = output / 'readback.blif'
  script.write_text(f'read_lib {quote(marked_lib)}\nread_blif {quote(marked_blif)}\nread_constr {quote(constr)}\nprint_stats\nstime -p\nwrite_blif {quote(readback)}\n')
  env = os.environ.copy()
  env['PATH'] = os.pathsep.join([str(abc.parent), str(abc.parent.parent / 'lib'), env.get('PATH', '')])
  log = output / 'abc.log'
  with log.open('w') as stream:
    result = subprocess.run([str(abc), '-s', '-f', str(script)], stdout=stream, stderr=subprocess.STDOUT, env=env)
  content = re.sub(r'\x1b\[[0-9;]*m', '', log.read_text(errors='replace'))
  delay = re.search(r'Delay\s*=\s*([0-9.]+)\s*ps', content)
  if result.returncode or not delay:
    raise RuntimeError(content[-3500:])
  value = float(delay[1]) - 2 * offset_ns * 1000
  if not 0 < value < offset_ns * 1000 / 2:
    raise ValueError(f'Offset isolation failed: delay={value}')
  endpoints = re.search(r'Start-point = pi(\d+)\.\s+End-point = po(\d+)\.', content)
  if not endpoints:
    raise ValueError('Missing start/end indices in ABC path report')
  i_start, i_end = map(int, endpoints.groups())
  if i_start >= len(audit['inputs']) or i_end >= len(audit['endpoints']):
    raise ValueError('Critical path ends at an analysis-only anchor')
  startpoint, endpoint = audit['inputs'][i_start], audit['endpoints'][i_end]
  if source_kind != 'all' and startpoint['kind'] != source_kind:
    raise ValueError('Incorrect critical path source class')
  if endpoint_kind != 'all' and endpoint['kind'] != endpoint_kind:
    raise ValueError('Incorrect critical path endpoint class')
  expected = Counter(audit['type_counts'])
  expected.update({'MEASURE_SELECTED_LAUNCH': audit['selected_launches'],
                   'MEASURE_LAUNCH': audit['launch_markers'] - audit['selected_launches'],
                   'MEASURE_SELECTED_ENDPOINT': audit['selected_endpoints'],
                   'MEASURE_ENDPOINT': audit['endpoint_markers'] - audit['selected_endpoints']})
  actual = Counter()
  with readback.open() as stream:
    for line in stream:
      if line.startswith('.gate '):
        actual[line.split()[1]] += 1
  if expected != actual:
    raise ValueError(f'ABC readback cell type mismatch: missing={expected-actual}, extra={actual-expected}')
  count = int(re.search(r'Gates\s*=\s*(\d+)', content)[1])
  if count != sum(expected.values()):
    raise ValueError('ABC stime gate count mismatch')
  audit.update({'source_kind': source_kind, 'endpoint_kind': endpoint_kind,
                'abc_total_ps': float(delay[1]), 'offset_ns': offset_ns, 'delay_ps': value,
                'critical_startpoint': startpoint, 'critical_endpoint': endpoint,
                'abc_gate_count': count, 'abc_readback_types_verified': True,
                'critical_path': [line for line in content.splitlines() if line.startswith('Path')],
                'frequency_proxy_mhz': 1e6 / value, 'wall_seconds': time.monotonic() - start,
                'source_sha256': sha(source), 'cutpoints_sha256': sha(cutpoints),
                'liberty_sha256': sha(liberty), 'measurement_liberty_sha256': sha(marked_lib),
                'measurement_blif_sha256': sha(marked_blif), 'abc_sha256': sha(abc),
                'analysis_script_sha256': sha(__file__),
                'method': 'Stock ABC stime, absolute BUF_X1 source driver, 5 fF per real endpoint; time markers de-embedded',
                'limitations': ['Structural combinational frequency proxy, not signoff Fmax',
                  'No clock-to-Q, setup, clock-tree or wire delay',
                  'Undefined pins are independent diagnostic sources; functional behavior is unresolved',
                  'Q and QN are independent launch points; path sensitization is not checked',
                  'ABC Liberty conditional arc handling and extrapolation are retained']})
  del audit['inputs'], audit['endpoints']
  (output / 'result.json').write_text(json.dumps(audit, indent=2) + '\n')
  return audit


_LIB_CACHE = {}
def liberty_cells_cached(path):
  if str(path) not in _LIB_CACHE:
    _LIB_CACHE[str(path)] = {name: {pin for pin, d in cell['pins'].items() if d == 'input'} for name, cell in liberty_cells(path).items()}
  return _LIB_CACHE[str(path)]


if __name__ == '__main__':
  p = argparse.ArgumentParser()
  p.add_argument('--source', type=Path, required=True)
  p.add_argument('--cutpoints', type=Path, required=True)
  p.add_argument('--output', type=Path, required=True)
  p.add_argument('--liberty', type=Path, default=ROOT / 'sys_lib/lib/NangateOpenCellLibrary_typical.lib')
  p.add_argument('--abc', type=Path, default=ROOT / 'sys_lib/tools/oss-cad-suite/bin/yosys-abc.exe')
  p.add_argument('--source-kind', default='sequential_output_pins')
  p.add_argument('--endpoint-kind', default='sequential_input_pins')
  p.add_argument('--offset-ns', type=float, default=100)
  a = p.parse_args()
  result = analyze(a.source.resolve(), a.cutpoints.resolve(), a.liberty.resolve(), a.abc.resolve(), a.output.resolve(), a.source_kind, a.endpoint_kind, a.offset_ns)
  print(json.dumps({key: result[key] for key in ('delay_ps', 'frequency_proxy_mhz', 'abc_gate_count', 'critical_startpoint', 'critical_endpoint', 'wall_seconds')}, indent=2))
