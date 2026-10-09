"""Derive SV-readable fixed replay files and independent packet packing samples."""

import argparse
import hashlib
import json
from pathlib import Path

from pymtl3 import mk_bits
from reference_model import ROOT, DataType, CtrlType, PayloadType, HostPacketType, hex_bits


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--vectors", type=Path, default=ROOT / "sv/vectors")
  args = parser.parse_args()
  output = args.vectors.resolve()
  rows = [json.loads(line) for line in (output / "baseline_trace.jsonl").read_text().splitlines()]
  layouts = {}
  for side in ["inputs", "outputs"]:
    fields = []
    offset = 0
    for name in rows[0][side]:
      width = 191 if name.endswith("__msg") and "cpu_pkt" in name else (
        35 if name.endswith("__msg") else (7 if name.startswith("address_") else 1))
      fields.append({"field": name, "lsb": offset, "msb": offset + width - 1, "nbits": width})
      offset += width
    encoded = []
    for row in rows:
      packed = 0
      for field in fields:
        raw = row[side][field["field"]]
        value = int(raw, 16) if isinstance(raw, str) else raw
        assert 0 <= value < (1 << field["nbits"])
        packed |= value << field["lsb"]
      encoded.append(format(packed, f"0{(offset + 3) // 4}x"))
    path = output / f"replay_{side}.hex"
    path.write_text("\n".join(encoded) + "\n")
    layouts[side] = {"file": path.name, "nbits": offset, "fields": fields,
      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
  (output / "replay_layout.json").write_text(json.dumps({
    "samples": len(rows), "sample_phase": "drive inputs, settle combinational logic, compare immediately before rising edge",
    "comparison": "All active raw output bits are present including idle messages. No HDL replay result is claimed by this encoding tool.",
    "excluded_outputs": ["recv_from_inter_cgra_noc__rdy", "send_to_inter_cgra_noc__val", "send_to_inter_cgra_noc__msg"],
    "fixed_inputs_not_encoded": {"recv_from_inter_cgra_noc__val": 0, "recv_from_inter_cgra_noc__msg": 0, "send_to_inter_cgra_noc__rdy": 0},
    "source_trace_sha256": hashlib.sha256((output / "baseline_trace.jsonl").read_bytes()).hexdigest(),
    "layouts": layouts, "row_labels": [{"scenario": r["scenario"], "cycle": r["cycle"]} for r in rows],
  }, indent=2) + "\n")

  data_fields = {"payload": 0x89abcdef, "predicate": 1, "bypass": 1, "delay": 1}
  ctrl_fields = {"operation": 0x55, "fu_in": [1, 2, 3, 4],
    "routing_xbar_outport": [1, 2, 3, 4, 5, 6, 7, 8],
    "fu_xbar_outport": [1, 2, 3, 1, 2, 3, 1, 2],
    "vector_factor_power": 3, "is_last_ctrl": 1,
    "write_reg_from": [1, 2, 3, 2], "write_reg_idx": [1, 3, 7, 15],
    "read_reg_towards": [3, 2, 1, 2], "read_reg_idx": [2, 4, 8, 14]}
  encoded_fields = {}
  for name, value in ctrl_fields.items():
    if isinstance(value, list):
      width = CtrlType.__bitstruct_fields__[name][0].nbits
      encoded_fields[name] = [mk_bits(width)(v) for v in value]
    else:
      encoded_fields[name] = value
  data = DataType(**data_fields)
  ctrl = CtrlType(**encoded_fields)
  payload_fields = {"cmd": 0x2d, "data": data_fields, "data_addr": 0x65,
                    "ctrl": ctrl_fields, "ctrl_addr": 5}
  payload = PayloadType(cmd=0x2d, data=data, data_addr=0x65, ctrl=ctrl, ctrl_addr=5)
  host_fields = {"src": 3, "dst": 4, "src_cgra_id": 1, "dst_cgra_id": 1,
    "src_cgra_x": 1, "src_cgra_y": 1, "dst_cgra_x": 1, "dst_cgra_y": 1,
    "opaque": 0xa5, "vc_id": 1}
  host = HostPacketType(**host_fields, payload=payload)
  values = [("data", data, data_fields), ("control", ctrl, ctrl_fields),
            ("payload", payload, payload_fields), ("host_packet", host, {**host_fields, "payload": payload_fields})]
  samples = [{"type": name, "nbits": type(value).nbits, "fields": fields,
              "expected_hex": hex_bits(value)} for name, value, fields in values]
  (output / "type_vectors.json").write_text(json.dumps({
    "purpose": "Encoding-only nonzero field samples, not legal executable configuration. Every array index is nonzero and index 0 differs from the highest index; one-bit fields necessarily use 1.",
    "oracle": "Actual custom PyMTL3 bitstruct.to_bits() from the frozen ac96 type factories",
    "samples": samples}, indent=2) + "\n")
  print(json.dumps({"replay_samples": len(rows), "input_nbits": layouts["inputs"]["nbits"],
    "output_nbits": layouts["outputs"]["nbits"], "packing_samples":
    {s["type"]: s["expected_hex"] for s in samples}}))


if __name__ == "__main__":
  main()
