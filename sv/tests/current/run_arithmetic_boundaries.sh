#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_arithmetic_boundaries.sh [rtl|synth]';exit 2;;esac
root=build/current/arithmetic-boundaries/$mode;mkdir -p "$root"
matched=0
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
for profile in 'div 16 1 0' 'div 32 1 0' 'div 64 1 0' 'inclusive 32 1 1' 'inclusive 32 2 1' 'inclusive 32 3 1' 'inclusive 32 4 1' 'exclusive 32 1 2' 'exclusive 32 3 2' 'exclusive 32 4 2' 'mac 16 1 3' 'loop 32 1 4' 'loop 64 1 4';do
  read -r kind width latency number <<<"$profile"
  name=${kind}_w${width}_l${latency}
  [[ -z ${ARITHMETIC_PROFILE_FILTER:-} || $name == "$ARITHMETIC_PROFILE_FILTER" ]] || continue
  matched=$((matched+1))
  case $kind in
    div) module=scalar_div;rtl=(rtl/fu/scalar/scalar_div_native.sv rtl/fu/scalar/scalar_div_pipeline.sv);;
    inclusive|exclusive) module=scalar_${kind}_div;rtl=(rtl/fu/scalar/scalar_div_native.sv rtl/fu/scalar/scalar_div_pipeline.sv);;
    mac) module=tile_alu_gen_mac;rtl=(rtl/fu/combo/cgra_alu_gen_mac.sv rtl/fu/combo/cgra_alu_gen_mac_core.sv rtl/fu/combo/cgra_multp.sv);;
    loop) module=scalar_loop_control;rtl=(rtl/fu/scalar/scalar_loop_control_native.sv);;
  esac
  if [[ $kind == mac ]];then rtl+=("rtl/fu/combo/$module.sv");else rtl+=("rtl/fu/scalar/$module.sv");fi
  if [[ $mode == synth ]];then
    "$SV2V" -DSYNTHESIS -Irtl/common "${rtl[@]}" --top="$module" --write="$root/$kind.v" >"$root/sv2v-$kind.log" 2>&1 || { cat "$root/sv2v-$kind.log";exit 1; }
  fi
  for legacy in 0 1;do
    # MAC compatibility uses the two existing original-HDL comparator benches.
    [[ $kind != mac || $legacy == 0 ]] || continue
    build="$root/$name/legacy$legacy";mkdir -p "$build"
    sources=("${rtl[@]}");defines=();latency_param=''
    [[ $kind != inclusive && $kind != exclusive ]] || latency_param="-set LATENCY $latency"
    if [[ $mode == synth ]];then
      # Scalar internal nets avoid false word-level dependencies in Verilator.
      # Port packing, cell logic, bit-level checks and the default convergence limit remain intact.
      "$YOSYS" -Q -T -p "read_verilog -defer $root/$kind.v; chparam -set DATA_W $width -set LEGACY_PYTHON $legacy $latency_param $module; hierarchy -check -top $module; proc; opt_clean; check -assert; synth -top $module -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename $module arithmetic_boundaries_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top arithmetic_boundaries_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+ARITHMETIC_BOUNDARIES_POST_SYNTH)
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_arithmetic_boundaries --Mdir "$build/obj" \
      -Wno-fatal -Irtl/common -Itests/current -GDATA_W="$width" -GLATENCY="$latency" -GKIND="$number" -GLEGACY_PYTHON="$legacy" \
      "${defines[@]}" "${sources[@]}" tests/current/tb_arithmetic_boundaries.sv \
      >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    exe="$build/obj/Vtb_arithmetic_boundaries${EXEEXT}";args=();marker=ARITHMETIC_BOUNDARIES_NATIVE_PASS
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/arithmetic_boundaries/$name/vectors.txt");marker=ARITHMETIC_BOUNDARIES_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'ARITHMETIC_BOUNDARIES_CHECK\|ARITHMETIC_BOUNDARIES_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    echo "ARITHMETIC_BOUNDARIES_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done

[[ $matched != 0 ]] || { echo "No arithmetic profile matched";exit 2; }
