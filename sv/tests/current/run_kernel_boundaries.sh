#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-all}; if [[ $# != 0 ]]; then shift; fi
case "$mode" in all|run) ;; *) echo 'usage: run_kernel_boundaries.sh [all|run] [axpy gemm gemv]'; exit 2;; esac
if [[ $# == 0 ]]; then set -- axpy gemm gemv; fi
root=build/current/kernel-boundaries
python3 tests/current/gen_kernel_boundaries.py --output "$root/fixtures"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log"; exit 1; }
}
for kernel in "$@"; do
  case "$kernel" in axpy|gemm|gemv) ;; *) exit 2;; esac
  for mem in ${KERNEL_MEMORY_MODES:-1 0}; do
    case "$mem" in 0|1) ;; *) exit 2;; esac
    build="$root/$kernel"; if [[ $mem == 0 ]]; then build="$build-memory0"; fi
    mkdir -p "$build"
    mapfile -t args < <(grep -v '^-GMEM_COMBINATIONAL=' "$root/fixtures/$kernel/verilator.args")
    if [[ $mode == all ]]; then
      { grep -v '^+' filelists/native.f | grep -v '^$'; printf '%s\n' tests/current/tb_native_kernel.sv; } | xargs sha256sum > "$build/compiled_sources.sha256"
      sha256sum rtl/common/*.svh >> "$build/compiled_sources.sha256"
      env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
        -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 --top-module tb_native_kernel \
        --Mdir "$build/obj" -Wno-fatal -Irtl/common -f filelists/native.f "${args[@]}" -GMEM_COMBINATIONAL="$mem" \
        tests/current/tb_native_kernel.sv >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log"; exit 1; }
    else
      sha256sum --check --status "$build/compiled_sources.sha256"
    fi
    exe="$build/obj/Vtb_native_kernel${EXEEXT}"
    for scenario in "$root/fixtures/$kernel"/n*; do
      label=$(basename "$scenario")
      common=("+PROGRAM=$scenario" "+STORE_COUNTS=$scenario/stores.txt")
      for pacing in normal backpressure; do
        extra=(); if [[ $pacing == backpressure ]]; then extra=(+BACKPRESSURE +HOST_GAPS); fi
        "$exe" "${common[@]}" "${extra[@]}" >"$build/$label-$pacing.log" 2>&1 || { cat "$build/$label-$pacing.log"; exit 1; }
        grep -q NATIVE_STORE_COUNTS_PASS "$build/$label-$pacing.log"
        grep NATIVE_KERNEL_MATH_PASS "$build/$label-$pacing.log"
      done
    done
    original="$root/fixtures/$kernel/n4_original"
    if [[ $kernel == axpy ]]; then original="$root/fixtures/$kernel/n16_original_a3"; fi
    common=("+PROGRAM=$original" "+STORE_COUNTS=$original/stores.txt")
    negative KERNEL_MATH "$build/negative-result.log" "$exe" "${common[@]}" +EXPECT_FAILURE
    negative NATIVE_KERNEL_TIMEOUT "$build/negative-timeout.log" "$exe" "${common[@]}" +STALL_FOREVER +MAX_CYCLES=3000
    # Requiring an additional store must reject an early completion, not merely
    # succeed after reading correct final values that happened to settle later.
    awk 'NR==1 {$2=$2+1} {print}' "$original/stores.txt" >"$build/excess-stores.txt"
    negative KERNEL_EARLY_RETURN "$build/negative-completion.log" "$exe" "+PROGRAM=$original" "+STORE_COUNTS=$build/excess-stores.txt"
    if [[ $kernel == axpy || $kernel == gemv ]]; then
      old="reference/current/kernel_boundaries/${kernel}_early_return"
      if [[ $kernel == axpy && $mem == 1 ]]; then
        "$exe" "+PROGRAM=$old" "+STORE_COUNTS=$old/stores.txt" >"$build/original-concurrent-return.log" 2>&1
        grep -q NATIVE_STORE_COUNTS_PASS "$build/original-concurrent-return.log"
        grep NATIVE_KERNEL_MATH_PASS "$build/original-concurrent-return.log"
      else
        negative KERNEL_EARLY_RETURN "$build/negative-original-return.log" "$exe" "+PROGRAM=$old" "+STORE_COUNTS=$old/stores.txt"
      fi
    fi
    echo "KERNEL_BOUNDARIES_PASS kernel=$kernel memory_combinational=$mem"
  done
done
