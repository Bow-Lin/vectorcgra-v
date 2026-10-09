# Peripheral migration work log

Agent: `/root/synth_tools`. Worktree: `D:/work/VectorCGRA/.worktrees/VectorCGRA`.
Parent branch starts stage 4/5 at `codex/sv-migration@1a5585a`; Python baseline
remains `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`.

## 2026-09-22 — interface audit

Read `mem/dma/DmaEngineRTL.py`, `fu/others/Im2colEngineRTL.py`, their existing
component tests, `mem/data/DataMemRTL.py`, message factories and command/state
constants. No original Python files changed.

DMA preserves 32-bit SPM words / 128-bit DRAM beats, nine handshake interfaces,
little-endian word packing, full/partial masks, one outstanding transaction and
tagged done. The implementation shifts nbytes right by two, despite a contradictory
comment about rounding up. Non-word-aligned byte counts are an existing unsupported
input domain; no silent repair will be made.

Im2col preserves IDLE/READ/EMIT/DONE, one explicit READ cycle per output, terminal
DONE until reset, retained geometry configuration across reset, and the private
preloaded scratchpad. `DataMemRTL` lazily initializes read locations without
resetting its initialization bits or data. Native ports will not add a new image
write channel absent from the original engine.

Planned evidence: unmodified generated HDL where translation succeeds, actual
Python cycle traces, independent DMA transactions / image-window expectations,
backpressure and reset tests, deliberate negative controls, and sv2v/Yosys
synthesis checks. Normal SV tests will not invoke project Python.

## 2026-09-22 — native components and two DMA contracts

Implemented `cgra_dma_engine.sv` and `cgra_im2col_engine.sv`; added four
frozen original HDL references with `phase4_peripheral_export.py --kind
{dma,dma-small,im2col,im2col-wide}`. Added retained SV benches and the
SV-only `run_components.sh` entry point. Initial DMA comparison failed at
cycle 39: the frozen translator emits a six-bit expression for the third
word's slice lower bound (`6'(32)*6'd2`), which wraps to zero. The fourth
word likewise selects lane one. Its MVOUT lane-one concatenation also
temporarily duplicates word zero into the unused third lane. Evidence is
preserved under `sv/build/phase4/peripheral/dma/failed-initial` and in the
unchanged reference HDL (lines 175, 178, 390).

Parent confirmed the existing hardware migration contract: default native
`BASELINE_TRANSLATED_SLICES=1` preserves these frozen HDL behaviors. The
explicit value `0` supplies original Python semantics as a separately
labelled extension. No Python or frozen HDL was repaired. Default tests
count the known incorrect MVIN words instead of claiming mathematical
correctness. Both width profiles now pass 654 cycles of full raw HDL
comparison, 22 transactions, including all 4/8/12-byte partial beats, full
beats, multi-beat tails, zero length, tags, done backpressure and reset.
Each deliberately distinct-data workload records 20 incorrect transferred
words in default hardware mode.

The explicit Python mode passes the independent transfer checks with zero
incorrect words. `phase4_peripheral_pytrace.py` drives exactly the captured
654 input cycles through unmodified ac96 Python, verifies every native
output bit, and freezes the oracle. An initial exporter infrastructure
error accessed `_dsl.Type` after PyMTL's simulation pass replaced ports with
Bits values; it was changed to `type(obj)`. That failed export is preserved
as `dma-pytrace-failed-type/failure.txt`. Both subsequent exports pass.

Im2col 32-bit/64-bit configurations each pass 876 full raw HDL cycles and
235 independent pixel/window checks across four complete runs and one
aborted run. Coverage includes stride 1/2, rectangular kernels, output
backpressure, ignored busy commands, retained geometry/image across reset,
mid-operation reset, sequential addresses and terminal done.

`check_synthesis.ps1` completes six profiles (both DMA semantics at both
address/tag widths and both Im2col configurations): sv2v, deferred Yosys
read/chparam/hierarchy, synth -noabc, check -assert, stat -json. All final
checks report zero problems; no mapping or timing is claimed. Initial
four-profile results before the DMA mode parameter are retained in
`build/phase4/peripheral/synthesis-before-baseline-mode/`.

Native generic composition wrappers `cgra_integrated_dma` and
`cgra_integrated_im2col` are now written. They require explicit matching
HAS_DMA/HAS_IM2COL parameters; Im2col preserves the original engine_active
CPU gate. Complete system reference exports and integration verification
are in progress, not yet counted as passing.

