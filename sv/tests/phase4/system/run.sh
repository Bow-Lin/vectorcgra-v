#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
label=${1:-mesh4-tiles2}
case "$label" in
  mesh4-tiles2) top=Phase4Mesh4Tiles2; args=(-GMULTI_COLS=2 -GMULTI_ROWS=2);;
  ring4-tiles2) top=Phase4Ring4Tiles2; args=(-GMULTI_COLS=4 -GMULTI_ROWS=1 -GTOPOLOGY=1);;
  mesh4-tiles4) top=Phase4Mesh4Tiles4; args=(-GMULTI_COLS=2 -GMULTI_ROWS=2 -GCOLS=4 -GROWS=4);;
  mesh4-tiles2-registered) top=Phase4Mesh4Tiles2Registered; args=(-GMULTI_COLS=2 -GMULTI_ROWS=2 -GMEM_COMBINATIONAL=0);;
  *) echo "Unknown frozen system profile: $label" >&2; exit 2;;
esac
out="build/phase4/system/$label"
mkdir -p "$out"
{ grep -v '^+' filelists/phase4.f | grep -v '^$'; printf '%s\n' tests/phase4/system/tb_multi.sv; } | xargs sha256sum > "$out/compiled_sources.sha256"
sha256sum rtl/common/*.svh >> "$out/compiled_sources.sha256"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_multi \
  --Mdir "$out" -o multi_test -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
  "${args[@]}" "+define+PHASE4_REFERENCE=$top" -f filelists/phase4.f \
  "reference/phase4/system/$label/original.v" tests/phase4/system/tb_multi.sv \
  > "$out/verilate.log" 2>&1 || { tail -n 40 "$out/verilate.log"; exit 1; }
make -C "$out" -f Vtb_multi.mk -j "${JOBS:-2}" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
  > "$out/compile.log" 2>&1 || { tail -n 30 "$out/compile.log"; exit 1; }
"$out/multi_test${EXEEXT}" "+VECTORS=$PWD/tests/phase4/system/$label" > "$out/run.log" 2>&1 || { cat "$out/run.log"; exit 1; }
grep -q PHASE4_MULTI_PASS "$out/run.log"
cat "$out/run.log"
