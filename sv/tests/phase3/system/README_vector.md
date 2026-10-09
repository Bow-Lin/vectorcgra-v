# Four-lane programmable CGRA system test

Run from the repository root:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/system/run_vector.sh
```

The daily runner consumes only checked-in native SV, frozen ac96 reference HDL,
and frozen vectors. It does not run project Python. It compiles with Verilator
and Clang, executes the positive test and two required-failure controls, and
saves evidence below `sv/build/phase3/system/vector`.

The fixed profile is one 2x2 CGRA, DATA_W=32, four 8-bit lanes, CTRL_DEPTH=8,
REG_DEPTH=16, two 16-word memory banks, GLOBAL_ADDR_W=7. The ordered FU list is
VectorAdderCombo, Mul, Mem, Nah. All four Tiles participate:

| Link | Operation and independent expected value |
|---|---|
| Tile0 -> Tile1 | Load address15 from bank0 |
| Tile1 -> Tile3 | Add bytes of 0x05040302 independently, modulo256 per lane |
| Tile3 -> Tile2 | Multiply the full 32-bit word by3, modulo2^32 |
| Tile2 -> Tile0 | Subtract bytes of 0x08070605 independently, modulo256 per lane |
| Tile0 / boundary | Store address16 in bank1; Tile2 also multicasts west[1] |

The two reset-separated inputs are 0x7ffeff01 and 0xff01027f. The independent
results are 0x84ff0004 and 0x04080a7e. The chosen data exercises lane overflow,
lane underflow, nonzero upper lanes and scalar carry across lanes. The test
reads both address16 and unchanged address15 through the host controller.

For each scenario, all 26 configuration/query packets are independently packed
in SV and compared with the canonical ac96 words. The scoreboard requires one
transfer on each native and gold internal chain link, all four Tile completions,
exactly one multicast, exactly two correctly addressed read responses, stable
host output under backpressure, and no unexpected boundary traffic. West holds
eight valid cycles; host initially holds then follows a periodic ready pattern.

At every pre-edge observation, the test compares native against independently
exported reference HDL and original Python cycles: 134 observations across both
scenarios, all 489 active raw output bits including invalid message data, and
all 505 replay input bits. Only the original single-CGRA contract's three
inactive inter-CGRA output ports are excluded. This is a finite two-state
Verilator test, not exhaustive or four-state equivalence.

`+EXPECT_FAILURE` changes the independent mathematical expectation and must
trigger the normal west-result checker. `+STALL_FOREVER +MAX_CYCLES=200` must
trigger the normal timeout. The runner requires nonzero exit and the exact
expected failure signature for both controls.

The migration exporter `phase3_vector_system_export.py` constructs unmodified
ac96 CgraRTL and executes a fresh Python model after translation. Raw reference
HDL and source/type manifests are in `sv/reference/phase3/system/vector/2x2`;
configuration, cycle traces and layout manifests are in the matching
`sv/vectors/phase3/system/vector/2x2`. Export succeeds without a semantic or
translation adapter. The one-time scaffold script derives this driver from
the reviewed logic-system test; it is not a daily dependency. New maintained
scripts/TB/vectors use LF. The raw reference `.v` retains PyMTL's original CRLF
bytes under `reference/** -text`; its tested hash is not changed for formatting.
`sv/results/phase3-vector-system.json` records hashes, commands and outcomes.

VectorMulCombo is not used. This test makes no claim about repairing its
baseline high-lane routing limitation, arbitrary lane counts, other geometries,
physical area or frequency.
