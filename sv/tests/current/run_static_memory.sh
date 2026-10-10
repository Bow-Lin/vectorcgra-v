#!/usr/bin/env bash
# Frozen Python replay and independent native protocol checks; no runtime PyMTL.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_static_memory.sh [rtl|synth]'; exit 2;; esac
root=build/current/static-memory/$mode
mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local result=$?
  set -e
  [[ $result != 0 ]] && grep -q "$marker" "$log" || { cat "$log"; exit 1; }
}
compile() {
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Itests/current "$@" \
    >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
}
synthesize() {
  local top=$1 output=$2
  shift 2
  "$YOSYS" -Q -T -p "read_verilog -defer $root/$top.v; chparam $* $top; hierarchy -check -top $top; proc; opt_clean; check -assert; synth -top $top -flatten -noabc; check -assert; rename $top $output; write_verilog -noattr $build/netlist.v" \
    >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log"; exit 1; }
  # write_verilog aliases different bits of the same vector. Verilator can
  # report UNOPTFLAT on these concatenations; check the emitted bit-level graph.
  "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top $output; proc; opt_clean; check -assert; scc -expect 0" \
    >"$build/scc.log" 2>&1 || { tail -n 40 "$build/scc.log"; exit 1; }
}
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS rtl/mem/cgra_static_ctrl_mem.sv --top=cgra_static_ctrl_mem \
    --write="$root/cgra_static_ctrl_mem.v" >"$root/sv2v-ctrl.log" 2>&1
  "$SV2V" -DSYNTHESIS -Itests/current rtl/mem/cgra_static_const_queue.sv tests/current/static_const_synth.sv \
    --top=static_const_synth --write="$root/static_const_synth.v" >"$root/sv2v-const.log" 2>&1
fi
for profile in 'ctrl_default 119 4 4 9 112 1' 'ctrl_nonpower 107 3 3 7 100 1' \
               'ctrl_subset 119 8 2 13 112 1' 'ctrl_single 119 1 1 3 112 0' \
               'ctrl_unlimited 119 3 3 0 112 0' 'ctrl_offset 119 3 3 7 40 0'; do
  read -r name bits depth period total op_lsb compat <<<"$profile"
  if [[ -n ${STATIC_PROFILES:-} && " $STATIC_PROFILES " != *" $name "* ]]; then continue; fi
  for legacy in 0 1; do
    if [[ $legacy == 1 && $compat == 0 ]]; then continue; fi
    build="$root/$name/legacy$legacy"
    mkdir -p "$build"
    sources=(rtl/mem/cgra_static_ctrl_mem.sv)
    defines=()
    if [[ $mode == synth ]]; then
      synthesize cgra_static_ctrl_mem cgra_static_ctrl_mem_netlist \
        -set CTRL_BITS "$bits" -set DEPTH "$depth" -set COUNT_PER_ITER "$period" \
        -set TOTAL_STEPS "$total" -set OP_LSB "$op_lsb" -set LEGACY_PYTHON "$legacy"
      sources=("$build/netlist.v"); defines=(+define+STATIC_POST_SYNTH)
    fi
    compile --top-module tb_static_ctrl_mem --Mdir "$build/obj" \
      -GCTRL_BITS="$bits" -GDEPTH="$depth" -GCOUNT_PER_ITER="$period" -GTOTAL_STEPS="$total" \
      -GOP_LSB="$op_lsb" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}" tests/current/tb_static_ctrl_mem.sv
    exe="$build/obj/Vtb_static_ctrl_mem${EXEEXT}"
    args=(); marker=STATIC_CTRL_NATIVE_PASS
    if [[ $legacy == 1 ]]; then args=("+VECTORS=reference/current/static_memory/$name/vectors.txt"); marker=STATIC_CTRL_REPLAY_PASS; fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
    grep "$marker" "$build/run.log"
    negative 'STATIC_CTRL_CHECK\|STATIC_CTRL_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $name == ctrl_default ]]; then
      for defect in budget reset unpaired; do
        if [[ $legacy == 1 ]]; then
          negative "DEFECT_${defect^^}" "$build/defect-$defect.log" "$exe" "+DEFECT=$defect"
        else
          "$exe" "+DEFECT=$defect" >"$build/defect-$defect.log" 2>&1
          grep STATIC_CTRL_DEFECT_FIXED "$build/defect-$defect.log"
        fi
      done
    fi
    if [[ $mode == rtl && $legacy == 0 && $name == ctrl_nonpower ]]; then
      negative STATIC_CTRL_ADDRESS "$build/invalid-address.log" "$exe" +INVALID_ADDRESS
    fi
    echo "STATIC_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done
for profile in 'const_original 19 3 1' 'const_four 35 4 0' 'const_wide 67 3 0' \
               'const_single 35 1 0' 'const_empty 35 0 0'; do
  read -r name bits count original <<<"$profile"
  if [[ -n ${STATIC_PROFILES:-} && " $STATIC_PROFILES " != *" $name "* ]]; then continue; fi
  for legacy in 0 1; do
    if [[ $legacy == 1 && $count == 0 ]]; then continue; fi
    build="$root/$name/legacy$legacy"
    mkdir -p "$build"
    sources=(rtl/mem/cgra_static_const_queue.sv)
    defines=()
    if [[ $mode == synth ]]; then
      synthesize static_const_synth static_const_netlist -set DATA_BITS "$bits" \
        -set NUM_CONST "$count" -set ORIGINAL "$original" -set LEGACY_PYTHON "$legacy"
      sources=("$build/netlist.v"); defines=(+define+STATIC_POST_SYNTH)
    fi
    compile --top-module tb_static_const_queue --Mdir "$build/obj" \
      -GDATA_BITS="$bits" -GNUM_CONST="$count" -GORIGINAL="$original" -GLEGACY_PYTHON="$legacy" \
      "${defines[@]}" "${sources[@]}" tests/current/tb_static_const_queue.sv
    exe="$build/obj/Vtb_static_const_queue${EXEEXT}"
    args=(); marker=STATIC_CONST_NATIVE_PASS
    if [[ $legacy == 1 ]]; then args=("+VECTORS=reference/current/static_memory/$name/vectors.txt"); marker=STATIC_CONST_REPLAY_PASS; fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
    grep "$marker" "$build/run.log"
    negative 'STATIC_CONST_CHECK\|STATIC_CONST_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $name == const_original ]]; then
      if [[ $legacy == 1 ]]; then
        negative DEFECT_RESET "$build/defect-reset.log" "$exe" +DEFECT_RESET
      else
        "$exe" +DEFECT_RESET >"$build/defect-reset.log" 2>&1
        grep STATIC_CONST_DEFECT_FIXED "$build/defect-reset.log"
      fi
    fi
    echo "STATIC_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done
if [[ $mode == rtl && -z ${STATIC_PROFILES:-} ]]; then
  for bad in 0 1 2 3; do
    build="$root/invalid-param-$bad"; mkdir -p "$build"
    compile --top-module tb_static_invalid --Mdir "$build/obj" -GBAD_CASE="$bad" \
      rtl/mem/cgra_static_ctrl_mem.sv rtl/mem/cgra_static_const_queue.sv tests/current/tb_static_invalid.sv
    negative 'STATIC_CTRL_PARAM\|STATIC_CTRL_LEGACY_DOMAIN\|STATIC_CONST_LEGACY_DOMAIN' \
      "$build/run.log" "$build/obj/Vtb_static_invalid${EXEEXT}"
    echo "STATIC_INVALID_PARAM_DETECTED case=$bad"
  done
fi
