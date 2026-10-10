#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_im2col_boundaries.sh [rtl|synth]';exit 2;;esac
root=build/current/memory-boundaries/im2col-$mode;mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
sources=(rtl/mem/cgra_data_mem.sv rtl/peripheral/cgra_im2col_engine.sv)
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS -Irtl/common -Itests/current "${sources[@]}" tests/current/im2col_boundary_synth.sv --top=im2col_boundary_synth --write="$root/converted.v" >"$root/sv2v.log" 2>&1
fi
for config in '32 64 0' '64 32 0' '32 30 0' '32 64 1' '64 32 1';do
  read -r width depth legacy <<< "$config"
  build=$root/w$width-d$depth-legacy$legacy;mkdir -p "$build"
  compile_sources=("${sources[@]}");defines=()
  if [[ $mode == synth ]];then
    "$YOSYS" -Q -T -p "read_verilog -defer $root/converted.v; chparam -set DATA_W $width -set SCRATCH_DEPTH $depth -set LEGACY_PYTHON $legacy im2col_boundary_synth; hierarchy -check -top im2col_boundary_synth; proc; opt; check -assert; synth -top im2col_boundary_synth -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename im2col_boundary_synth im2col_boundaries_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top im2col_boundaries_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
    compile_sources=("$build/netlist.v");defines=(+define+IM2COL_BOUNDARIES_POST_SYNTH)
  fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_im2col_boundaries --Mdir "$build/obj" \
    -GDATA_W="$width" -GSCRATCH_DEPTH="$depth" -GLEGACY_PYTHON="$legacy" +incdir+rtl/common +incdir+tests/current \
    "${defines[@]}" "${compile_sources[@]}" tests/current/tb_im2col_boundaries.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_im2col_boundaries${EXEEXT}";args=()
  if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/memory_boundaries/im2col_w${width}_d$depth/vectors.txt");fi
  "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep 'IM2COL_BOUNDARIES_PASS\|IM2COL_REPLAY_PASS' "$build/run.log"
  negative 'independent image window\|IM2COL_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
  if [[ $legacy == 0 ]];then
    for invalid in zero oversize stride kernel image destination reset;do
      if [[ $mode == rtl ]];then
        negative IM2COL_NATIVE_COMMAND "$build/invalid-$invalid.log" "$exe" "+INVALID=$invalid"
      else
        "$exe" "+INVALID=$invalid" >"$build/invalid-$invalid.log" 2>&1 || { cat "$build/invalid-$invalid.log";exit 1; }
        grep -q IM2COL_INVALID_REJECT_PASS "$build/invalid-$invalid.log"
      fi
    done
  else
    negative 'im2col final done' "$build/restart-defect.log" "$exe"
  fi
done
echo "IM2COL_BOUNDARIES_VALIDATION_PASS mode=$mode"
