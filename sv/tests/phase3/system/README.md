# Complete single-CGRA stage-3 tests

The maintained `cgra_programmable` top is built from `filelists/phase3.f`.
Every test uses a complete 2x2 array with controller, control ring, two memory
banks and all four Tiles. Normal commands consume checked-in HDL and vectors,
without running project Python.

| Runner | FU list in slot order | Independent result |
|---|---|---|
| `run_base.sh` | Adder, Mul, Mem, Nah | `(x+5)*3-8`: 28 and -11 |
| `run_logic.sh` | Adder, Mul, Mem, Logic, Nah | `(~x)*3-8`: -32 and 7 modulo 32 bits |
| `run_float.sh` | FpAdd, FpMul, Mem, Nah | `(x+5)*3-8`: 28 and -11 in the original FP format |
| `run_vector.sh` | VectorAdderCombo, Mul, Mem, Nah | lane-add `05040302`, scalar multiply by 3, lane-add `f8f9fafb`: `84ff0004` and `04080a7e` |

The loop is Tile0 load[15] -> Tile1 -> Tile3 -> Tile2 -> Tile0 store[16].
Tile2 also multicasts west. Each reset-separated run checks 26 independently
packed host messages, one transfer on each of four native and reference links,
four completion packets, two readbacks, and one west output. Host and west
stalls are deliberate. Every runner requires 134 raw snapshots of 489 active
output bits, including messages when valid is zero. Base, Logic and Vector
also compare all 505 input bits and 489 output bits with original Python
traces. FP uses original translated HDL containing HardFloat, without claiming
a pure-Python oracle for external IP. Its integer-only numerical oracle uses
the actual baseline 9-exponent/22-fraction format, not IEEE binary32.

From the migration repository root on the configured MSYS2 host:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/system/run_logic.sh
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/system/run_float.sh
```

`sv/scripts/run.ps1 -Task phase3-system` runs all four runners plus both
complete Tile-variant systems in `../tile_variants/run_cgra.sh`; pass the usual
`-OssCadSuite` and `-Sv2v` arguments. Context checks 134 snapshots of 489 active
output bits; Streaming checks 160 snapshots of 513 bits and uses real KingMesh
diagonal links. See `../tile_variants/README.md` for their state/reference contracts.

`run_negative.sh` checks wrong arithmetic results and permanent west
backpressure for Base/Logic/FP after their binaries have been built. Vector
does those checks in its own runner. Variant-system runners corrupt an
expected bit and require the exact cycle20 failure. Runners require both
nonzero exit and the intended checker diagnostic.

Only three external inter-CGRA outputs, originally undriven in single-CGRA
mode, are excluded from replay. This is finite two-state verification, not
exhaustive or four-state equivalence.

`check_synthesis.ps1` runs sv2v and Yosys `synth -noabc; check -assert` for all
six complete DUT profiles. It retains all top ports and checks total input/
output widths: 702/685 for four ports, 750/733 for eight ports. Those totals
include the inactive inter-CGRA interface; replay counts do not.
`check_guard.ps1` requires invalid `VECTOR_FACTOR_POWER=1` to fail at the
specified guard. Neither check measures standard-cell area or frequency.
