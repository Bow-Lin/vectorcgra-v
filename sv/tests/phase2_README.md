# Parameterized scalar array acceptance

`phase2_tb_cgra_scalar.sv` constructs the control program in SystemVerilog,
checks every accepted host packet against frozen Python packet encodings,
checks the mathematical result independently, and compares the native design
against both independently generated ac96 HDL and the Python cycle trace.
All active output bits are compared, including idle messages. Only the same
three undriven external inter-CGRA outputs as phase 1 are excluded.

Compile exactly one reference HDL file per executable. Define
`PHASE2_REFERENCE_MODULE` to its module name, set the test's `COLS`/`ROWS`
parameters (and any data/storage parameters), and add `rtl/common` to the
include path. The DUT is `cgra_scalar`; the test top is
`phase2_tb_cgra_scalar`. `+VECTORS=<absolute path>` selects the corresponding
`vectors/phase2/<case>` directory. `replay_meta.txt` specifies the required
cycles per scenario and the exact total sample count. Normal execution does
not invoke Python.

The Hamiltonian cycle starts at Tile 0, snakes through columns 1 through
COLS−1, then returns south through column 0. Tile 0 loads bank-0 address 15
and later stores bank-1 address 16. The first compute Tile adds 5, the second
multiplies by 3, and every later Tile adds −8. The final compute Tile also
multicasts west at row 1. Both native and reference internal links must each
transfer exactly once with the independently calculated intermediate value.
Each Tile must return exactly one complete packet. Host readback checks the
result and the untouched input. The two scenarios reset and reconfigure the
same design, with inputs 7 and −6 represented modulo DATA_W.

The baseline data-32 references have been executed in Python:

| Case | Each scenario, post-reset cycles | Total snapshots | Input/output bits | Results |
|---|---:|---:|---:|---|
| 2×2 | 64 | 134 | 505 / 489 | 28 / −11 |
| 3×2 | 76 | 158 | 579 / 563 | 12 / −27 |
| 4×4 | 140 | 286 | 805 / 789 | −68 / −107 |

These are Python-reference results, not a claim that the new native DUT has
passed. Native execution must produce `PHASE2_CGRA_PASS`; the optional
`PHASE2_REFERENCE_ONLY` compile switch substitutes reference HDL for the DUT
to validate the test itself and produces a distinct
`PHASE2_REFERENCE_TEST_PASS` marker. It does not validate the native design.

`+EXPECT_FAILURE` deliberately corrupts the independent arithmetic result.
`+STALL_FOREVER +MAX_CYCLES=200` permanently blocks the west multicast sink;
the fixed Python replay is disabled for this intentional input change, while
HDL lockstep and transaction checks remain active. Both negative controls
must terminate with nonzero exit and the designated failure message. The
test uses two-state PyMTL/Verilator observations and makes no arbitrary-X or
all-program equivalence claim.

Migration-only reproduction tools are `migration_tools/phase2_export.py`
and `migration_tools/phase2_testbench.py`. Each reference manifest freezes
the ac96 commit, submodules, imported sources, parameters, type bit positions
and generated RTL hash. An exporter snapshot is retained so later exporter
parameter support cannot obscure the exact script used for an earlier case.
No phase-1 reference or vector file is modified.
