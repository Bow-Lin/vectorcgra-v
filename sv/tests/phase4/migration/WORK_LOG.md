# Phase 4 migration, boundary links and global reduction

Agent: `/root/noc_contract`. Baseline Python is unchanged ac96. The root agent
owns the native multi-CGRA integration; this task owns independent programs,
traces and SV-only replays.

## 2026-09-22 — original dynamic FIR and small global sum

The original `MultiCgraRTL_migration_test.py` dynamic FIR has 126 configuration
packets, four CGRAs each with 2x2 KingMesh tiles, 14 FUs per tile, control depth
16 and 8 physical directions. Its scalar answer is independently
`3 + sum((10+i)*(12+i) for i in range(2,10)) = 2215`. The original harness,
source, sink, pause/preserve/terminate/resume sequence and configurations are
used unchanged. A read-only audit identified that the native Context Tile's
former 4-port-only guard excluded this legal baseline case; root relaxed that
guard. Successful simulation remains required before claiming support.

`phase4_migration_trace.py` records all host output bits, all physical boundary
send msg/val/rdy bits, inter-CGRA network traffic in both directions, and saved
progress/status/PHI-address state for every tile. It also records host command,
physical transfer and preserve/resume events. The SV bench maps the semantic
context endpoint name to the native generate-block hierarchy; the packet or
state bits themselves are not adapted.

`phase4_migration_reduce.py` constructs a separate small legal full-system
program. CGRAs 0 and 3 load vectors [1,2,3,4] and [5,6,7,8], reduce each locally,
then globally add them at CGRA0. The sum is 36. Local bases 17 and -5 produce
independent expected results 53 and 31, returned by each participant's RET
tile. Vector input comes from a channel so the baseline's level-sensitive
global request behavior is preserved. Host outputs are backpressured.

Both reference traces are currently being recorded. No pass claim is made by
this initial log entry. The normal SV-only runner additionally executes a
negative control which perturbs only the independent expected result and
requires a nonzero exit with the expected math-check marker. Exact replay
length, completion and input counts are asserted, as are preserved, restored
and cleared context state in the migration case.

## Completed oracle and first native results

The unmodified dynamic FIR completed in 165 recorded cycles (including reset),
with result 2215, 126 accepted host inputs, five physical transfers from CGRA0
north port 1 to CGRA2, and two nonzero context restores followed by clearing.
All 3,844 checked native output bits matched each cycle. The independent
arithmetic and context assertions passed; the wrong-result negative exited 1.

The first native launch correctly failed its Nah-presence guard: this test's
caller declares 14 FUs, while `FlexibleFuRTL.py:34-35` mutates that list at
elaboration by appending Nah. The original trace manifest records the caller
list. `test_profile.json` and the SV bench now explicitly include the effective
15th final Nah unit. This was a test-profile correction; neither original
Python, native RTL, nor recorded trace changed.

The global sum completed in 91 cycles, with 35 accepted host inputs and all
six tile completions. The Python reference asserted exactly two requests
(10,26) and two responses (36). Native SV matched all 1,779 host/NoC bits and
independently returned 53 and 31. Its math negative also exited 1 as required.

Root subsequently added independent memory write-port parameters while keeping
defaults equal. Both native system benches are being rebuilt against those
current sources; the Python traces are reused unchanged. An initial standalone
hash-check shell lacked `/usr/bin` on PATH and failed to locate `sha256sum` and
`grep`; no hash success was inferred from that launch. The corrected command
uses `/usr/bin` explicitly and reports exit 0 for both compiled source lists.
The final collector also checks every hash and rejects results older than the
recorded compilation source list.

## Final current-source replay

Both benches were re-Verilated and rebuilt after the memory parameter change.
They again passed all raw comparisons, counts, arithmetic, restore checks and
their expected-failure runs: dynamic FIR 165 x 3,844 bits; global sum 91 x 1,779
bits. The corrected `sha256sum -c` checks returned zero for both source lists.
The frozen Python traces were reused; no expensive Python oracle regeneration
was needed. `phase4_migration_results.py` collects final results only after the
source fingerprints and fresh-result timestamps match.

The first metadata collection rejected the MSYS `sha256sum` binary-format
records (`hash *path`), because the parser expected text-format `hash  path`.
It now accepts both standard forms and still verifies each complete SHA-256.
The collector then passed for both system runs and the asymmetric memory run;
this evidence-parser correction did not change or rerun the DUT tests.
