# Migration-only reference export

Current-target exporters (`current_*.py`) use the Python pinned in
`sv/reference/current/target.json`; the historical tools described below retain
the original ac96 baseline. `current_static_memory.py --output-root <directory>`
freezes the standalone static CtrlMem/ConstQueue APIs and records original Python
failures separately. CtrlMem uses an explicitly documented field-name adapter;
see [STATIC_MEMORY_API.md](../STATIC_MEMORY_API.md). No original Python is edited.

`current_ring_ctrl_memory.py --output-root <directory>` freezes the unchanged
RingMultiCtrlMemDynamicRTL wrapper and its original test. It retains the dummy
event and stalled-return defects; native repairs are verified separately by HDL
protocol tests. See [RING_CTRL_MEMORY_API.md](../RING_CTRL_MEMORY_API.md).

These scripts freeze the unmodified Python RTL at
`ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`. They are optional migration tools;
the normal SystemVerilog build uses checked-in RTL and vectors without importing
the project Python generator.

Run from this worktree with the custom PyMTL3 environment. For example, the
environment used to create the checked-in reference was:

```powershell
& D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/export_reference.py
& D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/export_vectors.py
& D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/export_packing_and_replay.py
```

Both commands protect existing reference outputs. To reproduce without
overwriting them, pass a fresh `--output` directory. `export_vectors.py` uses
the checked-in reference RTL hash for provenance; its simulation constructs
the exact same model as `export_reference.py` through `reference_model.py`.
The local tool path is an example, not a build dependency of the SV design.

## Fixed profile

One CGRA contains a 2×2 mesh of Tiles. The payload is 32 bits; predicate,
bypass, and delay make the data message 35 bits. The FU list, in priority
order, is AdderRTL, MulRTL, MemUnitRTL, NahRTL. Every Tile has 8 control words
and 16 registers per register bank. The data memory has two 16-word banks,
local address window 0–31, and a 7-bit global address field. Memory reads use
the baseline combinational mode. The control ring is the baseline PyOCN ring
with 5 nodes and one cycle per link. DMA and im2col are absent.

The `num_ctrl=8` constructor setting gives the control-count field sufficient
width for 8 words. The workload explicitly configures 2 words on Tile 0 and
1 word on each other Tile, so it does not rely on reset count defaults.

`sv/reference/manifest.json` records all parameters, the exact baseline and
submodule commits, imported source hashes, Python/PyMTL provenance, and the
generated RTL hash. Its field offsets are measured by setting each leaf field
to one and invoking the actual PyMTL packet packer. Array element zero is not
assumed to be at either end. The host packet is **191 bits**, control word
119 bits, CGRA payload 170 bits, and unused inter-CGRA packet 194 bits.

## Workload and recorded evidence

The program preloads address 15 in bank 0 and a sentinel at address 16 in
bank 1. Tile 0 loads address 15 and sends east to Tile 1, which adds 5 and
sends north to Tile 3. Tile 3 multiplies by 3 and sends west to Tile 2. Tile 2
adds −8, multicasts south to Tile 0 and west to the external sink. Tile 0
stores the result at address 16. After all four completion packets, the CPU
reads addresses 16 and 15. The two scenarios use input 7/result 28 and,
after a three-cycle reset and reconfiguration of the same model, input
−6/result −11. Arithmetic uses the baseline 32-bit modulo representation.

The west sink stalls for its first eight valid cycles. The CPU sink stalls
for its first six valid cycles and then follows `cycle % 7 >= 2`. Other
boundary sinks are always ready; all boundary sources are invalid and zero.
Each host request is held until accepted. Both runs take 64 post-reset
cycles, including eight idle cycles after the final response. Each directed
edge in the four-Tile chain transfers exactly once. The original input is
read back unchanged, and the bank-1 sentinel is overwritten by the result.

`sv/vectors/configuration.json` and the two packet `.hex` files specify exact
host packets. Their first 24 packets are preload/configuration/launch;
the last two queries are issued only after the four completion packets.
`baseline_trace.jsonl` records inputs and outputs after combinational
evaluation immediately before each rising edge, including three reset
snapshots per scenario. Its 134 rows are replayable cycle stimulus and
expected observations; `manifest.json` records their hash and event summary.

The observations alone do not establish PyMTL-to-HDL cycle equivalence:
actual HDL replay must pass before making that claim. All active `val`,
`rdy`, and message bits (including idle messages) are retained for replay.
A valid-message-only comparison is narrower functional evidence and does
not replace the migration's full active-output cycle contract. The
baseline single-CGRA option leaves the declared external inter-CGRA outputs
undriven; these inactive ports are excluded. PyMTL simulation is two-state,
so this evidence does not claim HDL four-state equivalence for uninitialized
memories or undriven values.

`export_packing_and_replay.py` derives 134-row SV `$readmemh` input/output
files and a layout describing every field offset from the recorded trace.
`type_vectors.json` provides nonzero Data/Ctrl/Payload/Host fields and their
packed hexadecimal encoding. These packing examples deliberately exercise
every field; they are not legal commands to execute on this fixed instance.

No source RTL fixes or the later B/C2 optimizations are included. The first
vector-export attempt failed while packing Python `int` list elements in
the migration script; explicit Bits3/Bits4/Bits2 construction fixed that
script-only error before the successful run. No baseline RTL was changed.

## Phase 2 migration tools

`phase2_export.py` freezes separate unmodified ac96 profiles for 2x2, 3x2,
4x4 and the 64-bit/control-depth-16/register-depth-8 variant. Each profile
retains its exact exporter snapshot, source hashes, packed fields and replay
data. `phase2_testbench.py` was the one-time scaffold for the checked-in
`tests/phase2_tb_cgra_scalar.sv`; the maintained test is compiled directly.

`phase2_port_support.py` helped extract baseline controller/memory blocks,
replace type and module names, and restore parameter expressions during the
port. It is not a hardware generator used by Make, and is not the source of
truth for subsequent edits to `rtl/`. Later corrections and integration are
maintained in the checked-in SystemVerilog. Final phase-2 coverage and evidence
are described in `../PHASE2_REPORT.md`.

`current_data_memory.py` 冻结未修改 DataMemRTL；原测试 Source/Sink 断言保留，附加多口位级轨迹及 Bits0 边界。日常回归不调用此工具。
