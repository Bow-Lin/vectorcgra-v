# Asymmetric memory port migration evidence

Agent: `/root/noc_contract`, 2026-09-22. No original Python edits.

Root extended the native memory's independent read/write port parameters.
The unmodified `DataMemControllerRTL` was then instantiated with read/write
counts 3/1 and 1/3. Both elaborate. **3/1 cannot translate**: line 508 calls
`trunc` from the one-bit write-crossbar source into a two-bit NoC remote source
port. RTLIR rejects increasing width through truncation. The complete failing
manifest and traceback are retained; native generalization of this shape is
not claimed equivalent to a working original HDL profile.

The 1/3 profile successfully froze the original HDL and exporter snapshot.
`bash sv/tests/phase4/memory/run.sh` compares every output bit, including invalid
message bits and disabled DMA outputs. It independently checks 24 competing
local writes, 25 local reads, an incoming NoC store/load, a remote tile load
and returned data, and three remote stores. Arbitration and both local and
NoC output backpressure are exercised. A final 300-cycle deterministic random
phase compares raw behavior, including reset and independently changing input
signals; it is not represented as transaction-scoreboard coverage.

Result: **464 cycles passed**, with **83 stall samples**. The intentionally
corrupted expected local-read value exits 1 with the required math marker.
`phase4_migration_results.py` checks compiled source hashes before collecting
the final `results.json`. Source/reference hashes, the actual raw output bit
count, log hashes and the unsupported 3/1 boundary are included there.

A separate `phase4_memory_check.py` run passed sv2v plus
`hierarchy/proc/flatten/opt/check -assert`, retaining top ports and introducing
no blackboxes. This is a structural frontend check, not full generic mapping
or a PPA measurement. Its first attempt correctly failed because the standalone
evidence source list omitted `cgra_xbar`; the missing dependency was added and
the original failure log retained as `yosys_missing_xbar.log`. No RTL changed
to make this check pass.
