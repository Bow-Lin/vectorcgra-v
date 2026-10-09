#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/../../.."
build=build/phase3/vector_combo/multp
mkdir -p "$build"
/ucrt64/bin/verilator --cc --main --exe --timing --compiler clang --top-module tb_multp --prefix Vmultp --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD rtl/fu/combo/cgra_multp.sv rtl/fu/combo/vendor/dp_fpfma/DW02_multp.v tests/phase3/vector_combo/tb_multp.sv > "$build/verilate.log" 2>&1
make -C "$build" -f Vmultp.mk -j 2 CXX=clang++ 'LINK=env -u LINK clang++' LDLIBS=-pthread > "$build/compile.log" 2>&1
"./$build/simulation.exe" > "$build/run.log" 2>&1
grep -q MULTP_PASS "$build/run.log"
cat "$build/run.log"
