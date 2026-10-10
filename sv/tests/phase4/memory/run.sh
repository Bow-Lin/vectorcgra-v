#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
build=build/phase4/memory/r1w3
mkdir -p "$build"
{ grep -v '^+' filelists/phase4.f | grep -v '^$'; printf '%s\n' tests/phase4/memory/tb_memory_asymmetric.sv reference/phase4/memory/r1w3/reference.v; } | xargs sha256sum > "$build/compiled_sources.sha256"
sha256sum rtl/common/*.svh >> "$build/compiled_sources.sha256"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_memory_asymmetric \
  --prefix Vmemory --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
  -f filelists/phase4.f reference/phase4/memory/r1w3/reference.v tests/phase4/memory/tb_memory_asymmetric.sv > "$build/verilate.log" 2>&1
make -C "$build" -f Vmemory.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$build/compile.log" 2>&1
"./$build/simulation${EXEEXT}" "+RESULT=$build/result.json" > "$build/run.log" 2>&1
grep -q PHASE4_MEMORY_PASS "$build/run.log"
cat "$build/run.log"
set +e
"./$build/simulation${EXEEXT}" +EXPECT_FAILURE > "$build/negative.log" 2>&1
negative=$?
set -e
[[ "$negative" != 0 ]]
grep -q 'MEM_MATH_MISMATCH intentional negative control' "$build/negative.log"
printf 'PHASE4_MEMORY_NEGATIVE_PASS exit=%s\n' "$negative"
