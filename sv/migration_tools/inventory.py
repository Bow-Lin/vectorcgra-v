#!/usr/bin/env python3
"""Audit pinned Python without importing it. References are not test coverage."""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import warnings

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'sv/reference/current/inventory'
MAP = ROOT / 'sv/migration_tools/inventory_map.json'
# Related evidence is family-level and retains its original date/source hashes.
EVIDENCE = {
  'system': ['sv/reference/current/validation_m22.json', 'sv/reference/current/program_tools/validation.json'],
  'fu': ['sv/reference/current/validation.json', 'sv/reference/current/arithmetic_boundaries/validation.json'],
  'combo': ['sv/reference/current/arithmetic_boundaries/validation.json'],
  'fp': ['sv/reference/current/pe_interfaces/validation.json'],
  'vector': ['sv/reference/current/vector_arithmetic/validation.json'],
  'reduce': ['sv/reference/current/vector_reduce/validation.json'],
  'loop_controller': ['sv/reference/current/loop_controller_semantics/validation.json'],
  'memory': ['sv/reference/current/memory_boundaries/validation.json'],
  'peripheral': ['sv/reference/current/memory_boundaries/validation.json'],
  'data_memory': ['sv/reference/current/data_memory/validation.json'],
  'scalable_memory': ['sv/reference/current/data_memory_scalable/validation.json'],
  'queue': ['sv/reference/current/pipe_queue/validation.json'],
  'link': ['sv/reference/current/or_link/validation.json', 'sv/reference/current/selector/validation.json'],
  'noc': ['sv/reference/current/noc_handshakes/validation.json'],
  'static_memory': ['sv/reference/current/static_memory/validation.json'],
  'ring_memory': ['sv/reference/current/ring_ctrl_memory/validation.json'],
  'state': ['sv/reference/current/structure/validation.json'],
  'context': ['sv/reference/current/pe_interfaces/validation.json'],
  'pe': ['sv/reference/current/pe_interfaces/validation.json'],
  'streaming': ['sv/reference/current/validation.json'],
  'config': ['sv/reference/current/config_tools/validation.json'],
  'program': ['sv/reference/current/program_tools/validation.json'],
  'abi': ['sv/reference/current/program_tools/validation.json'],
  'reg_file': ['sv/reference/current/inventory/reg_file_validation.json'],
}

