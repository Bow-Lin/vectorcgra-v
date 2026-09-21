"""Migration-only scaffold of self-contained SV tests and filelists."""
import json
import re
from phase3_scalar_export import ROOT, MODULES, write
from phase3_scalar_port import snake


def generate(profile):
  ref=ROOT/'sv/reference/phase3/scalar'/profile
  manifest=json.loads((ref/'manifest.json').read_text())
  vec=json.loads((ref/'vectors/manifest.json').read_text())
  p=manifest['parameters']; dw=p['DATA_W']; cd=p['CTRL_DEPTH']; rd=p['REG_DEPTH']
  ins=vec['input_layout']; outs=vec['output_layout']; cycles=vec['cycles']
  directory=ROOT/'sv/tests/phase3/scalar'/profile
  directory.mkdir(parents=True,exist_ok=True)
  def decl(layout,prefix=''):
    result=[]; seen=set()
    for n,w in layout:
      base=n.split('[')[0]
      if base in seen: continue
      seen.add(base)
      array=' [0:3]' if base.startswith('recv_in') else ' [0:1]' if base.startswith('send_out') else ''
      result.append(f'  logic [{w-1}:0] {prefix}{base}{array};')
    return '\n'.join(result)
  input_names=list(dict.fromkeys(n.split('[')[0] for n,w in ins))
  output_names=list(dict.fromkeys(n.split('[')[0] for n,w in outs))
  text='''`timescale 1ns/1ps
`include "cgra_profile_defs.svh"
// Frozen-input three-way test: native HDL, independently translated ac96 HDL,
// and original ac96 Python raw-cycle oracle. Daily execution uses only SV/tools.
module tb_scalar;
'''
  text+=f'  localparam int DATA_W={dw}, CTRL_DEPTH={cd}, REG_DEPTH={rd}, GLOBAL_ADDR_W=7;\n'
  text+='  localparam int CTRL_ADDR_W=$clog2(CTRL_DEPTH), REG_ADDR_W=$clog2(REG_DEPTH), ROUTING_OUTPUTS=8, ROUTING_SEL_W=4;\n'
  text+='  localparam int DATA_BITS=DATA_W+3, CTRL_BITS=87+8*REG_ADDR_W, PAYLOAD_BITS=6+DATA_BITS+7+CTRL_BITS+CTRL_ADDR_W;\n'
  # Include only the profile types needed by scalar FU ports; the complete header
  # also defines global packet types requiring the following independent constants.
  text+='  localparam int TILE_ID_W=3, MEM_PORT_W=2, BANK_PORT_W=2;\n'
  text+='  `include "cgra_profile.svh"\n'
  text+=f'  localparam int CYCLES={cycles}, INPUT_BITS={vec["input_bits"]}, OUTPUT_BITS={vec["output_bits"]};\n'
  text+='  logic clk=0; integer cycle; integer math_checks=0; integer pipeline_checks=0;\n'
  text+=decl(ins)+'\n'
  text+='  ctrl_t ctrl_view; assign ctrl_view=recv_opt__msg;\n'
  text+='  data_t operand[0:3]; assign operand=recv_in__msg;\n'
  text+='  data_t constant_view; assign constant_view=recv_const__msg;\n'
  text+='  logic [DATA_W-1:0] a,b,c; integer ia,ib,ic;\n'
  text+='  always_comb begin\n    ia=(ctrl_view.fu_in[0]==0)?0:((int\'(ctrl_view.fu_in[0])-1)&3);\n    ib=(ctrl_view.fu_in[1]==0)?0:((int\'(ctrl_view.fu_in[1])-1)&3);\n    ic=(ctrl_view.fu_in[2]==0)?0:((int\'(ctrl_view.fu_in[2])-1)&3);\n    a=operand[ia].payload; b=operand[ib].payload; c=constant_view.payload;\n  end\n'
  text+='  logic [INPUT_BITS-1:0] inputs[0:CYCLES-1];\n'
  checks=[]; refs=[]; files=['rtl/fu/scalar/'+('scalar_'+snake(m))+'.sv' for m in MODULES]
  files+=['rtl/fu/scalar/scalar_div_pipeline.sv']
  for record in manifest['modules']:
    name=record['module']; native='scalar_'+snake(name); prefix=name+'_'
    for kind in ['dut','gold']:
      pp=prefix+kind+'_'; text+=decl(outs,pp)+'\n'
      text+=f'  logic [OUTPUT_BITS-1:0] {pp}bits;\n'
      text+=f'  assign {pp}bits={{'+','.join(pp+n for n,w in outs)+'};\n'
      typ=native+f' #(.DATA_W({dw}),.CTRL_DEPTH({cd}),.REG_DEPTH({rd}))' if kind=='dut' else record['top']
      conns=['.clk(clk)']+[f'.{n}({n})' for n in input_names]+[f'.{n}({pp+n})' for n in output_names]
      text+=f'  {typ} {name}_{kind} (\n    '+',\n    '.join(conns)+'\n  );\n'
    checks.append(f'      if ({name}_dut_bits !== {name}_gold_bits) $fatal(1,"SCALAR_HDL_MISMATCH {name} cycle=%0d dut=%h gold=%h",cycle,{name}_dut_bits,{name}_gold_bits);')
    if name not in ['InclusiveDiv','ExclusiveDiv']:
      text+=f'  logic [OUTPUT_BITS-1:0] {name}_python[0:CYCLES-1];\n'
      checks.append(f'      if ({name}_dut_bits !== {name}_python[cycle]) $fatal(1,"SCALAR_PYTHON_MISMATCH {name} cycle=%0d dut=%h python=%h",cycle,{name}_dut_bits,{name}_python[cycle]);')
    # Undefining the original vendor guard permits separately namespaced divider
    # copies. No gate/state/logic text of frozen references is changed.
    refs+=['`undef DIV',f'`include "reference/phase3/scalar/{profile}/{record["namespaced"]}"']
  write(directory/'references.sv','\n'.join(refs)+'\n')
  text+='  task automatic expect_math(input logic [DATA_W-1:0] got,expected,input string operation);\n    if (got !== expected) $fatal(1,"SCALAR_MATH_MISMATCH %s cycle=%0d got=%h expected=%h",operation,cycle,got,expected);\n    math_checks++;\n  endtask\n'
  text+='  initial begin\n'
  text+=f'    $readmemh("reference/phase3/scalar/{profile}/vectors/inputs.hex",inputs);\n'
  for r in manifest['modules']:
    if r['module'] not in ['InclusiveDiv','ExclusiveDiv']:
      text+=f'    $readmemh("reference/phase3/scalar/{profile}/vectors/{r["module"]}.hex",{r["module"]}_python);\n'
  text+='    for(cycle=0;cycle<CYCLES;cycle++) begin\n'
  text+='      {'+','.join(n for n,w in ins)+'}=inputs[cycle];\n      #2;\n'
  text+='      if ($test$plusargs("NEGATIVE") && cycle==7) begin\n        $display("SCALAR_NEGATIVE_CONTROL injecting one oracle output bit");\n        Const_python[cycle][0]=~Const_python[cycle][0];\n      end\n'
  text+='\n'.join(checks)+'\n'
  text+='      if (recv_opt__val) begin\n        case(ctrl_view.operation)\n'
  ops={k:v for r in manifest['modules'] for k,v in r['operations'].items()}
  maths={'OPT_CONST':('Const','c'),'OPT_OR':('Logic','a|b'),'OPT_AND':('Logic','a&b'),
         'OPT_XOR':('Logic','a^b'),'OPT_BIT_NOT':('Logic','~a'),'OPT_NOT':('Logic',"DATA_W'(!a)"),
         'OPT_LLS':('Shifter','a<<b'),'OPT_LRS':('Shifter','a>>b'),
         'OPT_DIV':('Div','a/b'),'OPT_DIV_CONST':('Div','a/c'),
         'OPT_EQ':('Comp',"DATA_W'(a==b)"),'OPT_NE':('Comp',"DATA_W'(a!=b)"),
         'OPT_EQ_CONST':('Comp',"DATA_W'(a==c)"),'OPT_NE_CONST':('Comp',"DATA_W'(a!=c)"),
         'OPT_LT':('Comp',"DATA_W'($signed(a)<$signed(b))"),
         'OPT_LT_CONST':('Comp',"DATA_W'($signed(a)<$signed(c))"),
         'OPT_GT_CONST':('Comp',"DATA_W'($signed(a)>$signed(c))"),
         'OPT_GTE_CONST':('Comp',"DATA_W'($signed(a)>=$signed(c))")}
  # Independent payload math only: original predicate and handshake fields are
  # checked by complete traces, including invalid data and nonselected controls.
  for op,(module,expr) in maths.items():
    if op in ops:
      text+=f'          7\'d{ops[op]}: begin\n            expect_math({module}_dut_send_out__msg[0][DATA_BITS-1:3],{expr},"{op}");\n'
      text+=f'            if ({module}_dut_recv_opt__rdy !== ({module}_dut_send_out__val[0] & send_out__rdy[0])) $fatal(1,"SCALAR_HANDSHAKE_MISMATCH {module} cycle=%0d",cycle);\n          end\n'
  text+='          default: ;\n        endcase\n      end\n'
  cases=json.loads((ref/'vectors/cases.json').read_text())
  if profile=='w32':
    # Each phase has fixed 50/7 inputs, all-valid/ready and vf=0. Wait for the
    # pipeline fill then check unsigned quotient/remainder by a separate oracle.
    for code,label,value in [(ops['OPT_DIV_INCLUSIVE_END'],'InclusiveDiv',7),(ops['OPT_REM_INCLUSIVE_END'],'InclusiveDiv',1),(ops['OPT_DIV'],'ExclusiveDiv',7),(ops['OPT_REM'],'ExclusiveDiv',1)]:
      indices=[d['cycle'] for d in cases if d['phase']=='division' and d['code']==code and d['variation']>=8]
      text+=f'      if(cycle>={min(indices)} && cycle<={max(indices)}) begin\n'
      text+=f'        expect_math({label}_dut_send_out__msg[0][DATA_BITS-1:3],DATA_W\'({value}),"pipeline {label} {code}"); pipeline_checks++;\n      end\n'
  text+='      #3; clk=1; #5; clk=0;\n    end\n'
  text+='    if(math_checks<100) $fatal(1,"SCALAR_CHECKER_COVERAGE math_checks=%0d",math_checks);\n'
  text+='    if($test$plusargs("TIMEOUT_TEST")) wait(1\'b0);\n'
  text+=f'    $display("SCALAR_PASS profile={profile} cycles=%0d modules={len(manifest["modules"])} python_modules=13 raw_output_bits=%0d math_checks=%0d pipeline_checks=%0d",CYCLES,OUTPUT_BITS,math_checks,pipeline_checks);\n    $finish;\n  end\n  initial begin #1000000; $fatal(1,"SCALAR_TIMEOUT"); end\nendmodule\n'
  write(directory/'tb_scalar.sv',text)
  files += [f'tests/phase3/scalar/{profile}/references.sv',f'tests/phase3/scalar/{profile}/tb_scalar.sv']
  write(directory/'files.f','\n'.join(files)+'\n')
  print('SCALAR_TB_GENERATED',profile,cycles,len(manifest['modules']))


if __name__=='__main__':
  import sys
  generate(sys.argv[1])
