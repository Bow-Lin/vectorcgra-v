# Multi-CGRA system programs

All four profiles instantiate four CGRAs. Each CGRA visits every local Tile,
loads from the next CGRA's memory ownership range, computes a chain containing
ADD/MUL operations, stores remotely, completes, and services two host queries.
Two scenarios use positive and negative inputs with reset/reconfiguration.
Responses from different owners may interleave; each owner's two responses
must remain ordered. Host backpressure and wrong-result/timeout negatives are
checked in addition to raw cycle comparison.

From `sv/`, compile one model with MSYS2:

```text
bash tests/phase4/system/run.sh mesh4-tiles2
bash tests/phase4/system/run_negative.sh mesh4-tiles2
bash tests/phase4/system/replay.sh mesh4-tiles2
```

Profiles: `mesh4-tiles2`, `ring4-tiles2`,
`mesh4-tiles2-registered`, `mesh4-tiles4`. `JOBS=1` limits C++ compiler workers;
`MAKEFLAGS="OPT_FAST=-O0 OPT_SLOW=-O0"` reduces simulator compilation time
without changing hardware or simulation cycles. Omit it for Verilator's
default host compiler optimization.

`replay.sh` verifies the recorded compiled-source hashes and records runtime
vector hashes before/after executing both positive and negative tests. It
requires an existing model; use `run.sh` after editing hardware or the TB.
It also accepts `heterogeneous` for the separately compiled template model.

The first three profiles compare native SV, unmodified translated ac96 HDL
and original Python traces. The 64Tile profile compares the original HDL and
independent math/transaction results; see its README for the stopped optional
Python simulation. None of these runtime entry points executes Python.

The per-profile `results.json` files in this tests directory describe the
original Python runs, where present. Final native replay evidence is collected
in `../../../results/phase4-system-simulation.json`, with source and runtime
hashes. Do not substitute the Python-only metadata for a native test result.