def sha(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()

def symbols(tree, prefix=''):
  result = []
  for node in ast.iter_child_nodes(tree):
    if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
      name = prefix + node.name
      result.append({'name': name, 'line': node.lineno, 'kind': type(node).__name__,
                     'scope': 'diagnostic_only' if node.name == 'line_trace' else 'see_file_contract'})
      result.extend(symbols(node, name + '.'))
    else:
      result.extend(symbols(node, prefix))
  return result

def constants(path, prefix):
  values = {}
  for node in ast.parse(path.read_text()).body:
    if not isinstance(node, ast.Assign) or len(node.targets) != 1 or not isinstance(node.targets[0], ast.Name):
      continue
    name = node.targets[0].id
    if not name.startswith(prefix):
      continue
    value = node.value
    if isinstance(value, ast.Call) and len(value.args) == 1:
      value = value.args[0]
    if isinstance(value, ast.Constant) and isinstance(value.value, int):
      values[name[len(prefix):]] = value.value
  return values

def is_test(p):
  return '/test/' in p or '_test.py' in p or '_test_from_' in p

def test_family(p):
  if p.startswith(('cgra/', 'multi_cgra/')): return 'system'
  if p.startswith('tile/'): return 'pe'
  if p.startswith('noc/'): return 'noc'
  if 'LoopController' in p: return 'loop_controller'
  if 'GlobalReduce' in p or 'VectorAllReduce' in p: return 'reduce'
  if '/vector/' in p: return 'vector'
  if '/float/' in p: return 'fp'
  if p.startswith('fu/'): return 'fu'
  if p.startswith('mem/'): return 'memory'
  return 'test'

def command_contract(value):
  if value in (1, 2, 9, 15, 16, 22):
    return 'Context host ingress only; Base/Streaming reject at tile ingress', ['sv/rtl/tile/variants/tile_variant_core.sv']
  if value in (0, 3, 4, 5, 6, 7, 8, 13):
    return 'Base/Context/Streaming host-to-tile configuration', ['sv/rtl/tile/tile_programmable.sv', 'sv/rtl/tile/variants/tile_variant_core.sv']
  if value in (10, 11, 12, 14):
    return 'Controller memory request/response or completion traffic; direction matters', ['sv/rtl/controller/cgra_controller.sv']
  if value in (17, 18, 19, 20, 21):
    return 'Global reduction request/count/response; configured participant count required', ['sv/rtl/controller/cgra_global_reduce.sv', 'sv/rtl/fu/vector/tile_vector_all_reduce.sv']
  if value in (23, 24, 25):
    return 'Streaming memory FU sideband; accepted by Context ingress but has no streaming FU there', ['sv/rtl/fu/streaming/tile_streaming_memory_fu.sv', 'sv/rtl/tile/variants/tile_variant_core.sv']
  if value in (26, 27, 31):
    return 'LoopCounter/ctrl-memory sideband only; no LoopController system routing', ['sv/rtl/fu/scalar/scalar_loop_counter.sv', 'sv/rtl/mem/ctrl_mem.sv']
  if value in (28, 29, 30):
    return 'Base host ingress + LoopCounter sideband; Context/Streaming ingress omits these commands', ['sv/rtl/tile/tile_programmable.sv', 'sv/rtl/fu/scalar/scalar_loop_counter.sv']
  if 32 <= value <= 42:
    return 'Standalone LoopController API; absent from integrated controller routing', ['sv/rtl/controller/cgra_loop_controller.sv']
  if value == 43:
    return 'GEP stride configuration routed in all three tile variants; Python controller omission corrected', ['sv/rtl/controller/cgra_controller.sv', 'sv/rtl/fu/scalar/scalar_gep.sv']
  if 44 <= value <= 51:
    return 'Integrated DMA/controller only; 32-bit SPM and whole-word lengths', ['sv/rtl/controller/cgra_controller.sv', 'sv/rtl/peripheral/cgra_dma_engine.sv']
  if 52 <= value <= 58:
    return 'Integrated im2col/controller only; native launch fence and restart contract', ['sv/rtl/controller/cgra_controller.sv', 'sv/rtl/peripheral/cgra_im2col_engine.sv']
  raise AssertionError(value)

def build():
  target = json.loads((ROOT / 'sv/reference/current/target.json').read_text())
  mapping = json.loads(MAP.read_text())
  sources = target['source_sha256']
  assert len(sources) == 274
  expected = {p for p in sources if not p.endswith('__init__.py') and not is_test(p)}
  assert set(mapping) == expected, (expected - mapping.keys(), mapping.keys() - expected)
  files, names_by_path = [], {}
  warnings.filterwarnings('ignore', category=SyntaxWarning)
  for p, digest in sorted(sources.items()):
    assert sha(ROOT / p) == digest, 'Pinned Python changed: ' + p
    tree = ast.parse((ROOT / p).read_text())
    names_by_path[p] = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}
    if p.endswith('__init__.py'):
      row = {'status': 'package_marker', 'targets': [], 'family': 'framework', 'notes': 'Python package initialization; no RTL API.'}
    elif is_test(p):
      row = {'status': 'original_test', 'targets': [], 'family': test_family(p), 'notes': 'Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly.'}
    else:
      row = mapping[p].copy()
    row.update(source=p, source_sha256=digest, symbols=symbols(tree),
               related_evidence=EVIDENCE.get(row['family'], []))
    for q in row['targets'] + row['related_evidence']:
      assert (ROOT / q).is_file(), q
    files.append(row)
  abi = json.loads((ROOT / 'sv/tools/abi.json').read_text())
  original = constants(ROOT / 'lib/opt_type.py', 'OPT_')
  commands = constants(ROOT / 'lib/cmd_type.py', 'CMD_')
  assert original == abi['opcodes'] and commands == abi['commands']
  native = abi['native_opcodes']
  for header, values in [('cgra_opcodes.svh', original), ('cgra_native_extensions.svh', native)]:
    definitions = {name: int(value) for name, value in re.findall(
      r"`define CGRA_OPT_(\w+) 7'd(\d+)",
      (ROOT / 'sv/rtl/common' / header).read_text())}
    assert definitions == values, 'SV opcode ABI mismatch: ' + header
  rtl = {str(p.relative_to(ROOT)): p.read_text() for p in (ROOT / 'sv/rtl').rglob('*.sv')}
  opcodes = []
  for name, value in sorted((original | native).items(), key=lambda x: x[1]):
    # Explicit numeric dispatch audit: these modules use localparams/literals.
    handlers = [p for p, text in rtl.items() if re.search(r'`CGRA_OPT_' + name + r'\b', text)]
    if name.startswith(('FADD', 'FSUB', 'FINC', 'FMUL')):
      handlers.append('sv/rtl/fu/float/tile_fp_fu.sv')
    if name.startswith('VEC_REDUCE_'):
      handlers.append('sv/rtl/fu/vector/tile_vector_all_reduce.sv')
    elif name.startswith(('VEC_ADD', 'VEC_SUB')):
      handlers.extend(['sv/rtl/fu/vector/cgra_vector_adder.sv', 'sv/rtl/fu/vector/tile_vector_adder_combo.sv'])
    elif name.startswith('VEC_MUL'):
      handlers.extend(['sv/rtl/fu/vector/cgra_vector_mul.sv', 'sv/rtl/fu/vector/tile_vector_mul_combo.sv'])
    py = [p for p in sources if 'OPT_' + name in names_by_path[p] and
          p in mapping and mapping[p]['status'] in ('rtl', 'integrated', 'bounded_factory')]
    if name in ('VEC_INC', 'VEC_INC_COMBINED', 'REM_CONST'):
      state = 'defined_only_in_both'; assert not handlers and not py
    elif name in ('AND_CONST', 'OR_CONST'):
      state = 'native_implementation_at_python_reserved_encoding'; assert handlers and not py
    elif name in native:
      state = 'native_encoding_extension'; assert handlers
    elif name == 'START':
      state = 'control_sentinel'
    else:
      state = 'implemented_in_selected_fu'; assert handlers, name
    evidence = sorted({q for p in py for q in EVIDENCE.get(mapping[p]['family'], [])})
    if name in native or name in ('AND_CONST', 'OR_CONST'):
      evidence = ['sv/reference/current/validation.json']
    opcodes.append({'name': name, 'encoding': value, 'status': state,
      'python_hardware_references': sorted(py), 'sv_dispatch_or_control_references': sorted(set(handlers)),
      'related_evidence': evidence,
      'test_coverage_claim': 'none_from_reference_scan; inspect individual run/scenario evidence'})
  cmds = []
  for name, value in sorted(commands.items(), key=lambda x: x[1]):
    scope, targets = command_contract(value)
    cmds.append({'name': name, 'encoding': value, 'scope': scope, 'targets': targets})
  return {'schema': 1, 'python_target': target['python_target_commit'],
    'original_baseline': target['original_migration_baseline'],
    'counts': {'classified_files': len(files), 'categories': dict(sorted(Counter(x['status'] for x in files).items())),
               'symbols': sum(len(x['symbols']) for x in files), 'original_opcodes': len(original),
               'native_opcodes': len(native), 'commands': len(commands)},
    'coverage_meaning': 'Inventory completeness only. No percentage of behavioral correctness or original-test pass rate is inferred.',
    'files': files, 'opcodes': opcodes, 'commands': cmds}

