"""One-time FP source scaffold and byte-preserving HardFloat vendor import.

The checked-in SV is maintained directly; normal builds do not run this file.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'rtl/fu/float'
OUT.mkdir(parents=True, exist_ok=True)
template = (ROOT/'rtl/fu/tile_adder.sv').read_text()
header = template[template.index('`include'):template.index('\n);')+4]
ports = re.findall(r'\b(?:input|output)\s+logic\s+(?:\[[^\]]+\]\s+)?(\w+)', header)

def write(name, body, extra=''):
    h = header.replace('module tile_adder', f'module {name}')
    h = h.replace('`CGRA_PROFILE_PARAMETERS', '`CGRA_PROFILE_PARAMETERS,\n  parameter int FP_EXP_W = 8, FP_SIG_W = 23' + extra)
    text = '// ac96 FP interface and behavior; original HardFloat format mapping is preserved.\n' + h + '\n' + body + '\nendmodule\n'
    (OUT/(name+'.sv')).write_text(text, newline='\n')

for name, multiply in [('tile_fp_add', 0), ('tile_fp_mul', 1)]:
    write(name, '  tile_fp_fu #(`CGRA_PROFILE_BIND, .FP_EXP_W(FP_EXP_W),\n'
        f'    .FP_SIG_W(FP_SIG_W), .MULTIPLY({multiply})) core (\n    ' +
        ',\n    '.join(f'.{p}({p})' for p in ports) + '\n  );')

write('tile_fp_fu', r'''
  `include "cgra_profile.svh"
  localparam logic [6:0] FADD=37, FSUB=38, FADD_CONST=39, FINC=40, FMUL=41, FMUL_CONST=42;
  localparam logic [DATA_W-1:0] FLOATING_ONE = {1'b0, FP_EXP_W'((1 << (FP_EXP_W-1))-1), {FP_SIG_W{1'b0}}};
  ctrl_t control;
  data_t inputs [0:3], constant_data, result;
  logic [1:0] in0, in1;
  logic [DATA_W-1:0] a, b, arithmetic_result;
  logic all_valid;
  assign control = recv_opt__msg;
  assign constant_data = recv_const__msg;
  for (genvar i=0; i<4; i++) assign inputs[i] = recv_in__msg[i];
  assign send_out__msg[0] = result;
  assign send_out__msg[1] = '0;
  assign send_out__val[1] = 1'b0;
  assign send_to_ctrl_mem__msg = '0;
  assign send_to_ctrl_mem__val = 1'b0;
  assign recv_from_ctrl_mem__rdy = 1'b0;
  assign to_mem_raddr__msg = '0;
  assign to_mem_raddr__val = 1'b0;
  assign to_mem_waddr__msg = '0;
  assign to_mem_waddr__val = 1'b0;
  assign to_mem_wdata__msg = '0;
  assign to_mem_wdata__val = 1'b0;
  assign from_mem_rdata__rdy = 1'b0;
  initial begin
    if (DATA_W != FP_EXP_W + FP_SIG_W + 1) $fatal(1, "FP payload width must match ac96 exp+sig+1");
    if (FP_EXP_W < 2 || FP_SIG_W < 3) $fatal(1, "Unsupported HardFloat format");
  end
  // ac96 uses exp_nbits+1 and sig_nbits, rather than the usual IEEE field names.
  cgra_hardfloat_fn #(.EXP_W(FP_EXP_W+1), .SIG_W(FP_SIG_W), .MULTIPLY(MULTIPLY)) arithmetic (
    .a(a), .b(b), .sub_op(control.operation==FSUB), .result(arithmetic_result)
  );
  always_comb begin
    in0 = 0;
    in1 = 0;
    for (int i=0; i<4; i++) recv_in__rdy[i] = 0;
    recv_const__rdy = 0;
    recv_opt__rdy = 0;
    send_out__val[0] = 0;
    result = '0;
    a = 0;
    b = 0;
    all_valid = 0;
    if (recv_opt__val) begin
      if (control.fu_in[0] != 0) in0 = 2'(control.fu_in[0]-1);
      if (control.fu_in[1] != 0) in1 = 2'(control.fu_in[1]-1);
      if ((!MULTIPLY && (control.operation==FADD || control.operation==FSUB)) ||
          (MULTIPLY && control.operation==FMUL)) begin
        a = inputs[in0].payload;
        b = inputs[in1].payload;
        result.predicate = inputs[in0].predicate & inputs[in1].predicate;
        all_valid = recv_in__val[in0] & recv_in__val[in1];
        send_out__val[0] = all_valid;
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_in__rdy[in1] = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end else if ((!MULTIPLY && control.operation==FADD_CONST) ||
                   (MULTIPLY && control.operation==FMUL_CONST)) begin
        a = inputs[in0].payload;
        b = constant_data.payload;
        result.predicate = inputs[in0].predicate;
        // The original FMUL_CONST intentionally does not check recv_const.val.
        all_valid = recv_in__val[in0] & (MULTIPLY || recv_const__val);
        send_out__val[0] = all_valid;
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_const__rdy = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end else if (!MULTIPLY && control.operation==FINC) begin
        a = inputs[in0].payload;
        b = FLOATING_ONE;
        result.predicate = inputs[in0].predicate;
        all_valid = recv_in__val[in0];
        // FINC gates val with ready in ac96; retain that observable behavior.
        send_out__val[0] = all_valid & send_out__rdy[0];
        recv_in__rdy[in0] = all_valid & send_out__rdy[0];
        recv_opt__rdy = all_valid & send_out__rdy[0];
      end
      result.payload = arithmetic_result;
    end
  end''', ',\n  parameter bit MULTIPLY = 0')

(OUT/'cgra_hardfloat_fn.sv').write_text(r'''// Direct HDL replacement for the original PyMTL AddFN/MulFN wiring.
module cgra_hardfloat_fn #(
  parameter int EXP_W=9, SIG_W=23,
  parameter bit MULTIPLY=0,
  localparam int WIDTH=EXP_W+SIG_W
) (
  input logic [WIDTH-1:0] a, b,
  input logic sub_op,
  output logic [WIDTH-1:0] result
);
  logic [WIDTH:0] rec_a, rec_b, rec_result;
  logic [4:0] exception_flags;
  fNToRecFN #(EXP_W, SIG_W) convert_a (.in_(a), .out(rec_a));
  fNToRecFN #(EXP_W, SIG_W) convert_b (.in_(b), .out(rec_b));
  if (MULTIPLY) begin : multiply
    mulRecFN #(EXP_W, SIG_W) op (.control(1'b1), .a(rec_a), .b(rec_b),
      .roundingMode(3'b000), .out(rec_result), .exceptionFlags(exception_flags));
  end else begin : add_subtract
    addRecFN #(EXP_W, SIG_W) op (.control(1'b1), .subOp(sub_op), .a(rec_a), .b(rec_b),
      .roundingMode(3'b000), .out(rec_result), .exceptionFlags(exception_flags));
  end
  recFNToFN #(EXP_W, SIG_W) convert_result (.in_(rec_result), .out(result));
endmodule
''', newline='\n')

source = ROOT.parent/'fu/pymtl3_hardfloat/HardFloat'
vendor = ROOT/'rtl/vendor/hardfloat'
items = ['HardFloat_primitives.v','isSigNaNRecFN.v','HardFloat_rawFN.v',
    'fNToRecFN.v','recFNToFN.v','addRecFN.v','mulRecFN.v',
    'HardFloat_consts.vi','HardFloat_localFuncs.vi','HardFloat_specialize.vi',
    'RISCV/HardFloat_specialize.vi']
hashes = {}
for name in items:
    target = vendor/name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((source/'source'/name).read_bytes())
    hashes[name] = hashlib.sha256(target.read_bytes()).hexdigest()
(vendor/'COPYING.txt').write_bytes((source/'COPYING.txt').read_bytes())
(vendor/'provenance.json').write_text(json.dumps(dict(
    source='fu/pymtl3_hardfloat/HardFloat/source',
    submodule_commit='aea69e416e079178df4bb5697795ef653f55df58',
    byte_exact=True, files_sha256=hashes,
    license='COPYING.txt; Berkeley HardFloat BSD-style license'), indent=2)+'\n', newline='\n')
files = ['+incdir+rtl/common', '+incdir+rtl/vendor/hardfloat']
files += ['rtl/vendor/hardfloat/'+n for n in items if n.endswith('.v')]
files += ['rtl/fu/float/'+n+'.sv' for n in ['cgra_hardfloat_fn','tile_fp_fu','tile_fp_add','tile_fp_mul']]
(ROOT/'filelists/phase3_float.f').write_text('\n'.join(files)+'\n', newline='\n')
print('FLOAT_NATIVE_SCAFFOLD_PASS')
