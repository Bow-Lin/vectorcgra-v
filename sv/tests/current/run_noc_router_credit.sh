#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build=build/current/noc-handshakes/router-credit;mkdir -p "$build"
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_noc_router_credit --Mdir "$build/obj" \
  -f filelists/phase4_noc.f tests/current/tb_noc_router_credit.sv >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log";exit 1; }
exe=$build/obj/Vtb_noc_router_credit${EXEEXT}
"$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
grep NOC_ROUTER_CREDIT_PASS "$build/run.log"
set +e
"$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
status=$?
set -e
[[ $status != 0 ]] && grep -q NOC_ROUTER_RESULT "$build/negative.log" || { cat "$build/negative.log";exit 1; }
