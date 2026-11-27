#!/usr/bin/env python3
"""RTL elaboration guards for deliberately unsupported control-network profiles."""
import argparse
import importlib.util
import json
import os
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('control_runner',HERE/'run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)


def main():
  ap=argparse.ArgumentParser(description=__doc__)
  ap.add_argument('--output',type=Path,required=True)
  args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
  cases=dict(disconnected=dict(HAS_CTRL_RING=0),context=dict(TILE_VARIANT=1),
      streaming=dict(TILE_VARIANT=2,TILE_PORTS=8),legacy=dict(NOC_LEGACY_PYTHON=1),
      multi=dict(IS_MULTI=1),dma=dict(HAS_DMA=1),im2col=dict(HAS_IM2COL=1),
      ring_multicast=dict(CTRL_NETWORK=0,CTRL_MULTICAST=1))
  report=dict(baseline=r.BASELINE,evidence='RTL initial profile guards',cases=[])
  for name,changes in cases.items():
    parameters=dict(CTRL_NETWORK=1);parameters.update(changes)
    folder=out/name;folder.mkdir(exist_ok=True)
    tb=folder/'tb_control_profile.sv'
    tb.write_text('module tb_control_profile;\nlogic clk=0,reset=1;\n'
        'cgra_system #('+','.join(f'.{k}({v})' for k,v in parameters.items())+') dut(.clk,.reset);\n'
        'initial begin #2; $display("UNREJECTED_PROFILE");$finish;end\nendmodule\n')
    result=r.command([os.environ.get('VERILATOR','verilator'),'--binary','--timing','-j','1',
        '-Wno-fatal','-Wno-PINMISSING','-Irtl/common','-f','filelists/native.f',
        '--top-module','tb_control_profile','--Mdir',folder/'obj',tb],folder/'compile.log',600)
    row=dict(name=name,parameters=parameters,build=result,passed=False);report['cases'].append(row)
    binary=folder/'obj/Vtb_control_profile'
    if result['exit_code']==0 and binary.exists():
      r.clean_compiler_objects(binary)
      row['binary_sha256']=r.sha(binary)
      row['run']=r.command([binary],folder/'run.log',30)
      marker='CTRL_MULTICAST_PROFILE' if name=='ring_multicast' else 'CTRL_NETWORK_PROFILE'
      row['passed']=row['run']['exit_code'] not in {0,124} and marker in Path(row['run']['log']).read_text()
    print(f'CONTROL_PROFILE {name}: {row["passed"]}',flush=True)
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  report['all_passed']=all(x['passed'] for x in report['cases'])
  (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
  return int(not report['all_passed'])


if __name__=='__main__':raise SystemExit(main())
