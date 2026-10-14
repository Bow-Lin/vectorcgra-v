"""Complete a bounded remote-memory program on the original Ring architecture.

This is a supplementary program, not a changed claim about test_homo_1x4.
The original program's all-tile-zero addressing and unseeded routes stay frozen.
"""
import argparse
from collections import Counter
import importlib
import json
from pathlib import Path
import sys
import types
import traceback

from original_test_capture import Capture, ROOT, digest


def main():
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output',type=Path,required=True)
  parser.add_argument('--seed',type=int,default=3)
  args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
  pin=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for name,expected in pin['source_sha256'].items():assert digest(ROOT/name)==expected
  pkg=types.ModuleType('VectorCGRA');pkg.__path__=[str(ROOT)];sys.modules['VectorCGRA']=pkg
  mod=importlib.import_module('VectorCGRA.multi_cgra.test.RingMultiCgraRTL_test')
  from pymtl3 import DefaultPassGroup
  # Let the untouched original function construct its exact packet types and
  # architecture arguments; intercept before constructing its weak harness.
  captured=[]
  class Stop(Exception):pass
  class Arguments:
    def __init__(self,*values):captured.extend(values);raise Stop()
  mod.TestHarness=Arguments
  try:mod.test_homo_1x4({})
  except Stop:pass
  a=captured;assert len(a)==18
  DUT,FU,FuList,Packet=a[:4]
  Payload=Packet.get_field_type('payload');Data=Payload.get_field_type('data')
  Ctrl=Payload.get_field_type('ctrl')
  dut=DUT(Payload,a[4],a[5],a[7],a[6],a[8],a[9],a[10],a[11],a[12],a[14],a[14],a[15],FU,FuList,a[16])
  dut.elaborate()
  capture=Capture(dut,args.output/'dut000')
  assert capture.layout, 'Capture must bind ports before simulation locks them'
  capture.meta['reference_variant']='supplemental_ring_remote_program'
  dut.apply(DefaultPassGroup(linetrace=False))
  trace=[];cycle=0
  def tick():
    nonlocal cycle
    dut.sim_eval_combinational();capture.sample()
    if not dut.reset and dut.send_to_cpu_pkt.val and dut.send_to_cpu_pkt.rdy:
      trace.append(int(dut.send_to_cpu_pkt.msg.to_bits()))
    dut.sim_tick();cycle+=1
    assert cycle<1500,'Ring supplementary program timed out'
  def send(packet):
    dut.recv_from_cpu_pkt.msg @= packet;dut.recv_from_cpu_pkt.val @= 1
    while True:
      dut.sim_eval_combinational();accepted=bool(dut.recv_from_cpu_pkt.rdy);tick()
      if accepted:break
    dut.recv_from_cpu_pkt.val @= 0
  def packet(cmd,addr=0,data=0,ctrl=None,pc=0):
    payload=Payload(cmd=cmd,data=Data(data,1),data_addr=addr,ctrl_addr=pc)
    if ctrl is not None:payload.ctrl=ctrl
    return Packet(payload=payload)
  def control(op,read=False,write=False):
    c=Ctrl();c.operation=op
    c.fu_in[0]=type(c.fu_in[0])(1);c.fu_in[1]=type(c.fu_in[1])(1)
    if read:c.read_reg_towards[0]=type(c.read_reg_towards[0])(1)
    if write:
      c.fu_xbar_outport[4]=type(c.fu_xbar_outport[4])(1)
      c.write_reg_from[0]=type(c.write_reg_from[0])(2)
    return c
  result=dict(status='running',source_sha256=pin['source_sha256']['multi_cgra/test/RingMultiCgraRTL_test.py'],
    python_target=pin['python_target_commit'],source_files_checked=len(pin['source_sha256']),
    reference_variant='supplemental_ring_remote_program',captures=['dut000'],
    description='CGRA0 tile0 loads CGRA3 address24, computes 4*(seed+2), stores address25, completes, then host reads address25',seed=args.seed)
  original_config=[p for p in a[13] if int(p.payload.cmd)==int(mod.CMD_CONFIG)]
  original_launch=[p for p in a[13] if int(p.payload.cmd)==int(mod.CMD_LAUNCH)]
  first=original_config[0].payload.ctrl
  result['original_program_diagnosis']=dict(
    configuration_destinations=dict(Counter(int(p.dst) for p in original_config)),
    launch_destinations=dict(Counter(int(p.dst) for p in original_launch)),
    first_fu_selectors=[int(x) for x in first.fu_in],
    first_routing_to_operands=[int(x) for x in first.routing_xbar_outport[4:]],
    first_register_read_directions=[int(x) for x in first.read_reg_towards],
    explanation='All four copied programs target tile0; the first INC has neither an operand route nor an enabled register read.')
  try:
    dut.recv_from_cpu_pkt.val @= 0;dut.recv_from_cpu_pkt.msg @= Packet();dut.send_to_cpu_pkt.rdy @= 1
    dut.reset @= 1
    for _ in range(3):tick()
    dut.reset @= 0
    send(packet(mod.CMD_STORE_REQUEST,addr=24,data=args.seed))
    send(packet(mod.CMD_STORE_REQUEST,addr=25,data=0x5a5a))
    send(packet(mod.CMD_CONST,data=24));send(packet(mod.CMD_CONST,data=25))
    program=[control(mod.OPT_LD_CONST,write=True),control(mod.OPT_INC,True,True),
      control(mod.OPT_INC,True,True),control(mod.OPT_ADD,True,True),
      control(mod.OPT_ADD,True,True),control(mod.OPT_STR_CONST,True)]
    for pc,c in enumerate(program):send(packet(mod.CMD_CONFIG,ctrl=c,pc=pc))
    send(packet(mod.CMD_LAUNCH))
    while not trace:tick()
    complete=Packet(dst=4,payload=Payload(cmd=mod.CMD_COMPLETE))
    # Compare the full completion packet, including source, destination, VC and payload.
    assert trace==[int(complete.to_bits())],f'Unexpected completion: {trace}'
    send(packet(mod.CMD_LOAD_REQUEST,addr=25))
    while len(trace)<2:tick()
    response=Packet.from_bits(mod.mk_bits(Packet.nbits)(trace[1]))
    assert int(response.payload.cmd)==int(mod.CMD_LOAD_RESPONSE)
    assert int(response.payload.data.payload)==(4*(args.seed+2))&0xffffffff
    for _ in range(16):tick()
    assert len(trace)==2,'Duplicate Ring output'
    result.update(status='passed',cycles=cycle,expected_value=(4*(args.seed+2))&0xffffffff,output_words=[hex(x) for x in trace])
  except Exception as error:
    result.update(status='failed',error=repr(error),traceback=traceback.format_exc(),cycles=cycle)
  finally:
    capture.close()
    for name,expected in pin['source_sha256'].items():assert digest(ROOT/name)==expected
    (args.output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps(result,indent=2))
  return int(result['status']!='passed')


if __name__=='__main__':raise SystemExit(main())
