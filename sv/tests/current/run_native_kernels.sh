#!/usr/bin/env bash
# Native functional repairs have independent mathematics, not Python equivalence.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
if [[ $# == 0 ]]; then set -- gemm gemv spmv spmv_coo; fi
for kernel in "$@"; do
  case "$kernel" in gemm|gemv|spmv|spmv_coo) ;; *) echo "Unknown native kernel: $kernel" >&2; exit 2;; esac
  ref="reference/native/kernels/$kernel"
  build="build/native/$kernel"
  mkdir -p "$build"
  mapfile -t args < "$ref/verilator.args"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_kernel \
    --Mdir "$build" -Wno-fatal -Irtl/common -f filelists/native.f "${args[@]}" \
    tests/current/tb_native_kernel.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
  extra=()
  if [[ "$kernel" == spmv ]]; then extra=(+IDENTITY_NNZ=8); fi
  "$build/Vtb_native_kernel${EXEEXT}" "+PROGRAM=$ref" "${extra[@]}" >"$build/run.log" 2>&1 || { tail -n 12 "$build/run.log"; exit 1; }
  grep -q NATIVE_KERNEL_MATH_PASS "$build/run.log"
  cat "$build/run.log"
  set +e
  "$build/Vtb_native_kernel${EXEEXT}" "+PROGRAM=$ref" "${extra[@]}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  negative=$?
  "$build/Vtb_native_kernel${EXEEXT}" "+PROGRAM=$ref" +STALL_FOREVER +MAX_CYCLES=3000 >"$build/timeout-negative.log" 2>&1
  timeout=$?
  set -e
  [[ $negative != 0 && $timeout != 0 ]]
  grep -q KERNEL_MATH "$build/negative.log"
  grep -q NATIVE_KERNEL_TIMEOUT "$build/timeout-negative.log"
  echo "NATIVE_KERNEL_NEGATIVE_PASS kernel=$kernel"
  if [[ "$kernel" == spmv ]]; then
    for nnz in {0..8}; do
      scenario="$ref/scenarios/nnz$nnz"
      if [[ "$nnz" == 8 ]]; then scenario="$ref"; fi
      for mode in normal backpressure; do
        stalls=(); if [[ "$mode" == backpressure ]]; then stalls=(+BACKPRESSURE +HOST_GAPS); fi
        log="$build/nnz${nnz}-${mode}.log"
        "$build/Vtb_native_kernel${EXEEXT}" "+PROGRAM=$scenario" "+IDENTITY_NNZ=$nnz" "${stalls[@]}" >"$log" 2>&1 || { tail -n 12 "$log"; exit 1; }
        grep -q NATIVE_KERNEL_MATH_PASS "$log"
        grep -q "NATIVE_IDENTITY_STORES_PASS nnz=$nnz stores=$nnz" "$log"
        grep '_PASS' "$log"
      done
    done
    for case in wrong_prologue legacy_start binary_phi missing_loop_exit dropped_store_ack; do
      scenario="$ref/negative/$case"
      nnz=$(cat "$scenario/nnz.txt")
      set +e
      "$build/Vtb_native_kernel${EXEEXT}" "+PROGRAM=$scenario" "+IDENTITY_NNZ=$nnz" +MAX_CYCLES=3000 >"$build/$case.log" 2>&1
      status=$?
      set -e
      [[ "$status" != 0 ]]
      grep -Eq 'KERNEL_(MATH|STRAY_STORE|EARLY_RETURN)|NATIVE_KERNEL_TIMEOUT' "$build/$case.log"
      echo "NATIVE_SPMV_ABLATION_PASS case=$case"
    done
    echo NATIVE_SPMV_MATRIX_PASS
  fi
done
