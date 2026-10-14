"""A predeclared architecture matrix and two generic, all-PE mapped programs.

Only JSON/packet files change between workloads. No workload emits RTL.
The mathematical oracle lives in oracle.py and does not decode these controls.
"""
import argparse
import copy
import json
from pathlib import Path
import random

from common import configuration as cfg, program as packer, write_json

SEEDS = [0, 23, 917]
ALGORITHMS = ['add', 'affine']


def snake(cols, rows):
  return [y * cols + x for y in range(rows)
          for x in (range(cols) if y % 2 == 0 else reversed(range(cols)))]


def matrix():
  def regular(cols, rows, **parameters):
    return dict(schema=1, top='system', default_fus=['ADDER', 'MUL', 'CONST', 'MEM', 'NAH'],
        parameters=dict(CTRL_DEPTH=6, REG_DEPTH=5,
        NUM_CTRL=6, TOTAL_STEPS=6, BANK_DEPTH=8, NUM_BANKS=4, **parameters),
        architectures=[dict(cols=cols, rows=rows)])
  baseline = regular(2, 2)
  baseline['parameters'].update(REG_DEPTH=2)
  rect = regular(3, 2)
  registered = copy.deepcopy(rect); registered['parameters']['MEM_COMBINATIONAL'] = 0
  wide = regular(2, 3, DATA_W=64)
  wide['parameters'].update(CTRL_DEPTH=6, NUM_CTRL=6, TOTAL_STEPS=6, REG_DEPTH=9,
                            NUM_BANKS=2, BANK_DEPTH=32)
  context = regular(2, 3)
  context['variant'] = 'context'
  context['parameters'].update(CTRL_DEPTH=7, NUM_CTRL=7, TOTAL_STEPS=7, REG_DEPTH=7)
  streaming = regular(3, 2, TILE_PORTS=8)
  streaming.update(variant='streaming', default_fus=['ADDER', 'MUL', 'CONST', 'STREAMING_MEM', 'NAH'])
  # A directed, non-geometric chain through every tile. Port 4/6 links require
  # the explicit graph and cannot work if the implementation ignores that graph.
  custom = regular(3, 3, TILE_PORTS=8)
  order = list(range(9)); random.Random(20261014).shuffle(order)
  edges = []
  for left, right in zip(order, order[1:]):
    edges += [dict(src=left, dst=right, sp=4, dp=6, enabled=1),
              dict(src=right, dst=left, sp=6, dp=4, enabled=1)]
  # Explicit disabled link; unique unused ports.
  edges.append(dict(src=order[0], dst=order[-1], sp=5, dp=7, enabled=0))
  a = custom['architectures'][0]
  a.update(links=edges, read_ports=[order[1], order[0]],
           write_ports=[order[2], order[1], order[0]],
           boundary_in=[0]*9, boundary_out=[0]*9)
  a['fu_names'] = [['ADDER', 'CONST'] + (['MUL'] if t % 2 else []) +
                   (['MEM'] if t in order[:3] else []) + ['NAH'] for t in range(9)]
  ring = regular(2, 2, MULTI_COLS=3, MULTI_ROWS=1)
  ring.update(top='multi', topology='ring', address_map=[2, 0, 1])
  ring['architectures'] *= 3
  # Keep equal maximum dimensions to match the original template's geometry
  # rule; include two rectangular members and different per-tile FU catalogs.
  mesh = regular(3, 3, TILE_PORTS=8, MULTI_COLS=2, MULTI_ROWS=2)
  mesh.update(top='multi', address_map=[2, 0, 3, 1])
  mesh['parameters'].update(NUM_BANKS=2, BANK_DEPTH=8)
  mesh['architectures'] = []
  for cols, rows in [(2, 2), (3, 3), (3, 2), (2, 3)]:
    aa = dict(cols=cols, rows=rows)
    aa['fu_names'] = [['ADDER', 'CONST'] + (['MUL'] if t % 2 else []) + ['MEM', 'NAH']
                      for t in range(cols*rows)]
    mesh['architectures'].append(aa)
  documents = dict(base_2x2=baseline, rect_3x2_comb=rect, rect_3x2_registered=registered,
                   wide_2x3=wide, custom_3x3=custom, context_2x3=context,
                   streaming_3x2=streaming, ring_3=ring, heterogeneous_mesh=mesh)
  result = {}
  for name, document in documents.items():
    normalized = cfg.normalize(document)
    paths = [snake(a['cols'], a['rows']) for a in normalized['architectures']]
    if name == 'custom_3x3': paths = [order]
    result[name] = dict(config=document, normalized=normalized, paths=paths,
        python_model=('template' if name in {'custom_3x3', 'heterogeneous_mesh'} else 'regular'))
  return result


