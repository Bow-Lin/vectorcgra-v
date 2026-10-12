#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_or_link.sh [rtl|synth]';exit 2;;esac
root=build/current/or-link/$mode; mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS rtl/noc/cgra_or_link.sv --top=cgra_or_link --write="$root/design.v"
fi
for profile in '16 3' '32 5' '64 8' '1 1';do
  read -r width inputs <<<"$profile"
  build="$root/w${width}_n${inputs}"; mkdir -p "$build"
  sources=(rtl/noc/cgra_or_link.sv);defines=()
  if [[ $mode == synth ]];then
    "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_W $width -set NUM_INPUTS $inputs cgra_or_link; hierarchy -check -top cgra_or_link; proc; opt_clean; check -assert; synth -top cgra_or_link -flatten -noabc; check -assert; scc -expect 0; rename cgra_or_link or_link_netlist; write_verilog -noattr $build/netlist.v" \
      >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top or_link_netlist; proc; opt_clean; check -assert; scc -expect 0" \
      >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
    sources=("$build/netlist.v");defines=(+define+OR_LINK_POST_SYNTH)
  fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_or_link --Mdir "$build/obj" \
    -GDATA_W="$width" -GNUM_INPUTS="$inputs" "${defines[@]}" "${sources[@]}" tests/current/tb_or_link.sv \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_or_link${EXEEXT}"
  "$exe" >"$build/native.log" 2>&1 || { cat "$build/native.log";exit 1; }
  grep OR_LINK_NATIVE_PASS "$build/native.log"
  negative OR_LINK_CHECK "$build/native-negative.log" "$exe" +EXPECT_FAILURE
  if [[ $inputs != 1 ]];then
    vector="+VECTORS=reference/current/or_link/w${width}_n${inputs}/vectors.txt"
    "$exe" "$vector" >"$build/replay.log" 2>&1 || { cat "$build/replay.log";exit 1; }
    grep OR_LINK_REPLAY_PASS "$build/replay.log"
    negative OR_LINK_REPLAY_MISMATCH "$build/replay-negative.log" "$exe" "$vector" +EXPECT_FAILURE
  fi
  echo "OR_LINK_VALIDATION_PASS mode=$mode width=$width inputs=$inputs"
done
if [[ $mode == rtl ]];then
  build="$root/invalid-width";mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_or_link --Mdir "$build/obj" \
    -GDATA_W=0 rtl/noc/cgra_or_link.sv tests/current/tb_or_link.sv \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  negative OR_LINK_PARAMETER "$build/run.log" "$build/obj/Vtb_or_link${EXEEXT}"
  echo OR_LINK_INVALID_PARAMETER_DETECTED
fi
