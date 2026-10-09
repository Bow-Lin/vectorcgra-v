# Stage 4 test entry points

Run commands from the migration worktree root with:

```powershell
& ./sv/scripts/run.ps1 -Task phase4 -Jobs 1 `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

The task can be narrowed to `phase4-noc`, `phase4-system`,
`phase4-template`, `phase4-migration`, `phase4-peripheral` or `phase4-memory`.
All normal runners compile native SV and consume frozen HDL/text evidence;
none imports project Python or PyMTL. Migration-only exporters are separate.

| Directory | What actually runs |
|---|---|
| `noc` | Nine Mesh/Ring profiles; independent packet scoreboard; wrong-packet and permanent-stall negatives on `mesh_2x2_l1_w32` |
| `system` | Four CGRAs with 2x2 Tiles on Mesh/Ring, registered-memory Mesh, and four 4x4 CGRAs; each has two programs, wrong-oracle and timeout negatives |
| `template` | 21 physical Tiles in 2x2/3x3/2x2/2x2 CGRAs, eight ports, distinct FU lists and disabled directed links |
| `migration` | Global ADD and dynamic FIR task migration; raw unmodified Python replay plus independent results/state/transaction checks |
| `peripheral` | DMA and im2col components and complete integrated CGRAs; baseline translated DMA semantics are the default |
| `memory` | Read1/write3 asymmetric memory; the source read3/write1 translation failure is separately preserved |

The 64Tile system uses frozen original HDL and an independent arithmetic and
transaction oracle. Its optional original Python simulation did not complete;
it is not a three-way Python comparison. The other three homogeneous systems
and heterogeneous system also compare original Python raw-cycle traces.

`system/replay.sh <profile>` reruns an existing compiled model and its negative
controls after checking its source hashes. It hashes runtime text/hex assets
before and after execution. `heterogeneous` selects the template model. A
replay does not rebuild a stale model; compile with the matching `run.sh` first.

Synthesis is separate from simulation: `system/check_synthesis.ps1` performs
DUT-only generic synthesis for five system profiles. Component JSON reports
state explicitly whether they used full `synth -noabc` or only frontend
structure checks. No stage4 report claims a standard-cell area or Fmax result.
See `../../PHASE4_REPORT.md` for parameter bounds and original limitations.
