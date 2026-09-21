# Tile variants and streaming memory

These tests use native parameterized SystemVerilog. They do not execute project
Python during a normal build. The migration exporters are retained separately in
`sv/migration_tools/phase3_variants_*.py`.

From the repository root on the configured Windows/MSYS2 host:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/tile_variants/run_components.sh
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/tile_variants/run_tiles.sh
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/tile_variants/run_cgra.sh
& ./sv/tests/phase3/tile_variants/check_synthesis.ps1
```

The shell entry points use Verilator 5.050 and Clang 22.1.8 with C++20. The
synthesis entry uses sv2v 0.0.13 and Yosys 0.69+62, with configurable `-ToolRoot`.
Generated C++ and logs remain under `sv/build/phase3/tile_variants`. The tests use
seed 31415926. Warnings are retained; the run is not advertised as warning-free.

## Native contracts

- `tile_context_switch` keeps the ac96 command/PHI-address queues and progress,
  status, and PHI-address registers. The latter three do not reset. PAUSE can
  capture progress with input val/predicate low; RESUME consumes saved progress
  without waiting for the overwrite output's ready signal.
- `tile_streaming_memory_fu` implements the original request/response cursors.
  Configuration and cursors do not reset, and clear is unused. A changed control
  address starts streaming even with control val low. Responses must be ordered;
  completion requires the final response address to equal the configured end.
  No new stride/range interpretation or outstanding-request limit is introduced.
- `tile_context` supports the original four physical ports, register-to-routing
  path, constant capacity `CTRL_DEPTH+10`, FU-output overwrite, and immediate
  TERMINATE clear. Only Phi and Ret FU slots receive that clear.
- `tile_streaming` supports the original eight physical ports, constant capacity
  `CTRL_DEPTH`, no register-to-routing path, and the original streaming done-bit
  rules. Its raw controller packet retains the original transparent storage:
  the Python update block has no default assignment. Its constant-queue clear
  and the Context Tile's FU control-address input remain originally undriven.

The wrappers accept the shared profile and FU-list parameters. The tested lists
are Context `{Nah,Mem,Mul,Adder,Phi}` (five slots)
and Streaming `{Nah,StreamingMem,Mul,Adder}` (four slots), using SV concatenation
notation: slot zero occupies the rightmost, least-significant byte. The wrapper defaults
are the shared catalog defaults; callers explicitly select their intended list.
The current variant tests use DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16. Other widths
are parameterized in source but are not claimed as tested by these results.

## Oracle and independent checks

The frozen baseline is `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`.
`streaming-w32-c8-r16/Phase3StreamingW32C8R16.v` is exact, unmodified translator
output and is compiled beside the native streaming FU. The ContextSwitch and
both Tile references use actual unmodified Python simulation because the
baseline translator fails on those objects. No patched Python or corrected HDL
is used as their oracle.

- ContextSwitch: 360 cycles; every output bit compared, including idle messages;
  PAUSE suppression, PRESERVE, single-use RESUME under backpressure, queue delay,
  and reset retention.
- StreamingMem: 358 cycles against gold HDL; five independent ordered requests
  and responses, exactly one completion, request/output backpressure, reset and
  clear during a stream, plus 300 cycles of random raw inputs and vector factors.
- Context Tile: 210 cycles, two reset-separated programs and 12 outputs; the
  first independent sequence is `(0,1),(1,1),(0,0),(0,0),(2,1),(3,1)` as
  `(payload,predicate)`. The final segment fills all input channels, sends
  TERMINATE, and requires ready to recover on the following cycle.
- Streaming Tile: 190 cycles, two reset-separated streams, ten requests and ten
  outputs. Addresses are 10,12,14,16,18 and payloads are `address*7+1`.
- Full Context CGRA: 134 cycles; four-Tile loop `load[15] -> +5 -> *3 -> -8 ->
  store[16]`, plus west multicast, four completion packets per run, and host
  readback. Results are 28 and -11 after reset.
- Full Streaming CGRA: 160 cycles; real 2x2 KingMesh diagonal links carry
  `stream[10:2:18] -> +5 -> *3 -> -8 -> west`. Results are
  `[10,13,16,19,22]`, then `[-8,-5,-2,1,4]` after reset. Both diagonals carry five
  values per run; each Tile completes, and host reads verify retained SRAM.

Tile/system replays compare every active top-level output bit every sampled
cycle, including idle messages. Complete systems omit only the three originally
undriven external inter-CGRA outputs in `is_multi_cgra=False`; no active message
bits are masked. The frozen manifest names those endpoints. SV negative controls
flip an expected bit at cycle 20 and require a nonzero exit at that exact mismatch.
Unreset startup state is compared under the existing PyMTL/Verilator two-state,
zero-initialized simulation contract; no new hardware reset is implied.

## Preserved baseline/tool failures

The reference tree retains the full failed diagnostics:

- Four-port Streaming Tile cannot elaborate: control selector Bits4 is connected
  to a crossbar Bits3 selector. The original streaming CGRA test uses KingMesh
  with eight physical ports, which elaborates successfully.
- ContextSwitch and Context Tile HDL translation reject `DataType(0,0)` at
  `ContextSwitchRTL.py:73` because RTLIR requires all four bitstruct fields.
- Eight-port Streaming Tile HDL translation rejects a heterogeneous FU-array
  controller-packet connection (`ComponentIndex`). Pure Python simulation works.
- The first full-CGRA exporter attempt called `to_bits` before typed control
  field construction; its failure is retained in `context-cgra-pyreplay`. The
  successful Context oracle is `context-cgra-pyreplay-v2`.
- The first synthesis invocation joined Yosys commands into one line. The entry
  was corrected; the failed script/log is retained under the ignored synthesis
  `failed-script-format` directory. No RTL or check was weakened.

Generic synthesis includes every exposed Tile top port and performs
`synth -noabc; check -assert; stat -json`. Early source warnings and final check
results are separate in `sv/results/phase3-tile-variant-synthesis.json`. This is
an elaboration/synthesis compatibility check, not a mapped area or frequency result.
