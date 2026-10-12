"""Freeze unmodified LoopController Python I/O; native builds only read the text.

Run with the repository's custom PyMTL environment. No project source is edited.
"""
import argparse
import hashlib
import importlib
import json
from pathlib import Path
import random
import sys
import types

ROOT = Path(__file__).resolve().parents[2]
package = types.ModuleType('VectorCGRA')
package.__path__ = [str(ROOT)]
sys.modules['VectorCGRA'] = package
from pymtl3 import DefaultPassGroup, mk_bits
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload
from VectorCGRA.controller.LoopControllerRTL import LoopControllerRTL


def digest(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def packed(items):
  result = 0
  for value, width in items:
    result = (result << width) | int(value.to_bits() if hasattr(value, 'to_bits') else value)
  return result


class Trace:
  def __init__(self, params):
    self.params = params
    self.rows = []
    self.labels = []
    self.scenarios = []
    self.pw = 6 + params['DATA_W'] + 3 + params['DATA_ADDR_W'] + params['CTRL_BITS'] + params['CTRL_ADDR_W']

  def snapshot(self, dut, label):
    p = self.pw
    ins = [(dut.reset, 1)]
    for name in ('recv_config', 'recv_from_tile', 'recv_from_remote'):
      port = getattr(dut, name)
      ins += [(port.val, 1), (port.msg, p)]
    ins += [(dut.send_to_tile.rdy, 1), (dut.send_to_remote.rdy, 1)]
    outs = [(dut.all_loops_complete, 1), (dut.recv_config.rdy, 1),
            (dut.recv_from_tile.rdy, 1), (dut.recv_from_remote.rdy, 1)]
    for name in ('send_to_tile', 'send_to_remote'):
      port = getattr(dut, name)
      outs += [(port.val, 1), (port.msg, p)]
    self.rows.append((packed(ins), packed(outs)))
    self.labels.append(label)

  def boundary(self, label):
    # Reset sample output is intentionally not compared: each Python scenario
    # is a fresh instance, whereas SV runs all scenarios on the same instance.
    self.rows.append((1 << (3*self.pw+5), 0))
    self.labels.append(label + ':reset')

  def write(self, directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory/'vectors.txt').write_text(''.join(
      f'{i:0{(3*self.pw+9)//4}x} {o:0{(2*self.pw+9)//4}x}\n' for i, o in self.rows))
    (directory/'labels.json').write_text(json.dumps(self.labels, indent=2)+'\n')
    manifest = dict(parameters=self.params, cycles=len(self.rows),
                    input_bits=3*self.pw+6, output_bits=2*self.pw+6,
                    scenarios=self.scenarios, python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
                    vectors_sha256=digest(directory/'vectors.txt'),
                    generator_sha256=digest(Path(__file__)),
                    source_sha256=digest(ROOT/'controller/LoopControllerRTL.py'))
    (directory/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')


def original_tests(trace):
  tests = importlib.import_module('VectorCGRA.controller.test.LoopControllerRTL_test')
  original_runner = tests.run_sim
  def capture(th, max_cycles=300):
    th.elaborate()
    th.apply(DefaultPassGroup())
    th.sim_reset()
    trace.boundary(test_name)
    count = 0
    while not th.done() and count < max_cycles:
      th.sim_eval_combinational()
      trace.snapshot(th.dut, test_name+f':{count}')
      th.sim_tick()
      count += 1
    assert th.done(), test_name
    for _ in range(3):
      th.sim_eval_combinational()
      trace.snapshot(th.dut, test_name+':drain')
      th.sim_tick()
    trace.scenarios.append(dict(name=test_name, cycles=count+3, status='original_test_passed'))
  tests.run_sim = capture
  try:
    for test_name in sorted(n for n in vars(tests) if n.startswith('test_')):
      getattr(tests, test_name)()
  finally:
    tests.run_sim = original_runner


def synthetic(trace, capacity=False):
  p = trace.params
  D = mk_data(p['DATA_W'], 1)
  # Ctrl is opaque to LoopController. The original tests use 107 bits, and
  # other profiles use the current four-port PE's 119-bit layout.
  C = mk_ctrl(4, 2, 4, 2 if p['CTRL_BITS'] == 107 else 4)
  assert C.nbits == p['CTRL_BITS']
  P = mk_cgra_payload(D, mk_bits(p['DATA_ADDR_W']), C, mk_bits(p['CTRL_ADDR_W']))
  m = LoopControllerRTL(D, C, num_ccus=p['NUM_CCUS'], max_targets_per_ccu=p['MAX_TARGETS'],
                        data_mem_size=1 << p['DATA_ADDR_W'], ctrl_mem_size=1 << p['CTRL_ADDR_W'])
  m.apply(DefaultPassGroup())
  for name in ('recv_config','recv_from_tile','recv_from_remote'):
    getattr(m,name).val @= 0
    getattr(m,name).msg @= P()
  m.send_to_tile.rdy @= 0
  m.send_to_remote.rdy @= 0
  m.sim_reset()
  label = 'capacity' if capacity else 'mixed_events'
  trace.boundary(label)
  rng = random.Random(24001 + p['DATA_W'] + p['NUM_CCUS'])
  stats = dict(local_sends=0, remote_sends=0, simultaneous_events=0, stalled_sends=0)
  def tick(suffix, config=None, tile=None, remote=None, ready=(1,1)):
    for name, value in [('recv_config',config),('recv_from_tile',tile),('recv_from_remote',remote)]:
      getattr(m,name).val @= int(value is not None)
      getattr(m,name).msg @= value if value is not None else P()
    m.send_to_tile.rdy @= ready[0]
    m.send_to_remote.rdy @= ready[1]
    m.sim_eval_combinational()
    trace.snapshot(m, label+':'+suffix)
    stats['local_sends'] += int(m.send_to_tile.val & m.send_to_tile.rdy)
    stats['remote_sends'] += int(m.send_to_remote.val & m.send_to_remote.rdy)
    stats['simultaneous_events'] += int(m.recv_from_tile.val & m.recv_from_tile.rdy & m.recv_from_remote.val & m.recv_from_remote.rdy)
    stats['stalled_sends'] += int((m.send_to_tile.val & ~m.send_to_tile.rdy) | (m.send_to_remote.val & ~m.send_to_remote.rdy))
    m.sim_tick()
  idw = max(1,(p['NUM_CCUS']-1).bit_length())
  active = 1 if capacity else p['NUM_CCUS']
  for ci in range(active):
    for cmd,val in [(32,0),(33,3 if capacity else 7+ci),(34,1+ci%2),(35,1 if capacity else 2)]:
      tick('config', config=P(cmd,D(val,1,1,1),0,C(),ci))
    count = p['MAX_TARGETS'] if capacity else min(p['MAX_TARGETS'],2)
    for t in range(count):
      address = (ci+t) % (1 << p['CTRL_ADDR_W'])
      tick('target',config=P(36,D(address, int(t%2==1)),
                            (1 << (p['DATA_ADDR_W']-1)) if t else 0,C(),ci))
    tick('parent',config=P(37,D(1 << idw,0),0,C(),ci))
  tick('launch',config=P(38,D(),0,C(),0))
  if capacity:
    tick('complete',tile=P(31,D(),0,C(),0))
    for n in range(48):
      tick(str(n),ready=(int(n%5!=0),int(n%7!=0)))
    observed = int(m.ccu_state[0])
    wrap = p['MAX_TARGETS'] > 1 and p['MAX_TARGETS'] & (p['MAX_TARGETS']-1) == 0
    assert observed == (2 if wrap else 1)
    assert stats['local_sends']+stats['remote_sends'] > p['MAX_TARGETS'] if wrap else stats['local_sends']+stats['remote_sends'] == p['MAX_TARGETS']
    stats['python_dispatch_wrap_reproduced'] = wrap
  else:
    for n in range(400):
      tile = P(rng.choice([31,31,31,0]),D(rng.getrandbits(p['DATA_W']),rng.randrange(2)),0,C(),rng.randrange(active)) if rng.randrange(4) else None
      remote = P(rng.choice([40,40,0]),D(),0,C(),rng.randrange(1 << p['CTRL_ADDR_W'])) if rng.randrange(3)==0 else None
      config = P(38,D(),0,C(),0) if n in (90,230) else None
      tick(str(n),config,tile,remote,(rng.randrange(2),rng.randrange(2)))
    assert stats['stalled_sends'] > 0
    assert stats['simultaneous_events'] > 0
  trace.scenarios.append(dict(name=label,status='frozen_python_behavior',**stats))


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/loop_controller')
  args = parser.parse_args()
  target = json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,expected in target['source_sha256'].items():
    assert digest(ROOT/path)==expected, 'Pinned Python modified: '+path
  profiles = [('default',32,8,4,107,3),('wide',64,3,3,119,3),
              ('single',32,1,1,119,1),('eight_targets',32,8,8,119,4)]
  for name,width,ccus,targets,ctrl,addr in profiles:
    p=dict(DATA_W=width,NUM_CCUS=ccus,MAX_TARGETS=targets,CTRL_BITS=ctrl,DATA_ADDR_W=3,CTRL_ADDR_W=addr)
    trace=Trace(p)
    if name=='default': original_tests(trace)
    synthetic(trace)
    synthetic(trace,capacity=True)
    trace.write(args.output_root/name)
    print('LOOP_PYTHON_FROZEN',name,'cycles',len(trace.rows),flush=True)

if __name__ == '__main__':
  main()
