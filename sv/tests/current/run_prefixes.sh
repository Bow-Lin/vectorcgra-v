#!/usr/bin/env bash
# Incomplete reference traces are checked separately and never reported as
# completed kernels. Their status/termination remains in each manifest.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
for kernel in "${@:-gemm}"; do
  case "$kernel" in gemm|gemv) ;; *) exit 2;; esac
  ref="reference/current/kernels/$kernel"
  build="build/current/prefixes/$kernel"
  mkdir -p "$build"
  mapfile -t args < "$ref/prefix-verilator.args"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_current_kernel_prefix \
    --Mdir "$build" -Wno-fatal -Irtl/common -f filelists/native.f "${args[@]}" \
    "$ref/tb_current_kernel_prefix.sv" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
  "$build/Vtb_current_kernel_prefix${EXEEXT}" >"$build/run.log" 2>&1 || { tail -n 10 "$build/run.log"; exit 1; }
  cat "$build/run.log"
done
