# Phase 4 inter-CGRA NoC migration work log

Agent: `/root/noc_contract`. Worktree: `codex/sv-migration`, initial HEAD `1a5585a`. Python oracle baseline: `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`; no baseline Python changes authorized.

## 2026-09-22 — interface/source audit and implementation

Read PyOCN MeshNetwork/Router/DORYRoute, RingNetwork/Router/Route, input/output units, credit adapters, original queues, packet factories and the phase-2 native NoC modules.

Implemented parameterized `cgra_inter_mesh_route`, `cgra_inter_mesh_router`, `cgra_inter_mesh`, and `cgra_inter_ring` under `rtl/noc/inter_cgra`. Mesh reuses the validated normal queue, channel and advancing arbiter; Ring reuses the validated native credit network with the actual two-bit packet VC field. No fixed translated RTL is used as native implementation. Added the standalone `phase4_noc.f` list.

Confirmed baseline boundaries: MeshNetwork constructs `mk_bits(clog2(ncols/nrows))` without a minimum width, so one-row or one-column meshes cannot elaborate. A direct custom-PyMTL `mk_bits(clog2(1))` probe failed with `AssertionError: We don't allow Bits0`. Full failing network export records will be retained. Ring's `chl_lat` argument is unused; VC/credit constructor propagation supports the established two-VC/two-credit profile. Packets have two VC bits but VC2/3 cannot inject into this two-VC network. These are retained boundaries, not silently corrected behavior.

## Frozen references and simulation

Commands run by `/root/noc_contract` (repository root):

```
D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/phase4_noc_export.py --profile all
D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/phase4_noc_profiles.py
bash sv/tests/phase4/noc/run.sh <each of the nine legal profiles>
bash sv/tests/phase4/noc/run_negative.sh
D:/work/VectorCGRA/sys_lib/.venv/Scripts/python.exe sv/migration_tools/phase4_noc_results.py
```

Nine original HDL exports succeeded, with exact exporter snapshots and original
source hashes. Two original one-dimensional Mesh exports failed with the
expected Bits0 assertion; their manifests preserve the full traceback.

The first TB compilation exposed a Verilator 5.050 internal `V3Width` error on
an array-indexed postincrement used as an assignment value. Splitting the
test-only expression into assignment followed by increment fixed compilation;
no RTL changed. All nine final simulations passed: **18,729 raw-compared
cycles and 4,736 independently scored packet deliveries**. Ring 4 with latency
arguments zero and one produced identical counts, consistent with the original
unused parameter. Mesh 3x2 and Ring 6 exercised non-square and non-power-of-two
cases with 64-bit data. Both two-VC paths, dateline rewrite and VC2/3 rejection
were exercised.

The deliberately corrupted expected-packet run exited 1 and contained
`NOC_PACKET_MISMATCH` plus `intentional negative control`. The permanently
blocked output run exited 1 with `NOC_TIMEOUT`. The runner requires the exit
and marker together; it does not accept an arbitrary failed launch.

The synthesis command is `pwsh -File sv/tests/phase4/noc/check_synthesis.ps1`.
All four Mesh profiles have completed `synth -noabc; check -assert` successfully
with top ports retained and no blackboxes; five Ring profiles are still running
at this log entry. Final compact synthesis results will be added after closure.

## Bounded synthesis closure method

The Ring2 complete generic synthesis also passed `check -assert`, but its
mapped JSON was 466 MB. PowerShell's whole-object JSON conversion expanded it
to roughly 6.8 GB. The root agent requested bounded closure: retain complete
generic synthesis for all four Mesh profiles and Ring2, and run the remaining
Ring profiles through `hierarchy/proc/flatten/opt/check -assert` only.

The parser process was identified by querying its exact command line through
`NtQueryInformationProcess`: PID 22172 was this task's
`sv/tests/phase4/noc/check_synthesis.ps1`. Only that confirmed process was
stopped. Existing complete synthesis logs/netlists were retained. The new
`phase4_noc_check.py` streams JSON line by line, retaining only the small top
port dictionary, and counts cells/blackbox attributes without expanding the
whole graph. Re-conversion matched the earlier Verilog SHA exactly, allowing
the completed full-synthesis results to be reused honestly.

This is a change in validation scope, not a hardware optimization or a hidden
failed synthesis. Compact results explicitly distinguish complete generic
synthesis from the structural frontend checks; no area/frequency claim is
made. The original large logs and JSON files remain under ignored build paths.

## Final results

All nine synthesis profiles completed successfully: four Mesh profiles plus
Ring2 passed complete generic `synth -noabc`; Ring3, both Ring4 latency settings,
and Ring6 passed the documented structural frontend. Every final check reports
zero problems, retained top ports and zero blackboxes. The compact
`synthesis_results.json` records per-profile scope and hashes. Together with
the 18,729-cycle/4,736-packet simulation matrix and two negative controls, this
closes this task's NoC validation scope. No original Python or fixed golden
HDL changed.
