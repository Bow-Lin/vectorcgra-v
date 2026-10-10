#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
out=build/phase3/system/vector
mkdir -p "$out"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_programmable_vector \
  --Mdir "$out" -o system_test -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
  -f filelists/phase3.f reference/phase3/system/vector/2x2/Phase3VectorReference2x2.v tests/phase3/system/tb_programmable_vector.sv \
  > "$out/verilate.log" 2>&1 || { tail -n 50 "$out/verilate.log"; exit 1; }
make -C "$out" -f Vtb_programmable_vector.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
  > "$out/compile.log" 2>&1 || { tail -n 30 "$out/compile.log"; exit 1; }
"$out/system_test${EXEEXT}" "+VECTORS=$PWD/vectors/phase3/system/vector/2x2" > "$out/run.log" 2>&1 || { cat "$out/run.log"; exit 1; }
grep -q PHASE3_PROGRAMMABLE_VECTOR_PASS "$out/run.log"
cat "$out/run.log"
set +e
"$out/system_test${EXEEXT}" "+VECTORS=$PWD/vectors/phase3/system/vector/2x2" +EXPECT_FAILURE >"$out/negative.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q 'intentional negative control: West result mismatch' "$out/negative.log"; then
  cat "$out/negative.log"; echo VECTOR_SYSTEM_NEGATIVE_FAILED >&2; exit 1
fi
printf 'VECTOR_SYSTEM_NEGATIVE_PASS exit=%s\n' "$status"
set +e
"$out/system_test${EXEEXT}" "+VECTORS=$PWD/vectors/phase3/system/vector/2x2" +STALL_FOREVER +MAX_CYCLES=200 >"$out/timeout.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] || ! grep -q 'TIMEOUT scenario=' "$out/timeout.log"; then
  cat "$out/timeout.log"; echo VECTOR_SYSTEM_TIMEOUT_FAILED >&2; exit 1
fi
printf 'VECTOR_SYSTEM_TIMEOUT_PASS exit=%s\n' "$status"
