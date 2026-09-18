"""Compare the independent engine with stock ABC on small identical graphs."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from class_nldm import analyze, ROOT, ENGINE_MATH_SHA256, PROTOTYPE_SCRIPT_SHA256

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-dir", type=Path, default=ROOT/"sys_lib/build/timing-method-v2/packaged_validation")
parser.add_argument("--liberty", type=Path, default=ROOT/"sys_lib/lib/NangateOpenCellLibrary_typical.lib")
args = parser.parse_args()
directory = args.output_dir.resolve()
directory.mkdir(parents=True, exist_ok=True)
abc = ROOT / "sys_lib/tools/oss-cad-suite/bin/yosys-abc.exe"
lib = args.liberty.resolve()
env = os.environ.copy()
env["PATH"] = os.pathsep.join([str(abc.parent),str(abc.parent.parent/"lib"),env.get("PATH","")])
cases = [
  ("buffer", [".gate BUF_X1 A=a Z=y"], {"a":"primary_inputs"}, [("y","primary_outputs")]),
  ("duplicate_endpoints", [".gate BUF_X1 A=a Z=y"], {"a":"sequential_output_pins"}, [("y","sequential_input_pins"),("y","sequential_input_pins")]),
  ("negative_arc", [".gate INV_X1 A=a ZN=n", ".gate NAND2_X1 A1=n A2=b ZN=y"],
    {"a":"sequential_output_pins","b":"virtual_undefined_inputs"}, [("y","sequential_input_pins")]),
  ("nonunate", [".gate XOR2_X1 A=a B=b Z=n", ".gate BUF_X4 A=n Z=y", ".gate AND2_X1 A1=n A2=c ZN=p"],
    {"a":"sequential_output_pins","b":"virtual_undefined_inputs","c":"primary_inputs"},[("y","sequential_input_pins"),("p","primary_outputs")]),
  ("reconvergent", [".gate INV_X1 A=a ZN=n", ".gate BUF_X2 A=a Z=b", ".gate MUX2_X1 A=n B=b S=s Z=y"],
    {"a":"sequential_output_pins","s":"primary_inputs"}, [("y","sequential_input_pins")]),
]
report=[]
for name,gates,inputs,outputs in cases:
  here=directory/name
  here.mkdir(exist_ok=True)
  blif=here/"design.blif"
  blif.write_text(".model check\n.inputs "+" ".join(inputs)+"\n.outputs "+" ".join(o for o,_ in outputs)+"\n"+"\n".join(gates)+"\n.end\n")
  cuts=here/"cutpoints.json"
  cuts.write_text(json.dumps({"inputs":[{"net":n,"label":n,"kind":k} for n,k in inputs.items()],
    "outputs":[{"net":n,"label":f"endpoint{i}","kind":k} for i,(n,k) in enumerate(outputs)]},indent=2))
  constr=here/"timing.constr"
  constr.write_text("set_driving_cell BUF_X1\nset_load 5.0\n")
  script=here/"run.abc"
  script.write_text(f'read_lib "{lib.as_posix()}"\nread_blif "{blif.as_posix()}"\nread_constr "{constr.as_posix()}"\ntopo\nstime -p\n')
  proc=subprocess.run([str(abc),"-s","-f",str(script)],env=env,capture_output=True,text=True)
  text=proc.stdout+proc.stderr
  (here/"abc.log").write_text(text)
  assert proc.returncode==0,text
  delay=float(re.search(r"Delay\s*=\s*([\d.]+)\s*ps",text).group(1))
  independent=analyze(blif,cuts,lib)
  absolute=analyze(blif,cuts,lib,absolute_driver=True)
  measured=independent["all_sources"]["delay_ps"]
  error=abs(delay-measured)
  assert error<0.03,(name,delay,measured)
  for key,item in independent["path_classes"].items():
    if item["delay_ps"] is not None:
      assert item["startpoint"]["kind"]=={"PI":"primary_inputs","FF":"sequential_output_pins","VIRTUAL":"virtual_undefined_inputs"}[key.split("_to_")[0]]
      assert item["delay_ps"]<=measured+1e-8
  (here/"independent.json").write_text(json.dumps(independent,indent=2)+"\n")
  report.append({"case":name,"abc_delay_ps":delay,"independent_delay_ps":measured,"absolute_error_ps":error,
    "absolute_driver_delay_ps":absolute["all_sources"]["delay_ps"],
    "path_class_delays_ps":{k:v["delay_ps"] for k,v in independent["path_classes"].items()}})
result={"status":"passed","tolerance_ps":0.03,"cases":report, "engine_math_sha256":ENGINE_MATH_SHA256, "prototype_script_sha256":PROTOTYPE_SCRIPT_SHA256}
(directory/"report.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result,indent=2),flush=True)
