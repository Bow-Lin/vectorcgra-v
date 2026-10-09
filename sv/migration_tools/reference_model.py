"""Migration-only construction of the unmodified ac96 single-CGRA reference."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT.parent))

from pymtl3 import mk_bits
from VectorCGRA.cgra.CgraRTL import CgraRTL
from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
from VectorCGRA.fu.single.AdderRTL import AdderRTL
from VectorCGRA.fu.single.MulRTL import MulRTL
from VectorCGRA.fu.single.MemUnitRTL import MemUnitRTL
from VectorCGRA.fu.single.NahRTL import NahRTL
from VectorCGRA.lib.messages import (mk_data, mk_ctrl, mk_cgra_payload,
  mk_intra_cgra_pkt, mk_inter_cgra_pkt)

BASELINE = "ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b"
TOP = "VectorCGRA2x2Reference"
PARAMETERS = {
  "width": 2, "height": 2, "cgra_topology": "Mesh",
  "data_bitwidth": 32, "num_fu_inports": 4, "num_fu_outports": 2,
  "num_tile_inports": 4, "num_tile_outports": 4,
  "ctrl_mem_size": 8, "data_mem_size_global": 128,
  "data_mem_size_per_bank": 16, "num_banks_per_cgra": 2,
  "num_registers_per_reg_bank": 16, "num_ctrl": 8, "total_steps": 8,
  "multi_cgra_rows": 1, "multi_cgra_columns": 1,
  "is_multi_cgra": False, "has_ctrl_ring": True,
  "has_im2col_engine": False, "mem_access_is_combinational": True,
  "functional_units": ["AdderRTL", "MulRTL", "MemUnitRTL", "NahRTL"],
  "controller2addr_map": {"0": [0, 31]}, "idTo2d_map": {"0": [0, 0]},
}

DataType = mk_data(32, 1)
CtrlType = mk_ctrl(4, 2, 4, 4, 16)
PayloadType = mk_cgra_payload(DataType, mk_bits(7), CtrlType, mk_bits(3))
HostPacketType = mk_intra_cgra_pkt(1, 1, 4, PayloadType)
NocPacketType = mk_inter_cgra_pkt(1, 1, 4, 3, PayloadType)


def make_design():
  return CgraRTL(PayloadType, 1, 1, 2, 2, 8, 128, 16, 2, 16, 8, 8,
    True, FlexibleFuRTL, [AdderRTL, MulRTL, MemUnitRTL, NahRTL], "Mesh",
    {0: [0, 31]}, {0: [0, 0]}, is_multi_cgra=False,
    has_ctrl_ring=True, has_im2col_engine=False)


def hex_bits(value):
  bits = value.to_bits() if hasattr(value, "to_bits") else value
  return format(int(bits), f"0{(bits.nbits + 3) // 4}x")


def type_schema(Type):
  """Measure field positions through the reference packer, including arrays."""
  leaves = []
  def walk(value, path):
    if isinstance(value, list):
      for i, item in enumerate(value):
        walk(item, path + [i])
    elif hasattr(type(value), "__bitstruct_fields__"):
      for key in type(value).__bitstruct_fields__:
        walk(getattr(value, key), path + [key])
    else:
      obj = Type()
      parent = obj
      for part in path[:-1]:
        parent = parent[part] if isinstance(part, int) else getattr(parent, part)
      if isinstance(path[-1], int):
        parent[path[-1]] = type(value)(1)
      else:
        setattr(parent, path[-1], type(value)(1))
      packed = int(obj.to_bits())
      assert packed and not (packed & (packed - 1))
      offset = packed.bit_length() - 1
      name = "".join(f"[{p}]" if isinstance(p, int) else ("." if j else "") + p
                     for j, p in enumerate(path))
      leaves.append({"field": name, "lsb": offset, "msb": offset + value.nbits - 1,
                     "nbits": value.nbits})
  walk(Type(), [])
  assert sum(leaf["nbits"] for leaf in leaves) == Type.nbits
  return {"name": Type.__name__, "nbits": Type.nbits, "fields": leaves}
