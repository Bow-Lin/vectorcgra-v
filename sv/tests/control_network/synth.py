#!/usr/bin/env python3
"""Generic xc7 out-of-context synthesis, never a device/place-route claim."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('control_run',HERE/'run.py')
run=importlib.util.module_from_spec(spec);spec.loader.exec_module(run)
SV=run.SV


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  ap.add_argument('--geometries',default='2x2,3x3,4x4')
  ap.add_argument('--variants',default='0:0,1:0,2:0,1:1,2:1')
  args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
  old=out/'results.json'
  if old.exists():old.rename(out/f'previous-results-{time.time_ns()}.json')
  yosys=os.environ.get('YOSYS','yosys');sv2v=os.environ.get('SV2V','sv2v')
  sources={str(p.relative_to(SV)):run.sha(p) for p in run.source_files() if p.name!='tb_control_network.sv'}
  sources['tests/control_network/resource_top.sv']=run.sha(HERE/'resource_top.sv')
  versions=dict(yosys=subprocess.check_output([yosys,'-V'],text=True).strip(),
      sv2v=subprocess.check_output([sv2v,'--version'],text=True).strip())
  report=dict(baseline=run.BASELINE,evidence='Yosys synth_xilinx generic xc7 OOC only; no specific part, XDC, placement, routing, setup/hold, or board validation',
      sources=sources,tools=versions,cases=[])
  rtl=[SV/line for line in (SV/'filelists/control_network.f').read_text().splitlines() if line and not line.startswith('+')]
  # Conversion is shared; parameters are specialized before synthesis.
  converted=out/'network.v'
  conversion=run.command([sv2v,'-DSYNTHESIS','-I'+str(SV/'rtl/common'),
      '--top=control_resource_top','--write='+str(converted),*rtl,HERE/'resource_top.sv'],out/'sv2v.log',300)
  report['conversion']=conversion
  if conversion['exit_code']!=0:
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n');return 1
  for shape in args.geometries.split(','):
    cols,rows=map(int,shape.split('x'))
    for variant in args.variants.split(','):
      backend,multicast=map(int,variant.split(':'))
      params=dict(COLS=cols,ROWS=rows,MAX_COLS=cols,MAX_ROWS=rows,CTRL_NETWORK=backend,
          CTRL_MULTICAST=multicast,DATA_W=32,REG_DEPTH=5,CTRL_DEPTH=6,NUM_CTRL=6,
          TOTAL_STEPS=6,NUM_BANKS=4,BANK_DEPTH=8)
      folder=out/f'{shape}-b{backend}-mc{multicast}';folder.mkdir(exist_ok=True)
      key=hashlib.sha256(json.dumps([sources,params,versions],sort_keys=True).encode()).hexdigest()
      stat=folder/'stat.json';stamp=folder/'identity.json'
      row=dict(parameters=params,status='running',identity=key)
      report['cases'].append(row)
      cached=stat.exists() and stamp.exists() and json.loads(stamp.read_text()).get('identity')==key
      if cached:
        assert json.loads(stamp.read_text())['netlist_sha256']==run.sha(folder/'netlist.v'),'Changed cached synthesis netlist'
      if not cached:
        script=folder/'synth.ys'
        script.write_text('\n'.join([
          f'read_verilog {converted}',
          'chparam '+' '.join(f'-set {k} {v}' for k,v in params.items())+' control_resource_top',
          'hierarchy -check -top control_resource_top',
          'synth_xilinx -family xc7 -top control_resource_top -flatten -noiopad -noclkbuf',
          'check -assert','scc -expect 0',f'tee -o {stat} stat -json',
          f'write_verilog -noattr {folder/"netlist.v"}','']))
        row['synthesis']=run.command([yosys,'-Q','-T','-s',script],folder/'synth.log',1200)
      if stat.exists() and row.get('synthesis',{}).get('exit_code',0)==0:
        cells=json.loads(stat.read_text())['modules']['\\control_resource_top']['num_cells_by_type']
        row.update(status='passed',cells=cells,logic_LUT_cells=sum(cells.get('LUT'+str(i),0) for i in range(1,7)),
          FF_cells=sum(v for k,v in cells.items() if k.startswith('FD')),
          DSP_cells=sum(v for k,v in cells.items() if k.startswith('DSP')),
          BRAM_cells=sum(v for k,v in cells.items() if k.startswith('RAMB')),
          SRL_cells=sum(v for k,v in cells.items() if k.startswith('SRL')),
          LUTRAM_cells={k:v for k,v in cells.items() if k.startswith('RAM') and not k.startswith('RAMB')},
          netlist_sha256=run.sha(folder/'netlist.v'))
        stamp.write_text(json.dumps(dict(identity=key,netlist_sha256=row['netlist_sha256']),indent=2)+'\n')
      else:row['status']='failed'
      if (folder/'synth.ys').exists():row['synthesis_script']=(folder/'synth.ys').read_text()
      if (folder/'synth.log').exists():row['synthesis_log_sha256']=run.sha(folder/'synth.log')
      if stat.exists():row['stat_sha256']=run.sha(stat)
      (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
      print(f'CONTROL_SYNTH {shape} backend={backend} mc={multicast}: {row["status"]} LUTcells={row.get("logic_LUT_cells")}',flush=True)
  report['all_passed']=all(x['status']=='passed' for x in report['cases'])
  final_sources={str(p.relative_to(SV)):run.sha(p) for p in run.source_files() if p.name!='tb_control_network.sv'}
  final_sources['tests/control_network/resource_top.sv']=run.sha(HERE/'resource_top.sv')
  assert sources==final_sources,'Synthesis RTL sources changed during run'
  (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  return int(not report['all_passed'])


if __name__=='__main__':raise SystemExit(main())
