#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
if [[ $# == 0 ]]; then set -- mesh ring registered mesh64; fi
for profile in "$@"; do
  args=(-GMULTI_COLS=2 -GMULTI_ROWS=2)
  case "$profile" in
    mesh) ;;
    ring) args=(-GMULTI_COLS=4 -GMULTI_ROWS=1 -GTOPOLOGY=1);;
    registered) args+=(-GMEM_COMBINATIONAL=0);;
    mesh64) args+=(-GCOLS=4 -GROWS=4);;
    *) exit 2;;
  esac
  build="build/native/multi/$profile"
  mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_multi \
    --Mdir "$build" -Wno-fatal -Irtl/common -f filelists/native.f "${args[@]}" \
    tests/current/tb_native_multi.sv >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log"; exit 1; }
  "$build/Vtb_native_multi${EXEEXT}" >"$build/run.log" 2>&1 || { tail -n 12 "$build/run.log"; exit 1; }
  grep -q NATIVE_MULTI_PASS "$build/run.log"
  cat "$build/run.log"
  set +e
  "$build/Vtb_native_multi${EXEEXT}" +NEGATIVE >"$build/negative.log" 2>&1
  negative=$?
  "$build/Vtb_native_multi${EXEEXT}" +STALL_FOREVER >"$build/timeout-negative.log" 2>&1
  timeout=$?
  set -e
  [[ $negative != 0 && $timeout != 0 ]]
  grep -q 'Independent result/owner failure' "$build/negative.log"
  grep -q 'TIMEOUT multi-CGRA' "$build/timeout-negative.log"
  echo "NATIVE_MULTI_NEGATIVE_PASS profile=$profile"
done
