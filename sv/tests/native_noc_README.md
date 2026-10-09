# Native common/NoC component checks

These tests cover the hand-written modules in `rtl/common/cgra_{queue,register_file,channel,round_robin}.sv` and `rtl/noc/`. They do not replace full-CGRA workload/replay tests.

## Reference provenance

The reference is the unchanged PyMTL-generated Verilog for baseline commit `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`, with PyOCN submodule commit `d8ffacc64fb8dd24ce26e944d501016880302bbe`. The tests instantiate its original modules directly; they do not regenerate or modify the reference at run time.

| Frozen file | SHA-256 |
| --- | --- |
| `reference/VectorCGRA2x2Reference.v` | `f7d4479abe7b2305f21875a4ba82d685cb20d61275abbf4114786c57185487aa` |
| `reference/phase2/3x2/Phase2Reference3x2.v` | `e15db72b718b672ee423b9635aac3f918fcc84cf03adbf6ac236760011d990c2` |
| `reference/phase2/4x4/Phase2Reference4x4.v` | `5d8222b2ac95f3217968d0787a48d2973cc413cf3652b4dc1918cf7dfae4e93b` |

The phase-2 reference directories also contain the complete export manifest and exporter snapshot. Native source was ported from `lib/basic/val_rdy/queues.py`, the custom PyMTL `stdlib/primitive/{register_files,arbiters,encoders}.py`, and PyOCN's `pymtl3_net/{channel,router,xbar,ringnet,ocnlib/ifcs}` implementations.

| Check in `tb_native_noc.sv` | Frozen original module |
| --- | --- |
| Normal queue, 191 bits, depth 2 | `NormalQueueRTL__27b5f6f42d39604e` |
| Bypass queue, 191 bits, depth 2 | `BypassQueueRTL__27b5f6f42d39604e` |
| Bypass queue, 194 bits, depth 1 | `BypassQueueRTL__d2ce06ef3a7ce29e` |
| Round-robin arbiter, 7 requests | `RoundRobinArbiterEn__nreqs_7` |
| Register file, 35 bits, depth 8 | `RegisterFile__14fb828f022f9b03` |
| Normal-input xbar, 195 bits, 7 to 1 | `XbarRTL__b5022c8fd1dc7623` |
| Bypass-input xbar, 52 bits, 3 to 4 | `XbarBypassQueueRTL__8ef00c39f57f0208` |
| Credit ring, 191 bits, 5 nodes | `RingNetworkRTL__06419ffd7f2ed639` |

`tb_native_ring_profiles.sv` separately checks `RingNetworkRTL__0ef6fd6e3a72f330` (7 nodes, 191 bits) and `RingNetworkRTL__20cebbcf8628020c` (17 nodes, 195 bits) from the corresponding phase-2 reference files. Separate builds avoid collisions among generated type/module names.

## Running

From the worktree root, in PowerShell with the repository's MSYS2 tools installed:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/run_native_noc.sh
& C:/msys64/usr/bin/bash.exe sv/tests/run_native_ring_profiles.sh
& ./sv/tests/check_native_noc_synthesis.ps1
```

The synthesis script accepts `-ToolRoot` for the directory containing `sv2v-v0.0.13` and `oss-cad-suite`. Its default resolves the tools installed in the main checkout's `sys_lib/tools`. Generated files and logs stay under ignored `sv/build/native_noc`, `native_ring_7`, `native_ring_17`, and `native_noc_synthesis`.

The simulation runners return a nonzero status for compile failures, `$fatal` mismatches, conservation failures, or missing PASS markers. They use Verilator 5.050 and Clang/MSYS2; changing to a four-state simulator requires separate qualification.

## What is checked

- The component test compares all sampled message, valid, ready, and exposed count outputs for 500 cycles with seed `0x31415926`. Messages are compared even when valid is zero. It applies repeated reset, simultaneous enqueue/dequeue, random arbitration enable, random stalls and contention. Its stimulus deliberately varies unused/invalid fields and does not claim every source sequence obeys a held-valid protocol.
- Each larger ring test compares every node's raw output message/valid and input ready for 800 cycles with seed `0x27182818`. Producers retain valid packets until accepted. Both reset sequences, a 40-cycle all-destination stall, random backpressure, and a final 200-cycle drain are exercised. Independent assertions require correct destination, traffic at every node, observed input blocking, and equal accepted/delivered counts after the second reset. This is a count check plus cycle-by-cycle reference comparison, not an independent packet-identity scoreboard.
- The synthesis script runs sv2v, Yosys elaboration, `proc`, `opt`, `memory_collect`, and `check -assert` for 12 explicit configurations: queue depths 1/3/16; channel latencies 0/1/3; a two-read/two-write RF; both xbar styles; and 5/7/17-node rings. It does not estimate area or timing. It uses `read_verilog -defer`, then `chparam` and `hierarchy`; this avoids the installed Yosys's internal duplicate-module assertion encountered with `hierarchy -chparam` when reprocessing a parameterized parent after deriving its child.

These are finite, two-state differential tests, not a formal proof or a four-state unknown-propagation guarantee. Storage remains unreset where the baseline leaves it unreset; no RTL `setundef` or blanket zero filling is used. Normal queue clear is implemented, but these component simulations tie it low for the standard profile. The added clear port on bypass queues/channels is also tied low; no claim is made that the baseline exposes those clear interfaces.

## Preserved behavior and parameter boundary

- Full queues reject a simultaneous replacement; queue/RF storage is not reset, and enabled storage writes can occur during reset/clear.
- Empty bypass queues expose their incoming message even when invalid. Idle switches select input zero rather than forcing their message to zero.
- Switch arbitration advances without requiring downstream ready; the credit ejection arbiter advances on a valid grant even during a stall.
- Xbar routing retains destination truncation and out-of-range behavior. The static per-element valid writers avoid overlapping drivers when sv2v flattens unpacked arrays.
- Ring route ties go right; dateline crossing changes only the selected valid output's VC field. Port and VC ordering is unchanged.
- The public ring parameters explicitly require `VCS == 2` and `CREDITS == 2`. The baseline does not consistently propagate other VC/credit values through its constructors. Width, node count and packet field offsets are parameterized; the tested ring node counts are 5, 7 and 17.

## Recorded results

The larger-ring runs completed with `786/786` accepted/delivered and `806` blocked cycles summed over sources for 7 nodes; `800/800` and `4620` for 17 nodes. All nodes sent and received packets. Their full logs include the reproducible seed, width and cycle count.

The first native component run passed 500 cycles with `361/361` ring transfers. Integration synthesis then exposed an sv2v flattening issue in xbar's separate dynamic array writers. They were replaced with static per-element writers, preserving the original conditional behavior. The post-change component regression passed the same 500 cycles with `361/361` ring transfers.

The synthesis sanity script completed all 12 configurations, with 12 `Found and reported 0 problems` results. This check is restricted to the common/NoC modules and does not establish a warning-free or fully defined complete CGRA.
