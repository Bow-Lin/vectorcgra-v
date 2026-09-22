# Full-system boundary, reduction and task migration tests

From the repository root, run:

```
bash sv/tests/phase4/migration/run.sh dynamic_fir
bash sv/tests/phase4/migration/run.sh global_add
```

These targets compile only native SV and replay checked-in traces from the
unmodified ac96 Python system. Python is not needed for a normal simulation
run. Every raw output bit in the trace is checked on every cycle, including
invalid messages; nothing is masked by valid. Both targets also run an
intentional wrong-answer negative control and require its nonzero exit.

`dynamic_fir` uses the original 126-packet pause/preserve/terminate/reconfigure/
resume kernel, without changing its workload. Four CGRAs each contain 2x2
KingMesh Context Tiles. The caller's 14-FU list implicitly receives a final Nah
unit from the original `FlexibleFuRTL`; the SV profile explicitly contains the
same 15 units in the same order. The 165-cycle trace checks 3,844 bits per
cycle: host interface, every physical boundary, inter-CGRA NoC endpoints and
all 16 tiles' saved progress/status/PHI-address state. Independent checks require
the arithmetic result 2215, a completed task, five active physical transfers,
and saved nonzero state restored and subsequently cleared in both migrating
PHI tiles. Only the north link from CGRA0 to CGRA2 carries useful data in this
kernel; all other boundary signals are still compared.

`global_add` uses CGRAs 0 and 3. Their local lane sums are 10 and 26; the global
sum is 36. Adding local bases 17 and -5 must return 53 and 31. The 91-cycle
trace checks 1,779 raw host/NoC bits per cycle. It requires 35 host input
packets, all six programmed tiles' completions, exactly two reduction requests
and two responses in the Python reference, and the independent returned values.
The host is initially stalled and then periodically backpressured.

The oracle for these two system tests is **original Python**, not a claim of
simultaneous original-translated-HDL equivalence. Verilator runs in two-state
mode, so the traces do not establish four-state X behavior. The reference
manifests retain original sources, exact exporter snapshots and trace hashes.
`results.json` records the exact compiled native sources and compact results.