The first integrated DMA executable stopped at time zero at the native
mandatory-Nah guard. The profile extraction initially copied the three
configured FU kinds, overlooking `FlexibleFuRTL.py:35-36` automatically
appending Nah during original elaboration. The native bench now expands
the list to Adder/Mem/Ret/Nah. The original frozen HDL and manifest remain
unchanged; `dma-system/native-profile-expansion.json` records the corrected
effective native parameters. First-attempt logs, bench and Verilator input
record are retained under `dma-system/failed-missing-nah`. No shared RTL
was changed to bypass the guard.

Both complete integrations now pass positive and deliberate-negative tests:

- DMA: 86 raw differential cycles, 2 tag/done packets, 5 CPU loads, 2 DRAM
  read beats and 2 write beats. Two incorrect words from the frozen HDL
  MVIN defect remain visible and are expected explicitly.
- Im2col: 202 raw differential cycles, 16 CPU memory reads checked against
  independently enumerated windows, and 45 CPU blocked cycles from the
  original engine_active gate.

Command: `bash sv/tests/phase4/peripheral/run_systems.sh dma-system
im2col-system`. Each negative case corrupts one expected output bit at
cycle 20, fails with the named mismatch, and returns nonzero. No integrated
system synthesis was started: parent requested waiting while shared
MEM_WRITE_PORTS parameters are being extended. Historical collection keeps
the exact Verilator input database and excludes changed files from the
compiled SHA256 list. Parent will run final frozen-source regressions.

Read-only composition findings and scope boundaries are recorded in
`READ_ONLY_SYSTEM_REVIEW.md`. The multi-wrapper peripheral-enable guard
issue was sent to the parent and is being corrected there; no shared files
were edited by this agent.

## 2026-09-22 — final shared-source closure

After the parent's MEM_WRITE_PORTS and multi-wrapper guards froze, reran
the wrapper scaffolder to carry the independent write-port array width
into both peripheral compositions. This changes declaration/bindings only;
the default profiles preserve the same interfaces and behavior. Archived
earlier system logs, input databases and component summary under
`build/phase4/peripheral/historical-before-write-ports/` before rebuilding.

Final commands, from the worktree root:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase4/peripheral/run_components.sh
& C:/msys64/usr/bin/bash.exe sv/tests/phase4/peripheral/run_systems.sh
& sv/tests/phase4/peripheral/collect_results.ps1 -IncludeSystems
& sv/tests/phase4/peripheral/check_system_synthesis.ps1
& sv/tests/phase4/peripheral/check_synthesis.ps1
```

All six component and two system positive/negative tests pass on the final
shared source. The collection ran without `-Historical`; both system
Verilator input databases match the recorded current source SHA256 with
no inputs changed after compilation. Component synthesis was repeated
after the system runs so its six successful zero-problem final checks
also reference the final shared headers. No original Python or frozen
reference artifact was changed during this closure.

Complete DUT-only integration synthesis retained every top-level port,
used each SV bench's exact native parameters and performed no mapping:

| Native top | Ports | Yosys seconds | Check counts, initial to final | Yosys generic num_cells |
| --- | ---: | ---: | --- | ---: |
| cgra_integrated_dma | 33 | 781.032 | 733, 0, 0 | 4,137,558 |
| cgra_integrated_im2col | 30 | 406.646 | 388, 0, 0 | 3,279,460 |

Each raw `num_cells` figure includes the two hierarchical instances
reported by `num_submodules`; these are not standard-cell area figures.
Initial source un-driven diagnostics are retained separately from final
`check -assert` success. The flow neither tied unknown sources to zero nor
disabled checks. The compact port dumps, stat JSON and full logs are in
`build/phase4/peripheral/system-synthesis/`; final tool versions, parameters,
source/run-script/log hashes and an empty `source_changes_during_run` list
are in `system-synthesis-results.json`. No giant mapped/netlist JSON,
timing claim, new pipeline delay or replacement behavior model was used.

Parent was notified of completion and the remaining documented boundaries:
default DMA preserves the frozen HDL lane defect, Python mode is explicit,
unaligned byte counts are outside the supported complete-transfer domain,
and Im2col verification is two-state with original unreset state preserved.
The earlier sparse/disabled Template scope note remains unproven rather
than being presented as a tested failing or supported native profile.

Final packaging corrected only the three PowerShell report serializers to
emit LF instead of ConvertTo-Json's Windows CRLF. Existing reports were
normalized with parsed JSON data equality checked before/after; all three
scripts passed the PowerShell parser. No command, RTL, result value or
recorded source/log hash changed, so the completed hardware runs were not
repeated for this formatting-only correction.
