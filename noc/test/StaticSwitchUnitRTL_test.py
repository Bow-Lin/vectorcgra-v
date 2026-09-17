"""Cycle-by-cycle comparison against the unchanged PyOCN switch."""

import random

import pytest
from pymtl3 import DefaultPassGroup, clog2, mk_bits
from pymtl3.stdlib.test_utils import config_model_with_cmdline_opts

from ..PyOCN.pymtl3_net.router.SwitchUnitRTL import SwitchUnitRTL
from ..StaticSwitchUnitRTL import StaticSwitchUnitRTL
from ...lib.messages import mk_cgra_payload, mk_ctrl, mk_data, mk_intra_cgra_pkt


def control_packet_type():
  data_type = mk_data(32, 1)
  ctrl_type = mk_ctrl(4, 2, 4, 4, 16)
  payload_type = mk_cgra_payload(data_type, mk_bits(clog2(128)), ctrl_type,
                                mk_bits(clog2(6)))
  return mk_intra_cgra_pkt(4, 1, 16, payload_type)


def differential_switch(packet_type, num_inports, random_cycles=700, seed=719):
  """Compare every observable bit and arbitration state, including idle cycles."""
  models = [SwitchUnitRTL(packet_type, num_inports),
            StaticSwitchUnitRTL(packet_type, num_inports)]
  for model in models:
    model.elaborate()
    model.apply(DefaultPassGroup())
    model.sim_reset()
  rng = random.Random(seed)
  bits_type = mk_bits(packet_type.nbits)
  from_bits = getattr(packet_type, "from_bits", packet_type)
  cycles = 0
  stalled_selections = set()

  def snapshot(model):
    return (int(model.send.val), int(model.send.msg.to_bits()),
            tuple(int(port.rdy) for port in model.recv),
            int(model.encoder.out), int(model.arbiter.grants),
            int(model.arbiter.priority_reg.out))

  def cycle(requests, ready, reset=0):
    nonlocal cycles
    messages = [from_bits(bits_type(rng.getrandbits(packet_type.nbits)))
                for _ in range(num_inports)]
    for model in models:
      model.reset @= reset
      model.send.rdy @= ready
      for i in range(num_inports):
        model.recv[i].val @= (requests >> i) & 1
        model.recv[i].msg @= messages[i]
      model.sim_eval_combinational()
    assert snapshot(models[0]) == snapshot(models[1]), (cycles, "before edge")
    if requests == 0:
      # These are specified by the original switch, despite invalid messages.
      assert models[1].send.msg == messages[0]
      assert not models[1].send.val
      assert int(models[1].recv[0].rdy) == ready
    if requests and not ready:
      stalled_selections.add(int(models[1].encoder.out))
    for model in models:
      model.sim_tick()
    assert snapshot(models[0]) == snapshot(models[1]), (cycles, "after edge")
    cycles += 1

  # Every request pattern under both readiness values; no assumptions about
  # holding messages while stalled, so this includes the normal protocol.
  for requests in range(1 << num_inports):
    cycle(requests, 0)
    cycle(requests, 1)
  for _ in range(num_inports * 3):
    cycle((1 << num_inports) - 1, 0)
  for i in range(random_cycles):
    cycle(rng.randrange(1 << num_inports), rng.randrange(2), i % 113 == 0)
  cycle(0, 0, 1)
  cycle(0, 1)
  assert len(stalled_selections) == num_inports
  return {"cycles": cycles, "num_inports": num_inports,
          "packet_bits": packet_type.nbits, "seed": seed,
          "compared": ["send.val", "send.msg including invalid",
                       "all recv.rdy", "encoder", "grants", "priority state"]}


@pytest.mark.parametrize("num_inports", [2, 3, 5, 6, 8])
def test_static_switch_bits(num_inports):
  differential_switch(mk_bits(32), num_inports)


def test_static_switch_control_packet():
  packet_type = control_packet_type()
  assert packet_type.nbits == 199
  differential_switch(packet_type, 6, random_cycles=1800)


def test_static_switch_import(cmdline_opts, tmp_path, monkeypatch):
  """Exercise the real translation/import path when pytest uses --test-verilog."""
  monkeypatch.chdir(tmp_path)
  packet_type = control_packet_type()
  reference = SwitchUnitRTL(packet_type, 6)
  candidate = config_model_with_cmdline_opts(
    StaticSwitchUnitRTL(packet_type, 6), cmdline_opts, duts=[])
  for model in (reference, candidate):
    model.elaborate()
    model.apply(DefaultPassGroup())
    model.sim_reset()
  rng = random.Random(8679)
  bits_type = mk_bits(packet_type.nbits)
  for cycle in range(160):
    requests = cycle % 64
    ready = (cycle // 64) & 1
    messages = [packet_type.from_bits(bits_type(rng.getrandbits(packet_type.nbits)))
                for _ in range(6)]
    for model in (reference, candidate):
      model.send.rdy @= ready
      for i in range(6):
        model.recv[i].val @= (requests >> i) & 1
        model.recv[i].msg @= messages[i]
      model.sim_eval_combinational()
    assert reference.send.val == candidate.send.val
    assert reference.send.msg == candidate.send.msg
    assert [int(port.rdy) for port in reference.recv] == [int(port.rdy) for port in candidate.recv]
    reference.sim_tick()
    candidate.sim_tick()
