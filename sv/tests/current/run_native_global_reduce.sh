#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build=build/current/vector-reduce/system
mkdir -p "$build"
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -f filelists/native.f \
  --top-module tb_native_global_reduce --Mdir "$build/obj" -GMULTI_COLS=2 -GMULTI_ROWS=2 \
  tests/current/tb_native_global_reduce.sv >"$build/compile.log" 2>&1 \
  || { tail -n 50 "$build/compile.log";exit 1; }
exe="$build/obj/Vtb_native_global_reduce${EXEEXT}"
for multiply in 0 1;do
  args=();if [[ $multiply == 1 ]];then args=(+MULTIPLY);fi
  "$exe" "${args[@]}" >"$build/run-$multiply.log" 2>&1 || { cat "$build/run-$multiply.log";exit 1; }
  grep NATIVE_GLOBAL_REDUCE_PASS "$build/run-$multiply.log"
  set +e
  "$exe" "${args[@]}" +EXPECT_FAILURE >"$build/negative-$multiply.log" 2>&1
  result=$?
  set -e
  [[ $result != 0 ]] && grep -q GLOBAL_REDUCE_FINAL_MATH "$build/negative-$multiply.log"
done
