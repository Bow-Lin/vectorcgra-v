"""One-time explicit provenance classification of the interrupted initial exports.

No RTL is generated or modified. This preserves actual script generations rather
than treating a later --resume manifest writer as the historical RTL exporter.
"""
import json
from pathlib import Path
from phase3_scalar_export import ROOT,write,sha


def main():
  root=ROOT/'sv/reference/phase3/scalar'
  first=root/'w32/exporter_snapshot.py'
  adapted=root/'w64/exporter_snapshot.py'
  assert sha(first)=='3dd60cda1aeb3088d081e2f8afa34b84d5a137e474ad0a2a2b5b662b313952bc'
  assert sha(adapted)=='fbaa6ef329089ff55488b629e1fc8b7f2c6e7e9dbf02e37aed8421bae3ff5d0f'
  initial={'Const','Comp','Logic','Shifter','Sel','Phi','Grant','Ret','LoopControl'}
  for profile in ['w32','w64']:
    path=root/profile/'manifest.json'; data=json.loads(path.read_text())
    for record in data['modules']:
      script=first if profile=='w32' and record['module'] in initial else adapted
      record['original_export']=dict(script_snapshot=script.relative_to(ROOT).as_posix(),
        script_sha256=sha(script),rtl_sha256=record['rtl_sha256'],raw_rtl_generated=True,
        provenance_note='Initial w32 export before four translation failures and Windows placeholder hang.' if script==first else
          'Isolated adapter/host-fix exporter. The identical fbaa6ef3 script snapshot is retained in the subsequent w64 export; this script also generated the six missing w32 RTL files.')
    data['original_export_provenance_classification_script_sha256']=sha(Path(__file__))
    write(path,json.dumps(data,indent=2)+'\n')
  print('SCALAR_ORIGINAL_EXPORT_PROVENANCE_CLASSIFIED w32_initial=9 w32_adapter_export=6 w64_adapter_export=13')


if __name__=='__main__': main()
