#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/toolchain.sh"
cd "$(dirname "$0")/.."
mkdir -p build/native_noc
files=(rtl/common/cgra_register_file.sv rtl/common/cgra_queue.sv rtl/common/cgra_channel.sv rtl/common/cgra_round_robin.sv rtl/noc/cgra_switch.sv rtl/noc/cgra_xbar.sv rtl/noc/cgra_credit_send.sv rtl/noc/cgra_credit_input.sv rtl/noc/cgra_credit_recv.sv rtl/noc/cgra_ring_route.sv rtl/noc/cgra_ring_router.sv rtl/noc/cgra_credit_ring.sv)
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_native_noc --prefix Vnative_noc --Mdir build/native_noc -o native_noc -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD "${files[@]}" reference/VectorCGRA2x2Reference.v tests/tb_native_noc.sv > build/native_noc/verilate.log 2>&1
make -C build/native_noc -f Vnative_noc.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread > build/native_noc/compile.log 2>&1
./build/native_noc/native_noc${EXEEXT} > build/native_noc/run.log 2>&1
grep -q NATIVE_NOC_PASS build/native_noc/run.log
cat build/native_noc/run.log
