# 4×4 CGRA NoC experiments

The approved scope is in `OPTIMIZATION_PLAN.md`. The complete experiment history,
agent assignments, failures, validation and commits are recorded in
`EXPERIMENT_LOG.md`. Compact reports are tracked in `results/`.

## Environment

Use Python 3.12 and the custom PyMTL3 fork pinned in `requirements-lock.txt`:

```powershell
uv venv --python 3.12 sys_lib/.venv
uv pip install --python sys_lib/.venv/Scripts/python.exe -r sys_lib/requirements-lock.txt
git submodule update --init --recursive
```

See `LIBRARY.md` for the public NanGate45 library and tool versions. Keep the
matching library at `sys_lib/lib/NangateOpenCellLibrary_typical.lib`. Install
Yosys/ABC and sv2v on PATH or under `sys_lib/tools/`. The scripts also accept
explicit executable paths. On Windows the OSS CAD Suite `bin` and `lib` paths
are added automatically when the tools are called.

## Reproduce a stage

Run from the repository root, at the source commit associated with that stage.
Use a fresh output directory for each translation; existing RTL is not overwritten.

| Stage | Reproducible source/tool checkout | Hardware |
|---|---|---|
| A0 | `74eb4fc` | Original RTL from `41cb0c0`; only experiment tooling was added |
| B1 | `972145e` | Static control-ring switch |
| C2 final | `e91686f` | B1 plus shared Crossbar prologue comparisons |

Later report-only commits retain the C2 hardware. The original baseline commit
does not contain these newly added scripts; use the A0 tooling commit above to
reproduce it. Keep the local ignored tools/environment/library directories.

```powershell
sys_lib/.venv/Scripts/python.exe sys_lib/generate.py --output sys_lib/build/example
sys_lib/.venv/Scripts/python.exe sys_lib/synthesize.py --input sys_lib/build/example
sys_lib/.venv/Scripts/python.exe sys_lib/area_report.py sys_lib/build/example/hierarchical/mapped.json --liberty sys_lib/lib/NangateOpenCellLibrary_typical.lib --top VectorCGRA4x4 --output sys_lib/build/example/hierarchical/area
sys_lib/.venv/Scripts/python.exe sys_lib/mapped_timing.py --input sys_lib/build/example/hierarchical/mapped.json --output sys_lib/build/example/hierarchical/timing --manifest sys_lib/build/example/manifest.json --inactive-output recv_from_inter_cgra_noc__rdy --inactive-output send_to_inter_cgra_noc__val --inactive-output send_to_inter_cgra_noc__msg
sys_lib/.venv/Scripts/python.exe sys_lib/collect_results.py --input sys_lib/build/example --name example
```

The area flow maps the **complete CGRA**, preserving hierarchy for exact additive
ownership of every standard cell. Memories map to standard-cell registers and
logic. The real CGRA boundary ports remain exposed; test harness constants are
not synthesized. No workload configuration is used for constant propagation.

Timing is a separate analysis of the same mapped logic across hierarchy
boundaries with Yosys's ABC, using BUF_X1 drive and 5 fF endpoint loads. It is a
**combinational delay estimate** and reciprocal frequency reference, excluding
clock-to-Q, setup, clock-tree and routed timing. Per-module ABC mapping delays
are diagnostics, not the complete CGRA's delay. Unsupported or invalid timing
graphs must be reported; they cannot be silently repaired or replaced with
local delay numbers.

This fixed instance uses `is_multi_cgra=False`; the command above explicitly
identifies its three unimplemented inter-CGRA output ports. The analyzer checks
the manifest and requires every bit of those ports to be x. All four mesh data
boundaries remain timed. The baseline also has undefined inputs inside mapped
FU/constant-queue logic, so its complete-design delay is currently unavailable;
the command intentionally returns an error with diagnostic `timing.json`.

The optional mapping-before/after flatten modes are separate experimental
flows. Do not mix their area denominators or compare one version mapped with
hierarchy against another version flattened before mapping.

## Crossbar verification

```powershell
sys_lib/.venv/Scripts/python.exe sys_lib/verify_crossbar.py --case routing8x8 --case fu2x8 --cycles 200
sys_lib/.venv/Scripts/python.exe sys_lib/verify_crossbar.py --translate-only
sys_lib/.venv/Scripts/python.exe sys_lib/equivalence.py
```

For the exact fixed-instance crossbars, select `routing8x8_ctrl6` and
`fu2x8_ctrl6`. `--candidate-source` accepts an isolated prototype file. With a
translated manifest, `local_crossbar_synth.py --manifest <manifest> --output
<fresh-directory>` reproduces the local mapping flow. C1/C3 patch artifacts
apply to the original Crossbar, not to the final C2 implementation; their
reports explicitly distinguish screening results from complete-CGRA results.

The verifier loads reference source from the fixed baseline commit. Reports
retain source hashes, port shapes, seeds, state coverage and actual checks.
Baseline-to-baseline smoke checks validate the workflow, not an optimization.
Verilator import remains a separate check from RTLIR translation and Yosys
equivalence; see the experiment log for local toolchain limitations.

## Control-ring switch verification

```powershell
sys_lib/.venv/Scripts/python.exe -m pytest noc/test/StaticSwitchUnitRTL_test.py -q --tb=short
sys_lib/.venv/Scripts/python.exe sys_lib/verify_switch.py --output sys_lib/build/switch-example --case control6x199 --synth
```

This compares the original PyOCN switch against `StaticSwitchUnitRTL`, including
idle messages, backpressure and the continuously enabled round-robin arbiter.
The formal report accounts for every output and all priority-state bits.
Local switch area is separate from complete-CGRA area.

## Complete CGRA cycle comparisons

```powershell
sys_lib/.venv/Scripts/python.exe sys_lib/verify_cgra.py --record-only --output-dir sys_lib/build/reference-traces
sys_lib/.venv/Scripts/python.exe sys_lib/verify_cgra.py --reference-run sys_lib/build/reference-traces --output-dir sys_lib/build/candidate-replay
```

Reference and candidate execute in fresh Python processes using frozen source
snapshots. The reference records all top-level inputs and every output bit
before and after each clock edge; the candidate replays the exact input stream.
The scenarios cover INC/configuration/completion, traffic through all four mesh
boundaries, multicast under output backpressure, and configured prologue steps.
Expected output tokens and completion packets are also checked when recording
the reference, so a stalled or ineffective stimulus cannot silently pass.
These finite integration checks complement the component equivalence proofs.
The default simulation is slow on this host; the saved baseline trace can be
reused for later candidates after its baseline, seed and scenario checks pass.
