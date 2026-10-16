# Native SystemVerilog tests

The complete current test catalog is maintained in
[REGRESSION.md](../REGRESSION.md): 14 groups and 49 targets. Use `make -C sv current`
for the current component/PE/DMA entry, or `python3 sv/scripts/regression.py --all`
for the full catalog. Exact evidence and remaining scope are indexed in
[FINAL_ACCEPTANCE.md](../FINAL_ACCEPTANCE.md).

Current standalone static storage tests run with `make -C sv current-static-memory`
and `make -C sv current-static-memory-synth`. They cover frozen Python compatibility,
native handshake/reset corrections, negative controls, and real synthesized netlists.
See [STATIC_MEMORY_API.md](../STATIC_MEMORY_API.md) for the API and evidence scope.

The standalone ring/memory wrapper runs with `make -C sv current-ring-ctrl-memory`
and `make -C sv current-ring-ctrl-memory-synth`. Four parameter profiles cover
legacy Python replay and native completion/backpressure checks; see
[RING_CTRL_MEMORY_API.md](../RING_CTRL_MEMORY_API.md).

Stage 3 tests are under [`phase3/`](phase3/system/README.md): scalar,
vector/composite, floating-point, Tile variants and six complete single-CGRA
profiles. These are historical contracts; select their fixed source through
`sv/scripts/run_baseline.sh`, as described in the regression guide. Stage 2
parameterized array tests remain documented in [phase2_README.md](phase2_README.md).

Historical DUT sources are under [`legacy/rtl/`](legacy/README.md); golden HDL
is under `../reference/legacy/` and `../reference/vendor/`. These are excluded
from the native filelist. See [RTL_LAYOUT.md](../RTL_LAYOUT.md).

## Historical fixed 2x2 acceptance test

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

## 第四阶段历史记录

[phase4/README.md](phase4/README.md) 保留多 CGRA、异构结构、NoC、任务迁移、DMA/im2col 与非对称存储的历史用例。旧阶段默认配置兼容性重跑结果见 `phase4/compatibility/results.json`。当前已授权收尾任务及状态见 [MIGRATION_TASKS.md](../MIGRATION_TASKS.md)。

## 当前独立 API

`make -C sv current-data-memory current-data-memory-synth` 验证独立 DataMem 的 Python 对照、原生计分板及综合网表。

`current-scalable-memory` / `current-scalable-memory-synth` 通过共享台架验证 Scalable 包装层；NoC 随机输入期间本地功能及固定零输出均受检查。

`current-or-link` / `current-or-link-synth` 验证多输入 OrLink 的未修改 Python 轨迹及全部 valid 掩码的独立位计数结果。

`current-selector` / `current-selector-synth` 检查全部选择口和 valid 掩码，原生模式隔离未选口 ready；兼容模式逐位复现 Python 的 ready 锁存缺陷。

`current-pipe-queue` / `current-pipe-queue-synth` 检查 Python 逐位兼容、独立 FIFO 守恒及连续满替换；Normal Queue 替换负控必须失败。

`current-vector-reduce` / `current-vector-reduce-synth` 检查归约的原生数学、事务守恒和原 Python 缺陷兼容；`native-global-reduce` 验收四 CGRA 全局加／乘法。

`current-vector-arithmetic` / `current-vector-arithmetic-synth` 检查组合常量进位、独立加／乘法数学、完整 Python 轨迹，以及原生八 lane 乘法拒绝。

`current-loop-controller` / `current-loop-controller-synth` 现同时检查默认森林计数契约和原 Python 兼容分支；地址匹配、并发完成及 parent 语义见 [LOOP_CONTROLLER_API.md](../LOOP_CONTROLLER_API.md)。
