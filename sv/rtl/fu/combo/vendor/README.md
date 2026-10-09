# Existing ALUgenMAC dependency

This is the existing `fu/fused_alu_fixedp` IP from the ac96 migration baseline, not a newly licensed or rewritten arithmetic implementation. All original notices are retained in the source files.

| Vendored file | Original path | Original SHA-256 | Vendored SHA-256 |
| --- | --- | --- | --- |
| `svsrc/ALUgenMAC.sv` | `fu/fused_alu_fixedp/svsrc/ALUgenMAC.sv` | `a279b80f648394ed7b15c955360a8d803ec9a597105f0a5bd17dc32b982565a6` | same |
| `dp_fpfma/DW02_multp.v` | `fu/fused_alu_fixedp/dp_fpfma/DW02_multp.v` | `f20e7c48b787dbd3c5ed2ecda68a8864adb94570a127a03e89e84b0dd6735978` | `a9d9bb4b4b5fa032e5626e3dd32d069cf39d45765c398530bb41bb3a541b4515` |

`DW02_multp.v` differs only by CRLF-to-LF normalization. Its original Synopsys proprietary notice and the Genesis2 non-commercial notice in `ALUgenMAC.sv` remain applicable. The repository's general license does not replace those notices.

The ALU has fixed 16-bit operands and a 6-bit mode; `tile_alu_gen_mac` rejects other payload widths. The native DUT now uses `cgra_alu_gen_mac_core` and `cgra_multp`; these files remain the frozen reference and provenance, outside the DUT file list.

Compile `svsrc/ALUgenMAC.sv` with its directory on the include path; its existing relative include resolves `../dp_fpfma/DW02_multp.v`. When differential tests compile the frozen PyMTL reference, that reference already embeds the same IP, so the test file list uses that one definition rather than compiling a duplicate vendor definition.

`DW02_multp.v` is explicitly a simulation model with behavior inside `synopsys translate_off/on`. The native `cgra_multp` statically elaborates its radix-4 Booth and ordered 3:2 compression behavior, retaining both partial outputs exactly. It does not use the simulation-only vendor module in synthesis. The original notices are retained; this rendition does not change their license terms.

Validation compares both partial outputs against the original model and independently checks their sum against signed/unsigned multiplication: nine width combinations, 18,432 samples. Native MAC wrapper and FU tests also compare every output against the frozen original. Seven native multiplier/MAC profiles pass Yosys `proc; opt; check -assert`; these are structural checks, not mapped timing or area results. See `sv/tests/phase3/vector_combo` for the SV-only runners and reports. Four-state propagation is retained in the source but the differential test uses Verilator's two-state simulation.
