#!/usr/bin/env bash
# Run from any directory in an MSYS2 shell. No project Python in daily builds.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
profile="${1:-w32}"
case "$profile" in w32|w64) ;; *) echo 'usage: run.sh [w32|w64]' >&2; exit 2;; esac
build="build/phase3/scalar/$profile"
mkdir -p "$build"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_scalar \
  --prefix Vscalar --Mdir "$build" -o scalar_test -CFLAGS -std=c++20 \
  -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common -I. -f "tests/phase3/scalar/$profile/files.f" \
  >"$build/verilator.log" 2>&1
make -C "$build" -f Vscalar.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
  >"$build/compile.log" 2>&1
"$build/scalar_test${EXEEXT}" >"$build/run.log" 2>&1
cat "$build/run.log"
set +e
"$build/scalar_test${EXEEXT}" +NEGATIVE >"$build/negative.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q SCALAR_NEGATIVE_CONTROL "$build/negative.log" || ! grep -q SCALAR_PYTHON_MISMATCH "$build/negative.log"; then
  echo 'SCALAR_NEGATIVE_FAILED' >&2; exit 1
fi
printf 'SCALAR_NEGATIVE_PASS profile=%s exit=%s\n' "$profile" "$status"
set +e
"$build/scalar_test${EXEEXT}" +TIMEOUT_TEST >"$build/timeout.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q SCALAR_TIMEOUT "$build/timeout.log"; then
  echo 'SCALAR_TIMEOUT_NEGATIVE_FAILED' >&2; exit 1
fi
printf 'SCALAR_TIMEOUT_NEGATIVE_PASS profile=%s exit=%s\n' "$profile" "$status"
