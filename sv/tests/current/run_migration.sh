#!/usr/bin/env bash
# Compile/run checked-in native SV against frozen Python raw-cycle traces.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/toolchain.sh"
cd "$(dirname "$0")/../.."
label="${1:-dynamic_fir}"
mode="${2:-all}"
case "$mode" in all|compile|run) ;; *) echo "Usage: run_migration.sh label [all|compile|run]";exit 2;; esac
build="build/current/migration/$label"
bench="tests/current/migration/$label/tb_multi_migration.sv"
[[ -f "$bench" ]] || { echo "Unknown migration profile $label" >&2; exit 2; }
mkdir -p "$build"
stamp_args=(--path "$build/build-stamp.json" --source "$bench" --source tests/current/run_migration.sh
  --argument="COMPILER=$COMPILER" --argument="PROFILE=$label")
if [[ "$mode" != run ]]; then
  { grep -v '^+' filelists/native.f | grep -v '^$'; printf '%s\n' "$bench"; } | xargs sha256sum > "$build/compiled_sources.sha256"
  sha256sum rtl/common/*.svh >> "$build/compiled_sources.sha256"
  "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_multi_migration \
    --prefix Vmigration --Mdir "$build" -o simulation -CFLAGS -std=c++20 -CFLAGS -O0 --output-split 10000 --output-split-cfuncs 2000 -Wno-fatal -Wno-TIMESCALEMOD \
    -f filelists/native.f "$bench" > "$build/verilate.log" 2>&1
  make -C "$build" -f Vmigration.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$build/compile.log" 2>&1
  python3 scripts/build_stamp.py write "${stamp_args[@]}"
fi
python3 scripts/build_stamp.py check "${stamp_args[@]}"
if [[ "$mode" == compile ]]; then exit 0; fi
sha256sum --check --status "$build/compiled_sources.sha256"
cycles="$(cat "tests/current/migration/$label/replay_counts.txt")"
"./$build/simulation${EXEEXT}" "+TRACE=reference/current/migration/$label/cycles.txt" "+CYCLES=$cycles" "+RESULT=$build/result.json" > "$build/run.log" 2>&1
grep -q CURRENT_MIGRATION_PASS "$build/run.log"
cat "$build/run.log"
set +e
"./$build/simulation${EXEEXT}" "+TRACE=reference/current/migration/$label/cycles.txt" "+CYCLES=$cycles" +EXPECT_FAILURE > "$build/negative.log" 2>&1
negative=$?
set -e
[[ "$negative" != 0 ]]
grep -q 'MATH_RESULT mismatch intentional negative control' "$build/negative.log"
printf 'CURRENT_MIGRATION_NEGATIVE_PASS label=%s exit=%s\n' "$label" "$negative"
