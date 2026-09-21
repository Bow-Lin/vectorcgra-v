# Fixed 2x2 acceptance test

`tb_cgra_2x2_scalar.sv` tests the frozen `ac96a7` scalar profile, with
`cgra_2x2` and `VectorCGRA2x2Reference` driven together. The profile has four
mesh Tiles, 32-bit payloads, Adder/Mul/Mem/Nah FUs, eight control words,
16 registers per bank, and two data banks of 16 words. It is not a test of
arbitrary dimensions or all legal control programs.

Each scenario preloads input at address 15 and a sentinel at address 16.
Tile 0 loads the input and sends it east to Tile 1; Tile 1 adds 5 and sends
north to Tile 3; Tile 3 multiplies by 3 and sends west to Tile 2; Tile 2
adds -8 and multicasts south to Tile 0 and west to the external sink.
Tile 0 stores the returned result at address 16. Host reads verify both
the result and the unchanged input. The two inputs are 7 and 0xfffffffa,
with independently calculated 32-bit results 28 and 0xfffffff5. A fresh
three-cycle reset and complete reconfiguration precede each scenario.

The test enforces:

- Every independently constructed configuration/query packet matches the
  PyMTL-produced canonical packet hex, including all fields and array order.
- All four Tiles report completion exactly once, with full packet checks.
- Each directional internal mesh link transfers exactly once with the
  expected value; the external multicast result transfers exactly once.
- The host sink initially blocks six valid cycles and then periodically
  blocks; the west sink initially blocks eight valid cycles.
- Every sampled active output bit, including messages during invalid
  cycles, matches between the two HDL instances: 489 bits per cycle.
- The procedural SV driver's 505 input bits and the DUT's 489 output bits
  match the independently recorded PyMTL samples. There are exactly 134
  samples: three reset cycles and 64 execution cycles for each scenario.
- Eight cycles after the last response reject late duplicate traffic.
  Missing work, extra traffic, wrong values, and timeouts call `$fatal(1)`.

Only the three outputs left undriven by the original single-CGRA design
are excluded: `recv_from_inter_cgra_noc__rdy`,
`send_to_inter_cgra_noc__val`, and `send_to_inter_cgra_noc__msg`.
No mask depends on `val`. This run uses PyMTL and Verilator's two-state
behavior; it does not establish four-state initialization semantics.

Runtime controls:

- `+VECTORS=<directory>` selects checked-in packet and replay hex files.
- `+EXPECT_FAILURE` deliberately corrupts the algorithm's expected result.
  A successful negative check requires nonzero exit and the message
  `intentional negative control`.
- `+STALL_FOREVER +MAX_CYCLES=200` permanently blocks the west sink and
  must exit nonzero with `TIMEOUT scenario=`. This intentional input change
  disables the fixed PyMTL replay comparison for this negative test only;
  HDL lockstep and transaction checks remain enabled.
- `+TRACE=<file>` writes every sampled active interface to CSV. Columns
  start with scenario, cycle, reset, host input val/msg/rdy, and host output
  val/rdy/msg, followed by east, north, south, west ports 0 and 1, each with
  input val/msg/rdy and output val/rdy/msg. Invalid-cycle messages are kept.
- `+PACKETS=<file>` writes the constructed packet sequence to CSV.

Normal execution uses SystemVerilog and checked-in text vectors. Python
scripts under `migration_tools/` are provenance/export tools, not required
to run this test. The test's independent packing types live in
`scalar_workload_pkg.sv`; `tb_cgra_types.sv` separately checks the public
RTL package against nonzero PyMTL packing samples.
