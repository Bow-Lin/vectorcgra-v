#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_vector_arithmetic.sh [rtl|synth]';exit 2;;esac
root=build/current/vector-arithmetic/$mode;mkdir -p "$root"
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
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -Itests/current \
    --top-module tb_vector_arithmetic --Mdir "$build/obj" "$@" tests/current/tb_vector_arithmetic.sv \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
}
for profile in 'add 32 1' 'add 32 4' 'add 64 8' 'mul 32 4' 'mul 64 4' 'mul 64 8';do
  read -r kind width lanes <<<"$profile"
  number=0;stem=adder
  if [[ $kind == mul ]];then number=1;stem=mul;fi
  module=tile_vector_${stem}_combo
  rtl=("rtl/fu/vector/$module.sv" "rtl/fu/vector/cgra_vector_${stem}.sv")
  if [[ $mode == synth ]];then
    "$SV2V" -DSYNTHESIS -Irtl/common "${rtl[@]}" --top="$module" --write="$root/$kind.v" >"$root/sv2v-$kind.log" 2>&1
  fi
  for legacy in 0 1;do
    if [[ $kind == mul && $lanes != 4 && $legacy == 0 ]];then continue;fi
    build="$root/${kind}_w${width}_l${lanes}/legacy$legacy";mkdir -p "$build"
    sources=("${rtl[@]}");defines=()
    if [[ $mode == synth ]];then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/$kind.v; chparam -set DATA_W $width -set LANES $lanes -set LEGACY_PYTHON $legacy $module; hierarchy -check -top $module; proc; opt_clean; check -assert; synth -top $module -flatten -noabc; check -assert; scc -expect 0; rename $module vector_arithmetic_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top vector_arithmetic_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+VECTOR_ARITHMETIC_POST_SYNTH)
    fi
    compile -GDATA_W="$width" -GLANES="$lanes" -GKIND="$number" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}"
    exe="$build/obj/Vtb_vector_arithmetic${EXEEXT}";args=();marker=VECTOR_ARITHMETIC_NATIVE_PASS
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/vector_arithmetic/${kind}_w${width}_l${lanes}/vectors.txt");marker=VECTOR_ARITHMETIC_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'VECTOR_ARITHMETIC_CHECK\|VECTOR_ARITHMETIC_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $kind == add && $width == 32 && $lanes == 4 ]];then
      if [[ $legacy == 1 ]];then negative DEFECT_COMBINED_CONSTANT_CARRY "$build/carry.log" "$exe" +CARRY_DEFECT
      else "$exe" +CARRY_DEFECT >"$build/carry.log" 2>&1;grep VECTOR_ARITHMETIC_CARRY_FIXED "$build/carry.log";fi
    fi
    if [[ $kind == mul && $lanes == 8 ]];then negative DEFECT_OMITTED_HIGH_LANES "$build/high-lanes.log" "$exe" +HIGH_LANE_DEFECT;fi
    echo "VECTOR_ARITHMETIC_VALIDATION_PASS mode=$mode kind=$kind width=$width lanes=$lanes legacy=$legacy"
  done
done
build="$root/invalid-mul-lanes";mkdir -p "$build"
if [[ $mode == rtl ]];then
  compile -GKIND=1 -GLANES=8 rtl/fu/vector/tile_vector_mul_combo.sv rtl/fu/vector/cgra_vector_mul.sv
  negative 'VectorMulCombo native requires exactly four lanes' "$build/run.log" "$build/obj/Vtb_vector_arithmetic${EXEEXT}"
else
  # sv2v lowers $fatal into $display followed by $finish; Yosys stops there.
  grep -q 'VectorMulCombo native requires exactly four lanes' "$root/mul.v"
  negative '\$finish' "$build/run.log" "$YOSYS" -Q -T -p "read_verilog -defer $root/mul.v; chparam -set LANES 8 tile_vector_mul_combo; hierarchy -check -top tile_vector_mul_combo"
fi
echo "VECTOR_ARITHMETIC_PARAMETER_REJECT_PASS mode=$mode"
