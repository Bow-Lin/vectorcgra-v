The Tile migration has two native SystemVerilog differential tests. Run them
from PowerShell with `C:/msys64/usr/bin/bash.exe sv/tests/run_native_tile.sh`.
The script uses the established MSYS2 Verilator/Clang toolchain and requires no
project Python. Logs, executables, and source/log hashes go to
`sv/build/native_tile/`.

Both tests compare against the frozen phase-one modules in
`rtl/fixed/cgra_2x2_core.sv`, derived from ac96. This file is compiled only as
the test reference, not as a dependency of the parameterized native Tile.
The native profile is COLS=2, ROWS=2, DATA_W=32, CTRL_DEPTH=8, REG_DEPTH=16,
BANK_DEPTH=16, NUM_BANKS=2, GLOBAL_ADDR_W=7, NUM_CTRL=8, TOTAL_STEPS=8.
Both executables use explicit Verilator seed 31415926.

- `tb_native_tile.sv`: 2,000 sampled cycles of the complete Tile, including
  periodic reset, random controller/data/memory traffic, and backpressure.
- `tb_native_tile_units.sv`: 1,999 sampled cycles for each of FlexibleFu,
  RegisterCluster, routing crossbar (8 inputs), and FU crossbar (2 inputs).
  The run spans 2,000 clock cycles. Random selectors include truncated aliases,
  and clear/reset are exercised independently.

Every output is compared, including message bits while val is zero. These
random tests complement the directed CGRA workload/replay tests; they do not
replace those tests or claim exhaustive operation/configuration coverage.
The native Tile intentionally retains ac96's undriven ConstQueue clear input.

The FU list remains Adder, Mul, MemUnit, and Nah, with four operand inputs,
two FU outputs, and four physical Tile directions. DATA_W, CTRL_DEPTH,
REG_DEPTH, Tile ID width, and associated packet fields are elaboration
parameters. The vector replay counter remains 8 bits and prologue counters
remain 3 bits, as in ac96. Non-power-of-two storage depths preserve the original
undefined domain for out-of-range configuration addresses.
