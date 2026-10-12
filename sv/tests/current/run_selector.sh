#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_selector.sh [rtl|synth]';exit 2;;esac
root=build/current/selector/$mode;mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS rtl/noc/cgra_selector.sv --top=cgra_selector --write="$root/design.v"
fi
for profile in '19 3' '35 5' '67 8' '8 1';do
  read -r bits inputs <<<"$profile"
  for legacy in 0 1;do
    if [[ $inputs == 1 && $legacy == 1 ]];then continue;fi
    build="$root/b${bits}_n${inputs}/legacy$legacy";mkdir -p "$build"
    sources=(rtl/noc/cgra_selector.sv);defines=()
    if [[ $mode == synth ]];then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_BITS $bits -set NUM_INPUTS $inputs -set LEGACY_PYTHON $legacy cgra_selector; hierarchy -check -top cgra_selector; proc; opt_clean; check -assert; synth -top cgra_selector -flatten -noabc; check -assert; scc -expect 0; rename cgra_selector selector_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top selector_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+SELECTOR_POST_SYNTH)
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_selector --Mdir "$build/obj" \
      -GDATA_BITS="$bits" -GNUM_INPUTS="$inputs" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}" tests/current/tb_selector.sv \
      >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    exe="$build/obj/Vtb_selector${EXEEXT}";args=();marker=SELECTOR_NATIVE_PASS
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/selector/b${bits}_n${inputs}/vectors.txt");marker=SELECTOR_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'SELECTOR_CHECK\|SELECTOR_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $inputs == 3 ]];then
      if [[ $legacy == 1 ]];then negative DEFECT_UNSELECTED_READY "$build/defect.log" "$exe" +DEFECT
      else
        "$exe" +DEFECT >"$build/defect.log" 2>&1
        grep SELECTOR_DEFECT_FIXED "$build/defect.log"
        if [[ $mode == rtl ]];then negative SELECTOR_INDEX "$build/invalid-index.log" "$exe" +INVALID_INDEX;fi
      fi
    fi
    echo "SELECTOR_VALIDATION_PASS mode=$mode bits=$bits inputs=$inputs legacy=$legacy"
  done
done
if [[ $mode == rtl ]];then
  build="$root/invalid-legacy";mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_selector --Mdir "$build/obj" \
    -GNUM_INPUTS=1 -GLEGACY_PYTHON=1 rtl/noc/cgra_selector.sv tests/current/tb_selector.sv \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  negative SELECTOR_LEGACY_DOMAIN "$build/run.log" "$build/obj/Vtb_selector${EXEEXT}"
  echo SELECTOR_INVALID_PARAMETER_DETECTED
fi
