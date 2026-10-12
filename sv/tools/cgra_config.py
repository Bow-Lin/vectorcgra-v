#!/usr/bin/env python3
"""Validate JSON architectures and emit parameters for maintained CGRA RTL.

Only Python's standard library is used. This is a static table packer, not a
mapper or an RTL generator. Index zero always occupies the least significant
packed slice. FU slot order is explicit and is never sorted or deduplicated.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

SCHEMA = 1
UNUSED = 0xffffffff
FU_NAMES = (
  'ADDER MUL MEM NAH CONST COMP LOGIC SHIFTER SEL PHI GRANT GEP '
  'EXTRACT_PREDICATE RET LOOP_COUNTER LOOP_CONTROL DIV INCLUSIVE_DIV '
  'EXCLUSIVE_DIV VECTOR_ADDER VECTOR_MUL VECTOR_REDUCE SEQ_MUL_ADDER '
  'SEQ_MUL_SHIFTER PRL_MUL_ADDER THREE_MUL_ADDER_SHIFTER '
  'FOUR_INC_CMP_NOT_GRANT ALU_GEN_MAC FP_ADD FP_MUL').split()
FU_KINDS = {name: i for i, name in enumerate(FU_NAMES)}
FU_KINDS['STREAMING_MEM'] = 32
PYTHON_NAMES = dict(zip((
  'AdderRTL MulRTL MemUnitRTL NahRTL ConstRTL CompRTL LogicRTL ShifterRTL '
  'SelRTL PhiRTL GrantRTL GepRTL ExtractPredicateRTL RetRTL LoopCounterRTL '
  'LoopControlRTL DivRTL InclusiveDivRTL ExclusiveDivRTL VectorAdderComboRTL '
  'VectorMulComboRTL VectorAllReduceRTL SeqMulAdderRTL SeqMulShifterRTL '
  'PrlMulAdderRTL ThreeMulAdderShifterRTL FourIncCmpNotGrantRTL AluGenMacRTL '
  'FpAddRTL FpMulRTL').split(), FU_NAMES))
PYTHON_NAMES['StreamingMemUnitRTL'] = 'STREAMING_MEM'
PYTHON_NAMES['AluGenMacWrapperRTL'] = 'ALU_GEN_MAC'
DEFAULTS = dict(DATA_W=32, TILE_PORTS=4, CTRL_DEPTH=8, REG_DEPTH=16,
        BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8,
        TOTAL_STEPS=8, MULTI_COLS=1, MULTI_ROWS=1, HAS_DMA=0,
        HAS_IM2COL=0, MEM_COMBINATIONAL=1, MEMORY_LEGACY_PYTHON=0,
        NOC_LEGACY_PYTHON=0, VECTOR_LANES=4, VECTOR_FACTOR_POWER=0,
        FP_EXP_W=8, FP_SIG_W=23, FP_LEGACY_PYTHON=0,
        REDUCE_LEGACY_PYTHON=0, VECTOR_LEGACY_PYTHON=0,
        ARITH_LEGACY_PYTHON=0)
GEOMETRY = {'COLS', 'ROWS', 'MAX_COLS', 'MAX_ROWS', 'MEM_PORTS',
      'MEM_WRITE_PORTS', 'MAX_MEM_PORTS', 'FU_COUNT'}
BITS = {'HAS_DMA', 'HAS_IM2COL', 'MEM_COMBINATIONAL'} | {
  k for k in DEFAULTS if k.endswith('_LEGACY_PYTHON')}


class ConfigError(ValueError):
  pass


def require(condition, message):
  if not condition:
    raise ConfigError(message)


def integer(value, where, minimum=0, maximum=0x7fffffff):
  require(type(value) is int and minimum <= value <= maximum,
      f'{where}: expected integer in [{minimum}, {maximum}]')
  return value


def keys(value, allowed, where):
  require(isinstance(value, dict), f'{where}: expected object')
  require(not (value.keys() - allowed),
      f'{where}: unknown keys {sorted(value.keys() - allowed)}')


def clog2(value):
  return (value - 1).bit_length()


def packed(values, width):
  result = 0
  for i, value in enumerate(values):
    integer(value, f'packed[{i}]', 0, (1 << width) - 1)
    result |= value << (i * width)
  return result


def profile_widths(p):
  """Widths of the public cgra_profile_defs.svh parameter family."""
  d = dict(NUM_TILES=p['COLS'] * p['ROWS'],
      MAX_TILES=p['MAX_COLS'] * p['MAX_ROWS'],
      NUM_CGRAS=p['MULTI_COLS'] * p['MULTI_ROWS'])
  d.update(CGRA_ID_W=max(1, clog2(d['NUM_CGRAS'])),
      CGRA_X_W=max(1, clog2(p['MULTI_COLS'])),
      CGRA_Y_W=max(1, clog2(p['MULTI_ROWS'])),
      TILE_ID_W=clog2(d['MAX_TILES'] + 1),
      CTRL_ADDR_W=clog2(p['CTRL_DEPTH']), REG_ADDR_W=clog2(p['REG_DEPTH']),
      BANK_ADDR_W=clog2(p['BANK_DEPTH']), MEM_PORT_W=clog2(p['MAX_MEM_PORTS'] + 1),
      XBAR_MEM_PORTS=p['MEM_PORTS'] + 1 + p['HAS_DMA'],
      XBAR_WR_MEM_PORTS=p['MEM_WRITE_PORTS'] + 1 + p['HAS_DMA'],
      BANK_PORT_W=clog2(p['NUM_BANKS'] + 1), DATA_BITS=p['DATA_W'] + 3,
      ROUTING_OUTPUTS=p['TILE_PORTS'] + 4,
      ROUTING_SEL_W=clog2(p['TILE_PORTS'] + 5))
  d['XBAR_MEM_PORT_W'] = clog2(d['XBAR_MEM_PORTS'])
  d['XBAR_WR_MEM_PORT_W'] = clog2(d['XBAR_WR_MEM_PORTS'])
  d['CTRL_BITS'] = 39 + d['ROUTING_OUTPUTS'] * (d['ROUTING_SEL_W'] + 2) + 8 * d['REG_ADDR_W']
  d['PAYLOAD_BITS'] = 6 + d['DATA_BITS'] + p['GLOBAL_ADDR_W'] + d['CTRL_BITS'] + d['CTRL_ADDR_W']
  d['HOST_DST_LSB'] = d['PAYLOAD_BITS'] + 9 + 2 * (d['CGRA_ID_W'] + d['CGRA_X_W'] + d['CGRA_Y_W'])
  d['HOST_BITS'] = 2 * d['TILE_ID_W'] + d['HOST_DST_LSB']
  d['NOC_BITS'] = d['HOST_BITS'] + 1 + d['MEM_PORT_W']
  d['MEM_BITS'] = d['XBAR_MEM_PORT_W'] + d['MEM_PORT_W'] + d['BANK_PORT_W'] + p['GLOBAL_ADDR_W'] + d['DATA_BITS'] + d['CGRA_ID_W'] + d['TILE_ID_W']
  d['WR_MEM_BITS'] = d['MEM_BITS'] - d['XBAR_MEM_PORT_W'] + d['XBAR_WR_MEM_PORT_W']
  return d


def catalog(names, p, variant, where):
  require(isinstance(names, list) and names, f'{where}: nonempty ordered FU list required')
  out = []
  for name in names:
    require(isinstance(name, str), f'{where}: FU names must be strings')
    name = PYTHON_NAMES.get(name, name)
    require(name in FU_KINDS, f'{where}: unknown FU {name!r}')
    out.append(name)
  require(out.count('NAH') == 1, f'{where}: exactly one NAH is required')
  memory = 'STREAMING_MEM' if variant == 'streaming' else 'MEM'
  wrong = 'MEM' if variant == 'streaming' else 'STREAMING_MEM'
  require(wrong not in out, f'{where}: {wrong} is incompatible with {variant}')
  require(out.count(memory) <= 1, f'{where}: only one attached memory FU is supported')
  for name in out:
    if name.startswith('VECTOR_'):
      lanes = p['VECTOR_LANES']
      require(lanes >= 1 and p['DATA_W'] % lanes == 0, f'{where}: vector lanes must divide DATA_W')
      if name in {'VECTOR_MUL', 'VECTOR_REDUCE'}:
        require(lanes % 4 == 0, f'{where}: {name} requires a multiple of four lanes')
      if name == 'VECTOR_MUL' and not p['VECTOR_LEGACY_PYTHON']:
        require(lanes == 4, f'{where}: native VECTOR_MUL supports exactly four lanes')
    if name in {'FP_ADD', 'FP_MUL'}:
      require(p['DATA_W'] == 1 + p['FP_EXP_W'] + p['FP_SIG_W'], f'{where}: FP format does not match DATA_W')
      require(p['FP_EXP_W'] >= 2 and p['FP_SIG_W'] >= 3, f'{where}: unsupported HardFloat format')
  return out


def regular_links(cols, rows, ports):
  directions = [(0, 1, 1), (0, -1, 0), (-1, 0, 3), (1, 0, 2),
         (-1, 1, 6), (1, 1, 7), (1, -1, 4), (-1, -1, 5)]
  links = []
  for src in range(cols * rows):
    x, y = src % cols, src // cols
    for sp, (dx, dy, dp) in enumerate(directions[:ports]):
      if 0 <= x + dx < cols and 0 <= y + dy < rows:
        links.append(dict(src=src, dst=(y + dy) * cols + x + dx,
                 sp=sp, dp=dp, enabled=1))
  return links


def exterior_mask(t, cols, rows):
  x, y = t % cols, t // cols
  return (int(y == rows - 1) | (int(y == 0) << 1) |
      (int(x == 0) << 2) | (int(x == cols - 1) << 3))


def normalize(document):
  keys(document, {'schema', 'top', 'topology', 'variant', 'parameters',
          'default_fus', 'architectures', 'address_map'}, 'config')
  require(type(document.get('schema')) is int and document['schema'] == SCHEMA,
      'schema: expected version 1')
  top = document.get('top', 'system')
  variant = document.get('variant', 'base')
  topology = document.get('topology', 'mesh')
  require(isinstance(top, str) and top in {'system', 'multi'}, 'top: expected system or multi')
  require(isinstance(variant, str) and variant in {'base', 'context', 'streaming'}, 'variant: expected base, context or streaming')
  require(isinstance(topology, str) and topology in {'mesh', 'ring'}, 'topology: expected mesh or ring')
  require(top == 'multi' or topology == 'mesh', 'topology applies to multi; system uses its local control ring')
  raw = document.get('parameters', {})
  keys(raw, set(DEFAULTS) | GEOMETRY, 'parameters')
  p = dict(DEFAULTS, **raw)
  for key, value in p.items():
    integer(value, f'parameters.{key}', 0, 1 if key in BITS else 0x7fffffff)
  require(p['MULTI_COLS'] >= 1 and p['MULTI_ROWS'] >= 1, 'multi dimensions must be positive')
  count = p['MULTI_COLS'] * p['MULTI_ROWS']
  architectures = document.get('architectures')
  require(isinstance(architectures, list) and len(architectures) == count,
      'architectures count must equal MULTI_COLS * MULTI_ROWS')
  require(top != 'system' or count == 1, 'system configuration requires one CGRA')
  if top == 'multi':
    require((topology == 'mesh' and p['MULTI_COLS'] >= 2 and p['MULTI_ROWS'] >= 2) or
        (topology == 'ring' and p['MULTI_COLS'] >= 2 and p['MULTI_ROWS'] == 1),
        'multi Mesh requires >=2 rows/columns; Ring requires one row and >=2 nodes')
    require(not p['HAS_DMA'] and not p['HAS_IM2COL'], 'multi top has no peripheral ports')
  require(p['TILE_PORTS'] in {4, 8}, 'TILE_PORTS must be 4 or 8')
  require(variant != 'streaming' or p['TILE_PORTS'] == 8, 'streaming requires eight ports')
  require(1 <= p['GLOBAL_ADDR_W'] <= 32 and p['DATA_W'] >= max(11, p['GLOBAL_ADDR_W']), 'unsupported payload/address widths')
  require(p['CTRL_DEPTH'] >= 2 and 1 <= p['NUM_CTRL'] <= p['CTRL_DEPTH'], 'invalid control storage/count')
  require(p['REG_DEPTH'] >= 2 and p['TOTAL_STEPS'] <= 2047, 'invalid register depth or total steps')
  for key, minimum in [('NUM_BANKS', 1), ('BANK_DEPTH', 2)]:
    require(p[key] >= minimum and p[key] & (p[key] - 1) == 0, f'{key} must be a power of two >= {minimum}')
  require(count * p['NUM_BANKS'] * p['BANK_DEPTH'] <= 1 << p['GLOBAL_ADDR_W'], 'global address width cannot contain all memory windows')
  require(not p['HAS_DMA'] or p['DATA_W'] == 32, 'integrated DMA requires 32-bit words')
  require(p['VECTOR_FACTOR_POWER'] == 0, 'composed FU clusters require VECTOR_FACTOR_POWER=0')
  default_fus = document.get('default_fus', ['ADDER', 'MUL', 'STREAMING_MEM' if variant == 'streaming' else 'MEM', 'NAH'])
  default_fus = catalog(default_fus, p, variant, 'default_fus')
  result = []
  for ci, a in enumerate(architectures):
    where = f'architectures[{ci}]'
    keys(a, {'size', 'cols', 'rows', 'links', 'read_ports', 'write_ports',
        'boundary_in', 'boundary_out', 'fu_names'}, where)
    require('size' not in a or ('cols' not in a and 'rows' not in a), f'{where}: use size or cols/rows')
    cols = integer(a.get('cols', a.get('size')), where + '.cols', 2)
    rows = integer(a.get('rows', a.get('size')), where + '.rows', 2)
    tiles = cols * rows
    fu_lists = a.get('fu_names', [default_fus] * tiles)
    require(isinstance(fu_lists, list) and len(fu_lists) == tiles, f'{where}: fu_names must name every tile')
    fus = [catalog(fs, p, variant, f'{where}.fu_names[{t}]') for t, fs in enumerate(fu_lists)]
    links = a.get('links', regular_links(cols, rows, p['TILE_PORTS']))
    require(isinstance(links, list), f'{where}.links: expected list')
    edges = []; used_src = set(); used_dst = set()
    for li, link in enumerate(links):
      loc = f'{where}.links[{li}]'
      keys(link, {'src', 'dst', 'sp', 'dp', 'enabled'}, loc)
      edge = {k: integer(link.get(k), loc + '.' + k, 0,
          tiles - 1 if k in {'src', 'dst'} else p['TILE_PORTS'] - 1)
          for k in ['src', 'dst', 'sp', 'dp']}
      edge['enabled'] = integer(link.get('enabled', 1), loc + '.enabled', 0, 1)
      if edge['enabled']:
        source = (edge['src'], edge['sp']); dest = (edge['dst'], edge['dp'])
        require(source not in used_src and dest not in used_dst, f'{loc}: multiple links share a physical port')
        used_src.add(source); used_dst.add(dest)
      edges.append(edge)
    boundaries = {}
    for name, used in [('boundary_in', used_dst), ('boundary_out', used_src)]:
      masks = a.get(name, [exterior_mask(t, cols, rows) for t in range(tiles)])
      require(isinstance(masks, list) and len(masks) >= tiles, f'{where}.{name}: one mask per tile required')
      normalized = []
      for t, mask in enumerate(masks):
        integer(mask, f'{where}.{name}[{t}]', 0, (1 << p['TILE_PORTS']) - 1)
        require(t < tiles or mask == 0, f'{where}.{name}: padding must be zero')
        if t < tiles:
          require(mask & ~exterior_mask(t, cols, rows) == 0, f'{where}.{name}: boundary must be exterior cardinal port')
          require(all(not (mask & (1 << d)) or (t, d) not in used for d in range(p['TILE_PORTS'])), f'{where}.{name}: boundary and internal link share a port')
          normalized.append(mask)
      boundaries[name] = normalized
    ports = {}
    regular_memory = [y * cols for y in range(rows)] + list(range(1, cols))
    for name in ['read_ports', 'write_ports']:
      entries = a.get(name, regular_memory)
      require(isinstance(entries, list), f'{where}.{name}: expected list')
      seen = set(); normalized = []
      for entry in entries:
        entry = UNUSED if entry is None else integer(entry, f'{where}.{name}', 0, UNUSED)
        require(entry == UNUSED or entry < tiles, f'{where}.{name}: tile out of range')
        require(entry == UNUSED or entry not in seen, f'{where}.{name}: tile has multiple memory ports')
        seen.add(entry); normalized.append(entry)
      ports[name] = normalized
    result.append(dict(cols=cols, rows=rows, fu_names=fus, links=edges, **boundaries, **ports))
  max_cols = max(a['cols'] for a in result); max_rows = max(a['rows'] for a in result)
  for key, value in [('COLS', max_cols), ('ROWS', max_rows)]:
    require(key not in raw or raw[key] == value, f'{key} must match largest declared architecture')
    p[key] = value
  p.setdefault('MAX_COLS', max_cols); p.setdefault('MAX_ROWS', max_rows)
  require(p['MAX_COLS'] >= max_cols and p['MAX_ROWS'] >= max_rows, 'shared geometry is smaller than a CGRA')
  for name, param in [('read_ports', 'MEM_PORTS'), ('write_ports', 'MEM_WRITE_PORTS')]:
    needed = max(len(a[name]) for a in result)
    p.setdefault(param, max(1, needed))
    require(p[param] >= max(1, needed), f'{param} is smaller than explicit port tables')
    for a in result:
      a[name] += [UNUSED] * (p[param] - len(a[name]))
  p.setdefault('MAX_MEM_PORTS', p['MEM_PORTS'])
  require(p['MAX_MEM_PORTS'] >= p['MEM_PORTS'], 'MAX_MEM_PORTS is too small')
  needed = max(len(fs) for a in result for fs in a['fu_names'])
  p.setdefault('FU_COUNT', needed)
  require(p['FU_COUNT'] >= needed, 'FU_COUNT is smaller than a tile catalog')
  mapping = document.get('address_map', list(range(count)))
  require(isinstance(mapping, list) and len(mapping) == count, 'address_map: one CGRA ID per window required')
  for entry in mapping:
    integer(entry, 'address_map', 0, count - 1)
  require(sorted(mapping) == list(range(count)), 'address_map must be a permutation of all CGRA IDs')
  return dict(schema=SCHEMA, top=top, topology=topology, variant=variant,
        parameters=p, widths=profile_widths(p), architectures=result, address_map=mapping)


def emit(config):
  p = config['parameters']; d = config['widths']; aa = config['architectures']
  count = len(aa); tiles = d['MAX_TILES']; slots = p['FU_COUNT']
  links = max(1, max(len(a['links']) for a in aa))
  lines = ['// Generated static parameters; element zero is the least significant slice.']
  for name, value in sorted(dict(p, **d).items()):
    lines.append(f'localparam int CFG_{name}={value};')
  lines += [f'localparam int ARCH_LINKS={links};']
  def array(name, values, width):
    lines.append(f"localparam logic [{count-1}:0][{width-1}:0] {name}={count*width}'h{packed(values, width):x};")
  array('ARCH_COLS', [a['cols'] for a in aa], 32)
  array('ARCH_ROWS', [a['rows'] for a in aa], 32)
  if all(a['cols'] == a['rows'] for a in aa):
    array('ARCH_SIZES', [a['cols'] for a in aa], 32)
  array('ARCH_COUNTS', [packed([len(fs) for fs in a['fu_names']], 32) for a in aa], tiles * 32)
  array('ARCH_FUS', [packed([packed([FU_KINDS[n] for n in fs], 8) for fs in a['fu_names']], slots * 8) for a in aa], tiles * slots * 8)
  for key, name in [('src', 'SRC_TILE'), ('sp', 'SRC_PORT'), ('dst', 'DST_TILE'), ('dp', 'DST_PORT')]:
    array('ARCH_' + name, [packed([link[key] for link in a['links']], 32) for a in aa], links * 32)
  array('ARCH_ENABLED', [packed([link['enabled'] for link in a['links']], 1) for a in aa], links)
  for key, name, width, length in [('read_ports', 'READ', 32, p['MEM_PORTS']),
                  ('write_ports', 'WRITE', 32, p['MEM_WRITE_PORTS']),
                  ('boundary_in', 'BIN', p['TILE_PORTS'], tiles),
                  ('boundary_out', 'BOUT', p['TILE_PORTS'], tiles)]:
    array('ARCH_' + name, [packed(a[key], width) for a in aa], width * length)
  lines.append(f"localparam logic [{count*d['CGRA_ID_W']-1}:0] ARCH_ADDR_MAP={count*d['CGRA_ID_W']}'h{packed(config['address_map'], d['CGRA_ID_W']):x};")
  bindings = [f'.{name}(CFG_{name})' for name in sorted(p)]
  bindings += [f'.TILE_VARIANT({["base", "context", "streaming"].index(config["variant"])})',
        '.CUSTOM_ADDR_MAP(1)', '.ADDR_MAP(ARCH_ADDR_MAP)', '.CUSTOM_TOPOLOGY(\'1)', '.LINK_COUNT(ARCH_LINKS)']
  if config['top'] == 'multi':
    bindings += [f'.TOPOLOGY({int(config["topology"] == "ring")})', '.CGRA_COLS(ARCH_COLS)', '.CGRA_ROWS(ARCH_ROWS)']
  for param, name in [('TILE_FU_COUNTS', 'COUNTS'), ('TILE_FU_KINDS', 'FUS'),
            ('LINK_SRC_TILE', 'SRC_TILE'), ('LINK_SRC_PORT', 'SRC_PORT'),
            ('LINK_DST_TILE', 'DST_TILE'), ('LINK_DST_PORT', 'DST_PORT'),
            ('LINK_ENABLED', 'ENABLED'), ('READ_PORT_TILE', 'READ'),
            ('WRITE_PORT_TILE', 'WRITE'), ('BOUNDARY_IN_ENABLE', 'BIN'),
            ('BOUNDARY_OUT_ENABLE', 'BOUT')]:
    suffix = '[0]' if config['top'] == 'system' else ''
    if config['top'] == 'system' and name in {'COUNTS', 'FUS', 'BIN', 'BOUT'}:
      # System tables use local NUM_TILES, potentially smaller than MAX_TILES.
      stride = {'COUNTS': 32, 'FUS': slots * 8, 'BIN': p['TILE_PORTS'], 'BOUT': p['TILE_PORTS']}[name]
      suffix += f'[{d["NUM_TILES"] * stride - 1}:0]'
    bindings.append(f'.{param}(ARCH_{name}{suffix})')
  return {'architecture.svh': '\n'.join(lines) + '\n',
      'bindings.svh': '// Include inside cgra_system/cgra_multi_template #(...).\n' + ',\n'.join(bindings) + '\n'}


def load_json(path):
  def unique(pairs):
    result = {}
    for k, v in pairs:
      require(k not in result, f'duplicate JSON key: {k}')
      result[k] = v
    return result
  return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=unique)


def main(argv=None):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('config', type=Path)
  parser.add_argument('--output', type=Path, help='fresh output directory (required unless --check)')
  parser.add_argument('--check', action='store_true', help='validate without writing')
  args = parser.parse_args(argv)
  try:
    config = normalize(load_json(args.config))
    outputs = emit(config)
    if not args.check:
      require(args.output is not None, '--output is required unless --check')
      require(not args.output.exists(), 'output directory already exists; choose a fresh directory')
      # Finish validation/packing before creating any output files.
      digest = lambda data: hashlib.sha256(data).hexdigest()
      config['input_sha256'] = digest(args.config.read_bytes())
      config['tool_sha256'] = digest(Path(__file__).read_bytes())
      config['output_sha256'] = {name: digest(text.encode()) for name, text in outputs.items()}
      args.output.mkdir(parents=True)
      for name, text in outputs.items():
        (args.output / name).write_text(text, encoding='utf-8')
      (args.output / 'manifest.json').write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
    print(f'CGRA_CONFIG_PASS top={config["top"]} cgras={len(config["architectures"])} host_bits={config["widths"]["HOST_BITS"]}')
  except (ConfigError, OSError, json.JSONDecodeError) as error:
    parser.exit(2, f'CGRA_CONFIG_ERROR: {error}\n')


if __name__ == '__main__':
  main()
