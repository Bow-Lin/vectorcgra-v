#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_pipe_queue.sh [rtl|synth]';exit 2;;esac
root=build/current/pipe-queue/$mode;mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
compile() {
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_pipe_queue --Mdir "$build/obj" \
    "$@" tests/current/tb_pipe_queue.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
}
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS rtl/common/cgra_pipe_queue.sv --top=cgra_pipe_queue --write="$root/design.v"
fi
for profile in '8 1' '35 2' '67 3' '19 5';do
  read -r bits depth <<<"$profile"
  for legacy in 0 1;do
    build="$root/b${bits}_d${depth}/legacy$legacy";mkdir -p "$build"
    sources=(rtl/common/cgra_pipe_queue.sv rtl/common/cgra_queue.sv);defines=()
    if [[ $mode == synth ]];then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_BITS $bits -set DEPTH $depth -set LEGACY_PYTHON $legacy cgra_pipe_queue; hierarchy -check -top cgra_pipe_queue; proc; opt_clean; check -assert; synth -top cgra_pipe_queue -flatten -noabc; check -assert; scc -expect 0; rename cgra_pipe_queue pipe_queue_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top pipe_queue_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+PIPE_QUEUE_POST_SYNTH)
    fi
    compile -GDATA_BITS="$bits" -GDEPTH="$depth" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}"
    exe="$build/obj/Vtb_pipe_queue${EXEEXT}";args=();marker=PIPE_QUEUE_NATIVE_PASS
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/pipe_queue/b${bits}_d${depth}/vectors.txt");marker=PIPE_QUEUE_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'PIPE_QUEUE_CHECK\|PIPE_QUEUE_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    "$exe" +FULL_REPLACE >"$build/full-replace.log" 2>&1
    grep PIPE_QUEUE_FULL_REPLACE_PASS "$build/full-replace.log"
    if [[ $depth == 2 ]];then
      if [[ $legacy == 1 ]];then negative DEFECT_RESET_HANDSHAKE "$build/reset.log" "$exe" +RESET_HANDSHAKE
      else "$exe" +RESET_HANDSHAKE >"$build/reset.log" 2>&1;grep PIPE_QUEUE_RESET_FIXED "$build/reset.log";fi
    fi
    echo "PIPE_QUEUE_VALIDATION_PASS mode=$mode bits=$bits depth=$depth legacy=$legacy"
  done
done
if [[ $mode == rtl ]];then
  build="$root/normal-mutant";mkdir -p "$build"
  compile -GUSE_NORMAL_QUEUE=1 rtl/common/cgra_pipe_queue.sv rtl/common/cgra_queue.sv
  negative DEFECT_NORMAL_FULL_REPLACE "$build/run.log" "$build/obj/Vtb_pipe_queue${EXEEXT}" +FULL_REPLACE
  build="$root/invalid-width";mkdir -p "$build"
  compile -GBAD_WIDTH=1 rtl/common/cgra_pipe_queue.sv rtl/common/cgra_queue.sv
  negative PIPE_QUEUE_PARAMETER "$build/run.log" "$build/obj/Vtb_pipe_queue${EXEEXT}"
  echo PIPE_QUEUE_MUTANT_AND_PARAMETER_DETECTED
fi