def input_value(seed, owner, width):
  if seed == 0:
    return (1 << width) - 1 if owner % 2 == 0 else 0
  return random.Random(seed * 131 + owner).getrandbits(width)


def workload(entry, algorithm, seed):
  config = entry['normalized']; p = config['parameters']
  stages = []; steps = []; expectations = []; boundary = []
  n = len(config['architectures']); capacity = p['BANK_DEPTH'] * p['NUM_BANKS']
  width = p['DATA_W']; mask = (1 << width) - 1
  streaming = config['variant'] == 'streaming'
  owners = config['address_map']; rounds = p['CTRL_DEPTH']
  # Initialize every word and check all of them after the computation, including
  # untouched guards. This catches writes to the wrong bank or truncated address.
  initial = {}
  for slot, owner in enumerate(owners):
    words = [((seed+1)*0x45d9f3b + owner*97 + i*13) & mask for i in range(capacity)]
    words[-2] = input_value(seed, owner, width)
    initial[owner] = words
    steps.append(dict(kind='preload', address=slot*capacity, values=words))
  for c, (a, path) in enumerate(zip(config['architectures'], entry['paths'])):
    remote = (c+1) % n
    address = owners.index(remote)*capacity + capacity-2
    output_address = address+1
    if streaming:
      boundary.append(dict(port=2*p['COLS'], value=(initial[remote][-2]<<3)|4))
    stage = dict(cgra=c, source_owner=remote, source_address=address,
                 output_address=output_address, path=path, tiles=[])
    coefficient, offset, multiplied = 1, 0, False
    for index, t in enumerate(path):
      first = index == 0; last = index == len(path)-1
      def edge(src, dst):
        matches = [e for e in a['links'] if e['enabled'] and e['src']==src and e['dst']==dst]
        assert len(matches) == 1, (src, dst, matches)
        return matches[0]
      previous_in = edge(path[index-1], t)['dp'] if not first else 2
      previous_out = edge(t, path[index-1])['sp'] if not first else 2
      next_in = edge(path[index+1], t)['dp'] if not last else None
      next_out = edge(t, path[index+1])['sp'] if not last else previous_out
      def ctrl(operation, incoming=None, read=False, write=False, outgoing=None):
        out = dict(operation=operation, fu_in=[1, 2, 3, 4])
        if incoming is not None: out['routing_xbar_outport'] = {str(p['TILE_PORTS']): incoming+1}
        if read:
          out.update(read_reg_towards={'0': 1}, read_reg_idx={'0': p['REG_DEPTH']-1})
        if write:
          out.update(write_reg_from={'0': 2}, write_reg_idx={'0': p['REG_DEPTH']-1},
                     fu_xbar_outport={str(p['TILE_PORTS']): 1})
        if outgoing is not None: out['fu_xbar_outport'] = {str(outgoing): 1}
        return out
      constants = [address] if first and not streaming else []
      words = [ctrl('LD_CONST', write=True) if first and not streaming
               else ctrl('INC', incoming=previous_in, write=True)]
      offset += int(not first or streaming)
      operations = []
      for pc in range(1, rounds if last else rounds-1):
        multiply = algorithm == 'affine' and not multiplied and 'MUL' in a['fu_names'][t] and pc==1
        k = 3 if multiply else 1 + ((seed + c*3 + t*5 + pc) % 7)
        if last and pc==rounds-1:
          multiply=False;k=((11 if algorithm=='affine' else 17)-offset)&mask
        if pc not in {2,3}:
          if multiply: coefficient*=3;offset*=3;multiplied=True
          else: offset+=k
          offset &= mask
        operation = 'MUL_CONST' if multiply else 'ADD_CONST'
        operations.append(dict(kind='multiply' if multiply else 'add', value=k))
        constants.append(k)
        send = pc == (rounds-1 if last else rounds-2)
        words.append(ctrl(operation, read=True, write=not send,
                          outgoing=next_out if send else None))
        # Keep distinct live values in register 0 and the highest register.
        # pc1 consumes high into low. pc2 writes a separate constant into high;
        # pc3 consumes high into bank1. pc4 must still obtain pc1's low value.
        # The separation obeys token lifetimes and detects index aliasing.
        if pc == 1: words[-1]['write_reg_idx'] = {'0': 0}
        if pc == 2: words[-1] = ctrl('CONST', write=True)
        if pc == 3:
          words[-1]['write_reg_from'] = {'1': 2}
          words[-1]['write_reg_idx'] = {'1': p['REG_DEPTH']-1}
          words[-1]['fu_xbar_outport'] = {str(p['TILE_PORTS']+1): 1}
        if pc == 4: words[-1]['read_reg_idx'] = {'0': 0}
      if not last:
        if first:
          if streaming:
            constants.append(0); words.append(ctrl('ADD_CONST', incoming=next_in, outgoing=2))
          else:
            constants.append(output_address); words.append(ctrl('STR_CONST', incoming=next_in))
        else:
          words.append(dict(operation='NAH', routing_xbar_outport={str(previous_out): next_in+1}))
      assert len(words) == rounds
      steps += [dict(kind='constants', cgra=c, tile=t, values=constants),
                dict(kind='program', cgra=c, tile=t, words=words)]
      stage['tiles'].append(dict(tile=t, initial_increment=int(not first or streaming),
                                  operations=operations, register=p['REG_DEPTH']-1,
                                  last_control=rounds-1))
    stages.append(stage)
    assert coefficient==(3 if algorithm=='affine' else 1)
    assert offset==(11 if algorithm=='affine' else 17)
  for c, path in enumerate(entry['paths']):
    steps += [dict(kind='command', cmd='LAUNCH', cgra=c, tile=t) for t in reversed(path)]
  steps.append(dict(kind='barrier', completions=sum(len(x) for x in entry['paths'])))
  for slot in range(n):
    for address in range(slot*capacity, (slot+1)*capacity):
      steps.append(dict(kind='command', cmd='LOAD_REQUEST', data_addr=address))
  specification = dict(algorithm=algorithm, seed=seed, width=width, rounds=rounds,
    mathematical_function='3*x+11' if algorithm=='affine' else 'x+17',
    streaming=streaming, capacity=capacity, address_map=owners, initial=initial,
    stages=stages, boundary_inputs=boundary,
    expected_completions=[[c, t] for c, path in enumerate(entry['paths']) for t in path])
  return dict(schema=1, steps=steps), specification


