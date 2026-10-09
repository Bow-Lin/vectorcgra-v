# Remaining scalar FU migration

This directory tests the maintained modules in `rtl/fu/scalar`. The source
contract is `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`; the original Python and
`division.v` are unchanged. The standard interface is four data inputs, two
outputs, and the same full control/memory sidebands as `tile_adder`.

| Native modules | Extra parameters | Tested profiles |
|---|---|---|
| `scalar_const`, `scalar_comp`, `scalar_logic`, `scalar_shifter`, `scalar_sel`, `scalar_phi`, `scalar_grant`, `scalar_gep`, `scalar_extract_predicate`, `scalar_ret`, `scalar_loop_counter`, `scalar_loop_control`, `scalar_div` | `VECTOR_FACTOR_POWER=0` | DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16; DATA_W=64, CTRL_DEPTH=16, REG_DEPTH=8 |
| `scalar_inclusive_div` | `VECTOR_FACTOR_POWER=0`, `LATENCY=2` | DATA_W=32 only |
| `scalar_exclusive_div` | `VECTOR_FACTOR_POWER=0`, `LATENCY=4` | DATA_W=32 only |

All modules accept the shared `CGRA_PROFILE_PARAMETERS`. The pipeline wrappers
retain the baseline's hardcoded 32-bit divider and reject DATA_W other than 32.
Their default latency is tested. The underlying `scalar_div_pipeline` and
`scalar_div_stage` preserve the original restoring-divider implementation,
including its floor(WIDTH/CYCLE) partition rule; arbitrary latency values are
not claimed verified. `Ret`, `Phi` and `LoopCounter` retain 2**CTRL_ADDR_W state
slots, including rounded-up slots when CTRL_DEPTH is not a power of two.

## Daily SV-only entry points

From the repository root in PowerShell (MSYS2 UCRT Verilator and Clang installed):

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/run.sh w32
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/run.sh w64
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/scalar/check_synthesis.sh
```

The scripts use only frozen SV/hex assets and HDL/C++ tools, with no project
Python invocation. `CGRA_OSS_TOOLS` can override the default EDA tools directory
for the structural checks. The compile filelists are local to these tests and
do not modify the project's integration filelist. Logs go to
`build/phase3/scalar/{w32,w64,synthesis}` relative to `sv`.

Both simulation profiles compare every output bit on every recorded cycle,
including invalid message data and unused memory/sideband signals. Default:
15 native modules vs separately namespaced reference HDL, of which 13 also
compare the original Python cycle oracle. Wide: all 13 supported modules use
the same three-way comparison. The 303/424-bit snapshots are described in each
reference vector manifest; the test does not mask undefined or invalid bits.
Verilator is a two-state simulator, so this is not a claim about four-state X
equivalence or all possible control sequences.

Directed and seeded random stimuli cover every operation present in these
modules, zero/sign/overflow/shift boundaries, selector aliases including zero,
input/constant validity, predicate/bypass/delay, all control vector-factor
powers, output/control backpressure, resets, clear, and every control address.
Stateful sequences cover per-address returns/Phi, grant-once, loop lower/upper/
step commands, loop completion/shadow/reset and GEP stride commands. Independent
checks use arithmetic and signed comparisons, val/rdy equations, loop results
2/4/6/8 with terminating predicate, shadow 91 and reset-to-2. The pipeline
divider checks quotient 7 and remainder 1 for 50/7 after pipeline fill.

`+NEGATIVE` flips one bit of the Python oracle and must fail in the normal
comparison assertion. `+TIMEOUT_TEST` prevents normal completion and must fail
through the watchdog. The runner accepts neither a zero exit nor a wrong error
signature for either negative control.

The structural runner executes sv2v followed by Yosys `hierarchy -check; proc;
opt; check -assert; stat`, at both supported parameter profiles. This verifies
process lowering/connectivity, not a full technology mapping, cell area, timing,
or latch-free design. Latches in LoopControl and pipeline divider input capture
are inherited from ac96 and retained. Pipeline divider holding and counter
updates, and the vector-factor counter advancing on valid control rather than
an accepted handshake, likewise remain unchanged.

## Reference provenance and translation limitations

`reference/phase3/scalar/{w32,w64}/manifest.json` identifies baseline sources,
frozen raw RTL, namespace maps and script snapshots. Each module's
`original_export` identifies its actual historical generator snapshot; the
top-level `resume_transform` describes only later namespace/path/metadata work
and explicitly does not claim to have generated the raw RTL. The initial w32
script generated nine modules; the isolated adapter/host-fix script generated
the remaining six and all thirteen supported w64 modules. Raw `.v` files retain the
exported bytes. Joint-test copies only rename identifiers and normalize
diagnostic `line` path separators; the wrapper undefines the vendor `DIV`
guard between independently namespaced copies.

Four baseline modules did not directly translate in the installed PyMTL fork:

* Gep and LoopCounter used two-argument Data constructors; isolated copies
  append the existing default-zero bypass/delay fields for translation.
* ExtractPredicate's payload-type lookup was inside an update block; its isolated
  copy binds the same type at construction time.
* Div used unsigned Bits `//`, missing from the translator dispatch. Only the
  exporter process maps this AST operator to the existing unsigned `/` lowering.
  The original Python model still executes `//` and is the independent oracle.

The three source adapters have exact patches and hashes, and each adapted
Python model is compared with its original on every raw output bit and cycle
before its evidence is accepted. These references are explicitly **not**
described as direct exports of unmodified source. Original translation failure
logs are retained. Div-by-zero is excluded from original Python replay because
the baseline raises `ZeroDivisionError`; no defined numerical answer is claimed.

Inclusive/ExclusiveDiv contain an external Verilog placeholder and are not
claimed Python-simulated. Their HDL is exported using a host-only Placeholder
pass subclass to stop a Windows root-directory traversal hang (the installed
pass searches for the literal Unix root `/`). This does not change the divider
source or datapath. The original export attempt was interrupted at that hang.

Migration-only scripts are `phase3_scalar_export.py`, `phase3_scalar_vectors.py`,
`phase3_scalar_testbench.py` and the initial `phase3_scalar_port.py` conversion
aid. Native RTL is maintained directly after migration; rebuilding a native
design does not invoke any of these scripts. Results, exact commands, source
hashes, tool hashes and resolved implementation/tool failures are recorded in
`results/phase3-scalar.json`.
