"""Freeze asymmetric-port DataMemControllerRTL profiles without source edits."""
import argparse,json,os,re,subprocess,sys,traceback
from pathlib import Path
from reference_model import ROOT,BASELINE,type_schema
from phase4_migration_trace import sha,save
from pymtl3 import mk_bits
from pymtl3.passes.backends.verilog import VerilogTranslationPass,VerilogPlaceholderPass
from VectorCGRA.lib.messages import mk_data,mk_ctrl,mk_cgra_payload,mk_inter_cgra_pkt
from VectorCGRA.mem.data.DataMemControllerRTL import DataMemControllerRTL


def export(reads,writes):
  label=f'r{reads}w{writes}';out=ROOT/'sv/reference/phase4/memory'/label
  if out.exists():raise RuntimeError('Frozen evidence exists: '+str(out))
  out.mkdir(parents=True);(out/'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
  Data=mk_data(32,1);Ctrl=mk_ctrl(4,2,4,4,16)
  Payload=mk_cgra_payload(Data,mk_bits(7),Ctrl,mk_bits(3));Noc=mk_inter_cgra_pkt(2,2,4,reads,Payload)
  params=dict(COLS=2,ROWS=2,MULTI_COLS=2,MULTI_ROWS=2,DATA_W=32,CTRL_DEPTH=8,REG_DEPTH=16,
    GLOBAL_ADDR_W=7,NUM_BANKS=2,BANK_DEPTH=16,MEM_PORTS=reads,MEM_WRITE_PORTS=writes,MAX_MEM_PORTS=reads)
  m=dict(label=label,baseline_commit=BASELINE,parameters=params,packet=type_schema(Noc),
    top='Phase4Memory_'+label,exporter_sha256=sha(__file__),status='exporting')
  try:
    d=DataMemControllerRTL(Noc,128,16,2,reads,writes,2,2,4,True,
      {0:[0,0],1:[1,0],2:[0,1],3:[1,1]},False)
    os.chdir(out);d.elaborate();d.apply(VerilogPlaceholderPass())
    d.set_metadata(VerilogTranslationPass.enable,True)
    d.set_metadata(VerilogTranslationPass.explicit_module_name,m['top']);d.apply(VerilogTranslationPass())
    Path(d.get_metadata(VerilogTranslationPass.translated_filename)).resolve().replace(out/'reference.v')
    raw=(out/'reference.v').read_text();header=raw[raw.index('module '+m['top']):];header=header[:header.index(');')+2]
    (out/'top_ports.txt').write_text(header+'\n',newline='\n')
    m.update(status='exported',rtl_sha256=sha(out/'reference.v'))
  except Exception:
    m.update(status='baseline_export_failed',failure=traceback.format_exc());print(m['failure'],flush=True)
  m['source_sha256']={Path(x.__file__).resolve().relative_to(ROOT).as_posix():sha(x.__file__)
    for x in list(sys.modules.values()) if getattr(x,'__file__',None) and Path(x.__file__).suffix=='.py' and Path(x.__file__).resolve().is_relative_to(ROOT)}
  save(out/'manifest.json',m);print(m['status'].upper()+' '+label,flush=True)


if __name__=='__main__':
  changed=subprocess.check_output(['git','diff','--name-only',BASELINE,'--','*.py'],cwd=ROOT,text=True)
  assert not [p for p in changed.splitlines() if not p.startswith('sv/')]
  export(3,1);export(1,3)
