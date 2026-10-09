"""One-time unmodified ac96 Mesh/Ring network HDL export and provenance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import traceback

from reference_model import ROOT, BASELINE, type_schema
from pymtl3 import mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass, VerilogPlaceholderPass
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_inter_cgra_pkt
from VectorCGRA.noc.PyOCN.pymtl3_net.meshnet.MeshNetworkRTL import MeshNetworkRTL
from VectorCGRA.noc.PyOCN.pymtl3_net.ringnet.RingNetworkRTL import RingNetworkRTL
from VectorCGRA.noc.PyOCN.pymtl3_net.ocnlib.ifcs.positions import mk_mesh_pos, mk_ring_pos

PROFILES = {
  'mesh_2x2_l0_w32': ('mesh', 2, 2, 0, 32),
  'mesh_2x2_l1_w32': ('mesh', 2, 2, 1, 32),
  'mesh_2x2_l2_w32': ('mesh', 2, 2, 2, 32),
  'mesh_3x2_l1_w64': ('mesh', 3, 2, 1, 64),
  'mesh_1x2_l1_w32': ('mesh', 1, 2, 1, 32),
  'mesh_2x1_l1_w32': ('mesh', 2, 1, 1, 32),
  'ring_2_l1_w32': ('ring', 2, 1, 1, 32),
  'ring_3_l1_w32': ('ring', 3, 1, 1, 32),
  'ring_4_l0_w32': ('ring', 4, 1, 0, 32),
  'ring_4_l1_w32': ('ring', 4, 1, 1, 32),
  'ring_6_l1_w64': ('ring', 6, 1, 1, 64),
}

def sha(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write_json(path, obj):
  path.write_text(json.dumps(obj, indent=2)+'\n', newline='\n')

def export(label):
  network, cols, rows, latency, data_w = PROFILES[label]
  out=ROOT/'sv/reference/phase4/noc'/label
  if (out/'manifest.json').exists():
    print('PRESERVED '+label,flush=True)
    return
  out.mkdir(parents=True,exist_ok=True)
  (out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  git=lambda *args: subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
  assert not changed,changed
  Data=mk_data(data_w,1)
  Ctrl=mk_ctrl(4,2,4,4,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3))
  Packet=mk_inter_cgra_pkt(cols,rows,4,3,Payload)
  schema=type_schema(Packet)
  fields={f['field']:f for f in schema['fields']}
  info=dict(label=label,baseline_commit=BASELINE,
    pyocn_commit=git('-C','noc/PyOCN','rev-parse','HEAD'),
    network=network,top='Phase4_'+label,
    parameters=dict(WIDTH=Packet.nbits,COLS=cols,ROWS=rows,NODES=cols*rows,
      CHANNEL_LATENCY=latency,DATA_W=data_w,DST_LSB=fields['dst']['lsb'],DST_WIDTH=fields['dst']['nbits'],
      DST_X_LSB=fields['dst_x']['lsb'],X_WIDTH=fields['dst_x']['nbits'],
      DST_Y_LSB=fields['dst_y']['lsb'],Y_WIDTH=fields['dst_y']['nbits'],
      VC_LSB=fields['vc_id']['lsb'],VC_WIDTH=fields['vc_id']['nbits'],
      SRC_LSB=fields['src']['lsb'],SRC_X_LSB=fields['src_x']['lsb'],SRC_Y_LSB=fields['src_y']['lsb'],
      ID_LSB=fields['payload.data.payload']['lsb']),packet=schema,
    exporter_sha256=sha(__file__),source_sha256={})
  try:
    dut=MeshNetworkRTL(Packet,mk_mesh_pos(cols,rows),cols,rows,latency) if network=='mesh' else \
      RingNetworkRTL(Packet,mk_ring_pos(cols*rows),cols*rows,latency)
    os.chdir(out)
    dut.elaborate()
    dut.apply(VerilogPlaceholderPass())
    dut.set_metadata(VerilogTranslationPass.enable,True)
    dut.set_metadata(VerilogTranslationPass.explicit_module_name,info['top'])
    dut.apply(VerilogTranslationPass())
    Path(dut.get_metadata(VerilogTranslationPass.translated_filename)).resolve().replace(out/'reference.v')
    info.update(status='exported',rtl_sha256=sha(out/'reference.v'))
  except Exception:
    info.update(status='baseline_export_failed',failure=traceback.format_exc())
  for imported in list(sys.modules.values()):
    path=getattr(imported,'__file__',None)
    if path and Path(path).suffix=='.py' and Path(path).resolve().is_relative_to(ROOT):
      info['source_sha256'][Path(path).resolve().relative_to(ROOT).as_posix()]=sha(path)
  info['source_sha256']=dict(sorted(info['source_sha256'].items()))
  write_json(out/'manifest.json',info)
  print(info['status'].upper()+' '+label+' width='+str(Packet.nbits),flush=True)
  if info['status']!='exported':print(info['failure'],flush=True)

if __name__=='__main__':
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--profile',choices=['all',*PROFILES],default='all')
  args=parser.parse_args()
  for profile in PROFILES if args.profile=='all' else [args.profile]:
    export(profile)
