#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_vector_reduce.sh [rtl|synth]';exit 2;;esac
root=build/current/vector-reduce/$mode;mkdir -p "$root"
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
    --top-module tb_vector_reduce --Mdir "$build/obj" "$@" tests/current/tb_vector_reduce.sv \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
}
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS -Irtl/common rtl/fu/vector/tile_vector_all_reduce.sv \
    --top=tile_vector_all_reduce --write="$root/design.v" >"$root/sv2v.log" 2>&1
fi
for profile in '16 4' '32 4' '32 8' '64 8';do
  read -r width lanes <<<"$profile"
  for legacy in 0 1;do
    build="$root/w${width}_l${lanes}/legacy$legacy";mkdir -p "$build"
    sources=(rtl/fu/vector/tile_vector_all_reduce.sv);defines=()
    if [[ $mode == synth ]];then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_W $width -set LANES $lanes -set LEGACY_PYTHON $legacy tile_vector_all_reduce; hierarchy -check -top tile_vector_all_reduce; proc; opt_clean; check -assert; synth -top tile_vector_all_reduce -flatten -noabc; check -assert; scc -expect 0; rename tile_vector_all_reduce vector_reduce_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top vector_reduce_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+VECTOR_REDUCE_POST_SYNTH)
    fi
    compile -GDATA_W="$width" -GLANES="$lanes" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}"
    exe="$build/obj/Vtb_vector_reduce${EXEEXT}";args=();marker=VECTOR_REDUCE_NATIVE_PASS
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/vector_reduce/w${width}_l${lanes}/vectors.txt");marker=VECTOR_REDUCE_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep "$marker" "$build/run.log"
    negative 'VECTOR_REDUCE_CHECK\|VECTOR_REDUCE_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $width == 32 && $lanes == 4 ]];then
      for defect in mul_request invalid_control duplicate base_ready predicate early_retire response_stall clear;do
        if [[ $legacy == 1 ]];then negative "DEFECT_${defect^^}" "$build/defect-$defect.log" "$exe" "+DEFECT=$defect"
        else
          "$exe" "+DEFECT=$defect" >"$build/defect-$defect.log" 2>&1
          grep VECTOR_REDUCE_DEFECT_FIXED "$build/defect-$defect.log"
        fi
      done
    fi
    echo "VECTOR_REDUCE_VALIDATION_PASS mode=$mode width=$width lanes=$lanes legacy=$legacy"
  done
done
if [[ $mode == rtl ]];then
  build="$root/invalid-lanes";mkdir -p "$build"
  compile -GLANES=2 rtl/fu/vector/tile_vector_all_reduce.sv
  negative 'VectorAllReduce requires LANES' "$build/run.log" "$build/obj/Vtb_vector_reduce${EXEEXT}"
  echo VECTOR_REDUCE_INVALID_PARAMETER_DETECTED
fi
