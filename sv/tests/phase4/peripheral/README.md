# DMA and Im2col migration

From the worktree root, the regular build uses no project Python:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase4/peripheral/run_components.sh
& sv/tests/phase4/peripheral/check_synthesis.ps1
& sv/tests/phase4/peripheral/collect_results.ps1
```

The Bash entry point uses the existing MSYS2 Verilator/Clang toolchain. The
PowerShell synthesis entry point accepts `-ToolRoot` and uses sv2v followed
by Yosys `synth -noabc`, `check -assert`, and `stat -json`. Native DUT ports
remain exposed; no portless test wrapper removes the design. These are
generic synthesis checks, not standard-cell area or timing measurements.

`component-results.json` records exact logs/source hashes, warning counts,
coverage banners and the deliberately corrupted bit at cycle 20. Original
reference Verilog warnings are retained, including source latches in the
Im2col scratchpad; these builds are not warning-free.

## DMA contracts

`cgra_dma_engine` retains the original nine val/rdy interfaces. Supported
data widths are 32-bit SPM and 128-bit DRAM. Address, byte-count and tag
widths are parameters. SPM addresses count words; DRAM addresses count
bytes. Commands pack opcode, DRAM address, SPM address, byte count and tag
from high to low bits. The supported complete-transfer domain requires
byte counts divisible by four, including 4/8/12-byte partial beats. The
original unaligned truncation/underflow behavior is not repaired.

**Default `BASELINE_TRANSLATED_SLICES=1` follows the frozen generated
hardware.** Its narrow slice-index expressions select lanes 0,1,0,1 for a
four-word MVIN beat. For example, input words `[A,B,C,D]` produce `[A,B,A,B]`.
In MVOUT, the second inserted word temporarily leaves a copy of word zero
in unused lane two; the corresponding byte mask keeps that lane disabled
for a two-word partial beat. Both valid and idle messages preserve this
behavior. Original evidence is `reference/phase4/peripheral/dma/Phase4Dma.v`
lines 175, 178 and 390. The reference file is unchanged.

**Explicit `BASELINE_TRANSLATED_SLICES=0` follows original Python behavior.**
It is a separately selected extension, not a hardware-equivalent repair.
Its same 654 input cycles are replayed through actual unmodified ac96
Python and stored under `dma-pytrace` / `dma-small-pytrace`; every output
bit is checked at normal SV runtime without invoking Python. Default HDL
tests independently compare every raw output bit to the frozen HDL.

Each address/tag profile exercises 22 complete transactions: both directions
for 0 through 9 words, nonzero opcode dispatch, and reset/recovery. Tests
check 50 SPM writes, 48 SPM reads, 17 DRAM reads and 16 DRAM writes, delayed
responses, periodic request backpressure, tag retention and held done.
The default workload explicitly counts 20 incorrectly transferred words;
Python mode has zero. A bounded 1-byte case documents the existing
unsupported behavior and is reset before completion.

## Im2col

`cgra_im2col_engine` uses the shared CGRA profile plus `SCRATCH_DEPTH` and
`PRELOAD_IMAGE`. Pixel zero occupies the low DATA_W bits. Unspecified
pixels are zero with predicate one. It has exactly command packet,
store packet and done interfaces, with no added image-write port.

The native engine preserves the original READ/EMIT cycle split, nested
ox/oy/kx/ky order, address wrapping, ignored busy commands, and terminal
DONE until reset. Geometry registers, scratchpad contents and lazy-init
bits retain the original absence of reset. Reset clears only the original
FSM, loop counters, emit index and output data register. No new clear
signal is invented for either peripheral.

32-bit/64-bit payloads and 64/32-entry scratchpads are tested. Each performs
876 full HDL differential cycles, 235 independent window pixel checks,
four complete image runs and one partial run interrupted by reset.
Coverage includes stride 1/2, rectangular kernels, output backpressure,
busy command rejection, destination addresses and retained configuration.

## Integrated wrappers

`cgra_integrated_dma` composes `cgra_system` and the DMA engine. Invoke it
with `HAS_DMA=1`, `HAS_IM2COL=0`, and `DATA_W=32`. Default DMA hardware
semantics remain selected; the explicit Python mode parameter is forwarded.

`cgra_integrated_im2col` requires `HAS_IM2COL=1`, `HAS_DMA=0`, `IS_MULTI=0`.
It reproduces the original registered `engine_active` CPU gate: launch
handshake asserts the gate, engine done clears it, and packet message bits
continue to propagate while CPU valid/ready are gated.

Full-system tests use the original Integrated Python classes' frozen HDL:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase4/peripheral/run_systems.sh
& sv/tests/phase4/peripheral/check_system_synthesis.ps1
& sv/tests/phase4/peripheral/collect_results.ps1 -IncludeSystems
```

Final shared-source validation passes all six component profiles and both
integrated systems, including each deliberately corrupted-output negative
control. DMA checks 86 complete-system cycles, five CPU loads and two
transfers; Im2col checks 202 cycles, 16 CPU loads and 45 blocked CPU cycles.
The two integrated generic synthesis runs also finish with zero final
check problems. Initial source diagnostics (733 DMA / 388 Im2col) remain
in their logs and are distinct from the final zero counts.

These system programs
exercise external memory / engine / controller / CGRA memory / CPU paths;
they do not execute a Tile arithmetic kernel. Migration-only exporters are
under `sv/migration_tools/phase4_peripheral*`; their snapshots and source
hashes are retained with frozen reference artifacts.

`check_system_synthesis.ps1` selects each integration bench's actual native
parameter profile, exposes all DUT ports, and runs sv2v followed by complete
Yosys `synth -noabc; check -assert; stat -json`. It stores compact port dumps
and statistics under `build/phase4/peripheral/system-synthesis`, and source,
command, tool and log hashes in `system-synthesis-results.json`. The script
fails if input source hashes change while either profile is running. Its
generic cell counts are the unmodified Yosys statistics, including the
hierarchical instances listed by `num_submodules`; they are not mapped
standard-cell area or frequency measurements.