def generate(root):
  root.mkdir(parents=True, exist_ok=True)
  catalog = matrix()
  for name, entry in catalog.items():
    folder = root/name; folder.mkdir(exist_ok=True)
    write_json(folder/'config.json', entry['config'])
    write_json(folder/'architecture.json', entry)
    generated = folder/'generated'; generated.mkdir(exist_ok=True)
    for filename, text in cfg.emit(entry['normalized']).items():
      (generated/filename).write_text(text)
    for algorithm in ALGORITHMS:
      for seed in SEEDS:
        case = folder/f'{algorithm}_{seed}'; case.mkdir(exist_ok=True)
        document, spec = workload(entry, algorithm, seed)
        write_json(case/'program.json', document); write_json(case/'specification.json', spec)
        files, metadata = packer.encode_outputs(entry['normalized'], document)
        for filename, text in files.items(): (case/filename).write_text(text)
        write_json(case/'packing.json', metadata)
        (case/'boundary.txt').write_text(''.join(f'{x["port"]} {x["value"]:x}\n' for x in spec['boundary_inputs']))
  write_json(root/'matrix.json', dict(architectures=list(catalog), algorithms=ALGORITHMS,
      seeds=SEEDS, schedules=[0, 37], acceptance='complete program + all-memory oracle + Python comparison'))


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output', required=True, type=Path)
  generate(parser.parse_args().output)
