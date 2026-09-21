# Floating-point FU migration

`tile_fp_add` and `tile_fp_mul` directly implement the ac96 FU interface in
SystemVerilog. `tile_fp_fu` holds the shared combinational wrapper;
`cgra_hardfloat_fn` connects the original, vendored HardFloat modules. There
is no added register or arithmetic latency. Vendor source bytes, license,
submodule revision and hashes are in `rtl/vendor/hardfloat/`.

The baseline's format mapping is retained: `FP_EXP_W=8, FP_SIG_W=23` feeds
HardFloat `expWidth=9, sigWidth=23`, which means a 32-bit payload with **9
exponent and 22 fraction bits**, not IEEE binary32. The other tested profile,
`FP_EXP_W=4, FP_SIG_W=11`, feeds exponent 5/significand 11 in 16 bits.
`FINC` uses the baseline constant encoding, which represents **0.5** in both
tested formats. Changing these conventions would change existing behavior
and must be a separate functional fix.

The wrappers also retain `FINC`'s ready-gated valid and `FMUL_CONST`'s omission
of constant-valid gating. These are observed baseline behaviors, not new
interface recommendations. Rounding mode is 000 and HardFloat control is 1,
as in ac96. Exception flags are internal and not newly exposed.

From the migration repository root:

```powershell
& C:/msys64/usr/bin/bash.exe sv/tests/phase3/float/run.sh
& ./sv/tests/phase3/float/check_synthesis.ps1
```

Each of four add/mul/format combinations runs 1,170 complete raw-output
comparisons against separately namespaced ac96 HDL, including invalid cycles.
There are 168 independent expected-value checks per profile: 160 exact finite
arithmetic cases and eight special-value cases covering infinities, NaNs,
signed zero, subnormal and minimum-normal values. Directed handshake cases
and 1,000 seeded random samples exercise selection, metadata, valid/ready,
reset and clear. A deliberately wrong arithmetic expectation must fail in
the ordinary checker. The tests use Verilator's two-state behavior and do
not constitute exhaustive numerical or four-state equivalence.

The synthesis entry converts maintained sources with sv2v, runs Yosys
`synth -noabc`, and requires `check -assert` with zero final problems for all
four profiles. It does not measure standard-cell area or frequency.

`reference/phase3/float/` preserves original exported RTL. Joint-test copies
only namespace module/type/macro identifiers and convert diagnostic `line`
filename separators; each transformation is reversible and hashed. The
migration exporter uses a host-only placeholder-pass subclass because the
installed PyMTL pass loops at Windows drive roots during two directory
searches. No installed tool or original RTL was changed. Python export
scripts are migration records and are not part of these daily commands.
