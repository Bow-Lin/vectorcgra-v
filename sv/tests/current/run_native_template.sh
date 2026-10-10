#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build=build/native/template
mkdir -p "$build"
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_template --Mdir "$build" \
  -Wno-fatal -Irtl/common -Itests/phase4/template -f filelists/native.f \
  -GCOLS=3 -GROWS=3 -GTILE_PORTS=8 -GMULTI_COLS=2 -GMULTI_ROWS=2 \
  tests/current/tb_native_template.sv >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log"; exit 1; }
args=(+VECTORS=tests/phase4/template/heterogeneous)
"$build/Vtb_native_template${EXEEXT}" "${args[@]}" >"$build/run.log" 2>&1 || { tail -n 12 "$build/run.log"; exit 1; }
grep -q NATIVE_TEMPLATE_PASS "$build/run.log"
cat "$build/run.log"
set +e
"$build/Vtb_native_template${EXEEXT}" "${args[@]}" +NEGATIVE >"$build/negative.log" 2>&1
negative=$?
"$build/Vtb_native_template${EXEEXT}" "${args[@]}" +STALL_FOREVER >"$build/timeout-negative.log" 2>&1
timeout=$?
set -e
[[ $negative != 0 && $timeout != 0 ]]
grep -q 'Heterogeneous result/address/owner mismatch' "$build/negative.log"
grep -q NATIVE_TEMPLATE_TIMEOUT "$build/timeout-negative.log"
echo NATIVE_TEMPLATE_NEGATIVE_PASS
