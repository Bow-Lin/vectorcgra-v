#!/usr/bin/env bash
# Native SV and frozen reference only; no PyMTL/runtime RTL generation.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
selected="${1:-all}"
matches=0
for header in tests/phase4/noc/*/profile.svh; do
  label="$(basename "$(dirname "$header")")"
  if [[ "$selected" != all && "$selected" != "$label" ]]; then continue; fi
  matches=$((matches+1))
  build="build/phase4/noc/$label"
  mkdir -p "$build"
  { grep -v '^+' filelists/phase4_noc.f; printf '%s\n' "$header" "reference/phase4/noc/$label/reference.v" tests/phase4/noc/tb_inter_cgra_noc.sv; } |
    xargs sha256sum > "$build/compiled_sources.sha256"
  "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_inter_cgra_noc \
    --prefix Vinter_noc --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
    "+incdir+$(dirname "$header")" -f filelists/phase4_noc.f \
    "reference/phase4/noc/$label/reference.v" tests/phase4/noc/tb_inter_cgra_noc.sv > "$build/verilate.log" 2>&1
  make -C "$build" -f Vinter_noc.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$build/compile.log" 2>&1
  "./$build/simulation${EXEEXT}" "+RESULT=$build/result.json" > "$build/run.log" 2>&1
  grep -q PHASE4_NOC_PASS "$build/run.log"
  cat "$build/run.log"
done
[[ "$matches" != 0 ]] || { echo "Unknown profile: $selected" >&2; exit 2; }
