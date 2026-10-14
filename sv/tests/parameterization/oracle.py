"""Independent arithmetic and public-output acceptance, not an RTL trace oracle."""
from collections import Counter
import json
from pathlib import Path
from common import program


def expected(entry, spec):
  p = entry['normalized']['parameters']; width = p['DATA_W']; mask = (1<<width)-1
  memory = {int(c): list(words) for c, words in spec['initial'].items()}
  boundaries = []
  for c, path in enumerate(entry['paths']):
    source = (c+1) % len(entry['paths'])
    value = spec['initial'][str(source)][-2]
    assert spec['mathematical_function']==('3*x+11' if spec['algorithm']=='affine' else 'x+17')
    # Same mathematical function on every shape; no control-word interpretation,
    # per-tile expected values, or reconstruction of the mapping algorithm.
    value = ((3*value+11) if spec['algorithm']=='affine' else (value+17)) & mask
    if spec['streaming']:
      boundaries.append((2*p['COLS'], (value<<3)|4))
    else:
      memory[source][-1] = value
  reads = []
  for slot, owner in enumerate(spec['address_map']):
    for index, value in enumerate(memory[owner]):
      reads.append((slot*spec['capacity']+index, owner, value))
  return reads, boundaries


def parse_trace(path, layout):
  hosts = []; boundaries = []
  for line in Path(path).read_text().splitlines():
    fields = line.split()
    if fields[0] == 'H':
      assert len(fields)==3
      hosts.append(program.unpack(layout, int(fields[2], 16)))
    elif fields[0] == 'B':
      assert len(fields)==4
      boundaries.append((int(fields[2]), int(fields[3],16)))
    else:
      raise AssertionError('Unknown trace event '+line)
  return hosts, boundaries


def check(entry, spec, trace, corrupt=False):
  layout = program.layouts(entry['normalized'])['host']
  hosts, boundaries = parse_trace(trace, layout)
  completes = [p for p in hosts if p['payload']['cmd']==14]
  responses = [p for p in hosts if p['payload']['cmd']==11]
  assert len(completes)+len(responses)==len(hosts), 'Unexpected response command'
  assert Counter((p['src_cgra_id'],p['src']) for p in completes)==Counter(
      tuple(x) for x in spec['expected_completions']), 'Missing/duplicate/wrong completion owner'
  expected_reads, expected_boundary = expected(entry, spec)
  if corrupt:
    addr, owner, value = expected_reads[-1]
    expected_reads[-1] = (addr, owner, value^1)
  actual = []
  for packet in hosts:
    assert packet['dst_cgra_id']==0, 'Wrong CPU destination CGRA'
    # The host is addressed by the controller's ring node, not tile zero.
    if packet['payload']['cmd']==14:
      a = entry['normalized']['architectures'][packet['src_cgra_id']]
      destination = a['cols']*a['rows']
    else:
      p = entry['normalized']['parameters']; destination=p['MAX_COLS']*p['MAX_ROWS']
    assert packet['dst']==destination, 'Wrong controller destination node'
  for packet in responses:
    payload = packet['payload']; data = payload['data']
    assert data['predicate']==1 and data['bypass']==0 and data['delay']==0, 'Wrong data flags'
    actual.append((payload['data_addr'],packet['src_cgra_id'],data['payload']))
  assert actual==expected_reads, next((f'Memory mismatch at result {i}: actual={a}, expected={e}'
       for i,(a,e) in enumerate(zip(actual,expected_reads)) if a!=e),
       f'Response count actual={len(actual)} expected={len(expected_reads)}')
  assert boundaries==expected_boundary, f'Boundary mismatch {boundaries} != {expected_boundary}'
  # Compare complete packets between implementations, permitting only completion
  # interleaving across independent tiles. Read requests are serialized by driver.
  return dict(completions=sorted(program.pack(layout,p) for p in completes),
              responses=[program.pack(layout,p) for p in responses], boundaries=boundaries,
              checked_words=len(actual), active_tiles=len(completes))
