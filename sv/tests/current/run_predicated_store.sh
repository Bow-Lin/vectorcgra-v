#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}; case "$mode" in rtl|synth) ;; *) exit 2;; esac
root=build/current/kernel-boundaries/predicated-store/$mode; mkdir -p "$root"
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS -Irtl/common rtl/fu/tile_memory_fu.sv --top=tile_memory_fu --write="$root/design.v"
fi
for bits in 32 64; do
  build="$root/w$bits";mkdir -p "$build"
  sources=(rtl/fu/tile_memory_fu.sv);defs=()
  if [[ $mode == synth ]]; then
    "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_W $bits tile_memory_fu; hierarchy -check -top tile_memory_fu; proc; opt_clean; check -assert; synth -top tile_memory_fu -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename tile_memory_fu predicated_store_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top predicated_store_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
    sources=("$build/netlist.v");defs=(+define+PREDICATED_STORE_POST_SYNTH)
  fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" -MAKEFLAGS "CXX=$CXX LINK=$CXX" \
    -CFLAGS -O0 -Wno-fatal -Irtl/common --top-module tb_predicated_store --Mdir "$build/obj" \
    -GDATA_W="$bits" "${defs[@]}" "${sources[@]}" tests/current/tb_predicated_store.sv >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  "$build/obj/Vtb_predicated_store${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep PREDICATED_STORE_PASS "$build/run.log"
  set +e
  "$build/obj/Vtb_predicated_store${EXEEXT}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q PREDICATED_STORE_WAIT "$build/negative.log"
done
if [[ $mode == rtl ]]; then
  build="$root/legacy-mutant";mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" -MAKEFLAGS "CXX=$CXX LINK=$CXX" \
    -CFLAGS -O0 -Wno-fatal -Irtl/common --top-module tb_predicated_store --Mdir "$build/obj" \
    -GMEMORY_LEGACY_PYTHON=1 rtl/fu/tile_memory_fu.sv tests/current/tb_predicated_store.sv \
    >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  set +e
  "$build/obj/Vtb_predicated_store${EXEEXT}" >"$build/run.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q PREDICATED_STORE_WAIT "$build/run.log"
  echo PREDICATED_STORE_LEGACY_DEADLOCK_DETECTED
fi
