#!/usr/bin/env bash
# Stable native loop scheduling and immutable Python compatibility replay.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_loop_controller.sh [rtl|synth]';exit 2;;esac
root=build/current/loop-semantics/$mode
mkdir -p "$root"
rtl=(rtl/controller/cgra_loop_controller.sv rtl/controller/cgra_loop_controller_native.sv rtl/controller/cgra_loop_controller_legacy.sv)
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS "${rtl[@]}" --top=cgra_loop_controller --write="$root/design.v" >"$root/sv2v.log" 2>&1 \
    || { tail -n 40 "$root/sv2v.log";exit 1; }
fi
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
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module "$top" --Mdir "$build/obj" \
    -Wno-fatal -GDATA_W="$width" -GNUM_CCUS="$ccus" -GMAX_TARGETS="$targets" \
    -GCTRL_BITS="$ctrl" -GCTRL_ADDR_W="$addr" -GLEGACY_DISPATCH_WRAP="$legacy" \
    "${defines[@]}" "${source_files[@]}" "tests/current/$top.sv" "$@" \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
}
for profile in 'default 32 8 4 107 3' 'wide 64 3 3 119 3' 'single 32 1 1 119 1' 'eight_targets 32 8 8 119 4';do
  read -r name width ccus targets ctrl addr <<<"$profile"
  for legacy in 0 1;do
    build="$root/$name/legacy$legacy";mkdir -p "$build"
    source_files=("${rtl[@]}");defines=()
    if [[ $mode == synth ]];then
      # Optional SAT resource sharing exhausts this toolchain on the configured forest.
      # Keep structural optimization, emitted-netlist checks and the full functional bench.
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_W $width -set NUM_CCUS $ccus -set MAX_TARGETS $targets -set CTRL_BITS $ctrl -set CTRL_ADDR_W $addr -set LEGACY_PYTHON $legacy -set LEGACY_DISPATCH_WRAP $legacy cgra_loop_controller; hierarchy -check -top cgra_loop_controller; proc; opt_clean; check -assert; synth -top cgra_loop_controller -flatten -noabc -noshare; check -assert; scc -expect 0; rename cgra_loop_controller cgra_loop_controller_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top cgra_loop_controller_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      source_files=("$build/netlist.v");defines=(+define+LOOP_POST_SYNTH)
    fi
    top=tb_loop_controller_native;args=();marker=LOOP_NATIVE_SEMANTICS_PASS
    if [[ $legacy == 1 ]];then
      top=tb_loop_controller;args=("+VECTORS=reference/current/loop_controller/$name/vectors.txt");marker=LOOP_REPLAY_PASS
    fi
    compile
    exe="$build/obj/V${top}${EXEEXT}"
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'LOOP_CHECK\|LOOP_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $legacy == 1 && $targets != 1 && $targets != 3 ]];then
      negative LOOP_CHECK "$build/wrap-defect.log" "$exe"
    fi
    if [[ $legacy == 0 && $mode == rtl ]];then
      for invalid in TARGET NO_ROOT RANGE;do
        case $invalid in TARGET) marker=LOOP_CONFIG_TARGET_CAPACITY;;NO_ROOT) marker=LOOP_CONFIG_NO_ROOT;;RANGE) marker=LOOP_CONFIG_RANGE;;esac
        negative "$marker" "$build/invalid-${invalid,,}.log" "$exe" "+INVALID=$invalid"
      done
      if [[ $name == wide ]];then
        for invalid in CCU PARENT PARENT_CYCLE PARENT_UNCONFIGURED;do
          negative "LOOP_CONFIG_$invalid" "$build/invalid-${invalid,,}.log" "$exe" "+INVALID=$invalid"
        done
      fi
    fi
    if [[ $legacy == 0 && $mode == synth ]];then
      "$exe" +EMPTY_LAUNCH >"$build/empty-launch.log" 2>&1
      grep LOOP_EMPTY_LAUNCH_INERT "$build/empty-launch.log"
    fi
    echo "LOOP_SEMANTICS_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
    if [[ $name == default ]];then
      if [[ $legacy == 1 ]];then
        build="$root/$name/legacy1/defects";mkdir -p "$build"
        top=tb_loop_controller_native;compile -GLEGACY_PYTHON=1
        exe="$build/obj/V${top}${EXEEXT}"
      fi
      for defect in complete simultaneous siblings grandparent remote_target preempt reset busy_config;do
        if [[ $legacy == 1 ]];then
          negative "DEFECT_${defect^^}" "$build/defect-$defect.log" "$exe" "+DEFECT=$defect"
        else
          "$exe" "+DEFECT=$defect" >"$build/defect-$defect.log" 2>&1
          grep LOOP_SEMANTIC_FIXED "$build/defect-$defect.log"
        fi
      done
    fi
  done
done
