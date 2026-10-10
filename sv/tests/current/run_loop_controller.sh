#!/usr/bin/env bash
# Standalone payload API: frozen Python compatibility and independent native checks.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_loop_controller.sh [rtl|synth]'; exit 2;; esac
root=build/current/loop-controller/$mode
mkdir -p "$root"
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS rtl/controller/cgra_loop_controller.sv --top=cgra_loop_controller \
    --write="$root/design.v" >"$root/sv2v.log" 2>&1 || { tail -n 40 "$root/sv2v.log"; exit 1; }
fi
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log"; exit 1; }
}
for profile in 'default 32 8 4 107 3' 'wide 64 3 3 119 3' 'single 32 1 1 119 1' 'eight_targets 32 8 8 119 4'; do
  read -r name width ccus targets ctrl addr <<<"$profile"
  for legacy in 0 1; do
    build="$root/$name/legacy$legacy"
    mkdir -p "$build"
    source_files=(rtl/controller/cgra_loop_controller.sv)
    defines=()
    if [[ $mode == synth ]]; then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_W $width -set NUM_CCUS $ccus -set MAX_TARGETS $targets -set CTRL_BITS $ctrl -set CTRL_ADDR_W $addr -set LEGACY_DISPATCH_WRAP $legacy cgra_loop_controller; hierarchy -check -top cgra_loop_controller; proc; opt_clean; check -assert; synth -top cgra_loop_controller -flatten -noabc; check -assert; rename cgra_loop_controller cgra_loop_controller_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log"; exit 1; }
      source_files=("$build/netlist.v")
      defines=(+define+LOOP_POST_SYNTH)
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_loop_controller --Mdir "$build/obj" \
      -Wno-fatal -GDATA_W="$width" -GNUM_CCUS="$ccus" -GMAX_TARGETS="$targets" \
      -GCTRL_BITS="$ctrl" -GCTRL_ADDR_W="$addr" -GLEGACY_DISPATCH_WRAP="$legacy" \
      "${defines[@]}" "${source_files[@]}" tests/current/tb_loop_controller.sv \
      >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log"; exit 1; }
    exe="$build/obj/Vtb_loop_controller${EXEEXT}"
    args=()
    marker=LOOP_NATIVE_PASS
    if [[ $legacy == 1 ]]; then
      args=("+VECTORS=reference/current/loop_controller/$name/vectors.txt")
      marker=LOOP_REPLAY_PASS
    fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
    grep "$marker" "$build/run.log"
    negative 'LOOP_CHECK\|LOOP_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $legacy == 1 && $targets != 1 && $targets != 3 ]]; then
      negative LOOP_CHECK "$build/wrap-defect.log" "$exe"
      echo "LOOP_WRAP_DEFECT_DETECTED mode=$mode profile=$name"
    fi
    if [[ $legacy == 0 && $mode == rtl ]]; then
      negative LOOP_CONFIG_TARGET_CAPACITY "$build/invalid-target.log" "$exe" +INVALID_TARGET
      if [[ $name == wide ]]; then
        negative LOOP_CONFIG_CCU "$build/invalid-ccu.log" "$exe" +INVALID_CCU
        negative LOOP_CONFIG_PARENT "$build/invalid-parent.log" "$exe" +INVALID_PARENT
      fi
    fi
    echo "LOOP_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done
