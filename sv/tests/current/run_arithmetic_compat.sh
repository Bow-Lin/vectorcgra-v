#!/usr/bin/env bash
# Current RTL against frozen original HDL; no project Python at test time.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_arithmetic_compat.sh [rtl|synth]';exit 2;;esac
if [[ $mode == rtl ]];then
  # Broad phase3 scalar tests target ac96 Grant/GEP semantics. Div/LoopControl
  # use dedicated current Python replay; only the unchanged LoopCounter API
  # uses the old scalar vectors here.
  for profile in '32 8 16' '64 16 8';do
    read -r width depth registers <<<"$profile"
    build=build/current/arithmetic-boundaries/loop-counter/w$width;mkdir -p "$build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -Itests/current --top-module tb_loop_counter_compat --Mdir "$build/obj" \
      -GDATA_W="$width" -GCTRL_DEPTH="$depth" -GREG_DEPTH="$registers" rtl/fu/scalar/scalar_loop_counter.sv tests/current/tb_loop_counter_compat.sv \
      >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    "$build/obj/Vtb_loop_counter_compat${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep LOOP_COUNTER_COMPAT_PASS "$build/run.log"
    set +e
    "$build/obj/Vtb_loop_counter_compat${EXEEXT}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q LOOP_COUNTER_COMPAT_MISMATCH "$build/negative.log" || { cat "$build/negative.log";exit 1; }
  done
  bash tests/phase3/vector_combo/run.sh alu_gen_mac_w16_l4_b8_v0
  bash tests/phase3/vector_combo/run.sh alu_gen_mac_wrapper_w16_l4_b8_v0
fi
files=(rtl/fu/tile_adder.sv rtl/fu/tile_multiplier.sv
  rtl/fu/scalar/scalar_shifter.sv rtl/fu/scalar/scalar_comp.sv
  rtl/fu/scalar/scalar_logic.sv rtl/fu/scalar/scalar_grant.sv
  rtl/fu/combo/*.sv)
for kind in seq_mul_adder seq_mul_shifter prl_mul_adder three_mul_adder_shifter four_inc_cmp_not_grant;do
  module=tile_$kind
  for width in 32 64;do
    label=${kind}_w${width}_l4_b8_v0
    if [[ $kind == prl_mul_adder ]];then label=${label}_ctrl2;fi
    if [[ $mode == rtl ]];then
      bash tests/phase3/vector_combo/run.sh "$label"
      continue
    fi
    build=build/current/arithmetic-boundaries/combo-synth/$label;mkdir -p "$build"
    "$SV2V" -DSYNTHESIS -Irtl/common "${files[@]}" --top="$module" --write="$build/converted.v" >"$build/sv2v.log" 2>&1
    "$YOSYS" -Q -T -p "read_verilog -defer $build/converted.v; chparam -set DATA_W $width $module; hierarchy -check -top $module; proc; opt_clean; check -assert; synth -top $module -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename $module arithmetic_combo_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top arithmetic_combo_netlist; proc; opt_clean; check -assert; scc -expect 0; select -assert-none t:\$dlatch t:\$adlatch t:\$_DLATCH_*" >"$build/scc.log" 2>&1 || { tail -n 40 "$build/scc.log";exit 1; }
    sed '/^`line /d' "reference/phase3/vector_combo/$label/reference.v" >"$build/reference_compile.v"
    # Flattening removes the private Fu0 counter name. External full-port and
    # independent mathematical checks remain; the RTL run also checks this state.
    sed '/^if(dut\.Fu0\.vector_factor_counter/ d' "tests/phase3/vector_combo/$label/tb.sv" >"$build/tb_compile.sv"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common --top-module tb_phase3_vector --Mdir "$build/obj" \
      "+define+ARITHMETIC_COMBO_MODULE=$module" "$build/netlist.v" tests/current/arithmetic_combo_netlist_adapter.sv \
      "$build/reference_compile.v" "$build/tb_compile.sv" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    "$build/obj/Vtb_phase3_vector${EXEEXT}" "+RESULT=$build/result.json" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep P3_VECTOR_PASS "$build/run.log"
  done
done
echo "ARITHMETIC_COMPAT_PASS mode=$mode"