def markdown(data):
  lines = ['# Python → SV 完整映射清单', '',
    '由 `migration_tools/inventory.py` 生成。每个源文件的 SHA 和全部类／函数／方法（含更新块）见同目录 `inventory.json`。',
    '这是一份分类和实现位置清单，不是“274 个文件全部功能等价”或原 Python 测试通过率。证据链接保留各自批次；必须检查其参数、模式及源码 SHA。', '',
    '## 文件', '', '| Python 文件 | 类别 | 对应实现／工具 | 边界 |', '|---|---|---|---|']
  for r in data['files']:
    lines.append('| `' + r['source'] + '` | ' + r['status'] + ' | ' + '<br>'.join('`'+p+'`' for p in r['targets']) + ' | ' + r['notes'] + ' |')
  lines += ['', '## Opcode', '', '下列位置是 dispatch／控制引用，不等于每个 opcode 已完成独立数学或逐周期验证。实际支持还取决于 PE 的 FU catalog。', '',
    '| Opcode | 编码 | 状态 | SV 位置 |', '|---|---:|---|---|']
  for r in data['opcodes']:
    lines.append('| '+r['name']+' | '+str(r['encoding'])+' | '+r['status']+' | '+'<br>'.join('`'+p+'`' for p in r['sv_dispatch_or_control_references'])+' |')
  lines += ['', '## 命令与可达性', '', '能打包不代表任意顶层可处理。组件侧端口支持与 CPU → Controller → Tile 路由分开判断。', '',
    '| Command | 编码 | 范围 |', '|---|---:|---|']
  for r in data['commands']:
    lines.append('| '+r['name']+' | '+str(r['encoding'])+' | '+r['scope']+' |')
  return '\n'.join(lines)+'\n'

def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--check', action='store_true')
  args = parser.parse_args()
  data = build()
  outputs = {'inventory.json': json.dumps(data, indent=2, ensure_ascii=False)+'\n', 'inventory.md': markdown(data)}
  if args.check:
    for name, content in outputs.items():
      assert (DEST / name).read_text() == content, 'Stale inventory: '+name
  else:
    DEST.mkdir(parents=True, exist_ok=True)
    for name, content in outputs.items(): (DEST / name).write_text(content)
  print('MIGRATION_INVENTORY_PASS '+json.dumps(data['counts'], sort_keys=True))

if __name__ == '__main__':
  main()
