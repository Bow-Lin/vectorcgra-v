#!/usr/bin/env python3
"""Pack explicit control words and ordered host programs using only the standard library."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
# Explicit sibling loading also works under python -I -S; no project path setup.
spec = importlib.util.spec_from_file_location('cgra_config', HERE / 'cgra_config.py')
configuration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configuration)
ConfigError = configuration.ConfigError
require = configuration.require
keys = configuration.keys
integer = configuration.integer
ABI = configuration.load_json(HERE / 'abi.json')
COMMANDS = dict(ABI['commands'], **ABI.get('native_commands', {}))
OPCODES = dict(ABI['opcodes'], **ABI['native_opcodes'])


def number(value, where):
  if isinstance(value, str):
    require(re.fullmatch(r'-?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+)', value),
            f'{where}: expected integer or hexadecimal/binary bit pattern')
    negative = value.startswith('-')
    digits = value[1:] if negative else value
    value = int(digits, 0 if digits.lower().startswith(('0x', '0b')) else 10) * (-1 if negative else 1)
  require(type(value) is int, f'{where}: expected integer')
  return value


def enum(value, names, prefix, where):
  if isinstance(value, str) and not re.fullmatch(r'-?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+)', value):
    value = value.removeprefix(prefix)
    require(value in names, f'{where}: unknown symbol {value!r}')
    return names[value]
  return number(value, where)


def width(node):
  if isinstance(node, int):
    return node
  if isinstance(node, tuple):
    return node[0] * node[1]
  return sum(width(child) for child in node.values())


def layouts(config):
  p = config['parameters']; d = config['widths']
  data = dict(payload=p['DATA_W'], predicate=1, bypass=1, delay=1)
  ctrl = dict(operation=7, fu_in=(3, 4),
              routing_xbar_outport=(d['ROUTING_SEL_W'], d['ROUTING_OUTPUTS']),
              fu_xbar_outport=(2, d['ROUTING_OUTPUTS']), vector_factor_power=3,
              is_last_ctrl=1, write_reg_from=(2, 4), write_reg_idx=(d['REG_ADDR_W'], 4),
              read_reg_towards=(2, 4), read_reg_idx=(d['REG_ADDR_W'], 4))
  payload = dict(cmd=6, data=data, data_addr=p['GLOBAL_ADDR_W'], ctrl=ctrl, ctrl_addr=d['CTRL_ADDR_W'])
  host = dict(src=d['TILE_ID_W'], dst=d['TILE_ID_W'],
              src_cgra_id=d['CGRA_ID_W'], dst_cgra_id=d['CGRA_ID_W'],
              src_cgra_x=d['CGRA_X_W'], src_cgra_y=d['CGRA_Y_W'],
              dst_cgra_x=d['CGRA_X_W'], dst_cgra_y=d['CGRA_Y_W'],
              opaque=8, vc_id=1, payload=payload)
  noc = dict(src=d['CGRA_ID_W'], dst=d['CGRA_ID_W'], src_x=d['CGRA_X_W'], src_y=d['CGRA_Y_W'],
             dst_x=d['CGRA_X_W'], dst_y=d['CGRA_Y_W'], src_tile_id=d['TILE_ID_W'], dst_tile_id=d['TILE_ID_W'],
             remote_src_port=d['MEM_PORT_W'], opaque=8, vc_id=2, payload=payload)
  result = dict(data=data, ctrl=ctrl, payload=payload, host=host, noc=noc)
  for name, expected in [('data', 'DATA_BITS'), ('ctrl', 'CTRL_BITS'), ('payload', 'PAYLOAD_BITS'), ('host', 'HOST_BITS'), ('noc', 'NOC_BITS')]:
    require(width(result[name]) == d[expected], f'internal layout width mismatch: {name}')
  return result


def pack(node, value, where=''):
  if isinstance(node, int):
    if where.endswith('operation'):
      value = enum(value, OPCODES, 'OPT_', where)
    elif where.endswith('.cmd') or where == 'cmd':
      value = enum(value, COMMANDS, 'CMD_', where)
    else:
      value = number(value, where)
    signed = where == 'payload' or where.endswith('data.payload')
    minimum = -(1 << (node - 1)) if signed else 0
    require(minimum <= value < 1 << node, f'{where}: value does not fit {node} bits')
    return value & ((1 << node) - 1)
  if isinstance(node, tuple):
    bits, count = node
    if isinstance(value, dict):
      entries = [0] * count
      for index, entry in value.items():
        require(isinstance(index, str) and re.fullmatch(r'0|[1-9][0-9]*', index), f'{where}: sparse array indices must be decimal strings')
        idx = integer(int(index), where + '.index', 0, count - 1)
        entries[idx] = entry
    else:
      require(isinstance(value, list) and len(value) == count, f'{where}: expected {count} array elements')
      entries = value
    return sum(pack(bits, entry, f'{where}[{i}]') << (bits * i) for i, entry in enumerate(entries))
  keys(value, set(node), where or 'packet')
  result = 0
  for name, child in node.items():
    default = {} if isinstance(child, (dict, tuple)) else 0
    result = (result << width(child)) | pack(child, value.get(name, default), f'{where}.{name}' if where else name)
  return result


def unpack(node, value):
  if isinstance(node, int):
    return value
  if isinstance(node, tuple):
    bits, count = node
    return [(value >> (i * bits)) & ((1 << bits) - 1) for i in range(count)]
  result = {}; remaining = width(node)
  for name, child in node.items():
    remaining -= width(child)
    result[name] = unpack(child, (value >> remaining) & ((1 << width(child)) - 1))
  return result


def layout_fields(node, prefix='', offset=0):
  if isinstance(node, int):
    return [dict(field=prefix, lsb=offset, msb=offset + node - 1, nbits=node)]
  if isinstance(node, tuple):
    bits, count = node
    return [field for i in range(count) for field in layout_fields(bits, f'{prefix}[{i}]', offset + i * bits)]
  result = []; remaining = width(node)
  for name, child in node.items():
    remaining -= width(child)
    result.extend(layout_fields(child, f'{prefix}.{name}' if prefix else name, offset + remaining))
  return result


def target(config, cgra, tile):
  cgra = integer(cgra, 'cgra', 0, len(config['architectures']) - 1)
  architecture = config['architectures'][cgra]
  tile = integer(tile, 'tile', 0, architecture['cols'] * architecture['rows'] - 1)
  return cgra, tile


def data_value(value, predicate=1):
  return value if isinstance(value, dict) else dict(payload=value, predicate=predicate)


def host_command(config, command, cgra=0, tile=0, data=None, address=0, control=None, pc=0):
  cgra, tile = target(config, cgra, tile)
  cmd = enum(command, COMMANDS, 'CMD_', 'cmd')
  require(cmd in COMMANDS.values(), 'command: undefined command number')
  return dict(dst_cgra_id=cgra, dst=tile, payload=dict(cmd=cmd, data={} if data is None else data,
              data_addr=address, ctrl={} if control is None else control, ctrl_addr=pc))


def program_control(config, schema, word):
  # Check an instruction's usable selectors separately from raw wire packing.
  encoded = pack(schema, word, 'ctrl')
  decoded = unpack(schema, encoded)
  require(decoded['operation'] in OPCODES.values(), 'program operation is undefined')
  p = config['parameters']
  route_inputs = p['TILE_PORTS'] + (0 if config['variant'] == 'streaming' else 4)
  require(all(v <= 4 for v in decoded['fu_in']), 'fu_in selector exceeds four FU inputs')
  require(all(v <= route_inputs for v in decoded['routing_xbar_outport']), 'routing selector exceeds available inputs')
  require(all(v <= 2 for v in decoded['fu_xbar_outport']), 'FU crossbar selector exceeds two FU outputs')
  for name in ['write_reg_idx', 'read_reg_idx']:
    require(all(v < p['REG_DEPTH'] for v in decoded[name]), f'{name}: register index exceeds depth')
  if config['variant'] == 'streaming':
    require(all(v < 2 for v in decoded['read_reg_towards']), 'streaming PE has no register-to-routing path')
  return decoded


def multicast_packets(config, tiles, pc, control):
  """Explicit CONFIG-only multicast; mask data is sent over the host ABI."""
  p=config['parameters'];n=config['widths']['NUM_TILES']
  require(p.get('CTRL_NETWORK',0)!=0 and p.get('CTRL_MULTICAST',0)==1,
      'CONFIG multicast requires dedicated CTRL_NETWORK and CTRL_MULTICAST=1')
  require(isinstance(tiles,list) and tiles, 'multicast tiles: nonempty list required')
  for tile in tiles:target(config,0,tile)
  require(len(set(tiles))==len(tiles), 'multicast tiles must be unique')
  integer(pc,'multicast control address',0,p['CTRL_DEPTH']-1)
  mask=sum(1<<tile for tile in tiles);bits=p['DATA_W']
  packets=[host_command(config,'CTRL_MASK_WORD',data=data_value((mask>>(i*bits))&((1<<bits)-1),0),address=i)
      for i in range((n+bits-1)//bits)]
  packets.append(host_command(config,'CONFIG_MULTICAST',control=control,pc=pc))
  return packets


def config_batch(config,writes,defaults,multicast):
  """Merge only this explicit phase; select matching heads of per-PE FIFOs.

  No constant, launch, barrier, or other ordered command can occur inside it.
  Every emitted group removes at most one head per PE, including overwrites.
  """
  require(isinstance(writes,list) and writes, 'config_batch.writes: nonempty list required')
  require(type(multicast) is bool, 'config_batch.multicast: expected boolean')
  types=layouts(config);queues={};original=[]
  for i,w in enumerate(writes):
    keys(w,{'tile','address','ctrl'},'config_batch write')
    _,tile=target(config,0,w.get('tile'))
    pc=integer(w.get('address'),'config_batch address',0,config['parameters']['CTRL_DEPTH']-1)
    keys(w.get('ctrl'),set(types['ctrl']),'config_batch ctrl')
    ctrl=program_control(config,types['ctrl'],dict(defaults,**w['ctrl']))
    packet=host_command(config,'CONFIG',tile=tile,control=ctrl,pc=pc)
    original.append(packet);queues.setdefault(tile,[]).append((i,packet))
  if not multicast:return original
  require(config['parameters'].get('CTRL_MULTICAST',0)==1,
      'config_batch multicast requires CTRL_MULTICAST=1')
  result=[]
  while any(queues.values()):
    groups={}
    for tile,q in queues.items():
      if q:
        index,packet=q[0]
        key=pack(types['payload'],packet['payload'],'payload')
        groups.setdefault(key,[]).append((tile,index,packet))
    group=min(groups.values(),key=lambda g:(-len(g),min(x[1] for x in g)))
    tiles=[x[0] for x in group];packet=group[0][2]
    if len(tiles)>1:result+=multicast_packets(config,tiles,packet['payload']['ctrl_addr'],packet['payload']['ctrl'])
    else:result.append(packet)
    for tile in tiles:queues[tile].pop(0)
  return result


def expand_packets(config,encoded,indices=False):
  """Validate native wire commands and return their logical unicast meaning."""
  p=config['parameters'];types=layouts(config);n=config['widths']['NUM_TILES'];bits=p['DATA_W']
  words=(n+bits-1)//bits;mask=0;valid=False;next_word=0;result=[]
  for index,value in enumerate(encoded):
    packet=unpack(types['host'],value);payload=packet['payload'];cmd=payload['cmd']
    if cmd in ABI.get('native_commands',{}).values():
      require(p.get('CTRL_NETWORK',0)!=0 and p.get('CTRL_MULTICAST',0)==1,
          'native multicast command is unsupported by this architecture')
      require(packet['dst_cgra_id']==0,'multicast is local to a single CGRA')
      if cmd==COMMANDS['CTRL_MASK_WORD']:
        i=payload['data_addr'];chunk=payload['data']['payload']
        require(i<words and (i==0 or i==next_word),'mask words must be consecutive starting at zero')
        require((chunk<<(i*bits))>>n==0,'mask contains absent or padding target bits')
        if i==0:mask=0;valid=False
        mask=(mask&~(((1<<bits)-1)<<(i*bits)))|(chunk<<(i*bits))
        valid=i==words-1;next_word=0 if valid else i+1
        continue
      require(valid and mask!=0,'multicast requires a complete nonempty target mask')
      integer(payload['ctrl_addr'],'multicast control address',0,p['CTRL_DEPTH']-1)
      program_control(config,types['ctrl'],payload['ctrl'])
      for tile in range(n):
        if mask&(1<<tile):
          item=copy.deepcopy(packet);item['dst']=tile;item['payload']['cmd']=COMMANDS['CONFIG']
          result.append((index,item) if indices else item)
    else:result.append((index,packet) if indices else packet)
  return result


def compile_program(config, document):
  keys(document, {'schema', 'steps', 'packets', 'control_defaults'}, 'program')
  require(type(document.get('schema')) is int and document['schema'] == 1, 'program schema: expected version 1')
  require(('steps' in document) != ('packets' in document), 'provide exactly one of steps or packets')
  types = layouts(config); packets = []; barriers = []
  defaults = document.get('control_defaults', {})
  keys(defaults, set(types['ctrl']), 'control_defaults')
  if 'packets' in document:
    require(not defaults, 'control_defaults applies only to program steps')
    require(isinstance(document['packets'], list), 'packets: expected list')
    packets = document['packets']
  else:
    steps = document['steps'];require(isinstance(steps, list), 'steps: expected list')
    for index, step in enumerate(steps):
      require(isinstance(step, dict), f'steps[{index}]: expected object')
      kind = step.get('kind')
      if kind == 'preload':
        keys(step, {'kind', 'address', 'values'}, 'preload')
        address = integer(step.get('address'), 'preload.address', 0, (1 << config['parameters']['GLOBAL_ADDR_W']) - 1)
        values = step.get('values');require(isinstance(values, list) and values, 'preload.values: nonempty list required')
        require(address + len(values) <= len(config['architectures']) * config['parameters']['NUM_BANKS'] * config['parameters']['BANK_DEPTH'], 'preload exceeds mapped memory windows')
        for i, value in enumerate(values):
          packets.append(host_command(config, 'STORE_REQUEST', data=data_value(value), address=address + i))
      elif kind == 'constants':
        keys(step, {'kind', 'cgra', 'tile', 'values'}, 'constants')
        cgra, tile = target(config, step.get('cgra', 0), step.get('tile', 0))
        values = step.get('values');require(isinstance(values, list), 'constants.values: expected list')
        depth = config['parameters']['CTRL_DEPTH'] + (10 if config['variant'] == 'context' else 0)
        require(len(values) <= depth, 'constant batch exceeds queue capacity')
        for value in values:
          packets.append(host_command(config, 'CONST', cgra, tile, data_value(value)))
      elif kind == 'program':
        keys(step, {'kind', 'cgra', 'tile', 'start', 'words', 'period', 'total_steps'}, 'program step')
        cgra, tile = target(config, step.get('cgra', 0), step.get('tile', 0))
        words = step.get('words');require(isinstance(words, list) and words, 'program.words: nonempty list required')
        p = config['parameters'];start = integer(step.get('start', 0), 'start', 0, p['CTRL_DEPTH'] - 1)
        require(start + len(words) <= p['CTRL_DEPTH'], 'program words exceed control storage')
        period = integer(step.get('period', len(words)), 'period', 1, p['CTRL_DEPTH'])
        total = integer(step.get('total_steps', len(words)), 'total_steps', 1, 2047)
        require(start + period <= p['CTRL_DEPTH'], 'program iteration window exceeds control storage')
        require(start == 0 or config['variant'] == 'context', 'nonzero program entry requires the Context command interface')
        if config['variant'] == 'context':
          packets.append(host_command(config, 'CONFIG_CTRL_LOWER_BOUND', cgra, tile, data_value(start, 0)))
        packets += [host_command(config, 'CONFIG_COUNT_PER_ITER', cgra, tile, data_value(period, 0)),
                    host_command(config, 'CONFIG_TOTAL_CTRL_COUNT', cgra, tile, data_value(total, 0))]
        for i, word in enumerate(words):
          keys(word, set(types['ctrl']), 'control word')
          control = program_control(config, types['ctrl'], dict(defaults, **word))
          packets.append(host_command(config, 'CONFIG', cgra, tile, control=control, pc=start + i))
      elif kind == 'command':
        keys(step, {'kind', 'cmd', 'cgra', 'tile', 'data', 'data_addr', 'ctrl', 'ctrl_addr'}, 'command')
        packets.append(host_command(config, step.get('cmd'), step.get('cgra', 0), step.get('tile', 0),
                       data_value(step.get('data', {}), 0), step.get('data_addr', 0), step.get('ctrl'), step.get('ctrl_addr', 0)))
      elif kind == 'config_multicast':
        keys(step,{'kind','tiles','address','ctrl'},'config_multicast')
        keys(step.get('ctrl'),set(types['ctrl']),'config_multicast ctrl')
        ctrl=program_control(config,types['ctrl'],dict(defaults,**step['ctrl']))
        packets+=multicast_packets(config,step.get('tiles'),step.get('address'),ctrl)
      elif kind == 'config_batch':
        keys(step,{'kind','writes','multicast'},'config_batch')
        packets+=config_batch(config,step.get('writes'),defaults,step.get('multicast',False))
      elif kind == 'packet':
        keys(step, {'kind', 'packet'}, 'packet step')
        packets.append(step.get('packet'))
      elif kind == 'barrier':
        keys(step, {'kind', 'completions'}, 'barrier')
        count = integer(step.get('completions'), 'barrier.completions', 0)
        require(not barriers or count >= barriers[-1]['completions'], 'completion barriers must be cumulative and nondecreasing')
        barriers.append(dict(before_packet=len(packets), completions=count))
      else:
        raise ConfigError(f'steps[{index}]: unknown kind {kind!r}')
  encoded = [pack(types['host'], value, 'host') for value in packets]
  require(encoded, 'program contains no host packets')
  # Constants replay in place; consuming one does not free a loading slot.
  # Context TERMINATE clears its queue. Other variants need external reset,
  # which is outside this single-epoch packet stream.
  loaded = {}
  depth = config['parameters']['CTRL_DEPTH'] + (10 if config['variant'] == 'context' else 0)
  for packet in expand_packets(config,encoded):
    cmd = packet['payload']['cmd'];pair = (packet['dst_cgra_id'], packet['dst'])
    if config['parameters'].get('CTRL_NETWORK',0):
      capabilities=ABI['control_network']
      allowed=capabilities['controller_forward_commands']+capabilities['controller_local_commands']
      require(cmd in {COMMANDS[x] for x in allowed},
          'command has no enabled Controller path in the dedicated profile')
      if cmd in {COMMANDS[x] for x in capabilities['controller_forward_commands']}:
        require(cmd in {COMMANDS[x] for x in capabilities['base_ingress_commands']},
            'command is not supported by the dedicated Base profile')
        target(config,*pair)
        if cmd==COMMANDS['CONFIG']:
          integer(packet['payload']['ctrl_addr'],'control address',0,config['parameters']['CTRL_DEPTH']-1)
          program_control(config,types['ctrl'],packet['payload']['ctrl'])
    if cmd == COMMANDS['CONST']:
      target(config, *pair)
      loaded[pair] = loaded.get(pair, 0) + 1
      require(loaded[pair] <= depth, 'cumulative constants exceed queue capacity; execution does not free slots')
    elif cmd == COMMANDS['TERMINATE'] and config['variant'] == 'context':
      loaded[pair] = 0
  # A terminal barrier is meaningful too; drivers must check it after the last packet.
  return types, encoded, barriers


def encode_outputs(config, document):
  types, packets, barriers = compile_program(config, document)
  def hexword(value, bits):
    return format(value, f'0{(bits + 3) // 4}x')
  decoded = [unpack(types['host'], word) for word in packets]
  controls = []; constants = []; preloads = []; index = []
  for i, packet in expand_packets(config,packets,indices=True):
    payload = packet['payload'];cmd = payload['cmd']
    entry = dict(packet_index=i, cgra=packet['dst_cgra_id'], tile=packet['dst'])
    if cmd == COMMANDS['CONFIG']:
      controls.append(hexword(pack(types['ctrl'], payload['ctrl']), width(types['ctrl'])))
      index.append(dict(entry, kind='control', file_index=len(controls)-1, address=payload['ctrl_addr']))
    elif cmd == COMMANDS['CONST']:
      constants.append(hexword(pack(types['data'], payload['data']), width(types['data'])))
      index.append(dict(entry, kind='constant', file_index=len(constants)-1))
    elif cmd == COMMANDS['STORE_REQUEST']:
      preloads.extend([f'@{payload["data_addr"]:x}', hexword(pack(types['data'], payload['data']), width(types['data']))])
      index.append(dict(entry, kind='store', address=payload['data_addr']))
  outputs = {'program.hex': '\n'.join(hexword(word, width(types['host'])) for word in packets) + '\n',
             'control.hex': '\n'.join(controls) + ('\n' if controls else ''),
             'constants.hex': '\n'.join(constants) + ('\n' if constants else ''),
             'preload.hex': '\n'.join(preloads) + ('\n' if preloads else ''),
             'barriers.txt': '\n'.join(f'{b["before_packet"]} {b["completions"]}' for b in barriers) + ('\n' if barriers else ''),
             'index.json': json.dumps(index, indent=2) + '\n'}
  metadata = dict(packet_count=len(packets), control_count=len(controls), constant_count=len(constants),
                  multicast_packets=sum(p['payload']['cmd']==COMMANDS['CONFIG_MULTICAST'] for p in decoded),
                  mask_packets=sum(p['payload']['cmd']==COMMANDS['CTRL_MASK_WORD'] for p in decoded),
                  wire_control_packets=sum(p['payload']['cmd'] in {COMMANDS['CONFIG'],COMMANDS['CONFIG_MULTICAST']} for p in decoded),
                  store_count=len(preloads)//2, barriers=barriers,
                  layouts={name: dict(nbits=width(node), fields=layout_fields(node)) for name, node in types.items()})
  return outputs, metadata


def main(argv=None):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--config', type=Path, required=True, help='architecture JSON input accepted by cgra_config.py')
  parser.add_argument('--program', type=Path, required=True)
  parser.add_argument('--output', type=Path)
  parser.add_argument('--check', action='store_true')
  args = parser.parse_args(argv)
  try:
    config = configuration.normalize(configuration.load_json(args.config))
    document = configuration.load_json(args.program)
    outputs, metadata = encode_outputs(config, document)
    if not args.check:
      require(args.output is not None, '--output required unless --check')
      require(not args.output.exists(), 'output directory already exists; choose a fresh directory')
      sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
      metadata.update(schema=1, python_target=ABI['python_target'], parameters=config['parameters'], widths=config['widths'],
                      input_sha256=dict(config=sha(args.config), program=sha(args.program)),
                      tool_sha256={name: sha(HERE / name) for name in ['cgra_program.py', 'cgra_config.py', 'abi.json']},
                      output_sha256={name: hashlib.sha256(text.encode()).hexdigest() for name, text in outputs.items()})
      args.output.mkdir(parents=True)
      for name, text in outputs.items():
        (args.output / name).write_text(text, encoding='utf-8')
      (args.output / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    print(f'CGRA_PROGRAM_PASS packets={metadata["packet_count"]} controls={metadata["control_count"]} constants={metadata["constant_count"]} stores={metadata["store_count"]}')
  except (ConfigError, OSError, json.JSONDecodeError) as error:
    parser.exit(2, f'CGRA_PROGRAM_ERROR: {error}\n')


if __name__ == '__main__':
  main()
