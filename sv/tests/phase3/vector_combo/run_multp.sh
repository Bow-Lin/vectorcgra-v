#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
build=build/phase3/vector_combo/multp
mkdir -p "$build"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_multp --prefix Vmultp --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD rtl/fu/combo/cgra_multp.sv reference/vendor/alu_gen_mac/dp_fpfma/DW02_multp.v tests/phase3/vector_combo/tb_multp.sv > "$build/verilate.log" 2>&1
make -C "$build" -f Vmultp.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$build/compile.log" 2>&1
"./$build/simulation${EXEEXT}" > "$build/run.log" 2>&1
grep -q MULTP_PASS "$build/run.log"
cat "$build/run.log"
