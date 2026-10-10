#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_arithmetic_guards.sh [rtl|synth]';exit 2;;esac
root=build/current/arithmetic-boundaries/guards/$mode;mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
for profile in pipeline-width pipeline-latency inclusive-latency primitive-stages mac-width;do
  rtl=(rtl/fu/scalar/scalar_div_pipeline.sv rtl/fu/scalar/scalar_div_native.sv)
  case "$profile" in
    pipeline-width) module=scalar_exclusive_div;parameter=DATA_W;value=64;marker='pipeline divider requires DATA_W=32\|DIV_NATIVE_PIPELINE_PARAMETERS';;
    pipeline-latency) module=scalar_exclusive_div;parameter=LATENCY;value=33;marker='DIV_NATIVE_PIPELINE_PARAMETERS\|DIV_PIPELINE_PARAMETERS';;
    inclusive-latency) module=scalar_inclusive_div;parameter=LATENCY;value=33;marker='DIV_NATIVE_PIPELINE_PARAMETERS\|DIV_PIPELINE_PARAMETERS';;
    primitive-stages) module=scalar_div_pipeline;parameter=CYCLE;value=33;marker=DIV_PIPELINE_PARAMETERS;;
    mac-width) module=tile_alu_gen_mac;parameter=DATA_W;value=32;marker='ALUgenMAC requires DATA_W=16';
      rtl=(rtl/fu/combo/tile_alu_gen_mac.sv rtl/fu/combo/cgra_alu_gen_mac.sv rtl/fu/combo/cgra_alu_gen_mac_core.sv rtl/fu/combo/cgra_multp.sv);;
  esac
  if [[ $module == scalar_exclusive_div || $module == scalar_inclusive_div ]];then rtl+=("rtl/fu/scalar/$module.sv");fi
  build=$root/$profile;mkdir -p "$build"
  if [[ $mode == rtl ]];then
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common --top-module "$module" --Mdir "$build/obj" \
      "-G$parameter=$value" "${rtl[@]}" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    negative "$marker" "$build/run.log" "$build/obj/V$module${EXEEXT}"
  else
    "$SV2V" -DSYNTHESIS -Irtl/common "${rtl[@]}" --top="$module" --write="$build/converted.v" >"$build/sv2v.log" 2>&1
    grep -q "$marker" "$build/converted.v"
    negative '\$finish' "$build/run.log" "$YOSYS" -Q -T -p "read_verilog -defer $build/converted.v; chparam -set $parameter $value $module; hierarchy -check -top $module"
  fi
  echo "ARITHMETIC_PARAMETER_REJECT_PASS mode=$mode profile=$profile"
done
if [[ $mode == rtl ]];then
  for profile in 'catalog32 32 30 240\x27h201d1c1a191817161514131211100f0e0d0c0b0a09080706050403020100' 'mac16 16 2 16\x27h031b';do
    read -r name width count kinds <<<"$profile";kinds=$(printf '%b' "$kinds")
    "$VERILATOR" --lint-only --timing -Wall -Wno-fatal -Werror-LATCH -Werror-UNDRIVEN \
      -Irtl/common -f filelists/native.f --top-module tile_flexible_fu_configurable \
      -GDATA_W="$width" -GFU_COUNT="$count" -GFU_KINDS="$kinds" >"$root/$name-lint.log" 2>&1 || { tail -n 40 "$root/$name-lint.log";exit 1; }
    echo "ARITHMETIC_CATALOG_LINT_PASS profile=$name"
  done
  for legacy in 0 1;do
    build=$root/defects/legacy$legacy;mkdir -p "$build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_arithmetic_defects --Mdir "$build/obj" \
      -GLEGACY_PYTHON="$legacy" rtl/fu/scalar/scalar_div_pipeline.sv rtl/fu/combo/cgra_alu_gen_mac_core.sv \
      rtl/fu/combo/cgra_multp.sv tests/current/tb_arithmetic_defects.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    for defect in DIV MAC;do
      args=();marker=DIV_REMAINDER_ITERATIONS
      if [[ $defect == MAC ]];then args=(+MAC);marker=MAC_SIGNED_OVERFLOW;fi
      if [[ $legacy == 0 ]];then
        "$build/obj/Vtb_arithmetic_defects${EXEEXT}" "${args[@]}" >"$build/$defect.log" 2>&1
        grep ARITHMETIC_DEFECT_FIXED "$build/$defect.log"
      else
        negative "$marker" "$build/$defect.log" "$build/obj/Vtb_arithmetic_defects${EXEEXT}" "${args[@]}"
        echo "ARITHMETIC_LEGACY_DEFECT_DETECTED defect=$defect"
      fi
    done
  done
fi
