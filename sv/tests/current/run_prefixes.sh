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
  args+=(-GNOC_LEGACY_PYTHON=1 -GMEMORY_LEGACY_PYTHON=1 -GARITH_LEGACY_PYTHON=1 -GVECTOR_LEGACY_PYTHON=1 -GFP_LEGACY_PYTHON=1 -GREDUCE_LEGACY_PYTHON=1)
  { grep -vE '^\+|^$' filelists/native.f; printf '%s\n' "$ref/tb_current_kernel_prefix.sv"; } | xargs sha256sum > "$build/compiled_sources.sha256"
  sha256sum rtl/common/*.svh >> "$build/compiled_sources.sha256"
  printf '%s\n' "${args[@]}" > "$build/compiled_args.txt"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 --output-split 10000 --output-split-cfuncs 2000 --top-module tb_current_kernel_prefix \
    --Mdir "$build" -Wno-fatal -Irtl/common -f filelists/native.f "${args[@]}" \
    "$ref/tb_current_kernel_prefix.sv" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
  "$build/Vtb_current_kernel_prefix${EXEEXT}" >"$build/run.log" 2>&1 || { tail -n 10 "$build/run.log"; exit 1; }
  cat "$build/run.log"
  set +e
  "$build/Vtb_current_kernel_prefix${EXEEXT}" +NEGATIVE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q CURRENT_KERNEL_MISMATCH "$build/negative.log"
  echo "CURRENT_KERNEL_NEGATIVE_PASS kernel=$kernel"
done
