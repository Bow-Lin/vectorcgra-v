// Native-only ABI additions. The frozen Python opcode table remains unchanged.
// 102/103 implement unsigned comparisons required by ICMP_ULT YAML programs.
`ifndef CGRA_NATIVE_EXTENSIONS_SVH
`define CGRA_NATIVE_EXTENSIONS_SVH
`include "cgra_opcodes.svh"
`define CGRA_OPT_ULT 7'd102
`define CGRA_OPT_ULT_CONST 7'd103
// Explicit native PHIs preserve the frozen two-input/start opcode semantics.
`define CGRA_OPT_PHI_N 7'd104
`define CGRA_OPT_PHI_START_PRED 7'd105
`endif
