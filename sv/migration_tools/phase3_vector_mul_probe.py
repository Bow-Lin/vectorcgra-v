"""Record the original Python side of the VectorMulCombo shift discrepancy."""
import hashlib
import json
from pathlib import Path
from reference_model import ROOT, BASELINE
from pymtl3 import DefaultPassGroup, mk_bits
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt
from VectorCGRA.fu.vector.VectorMulComboRTL import VectorMulComboRTL

Data = mk_data(32, 1)
Ctrl = mk_ctrl(4, 2, 4, 4, 16)
Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(3))
Packet = mk_intra_cgra_pkt(1, 1, 4, Payload)
dut = VectorMulComboRTL(Packet, 4, 2, 0, 4)
dut.apply(DefaultPassGroup())
dut.clear @= 0
dut.ctrl_addr_inport @= 0
dut.recv_const.msg @= Data()
dut.recv_const.val @= 0
dut.recv_from_ctrl_mem.msg @= Payload()
dut.recv_from_ctrl_mem.val @= 0
dut.send_to_ctrl_mem.rdy @= 1
dut.from_mem_rdata.msg @= Data()
dut.from_mem_rdata.val @= 0
dut.to_mem_raddr.rdy @= 1
dut.to_mem_waddr.rdy @= 1
dut.to_mem_wdata.rdy @= 1
for p in dut.send_out:
  p.rdy @= 1
dut.sim_reset()
records = []
for operation, a, b in [(75, 256, 256), (75, 0xffffffff, 0xffffffff), (55, 0xffffffff, 0xffffffff)]:
  control = Ctrl()
  control.operation = mk_bits(7)(operation)
  dut.recv_opt.msg @= control
  dut.recv_opt.val @= 1
  for i, p in enumerate(dut.recv_in):
    p.msg @= Data(a if i == 0 else b if i == 1 else 0, 1)
    p.val @= 1
  dut.sim_eval_combinational()
  records.append(dict(operation=operation, a=f'{a:08x}', b=f'{b:08x}',
    python_payload=f'{int(dut.send_out[0].msg.payload):08x}', python_val=int(dut.send_out[0].val)))
source = ROOT/'fu/vector/VectorMulComboRTL.py'
report = dict(baseline_commit=BASELINE, source=str(source.relative_to(ROOT)),
  source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), records=records,
  oracle='translated_hdl', python_equivalence=False,
  reason='RTLIR gives shift-count multiplication the literal operand width; Python uses full integer multiplication.')
dest = ROOT/'sv/tests/phase3/vector_combo/python_hdl_discrepancy.json'
dest.write_text(json.dumps(report, indent=2)+'\n', newline='\n')
print(json.dumps(report, indent=2))
