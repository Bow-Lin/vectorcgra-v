#!/usr/bin/env bash
# Compile/run checked-in native SV against frozen Python raw-cycle traces.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/../../.."
label="${1:-dynamic_fir}"
mode="${2:-all}"
build="build/phase4/migration/$label"
bench="tests/phase4/migration/$label/tb_multi_migration.sv"
[[ -f "$bench" ]] || { echo "Unknown migration profile $label" >&2; exit 2; }
mkdir -p "$build"
if [[ "$mode" != run ]]; then
  { grep -v '^+' filelists/phase4.f | grep -v '^$'; printf '%s\n' "$bench"; } | xargs sha256sum > "$build/compiled_sources.sha256"
  sha256sum rtl/common/*.svh >> "$build/compiled_sources.sha256"
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang --top-module tb_multi_migration \
    --prefix Vmigration --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
    -f filelists/phase4.f "$bench" > "$build/verilate.log" 2>&1
  make -C "$build" -f Vmigration.mk -j 2 CXX=clang++ 'LINK=env -u LINK clang++' LDLIBS=-pthread > "$build/compile.log" 2>&1
fi
if [[ "$mode" == compile ]]; then exit 0; fi
cycles="$(cat "tests/phase4/migration/$label/replay_counts.txt")"
"./$build/simulation.exe" "+TRACE=reference/phase4/migration/$label/cycles.txt" "+CYCLES=$cycles" "+RESULT=$build/result.json" > "$build/run.log" 2>&1
grep -q PHASE4_MIGRATION_PASS "$build/run.log"
cat "$build/run.log"
set +e
"./$build/simulation.exe" "+TRACE=reference/phase4/migration/$label/cycles.txt" "+CYCLES=$cycles" +EXPECT_FAILURE > "$build/negative.log" 2>&1
negative=$?
set -e
[[ "$negative" != 0 ]]
grep -q 'MATH_RESULT mismatch intentional negative control' "$build/negative.log"
printf 'PHASE4_MIGRATION_NEGATIVE_PASS label=%s exit=%s\n' "$label" "$negative"
