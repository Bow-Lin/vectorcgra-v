"""Run external architecture/program files on unmodified, SHA-pinned Python RTL.

Original constructors and set_param select hardware. No replacement update block,
internal state write, reference-output patch, or generated Verilog is used.
"""
import argparse
import importlib
import json
from pathlib import Path
import sys
import time
import traceback
import types

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'sv/tests/parameterization'))
from common import python_hashes, program, write_json, sha
from oracle import check


def build(entry):
  from pymtl3 import mk_bits
  from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt
  from VectorCGRA.fu.flexible.FlexibleFuRTL import FlexibleFuRTL
  config = entry['normalized']; p = config['parameters']; aa = config['architectures']
  names = {'ADDER':'AdderRTL', 'MUL':'MulRTL', 'CONST':'ConstRTL',
           'MEM':'MemUnitRTL','STREAMING_MEM':'StreamingMemUnitRTL','NAH':'NahRTL'}
  def fus(names_):
    return [getattr(importlib.import_module('VectorCGRA.fu.single.'+names[n]),names[n]) for n in names_]
  Data = mk_data(p['DATA_W'],1)
  Ctrl = mk_ctrl(4,2,p['TILE_PORTS'],p['TILE_PORTS'],p['REG_DEPTH'])
  Payload = mk_cgra_payload(Data,mk_bits(p['GLOBAL_ADDR_W']),Ctrl,
                             mk_bits((p['CTRL_DEPTH']-1).bit_length()))
  Host = mk_intra_cgra_pkt(p['MULTI_COLS'],p['MULTI_ROWS'],p['MAX_COLS']*p['MAX_ROWS'],Payload)
  assert Host.nbits==config['widths']['HOST_BITS']
  capacity = p['BANK_DEPTH']*p['NUM_BANKS']; count = len(aa)
  address_map = {owner:[slot*capacity,(slot+1)*capacity-1]
                 for slot,owner in enumerate(config['address_map'])}
  coords = {c:(c%p['MULTI_COLS'],c//p['MULTI_COLS']) for c in range(count)}
  storage = [p['CTRL_DEPTH'],1<<p['GLOBAL_ADDR_W'],p['BANK_DEPTH'],p['NUM_BANKS'],
             p['REG_DEPTH'],p['NUM_CTRL'],p['TOTAL_STEPS']]
  template = entry['python_model']=='template'
  if template:
    from VectorCGRA.lib.util.cgra.Tile import Tile
    from VectorCGRA.lib.util.cgra.Link import Link
    from VectorCGRA.lib.util.cgra.DataSPM import DataSPM
    fu_alias = {'ADDER':'add','MUL':'mul','CONST':'constant','MEM':'mem','NAH':None}
    all_tiles = {}; all_links = {}; all_memory = {}
    for c,a in enumerate(aa):
      tiles = [Tile(t%a['cols'],t//a['cols'],p['REG_DEPTH'],
                    [fu_alias[f] for f in fs if fu_alias[f] is not None])
               for t,fs in enumerate(a['fu_names'])]
      links = []
      for edge in a['links']:
        link = Link(tiles[edge['src']],tiles[edge['dst']],edge['sp'],edge['dp'])
        link.disabled = not edge['enabled'];link.validatePorts();links.append(link)
      for direction, ports in [('read',a['read_ports']),('write',a['write_ports'])]:
        for port,t in enumerate(ports):
          if t==0xffffffff: continue
          # Memory signals are dedicated ports; the original graph helper also
          # reserves an unused cardinal routing pin. Custom graphs use south.
          side = (2 if t%a['cols']==0 else 1) if count>1 else 1
          link = Link(None,tiles[t],port,side) if direction=='read' else Link(tiles[t],None,side,port)
          link.fromMem=direction=='read';link.toMem=direction=='write';link.memPort=port
          # Mark the dedicated memory relation independently of routing: the
          # graph's explicit routing masks remain authoritative.
          if direction=='read': tiles[t].fromMem=True
          else: tiles[t].toMem=True
          links.append(link)
      for t,tile in enumerate(tiles):
        for side in range(p['TILE_PORTS']):
          if a['boundary_in'][t] & (1<<side): tile.invalidInPorts.discard(side)
          if a['boundary_out'][t] & (1<<side): tile.invalidOutPorts.discard(side)
      all_tiles[c]=tiles;all_links[c]=links
      all_memory[c]=DataSPM(len(a['read_ports']),len(a['write_ports']))
    if count==1:
      from VectorCGRA.cgra.CgraTemplateRTL import CgraTemplateRTL
      dut = CgraTemplateRTL(Payload,1,1,aa[0]['rows'],aa[0]['cols'],*storage,
          bool(p['MEM_COMBINATIONAL']),FlexibleFuRTL,[],all_tiles[0],all_links[0],all_memory[0],
          address_map,coords,is_multi_cgra=False,
          provided_max_per_cgra_rows=p['MAX_ROWS'],provided_max_per_cgra_cols=p['MAX_COLS'],
          provided_max_num_rd_tiles=p['MAX_MEM_PORTS'],provided_max_num_wr_tiles=p['MEM_WRITE_PORTS'])
    else:
      from VectorCGRA.multi_cgra.MeshMultiCgraTemplateRTL import MeshMultiCgraTemplateRTL
      dut = MeshMultiCgraTemplateRTL(Payload,p['MULTI_ROWS'],p['MULTI_COLS'],*storage,
        FlexibleFuRTL,[],address_map,{c:p['CTRL_DEPTH'] for c in range(count)},
        {c:[a['rows'],a['cols']] for c,a in enumerate(aa)},all_tiles,all_links,all_memory,
        bool(p['MEM_COMBINATIONAL']),True)
  elif count>1:
    assert config['topology']=='ring'
    from VectorCGRA.multi_cgra.RingMultiCgraRTL import RingMultiCgraRTL
    dut = RingMultiCgraRTL(Payload,p['MULTI_ROWS'],p['MULTI_COLS'],aa[0]['rows'],aa[0]['cols'],
        *storage,bool(p['MEM_COMBINATIONAL']),FlexibleFuRTL,fus(aa[0]['fu_names'][0]),address_map)
  else:
    model = {'base':'CgraRTL','context':'CgraWithContextSwitchRTL','streaming':'CgraWithStreamingLoadRTL'}[config['variant']]
    cls = getattr(importlib.import_module('VectorCGRA.cgra.'+model),model)
    dut = cls(Payload,1,1,aa[0]['cols'],aa[0]['rows'],*storage,bool(p['MEM_COMBINATIONAL']),
        FlexibleFuRTL,fus(aa[0]['fu_names'][0]),'Mesh' if p['TILE_PORTS']==4 else 'KingMesh',
        address_map,coords,is_multi_cgra=False)
  # This is the same public PyMTL parameter mechanism used by CgraRTL_test.py.
  # In particular it preserves the explicitly ordered FU list instead of the
  # template helper's set-based ordering. All FU implementations remain original.
  for c,a in enumerate(aa):
    for t,fs in enumerate(a['fu_names']):
      path = f'top.cgra[{c}].tile[{t}].construct' if count>1 else f'top.tile[{t}].construct'
      dut.set_param(path,FuList=fus(fs))
  dut.elaborate()
  structure=[]
  for c,a in enumerate(aa):
    system = dut.cgra[c] if count>1 else dut
    assert len(system.tile)==a['cols']*a['rows']
    for t,tile in enumerate(system.tile):
      actual = [type(f).__name__ for f in tile.element.fu]
      assert actual==[names[n] for n in a['fu_names'][t]], (c,t,actual,a['fu_names'][t])
      structure.append(dict(cgra=c,tile=t,fus=actual))
  return dut, Host, Data, structure


def simulate(dut, Host, Data, entry, case, schedule):
  from pymtl3 import DefaultPassGroup, mk_bits
  config = entry['normalized']; p = config['parameters']; count = len(config['architectures'])
  packets = [Host.from_bits(mk_bits(Host.nbits)(int(line,16)))
             for line in (case/'program.hex').read_text().splitlines()]
  barriers = [tuple(map(int,line.split())) for line in (case/'barriers.txt').read_text().splitlines()]
  boundary = [(int(line.split()[0]),int(line.split()[1],16))
              for line in (case/'boundary.txt').read_text().splitlines()]
  spec = json.loads((case/'specification.json').read_text())
  dut.apply(DefaultPassGroup(linetrace=False))
  boundary_in=[];boundary_out=[]
  if count==1:
    for side in ['north','south','west','east']:
      if hasattr(dut,'recv_data_on_boundary_'+side):
        boundary_in.extend(getattr(dut,'recv_data_on_boundary_'+side))
        boundary_out.extend(getattr(dut,'send_data_on_boundary_'+side))
    dut.cgra_id @= 0;dut.address_lower @= 0;dut.address_upper @= p['NUM_BANKS']*p['BANK_DEPTH']-1
    dut.recv_from_inter_cgra_noc.val @= 0
    dut.recv_from_inter_cgra_noc.msg @= type(dut.recv_from_inter_cgra_noc.msg)()
    dut.send_to_inter_cgra_noc.rdy @= 0
  dut.recv_from_cpu_pkt.val @= 0;dut.recv_from_cpu_pkt.msg @= Host();dut.send_to_cpu_pkt.rdy @= 0
  for interface in boundary_in: interface.val @= 0;interface.msg @= Data()
  for interface in boundary_out: interface.rdy @= 0
  dut.reset @= 1
  for _ in range(3): dut.sim_tick()
  dut.reset @= 0
  pi=bi=xi=complete=reads=boundary_outputs=outstanding=hold=0
  pending=False; rng=schedule or 1; done=None; trace=[]
  # The native transport checks stall stability; the reference is compared at
  # accepted transactions because legacy arbitration can change while stalled.
  for cycle in range(20000):
    rng ^= (rng<<13)&0xffffffff; rng ^= rng>>17; rng ^= (rng<<5)&0xffffffff
    while bi<len(barriers) and pi>=barriers[bi][0] and complete>=barriers[bi][1]: bi+=1
    if not pending and pi<len(packets) and not(bi<len(barriers) and pi>=barriers[bi][0]) and (
        int(packets[pi].payload.cmd)!=10 or outstanding==0) and (schedule==0 or rng&7): pending=True
    dut.recv_from_cpu_pkt.val @= int(pending)
    dut.recv_from_cpu_pkt.msg @= packets[pi] if pi<len(packets) else Host()
    dut.send_to_cpu_pkt.rdy @= int(bool(schedule==0 or (hold>=8 and (rng>>3)&3)))
    for port,interface in enumerate(boundary_in):
      interface.val @= int(xi<len(boundary) and boundary[xi][0]==port)
      interface.msg @= Data.from_bits(mk_bits(Data.nbits)(boundary[xi][1])) if xi<len(boundary) else Data()
    for interface in boundary_out: interface.rdy @= int(bool(schedule==0 or (rng>>5)&3))
    dut.sim_eval_combinational()
    if pending and dut.recv_from_cpu_pkt.rdy:
      if int(packets[pi].payload.cmd)==10: outstanding+=1
      pi+=1;pending=False
    if xi<len(boundary) and boundary_in[boundary[xi][0]].rdy: xi+=1
    if dut.send_to_cpu_pkt.val:
      if not dut.send_to_cpu_pkt.rdy: hold+=1
      else:
        packet = dut.send_to_cpu_pkt.msg
        cmd = int(packet.payload.cmd)
        if cmd==14: complete+=1
        elif cmd==11: reads+=1;outstanding-=1
        else: raise AssertionError('Unexpected original host command '+str(cmd))
        trace.append(f'H {cycle} {int(packet.to_bits()):x}')
    for port,interface in enumerate(boundary_out):
      if interface.val and interface.rdy:
        boundary_outputs+=1;trace.append(f'B {cycle} {port} {int(interface.msg.to_bits()):x}')
    dut.sim_tick()
    if pi==len(packets) and bi==len(barriers) and xi==len(boundary) and complete==len(spec['expected_completions']) and reads==spec['capacity']*count and boundary_outputs==int(spec['streaming']):
      if done is None: done=cycle
      if cycle>=done+32: break
  path = case/'python_trace.txt';path.write_text('\n'.join(trace)+'\n')
  assert done is not None and cycle<19999, f'PYTHON_TIMEOUT sent={pi}/{len(packets)} complete={complete} reads={reads} boundary={boundary_outputs}'
  observed = check(entry,spec,path)
  native = check(entry,spec,case/f'trace_{schedule}.txt')
  assert observed==native, 'PYTHON_SV_ACCEPTED_PACKETS_DIFFER'
  return dict(cycles=cycle,observations=observed,trace_sha256=sha(path))


def main():
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--architecture',required=True,type=Path)
  parser.add_argument('--case',required=True,type=Path)
  parser.add_argument('--schedule',type=int,default=37)
  parser.add_argument('--fresh',action='store_true',help='Ignore an identical, verified reference from this tool')
  args=parser.parse_args(); start=time.monotonic();pin=python_hashes()
  pkg=types.ModuleType('VectorCGRA');pkg.__path__=[str(ROOT)];sys.modules['VectorCGRA']=pkg
  entry=json.loads(args.architecture.read_text())
  result=dict(status='failed',python_target=pin['python_target_commit'],source_files_checked=len(pin['source_sha256']),
      architecture_sha256=sha(args.architecture),program_sha256=sha(args.case/'program.hex'),
      specification_sha256=sha(args.case/'specification.json'),reference_tool_sha256=sha(__file__),
      schedule=args.schedule,reused_reference=False,
      comparison='full accepted packets; independent completion order; serialized reads')
  previous=args.case/'python_result.json'
  if previous.exists() and not args.fresh:
    old=json.loads(previous.read_text())
    keys=['python_target','architecture_sha256','program_sha256','specification_sha256',
          'reference_tool_sha256','schedule']
    if old.get('status')=='passed' and all(old.get(k)==result[k] for k in keys):
      path=args.case/'python_trace.txt'
      assert sha(path)==old['trace_sha256'], 'Corrupted cached Python trace'
      spec=json.loads((args.case/'specification.json').read_text())
      assert check(entry,spec,path)==check(entry,spec,args.case/f'trace_{args.schedule}.txt')
      old['reused_reference']=True;write_json(previous,old)
      print('PARAM_PYTHON_REUSED verified original sources, architecture, program, trace and current native result',flush=True)
      return 0
  try:
    dut,Host,Data,structure=build(entry);result['structure']=structure
    result.update(simulate(dut,Host,Data,entry,args.case,args.schedule));result['status']='passed'
  except Exception:
    result['failure']=traceback.format_exc();print(result['failure'],flush=True)
  python_hashes();result['seconds']=round(time.monotonic()-start,3)
  write_json(args.case/'python_result.json',result)
  print('PARAM_PYTHON_RESULT',result['status'],flush=True)
  return 0 if result['status']=='passed' else 1


if __name__=='__main__': sys.exit(main())
