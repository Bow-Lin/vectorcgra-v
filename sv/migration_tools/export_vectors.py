"""Run the unchanged Python baseline and freeze replayable 2x2 scalar traces."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from reference_model import (ROOT, BASELINE, TOP, DataType, CtrlType, PayloadType,
  HostPacketType, NocPacketType, make_design, hex_bits)
from pymtl3 import DefaultPassGroup, mk_bits
from VectorCGRA.lib.cmd_type import (CMD_CONFIG, CMD_CONFIG_COUNT_PER_ITER,
  CMD_CONFIG_TOTAL_CTRL_COUNT, CMD_CONST, CMD_LAUNCH, CMD_STORE_REQUEST,
  CMD_LOAD_REQUEST, CMD_LOAD_RESPONSE, CMD_COMPLETE)
from VectorCGRA.lib.opt_type import (OPT_LD_CONST, OPT_STR_CONST, OPT_ADD_CONST,
  OPT_MUL_CONST)

DIRECTIONS = ["north", "south", "west", "east"]


def packet(cmd, tile=0, data=0, predicate=0, address=0, ctrl=None, ctrl_addr=0):
  return HostPacketType(src=0, dst=tile,
    payload=PayloadType(cmd=cmd, data=DataType(data & 0xffffffff, predicate),
      data_addr=address, ctrl=ctrl or CtrlType(), ctrl_addr=ctrl_addr))


def control(operation, input_direction=None, output_directions=()):
  route = [0] * 8
  if input_direction is not None:
    route[4] = input_direction + 1
  crossbar = [0] * 8
  for direction in output_directions:
    crossbar[direction] = 1
  return CtrlType(operation=operation, fu_in=[mk_bits(3)(i) for i in [1, 2, 3, 4]],
    routing_xbar_outport=[mk_bits(4)(i) for i in route],
    fu_xbar_outport=[mk_bits(2)(i) for i in crossbar])


def configuration(input_value):
  programs = [
    [control(OPT_LD_CONST, output_directions=(3,)), control(OPT_STR_CONST, 0)],
    [control(OPT_ADD_CONST, 2, (0,))],
    [control(OPT_ADD_CONST, 3, (1, 2))],
    [control(OPT_MUL_CONST, 1, (2,))],
  ]
  constants = [[15, 16], [5], [0xfffffff8], [3]]
  packets = [packet(CMD_STORE_REQUEST, data=input_value, predicate=1, address=15),
             packet(CMD_STORE_REQUEST, data=0xdeadbeef, predicate=1, address=16)]
  descriptions = ["preload bank0[15] input", "preload bank1[0] sentinel"]
  for tile in range(4):
    for value in constants[tile]:
      packets.append(packet(CMD_CONST, tile, value, 1))
      descriptions.append(f"tile{tile} constant {value:#010x}")
    for command in [CMD_CONFIG_COUNT_PER_ITER, CMD_CONFIG_TOTAL_CTRL_COUNT]:
      packets.append(packet(command, tile, len(programs[tile])))
      descriptions.append(f"tile{tile} command{command} count {len(programs[tile])}")
    for address, ctrl in enumerate(programs[tile]):
      packets.append(packet(CMD_CONFIG, tile, ctrl=ctrl, ctrl_addr=address))
      descriptions.append(f"tile{tile} ctrl{address} operation {int(ctrl.operation)}")
  for tile in [2, 3, 1, 0]:
    packets.append(packet(CMD_LAUNCH, tile))
    descriptions.append(f"launch tile{tile}")
  queries = [packet(CMD_LOAD_REQUEST, address=16), packet(CMD_LOAD_REQUEST, address=15)]
  entries = [{"index": i, "description": d, "hex": hex_bits(p)}
             for i, (p, d) in enumerate(zip(packets, descriptions))]
  entries += [{"index": len(packets) + i,
               "description": f"after all 4 completions query address {int(p.payload.data_addr)}",
               "hex": hex_bits(p)} for i, p in enumerate(queries)]
  return packets, queries, entries


def snapshot(dut):
  inputs = {"reset": int(dut.reset), "cgra_id": int(dut.cgra_id),
    "address_lower": int(dut.address_lower), "address_upper": int(dut.address_upper),
    "recv_from_cpu_pkt__val": int(dut.recv_from_cpu_pkt.val),
    "recv_from_cpu_pkt__msg": hex_bits(dut.recv_from_cpu_pkt.msg),
    "send_to_cpu_pkt__rdy": int(dut.send_to_cpu_pkt.rdy)}
  outputs = {"recv_from_cpu_pkt__rdy": int(dut.recv_from_cpu_pkt.rdy),
    "send_to_cpu_pkt__val": int(dut.send_to_cpu_pkt.val),
    "send_to_cpu_pkt__msg": hex_bits(dut.send_to_cpu_pkt.msg)}
  for direction in DIRECTIONS:
    for i in range(2):
      recv = getattr(dut, f"recv_data_on_boundary_{direction}")[i]
      send = getattr(dut, f"send_data_on_boundary_{direction}")[i]
      base = f"recv_data_on_boundary_{direction}__{i}__"
      inputs[base + "val"] = int(recv.val)
      inputs[base + "msg"] = hex_bits(recv.msg)
      outputs[base + "rdy"] = int(recv.rdy)
      base = f"send_data_on_boundary_{direction}__{i}__"
      inputs[base + "rdy"] = int(send.rdy)
      outputs[base + "val"] = int(send.val)
      outputs[base + "msg"] = hex_bits(send.msg)
  return inputs, outputs


def scalar(value):
  return int(value.payload), int(value.predicate)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--output", type=Path, default=ROOT / "sv/vectors")
  parser.add_argument("--max-cycles", type=int, default=2000)
  args = parser.parse_args()
  output = args.output.resolve()
  output.mkdir(parents=True, exist_ok=True)
  if (output / "baseline_trace.jsonl").exists():
    parser.error("Trace already exists; use a fresh --output directory.")
  scenarios = [{"name": "positive", "input": 7, "expected": 28},
               {"name": "negative_after_reset", "input": 0xfffffffa, "expected": 0xfffffff5}]
  configs = []
  for scenario in scenarios:
    packets, queries, entries = configuration(scenario["input"])
    configs.append({**scenario, "configuration_count": len(packets), "packets": entries})
  (output / "configuration.json").write_text(json.dumps({
    "baseline_commit": BASELINE, "top": TOP, "host_packet_nbits": HostPacketType.nbits,
    "program": "T0 LD[15] -> east T1 ADD5 -> north T3 MUL3 -> west T2 ADD(-8) -> south T0 ST[16]; T2 also multicasts west",
    "scenarios": configs}, indent=2) + "\n")
  for scenario in configs:
    (output / (scenario["name"] + "_packets.hex")).write_text(
      "\n".join(p["hex"] for p in scenario["packets"]) + "\n")
  dut = make_design()
  dut.elaborate()
  dut.apply(DefaultPassGroup())
  dut.cgra_id @= 0
  dut.address_lower @= 0
  dut.address_upper @= 31
  dut.recv_from_inter_cgra_noc.val @= 0
  dut.recv_from_inter_cgra_noc.msg @= NocPacketType()
  dut.send_to_inter_cgra_noc.rdy @= 0
  for direction in DIRECTIONS:
    for i in range(2):
      recv = getattr(dut, f"recv_data_on_boundary_{direction}")[i]
      send = getattr(dut, f"send_data_on_boundary_{direction}")[i]
      recv.val @= 0
      recv.msg @= DataType()
      send.rdy @= 1
  trace = []
  results = []
  link_map = [(0, 3, 1, "east"), (1, 0, 3, "north"),
              (3, 2, 2, "west"), (2, 1, 0, "south")]
  for scenario in scenarios:
    packets, queries, _ = configuration(scenario["input"])
    source_index = 0
    query_index = 0
    completions = []
    responses = []
    west_events = []
    link_events = []
    host_hold = 0
    west_hold = 0
    done_cycle = None
    dut.recv_from_cpu_pkt.val @= 0
    dut.recv_from_cpu_pkt.msg @= HostPacketType()
    dut.send_to_cpu_pkt.rdy @= 0
    dut.send_data_on_boundary_west[1].rdy @= 0
    dut.reset @= 1
    for reset_cycle in range(3):
      dut.sim_eval_combinational()
      inputs, outputs = snapshot(dut)
      trace.append({"scenario": scenario["name"], "cycle": reset_cycle - 3,
                    "inputs": inputs, "outputs": outputs})
      dut.sim_tick()
    dut.reset @= 0
    for cycle in range(args.max_cycles):
      querying = source_index == len(packets) and len(completions) == 4
      active = packets[source_index] if source_index < len(packets) else (
        queries[query_index] if querying and query_index < len(queries) else None)
      dut.recv_from_cpu_pkt.val @= int(active is not None)
      dut.recv_from_cpu_pkt.msg @= active if active is not None else HostPacketType()
      dut.send_to_cpu_pkt.rdy @= int(host_hold >= 6 and cycle % 7 >= 2)
      dut.send_data_on_boundary_west[1].rdy @= int(west_hold >= 8)
      dut.sim_eval_combinational()
      inputs, outputs = snapshot(dut)
      trace.append({"scenario": scenario["name"], "cycle": cycle,
                    "inputs": inputs, "outputs": outputs})
      if active is not None and dut.recv_from_cpu_pkt.rdy:
        if querying:
          query_index += 1
        else:
          source_index += 1
      if dut.send_to_cpu_pkt.val:
        if host_hold < 6:
          host_hold += 1
        if dut.send_to_cpu_pkt.rdy:
          pkt = dut.send_to_cpu_pkt.msg
          if pkt.payload.cmd == CMD_COMPLETE:
            tile = int(pkt.src)
            assert tile not in completions and int(pkt.dst) == 4, str(pkt)
            completions.append(tile)
          else:
            assert pkt.payload.cmd == CMD_LOAD_RESPONSE, str(pkt)
            responses.append({"cycle": cycle, "address": int(pkt.payload.data_addr),
              "data": int(pkt.payload.data.payload), "predicate": int(pkt.payload.data.predicate),
              "hex": hex_bits(pkt)})
      west = dut.send_data_on_boundary_west[1]
      if west.val:
        if west_hold < 8:
          west_hold += 1
        if west.rdy:
          assert scalar(west.msg) == (scenario["expected"], 1), str(west.msg)
          west_events.append({"cycle": cycle, "data": int(west.msg.payload)})
      for direction in DIRECTIONS:
        for i in range(2):
          if (direction, i) != ("west", 1):
            send = getattr(dut, f"send_data_on_boundary_{direction}")[i]
            assert not send.val, (scenario["name"], cycle, direction, i)
      for src, port, dst, direction in link_map:
        link = dut.tile[src].send_data[port]
        if link.val & link.rdy:
          link_events.append({"cycle": cycle, "src": src, "dst": dst,
            "direction": direction, "data": int(link.msg.payload), "predicate": int(link.msg.predicate)})
      if len(completions) == 4 and len(responses) == 2 and len(west_events) == 1:
        if done_cycle is None:
          done_cycle = cycle
        if cycle >= done_cycle + 8:
          dut.sim_tick()
          break
      dut.sim_tick()
    else:
      debug = {"scenario": scenario, "source_index": source_index, "query_index": query_index,
        "completions": completions, "responses": responses, "west_events": west_events,
        "link_events": link_events,
        "tiles": [tile.line_trace() for tile in dut.tile]}
      (output / "failure.json").write_text(json.dumps(debug, indent=2) + "\n")
      raise RuntimeError(f"Reference stalled after {args.max_cycles} cycles; see {output / 'failure.json'}")
    assert sorted(completions) == [0, 1, 2, 3]
    assert [(r["data"], r["predicate"]) for r in responses] == [
      (scenario["expected"], 1), (scenario["input"], 1)], responses
    assert len(west_events) == 1, west_events
    assert Counter((e["src"], e["dst"]) for e in link_events) == Counter({(0, 1): 1, (1, 3): 1, (3, 2): 1, (2, 0): 1}), link_events
    results.append({**scenario, "cycles_after_reset": cycle + 1,
      "completion_order": completions, "responses": responses,
      "west_events": west_events, "link_events": link_events,
      "host_initial_backpressure_valid_cycles": host_hold,
      "west_initial_backpressure_valid_cycles": west_hold})
    print(json.dumps(results[-1]), flush=True)
  (output / "baseline_trace.jsonl").write_text(
    "".join(json.dumps(row, separators=(",", ":")) + "\n" for row in trace))
  trace_digest = hashlib.sha256((output / "baseline_trace.jsonl").read_bytes()).hexdigest()
  manifest = {"baseline_commit": BASELINE, "top": TOP,
    "trace_file": "baseline_trace.jsonl", "trace_sha256": trace_digest,
    "sample_phase": "After driving inputs and evaluating combinational logic, immediately before rising edge",
    "reset": "Three explicit rising edges per scenario; second scenario reuses same model and resets/reconfigures it",
    "comparison_contract": "These are Python-reference observations, not evidence that HDL replay has passed. All active output bits including idle msg are recorded for full replay. Inactive inter-CGRA ports are excluded because baseline leaves them undriven. Any narrower cross-language valid-only check is limited functional evidence, not a replacement for the migration's full active-output cycle contract. PyMTL is two-state; HDL X/uninitialized-memory behavior is not established by this trace.",
    "input_policy": "No boundary inputs; other seven boundary sinks ready=1; west[1] stalls first eight valid cycles; CPU stalls first six valid cycles then ready=(cycle%7>=2). Host request is held until accepted. Queries start after all four completions.",
    "trace_rows": len(trace), "scenarios": results,
    "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "reference_rtl_sha256": hashlib.sha256((ROOT / f"sv/reference/{TOP}.v").read_bytes()).hexdigest(),
    "python_executable": sys.executable,
  }
  (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
  print(f"Wrote {len(trace)} cycle snapshots to {output}")


if __name__ == "__main__":
  main()
