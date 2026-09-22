# Inter-CGRA network migration tests

From MSYS2, run `bash sv/tests/phase4/noc/run.sh all` from the repository root.
`run.sh ring_6_l1_w64` selects one profile. This is an SV-only build: native
parameterized RTL and the checked-in original HDL are compiled together.
Run `bash sv/tests/phase4/noc/run_negative.sh` after the Mesh 2x2 latency-1 build.
For synthesis, run `pwsh -File sv/tests/phase4/noc/check_synthesis.ps1`.

Nine profiles cover Mesh 2x2 with channel latencies 0/1/2, Mesh 3x2 with 64-bit
data, Ring 2/3/4/6, 32/64-bit data, and both values of the original Ring latency
argument. The Ring argument is unused by the baseline constructor, so its two
four-node profiles intentionally have identical behavior. The actual packet
layout comes from `mk_inter_cgra_pkt`, including its two-bit VC field.

Each profile compares every output bit (`recv_rdy`, `send_val`, and the entire
`send_msg`, also when invalid) for exactly 2,081 cycles. It first resets with
traffic in flight, then runs two scored scenarios of 64 packets per source.
Scored sources hold packets until accepted. An independent scoreboard checks
full packet identity, destination, no duplicate/lost delivery, per-flow order,
dateline VC rewriting, and invalid-VC rejection. Sinks initially stall, then
use deterministic backpressure, then drain. Ring order is checked separately
per initial VC because the baseline may reorder between VCs. The warm-up
traffic may change while stalled; it is raw-compared but is not scored.

The negative target deliberately corrupts an expected packet and requires a
nonzero simulation exit with the designated marker. A second negative target
holds all sinks stalled and requires the timeout assertion to fail. A printed
PASS alone is not sufficient. Normal success asserts exact cycle and packet
totals and emits a JSON result.

Synthesis elaborates all nine profiles. Four Mesh profiles and the two-node
Ring run the complete generic `synth -noabc` flow. The remaining Ring profiles
run `hierarchy; proc; flatten; opt; check -assert` as a bounded structural
frontend check. All checks reject black boxes and verify the original top port
names, directions, and widths remain present. This is a synthesis compatibility
check; it is not an area/frequency measurement or a sequential equivalence
proof. Verilator is a two-state simulator; unknown-state equivalence is not
claimed.

The frozen one-dimensional Mesh failures are preserved separately: unmodified
`MeshNetworkRTL` constructs `mk_bits(clog2(1))`, which is illegal. The native
Mesh therefore rejects dimensions below two. Original Ring construction does
not propagate nondefault VC/credit parameters to its routers, so the native
wrapper supports its actual two-VC/two-credit implementation only. No original
Python source or generated reference is patched.

Raw logs, elaborated netlists, and large Yosys JSON files live under ignored
`sv/build/phase4/noc/`. A migration-only Python helper streams large Yosys JSON
files to inspect ports without loading the entire mapped graph into memory.
Compact tracked results are `simulation_results.json`
and `synthesis_results.json`. Reference manifests include original source
hashes and an exact exporter snapshot. The Python migration scripts are
one-time evidence tools and are not required for the SV-only test target.
