#!/usr/bin/env python3
"""Observe original Python ReLU completion/store ordering without changing RTL.

Requires the project's PyMTL fork. This is an opt-in migration diagnostic, not
part of the standalone/native regression. Continuing after RETURN is observation
only: it never converts an early completion into a functional acceptance pass.
"""
import argparse
import contextlib
import hashlib
import importlib
import importlib.metadata
import json
from pathlib import Path
import signal
import sys
import types

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--memory', type=int, choices=[0, 1], required=True)
  parser.add_argument('--output', type=Path, required=True)
  parser.add_argument('--wall-seconds', type=int, default=900)
  args = parser.parse_args()
  out = args.output.resolve()
  if out.exists():
    parser.error('output already exists; choose a fresh directory')
  target = json.loads((ROOT/'sv/reference/current/target.json').read_text())
  def audit():
    for name, expected in target['source_sha256'].items():
      if sha(ROOT/name) != expected:
        raise RuntimeError(f'Original Python source changed: {name}')
  audit()
  out.mkdir(parents=True)
  pkg = types.ModuleType('VectorCGRA')
  pkg.__path__ = [str(ROOT)]
  sys.modules['VectorCGRA'] = pkg
  from pymtl3 import DefaultPassGroup
  mod = importlib.import_module('VectorCGRA.cgra.test.CgraRTL_relu4x4_test_from_yaml')
  events = dict(stores=[], bank_writes=[], host_responses=[])
  info = dict(schema=1, status='running', python_target=target['python_target_commit'],
              source_files_checked=len(target['source_sha256']),
              target_sha256=sha(ROOT/'sv/reference/current/target.json'),
              probe_sha256=sha(Path(__file__)), python_version=sys.version.split()[0],
              pymtl_version=importlib.metadata.version('pymtl3'),
              memory_combinational=args.memory, post_return_observation_cycles=16,
              yaml_sha256=sha(ROOT/'validation/test/relu.yaml'),
              uploaded_yaml_sha256=sha(ROOT/'sv/examples/yaml/relu_neura_pass.yaml'))
  if (ROOT/'validation/test/relu.yaml').read_bytes().rstrip(b'\n') != (
      ROOT/'sv/examples/yaml/relu_neura_pass.yaml').read_bytes().rstrip(b'\n'):
    raise RuntimeError('Original and uploaded YAML differ beyond the final newline')

  def run(th, **unused):
    constructor = th._dsl.args
    assert constructor[15] == bool(args.memory)
    assert (constructor[5], constructor[6], constructor[13], constructor[14]) == (4, 4, 5, 170)
    packets = ''.join(f'{int(p.to_bits()):x}\n' for p in constructor[12])
    # The original Python YAML translator must still generate the frozen input.
    frozen = ROOT/'sv/reference/current/kernels/relu4x4/program.hex'
    assert [int(v, 16) for v in packets.split()] == [int(v, 16) for v in frozen.read_text().split()]
    (out/'program.hex').write_text(packets)
    info['program_sha256'] = sha(out/'program.hex')
    print(f'PYTHON_RELU_ELABORATING memory={args.memory}', file=sys.__stdout__, flush=True)
    th.apply(DefaultPassGroup())
    d = th.dut
    for cycle in range(600):
      th.reset @= int(cycle < 3)
      th.sim_eval_combinational()
      if cycle % 100 == 0:
        print(f'PYTHON_RELU_OBSERVING memory={args.memory} cycle={cycle}', file=sys.__stdout__, flush=True)
      completion = None
      if cycle >= 3:
        for tile, t in enumerate(d.tile):
          if t.to_mem_wdata.val and t.to_mem_wdata.rdy:
            assert t.to_mem_waddr.val and t.to_mem_waddr.rdy
            events['stores'].append(dict(cycle=cycle, tile=tile, address=int(t.to_mem_waddr.msg),
                data=int(t.to_mem_wdata.msg.payload), predicate=int(t.to_mem_wdata.msg.predicate)))
        for bank, wrapper in enumerate(d.data_mem.memory_wrapper):
          if wrapper.memory.wen[0]:
            # CPU preloads enter the additional write port (7). The ReLU STORE
            # is at core1, connected to local memory write port 1.
            source = int(wrapper.channel_wr.send.msg.src)
            assert source in (1, 7), f'unexpected memory writer {source}'
            if source == 1:
              events['bank_writes'].append(dict(cycle=cycle, bank=bank,
                  address=bank*16+int(wrapper.memory.waddr[0]),
                  data=int(wrapper.memory.wdata[0].payload), predicate=int(wrapper.memory.wdata[0].predicate)))
        if d.send_to_cpu_pkt.val and d.send_to_cpu_pkt.rdy:
          packet = d.send_to_cpu_pkt.msg
          completion = dict(cycle=cycle, command=int(packet.payload.cmd), src=int(packet.src),
              stores_including_same_edge=len(events['stores']),
              bank_writes_including_same_edge=len(events['bank_writes']))
          events['host_responses'].append(completion)
      # All handshakes and physical bank write enables refer to this edge.
      # Sample before ticking, but include them in the completion-edge counts.
      th.sim_tick()
      if completion:
        completion['memory_after_edge'] = [int(v.payload) for b in d.data_mem.memory_wrapper for v in b.memory.regs]
      if th.done() and 'original_test_done_cycle' not in info:
        info['original_test_done_cycle'] = cycle
      if events['host_responses'] and cycle >= events['host_responses'][0]['cycle']+16:
        break
    assert th.done(), 'Original test did not finish'
    assert len(events['host_responses']) == 1
    complete = events['host_responses'][0]
    assert (complete['command'], complete['src']) == (14, 9)
    assert len(events['stores']) == len(events['bank_writes']) == 32
    for name in ['stores', 'bank_writes']:
      assert [e['address'] for e in events[name]] == list(range(32))
      assert all(e['data'] == max(0, e['address']-16) and e['predicate'] == 1 for e in events[name])
    final = [int(v.payload) for b in d.data_mem.memory_wrapper for v in b.memory.regs]
    assert final == [max(0, i-16) for i in range(32)]
    info.update(status='observed', original_test_passed=True, completion_cycle=complete['cycle'],
                stores_at_completion=complete['stores_including_same_edge'],
                bank_writes_at_completion=complete['bank_writes_including_same_edge'],
                last_store_cycle=events['stores'][-1]['cycle'],
                last_bank_write_cycle=events['bank_writes'][-1]['cycle'],
                final_stores=32, final_bank_writes=32, final_memory=final,
                final_memory_matches_relu=True, final_cycle=cycle,
                early_return=complete['stores_including_same_edge'] < 32 or complete['bank_writes_including_same_edge'] < 32)

  # Only replace the test driver/trace output. TestHarness, Sources, Sink, RTL,
  # initial input values and YAML-generated control packets are unchanged.
  mod.run_sim = run
  mod.config_model_with_cmdline_opts = lambda th, *a, **kw: th
  mod.init_trace_logger = lambda *a, **kw: None
  mod.close_trace_logger = lambda: None
  def timeout(signum, frame):
    raise TimeoutError('Python ReLU probe exceeded wall-clock limit')
  signal.signal(signal.SIGALRM, timeout)
  signal.alarm(args.wall_seconds)
  try:
    with (out/'generation.log').open('w') as log, contextlib.redirect_stdout(log):
      mod.sim_relu_return({}, mem_access_is_combinational=bool(args.memory))
    audit()
  except BaseException as error:
    info.update(status='failed', error=repr(error))
    raise
  finally:
    signal.alarm(0)
    (out/'events.json').write_text(json.dumps(events, indent=2)+'\n')
    info['events_sha256'] = sha(out/'events.json')
    (out/'result.json').write_text(json.dumps(info, indent=2)+'\n')
  print(f'PYTHON_RELU_OBSERVED memory={args.memory} completion={info["completion_cycle"]} '
        f'stores={info["stores_at_completion"]}/32 bank_writes={info["bank_writes_at_completion"]}/32 '
        f'last_store={info["last_store_cycle"]} last_bank_write={info["last_bank_write_cycle"]} '
        f'early_return={info["early_return"]}', flush=True)


if __name__ == '__main__':
  main()
