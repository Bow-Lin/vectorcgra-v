#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) exit 2;;esac
root=build/current/memory-boundaries/controller-compat-$mode;mkdir -p "$root"
sources=(rtl/common/cgra_round_robin.sv rtl/common/cgra_queue.sv rtl/common/cgra_channel.sv rtl/noc/cgra_switch.sv rtl/noc/cgra_xbar.sv rtl/mem/cgra_data_bank.sv rtl/mem/cgra_data_memory.sv)
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
build=$root/r3w1;mkdir -p "$build";defines=()
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS -Irtl/common "${sources[@]}" --top=cgra_data_memory --write="$root/converted.v" >"$root/sv2v.log" 2>&1
  "$YOSYS" -Q -T -p "read_verilog -defer $root/converted.v; chparam -set MEM_PORTS 3 -set MEM_WRITE_PORTS 1 -set MAX_MEM_PORTS 3 -set MULTI_COLS 2 -set MULTI_ROWS 2 -set MEMORY_LEGACY_PYTHON 1 cgra_data_memory; hierarchy -check -top cgra_data_memory; proc; opt; check -assert; synth -top cgra_data_memory -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename cgra_data_memory memory_boundaries_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
  "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top memory_boundaries_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
  sources=("$build/netlist.v");defines=(+define+MEMORY_BOUNDARIES_POST_SYNTH)
fi
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_memory_boundary_replay --Mdir "$build/obj" \
  -GMEM_PORTS=3 -GMEM_WRITE_PORTS=1 -GMAX_MEM_PORTS=3 -GMULTI_COLS=2 -GMULTI_ROWS=2 -GMEMORY_LEGACY_PYTHON=1 \
  +incdir+rtl/common "${defines[@]}" "${sources[@]}" tests/current/tb_memory_boundary_replay.sv >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log";exit 1; }
exe="$build/obj/Vtb_memory_boundary_replay${EXEEXT}"
"$exe" +VECTORS=reference/current/memory_boundaries/controller_r3w1/vectors.txt >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
grep MEMORY_REPLAY_PASS "$build/run.log"
negative MEM_REPLAY_MISMATCH "$build/negative.log" "$exe" +VECTORS=reference/current/memory_boundaries/controller_r3w1/vectors.txt +EXPECT_FAILURE
if [[ $mode == rtl ]];then
  build=$root/r1w3;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_memory_boundary_compat --Mdir "$build/obj" \
    +incdir+rtl/common "${sources[@]}" reference/current/memory_boundaries/r1w3_reference.v tests/current/tb_memory_boundary_compat.sv >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_memory_boundary_compat${EXEEXT}"
  "$exe" "+RESULT=$build/result.json" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep PHASE4_MEMORY_PASS "$build/run.log"
  negative MEM_MATH_MISMATCH "$build/negative.log" "$exe" "+RESULT=$build/result.json" +EXPECT_FAILURE
fi
echo "MEMORY_BOUNDARIES_COMPAT_PASS mode=$mode"
