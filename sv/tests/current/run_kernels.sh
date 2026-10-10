#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
for kernel in "${@:-axpy}"; do
  case "$kernel" in axpy|fir4x4|gemm|gemv|histogram|relu4x4|sad|spmv) ;; *) echo "Unknown kernel: $kernel" >&2; exit 2;; esac
  ref="reference/current/kernels/$kernel"
  build="build/current/kernels/$kernel"
  if [[ ! -f "$ref/verilator.args" ]]; then
    echo "No completed Python reference for $kernel; see $ref/manifest.json" >&2
    exit 2
  fi
  mkdir -p "$build"
  mapfile -t args < "$ref/verilator.args"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" \
    --top-module tb_current_kernel --Mdir "$build" -Wno-fatal -Irtl/common \
    -f filelists/native.f "${args[@]}" "$ref/tb_current_kernel.sv" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
  "$build/Vtb_current_kernel${EXEEXT}" >"$build/run.log" 2>&1 || { tail -n 10 "$build/run.log"; exit 1; }
  cat "$build/run.log"
done
