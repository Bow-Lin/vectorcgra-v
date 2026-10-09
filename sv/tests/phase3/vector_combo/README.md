# Native vector and composite FU migration tests

The oracle is frozen translated HDL from unmodified `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`. These tests do not assert general equivalence to Python simulation. In particular, VectorMulCombo has a demonstrated Python/HDL discrepancy described below.

From the repository root, run in MSYS2 with Verilator and Clang installed:

```sh
bash sv/tests/phase3/vector_combo/run.sh all
bash sv/tests/phase3/vector_combo/run_multp.sh
bash sv/tests/phase3/vector_combo/run_negative.sh
```

`run.sh <profile-directory-name>` selects one profile. From PowerShell, `check_synthesis.ps1` checks seven multiplier/MAC profiles and all 28 non-MAC simulation profiles; its `-ToolRoot` option selects an installed tool bundle and `-MacOnly` selects the initial seven. These normal test paths do not invoke PyMTL or generate RTL. Migration-only Python exporters and test authoring scripts are under `sv/migration_tools/phase3_vector_*.py`.

After building the default eight-bit VectorAdder leaf profile, `run_negative.sh` corrupts one independent expected-result bit. It requires a nonzero simulator exit and the ordinary arithmetic checker's cycle64 failure, so a missing file or an unrelated simulator failure cannot count as success.

Each of 30 FU profiles executes 640 cycles. The bench compares every declared output, including messages when valid is low, and separately checks payload arithmetic. It varies control/input validity, ready, selectors including truncated aliases, clear, reset, supported/unsupported operations, and vector-factor control. Stateful composites check an independent eight-bit vector counter; AllReduce checks controller request state. Every supported opcode must be hit, and arithmetic and handshake coverage counters are asserted before success. Random seed is `3b123456`. Testbench and frozen-reference hashes, results and coverage counts are collected in `results.json`; raw run/build logs remain in ignored `sv/build/phase3/vector_combo`.

| Family | Profiles |
| --- | --- |
| VectorAdder / VectorMul bit-vector leaves | lane width 1, 8, 16; four inputs, two outputs |
| VectorAdderCombo | data32 lanes1/2/4/8; data64 lanes8 |
| VectorMulCombo | data32/64 lanes4/8 |
| VectorAllReduce | data32 lanes4/8; data64 lanes8 |
| SeqMulAdder, SeqMulShifter, PrlMulAdder, ThreeMulAdderShifter, FourIncCmpNotGrant | data32 and data64 |
| AluGenMac FU and low-level wrapper | fixed data16; all eight FU operations / all 64 wrapper modes |

The three 64-bit vector outer profiles with eight lanes use constructor vector-factor power 3; the baseline outer implementations ignore that parameter. Tests still vary the runtime control vector factor. Native outer FUs have the standard four data inputs and two outputs plus existing memory/controller interfaces. Bit-vector leaves retain their original carry/flat-data APIs. Vector addition requires a positive lane count dividing `DATA_W`; multiply and reduction require a multiple of four dividing it. MAC is explicitly fixed at 16 data bits.

`synthesis_results.json` records all 28 non-MAC profiles passing `hierarchy -check; proc; flatten; opt; check; synth -noabc; check -assert`. Every profile has zero final problems, no blackbox modules, and identical top-level port names, directions and widths before/after synthesis. The full converted Verilog, intermediate/final netlist JSON and logs are preserved in `build/phase3/vector_combo/synthesis/extended_flat`. No standard-cell area or timing was measured.

The earlier unflattened `proc; opt; check -assert` failed on **25 of 28** profiles because baseline ports/fields are undriven; only the three VectorMul leaf profiles passed that earlier check. `synthesis_hierarchical_results.json` and `build/phase3/vector_combo/synthesis/extended` retain those failures. `-HierarchicalOnly` reproduces that stricter early-stage audit and intentionally exits nonzero. The complete synthesis flow removes unused connectivity and optimizes undefined logic using Yosys's ordinary rules; no custom `setundef`, tie-zero pass or source correction is used. Final zero structural problems does **not** define the baseline's unknown values or prove four-state equivalence, and post-synthesis functional equivalence has not been claimed.

`tb_multp.sv` separately tests nine `(A_W,B_W,OUT_W)` combinations, including one-bit, odd, signed and extended-output widths. It compares **both** partial outputs with the original DW02 model and checks their sum against an independent product. Small operand combinations are exhaustive; larger widths combine directed edge patterns and seeded random samples. All nine configurations run 2,048 samples, for 18,432 total. The native combinational implementation adds no state or pipeline boundary. The surrounding MAC retains the baseline's inferred operand latches.

## Compatibility boundaries and retained behavior

* **VectorMulCombo Python/HDL difference:** RTLIR emits a narrow unsigned multiplication in the shift count, e.g. `4'(sub_bw) * 4'd2` for an eight-bit lane. Thus shifts 16 and 24 become 0 and 8. For opcode75, data32/lanes4, inputs `0x100` and `0x100`, original Python produces `0x10000`, while original translated HDL and native SV produce `0x1`. The native default deliberately matches the translated hardware. `python_hdl_discrepancy.json` records the actual unmodified Python probe; HDL/native witness lines and expressions are retained in the summary. Mul-combo profiles set `oracle=translated_hdl` and `python_equivalence=false`. This is a substantive baseline discrepancy, not an interface adapter effect.
* The original PrlMulAdder cannot elaborate with standard four-input Ctrl because it constructs two-input children and attempts to zero-extend a wider selector into a narrower one. Its failed manifest is retained. The comparison uses the original legal two-input Ctrl and an explicit field adapter into the native standard interface; it verifies that common semantic domain, not direct equivalence of the failing baseline configuration.
* Original VectorMulCombo routes data only to lanes0..3 even when eight lanes are allocated. AdderCombo's combined-constant add retains the original absent carry chaining. AllReduce global multiply sends the zero add-reduction field; its original request precedence, readiness and `already_sent_to_controller` behavior are preserved and tested.
* Existing undriven fields and partially assigned inputs remain undriven. No blanket zero substitution was applied. Verilator compares their two-state realization; these tests are not a four-state or formal equivalence proof.
* MAC signed comparisons retain the original subtraction-sign-bit equations, including overflow behavior. Its native `cgra_multp` preserves the vendor partial-product decomposition; vendor files retain notices and provenance and are not in the native synthesis file list.

Reference import fixes are host-only: root-aware Windows directory traversal in a local PlaceholderPass subclass, arithmetic-width parsing for wrapper port metadata, and removal of invalid Windows `` `line`` location directives in an ignored compiler copy. Frozen executable reference HDL is not changed. Each successful reference has an `exporter_snapshot.py` whose hash matches its manifest's historical exporter hash; the current evolved exporter is not substituted into that provenance. The failed Prl4 export also has its snapshot but failed before source-hash collection. Initial failures from these host issues and the real Prl/shift behavior must not be counted as native test passes.
