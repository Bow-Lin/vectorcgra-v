#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
out=build/phase3/system/logic
mkdir -p "$out"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_programmable_logic \
  --Mdir "$out" -o system_test -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
  -f filelists/phase3.f reference/phase3/system/logic/2x2/Phase3LogicReference2x2.v tests/phase3/system/tb_programmable_logic.sv \
  > "$out/verilate.log" 2>&1 || { tail -n 50 "$out/verilate.log"; exit 1; }
make -C "$out" -f Vtb_programmable_logic.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
  > "$out/compile.log" 2>&1 || { tail -n 30 "$out/compile.log"; exit 1; }
"$out/system_test${EXEEXT}" "+VECTORS=$PWD/vectors/phase3/system/logic/2x2" > "$out/run.log" 2>&1 || { cat "$out/run.log"; exit 1; }
grep -q PHASE3_PROGRAMMABLE_LOGIC_PASS "$out/run.log"
cat "$out/run.log"
