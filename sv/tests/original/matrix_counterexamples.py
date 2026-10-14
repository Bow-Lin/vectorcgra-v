"""Reproduce original matrix-program failures and isolate configuration repairs.

Uses native RTL to identify program defects; it is not a completed Python run.
Existing corrected programs and their mathematical expectations are unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

from run import ROOT, command
sys.path.insert(0,str(ROOT/'sv/migration_tools'))
from native_kernels import decode,encode


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--generate-only',action='store_true')
  args=ap.parse_args();results=[]
  for kernel in ['gemm','gemv']:
    original=json.loads((ROOT/'sv/reference/current/kernels'/kernel/'manifest.json').read_text())
    fixed=ROOT/'sv/reference/native/kernels'/kernel
    manifest=json.loads((fixed/'manifest.json').read_text());p=manifest['parameters']
    rw=(p['REG_DEPTH']-1).bit_length();ca=(p['CTRL_DEPTH']-1).bit_length()
    cb=39+48+8*rw;pb=6+35+p['GLOBAL_ADDR_W']+cb+ca
    idw=max(1,(p['MULTI_ROWS']*p['MULTI_COLS']-1).bit_length())
    dstshift=pb+9+2*(idw+max(1,(p['MULTI_COLS']-1).bit_length())+max(1,(p['MULTI_ROWS']-1).bit_length()))
    raw=[int(x,16) for x in original['configuration_packets']]
    repaired=[int(x,16) for x in (fixed/'program.hex').read_text().splitlines()]
    def location(v):return (v>>dstshift)&31,v&((1<<ca)-1)
    def cmd(v):return (v>>(pb-6))&63
    before={location(v):decode((v>>ca)&((1<<cb)-1),rw) for v in raw if cmd(v)==3}
    retained={}
    for c in manifest['changes']:
      if c['kind']=='retain_live_register':retained.setdefault((c['tile'],c['pc']),[]).append(c['bank'])
    without=[]
    for v in repaired:
      if cmd(v)==3 and location(v) in retained:
        ctrl=decode((v>>ca)&((1<<cb)-1),rw);old=before[location(v)]
        for bank in retained[location(v)]:
          for field in ['read_src','write_src','write_idx']:ctrl[field][bank]=old[field][bank]
          ctrl['route'][4+bank]=old['route'][4+bank]
        v=(v&~(((1<<cb)-1)<<ca))|(encode(ctrl,rw)<<ca)
      without.append(v)
    variants={'original_program':raw,'without_register_retention':without}
    if kernel=='gemm':variants['without_stride']=[v for v in repaired if cmd(v)!=43]
    for name,packets in variants.items():
      target=args.output/kernel/name;target.mkdir(parents=True,exist_ok=True)
      for file in ['expected.hex','return.hex']:shutil.copyfile(fixed/file,target/file)
      program=target/'program.hex';program.write_text(''.join(f'{v:x}\n' for v in packets))
      if args.generate_only:continue
      binary=ROOT/'sv/build/native'/kernel/'Vtb_native_kernel'
      record=command([str(binary),'+PROGRAM='+str(target.resolve()),'+MAX_CYCLES=12000'],target/'run.log',120)
      log=(target/'run.log').read_text()
      # Only an actual simulation failure is an expected counterexample.
      detected=record['exit_code'] not in [0,124] and any(s in log for s in ['NATIVE_KERNEL_TIMEOUT','KERNEL_MATH'])
      record.update(kernel=kernel,variant=name,expected_counterexample=detected,
        program_sha256=hashlib.sha256(program.read_bytes()).hexdigest())
      results.append(record)
      print('MATRIX_COUNTEREXAMPLE',kernel,name,detected,flush=True)
  if not args.generate_only:
    (args.output/'results.json').write_text(json.dumps(dict(schema=1,python_equivalence=False,checks=results),indent=2)+'\n')
  return int(any(not r['expected_counterexample'] for r in results))


if __name__=='__main__':raise SystemExit(main())
