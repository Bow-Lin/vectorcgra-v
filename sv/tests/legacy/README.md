# Historical DUT implementations

`rtl/` contains six historical entry/type/implementation files moved out of the
maintained core. They remain available to historical tests and migration tools;
ordinary `filelists/native.f` must not compile them.

The old scalar chain is `cgra_2x2 -> cgra_scalar -> tile_core -> tile_flexible_fu`.
`cgra_programmable` is the older programmable-array top; `cgra_types_pkg` describes
the fixed 2x2 packet layout. Current public entry points are `cgra_pe`,
`cgra_system`, `cgra_multi` and `cgra_multi_template` under `sv/rtl/`.

`relocations.json` records byte-preserving old/new paths and hashes. Golden HDL
is stored separately under `sv/reference/legacy/` and `sv/reference/vendor/`.
See [RTL_LAYOUT.md](../../RTL_LAYOUT.md) for paths and baseline runner behavior.
Run historical contracts through `sv/scripts/run_baseline.sh`; current shared
components may intentionally have different semantics from their old baseline.
