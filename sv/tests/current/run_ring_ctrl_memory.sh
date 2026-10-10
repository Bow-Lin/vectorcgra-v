#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_ring_ctrl_memory.sh [rtl|synth]'; exit 2;; esac
root=build/current/ring-ctrl-memory/$mode
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
mapfile -t rtl < <(grep -v '^+' filelists/ring_ctrl_memory.f)
if [[ $mode == synth ]]; then
  # Keep conversion artifacts separate when profile-filtered runs overlap.
  profile_key=${RING_CTRL_PROFILES:-all}
  design="$root/design-${profile_key// /-}.v"
  "$SV2V" -DSYNTHESIS -Irtl/common "${rtl[@]}" --top=cgra_ring_multi_ctrl_mem \
    --write="$design" >"$design.log" 2>&1 || { tail -n 40 "$design.log"; exit 1; }
fi
for profile in 'original 2 2 16 4 16 16 12 12 2 4 4' \
               'nonpower 3 1 32 7 6 8 3 6 4 4 4' \
               'wide 1 2 64 9 8 16 4 5 4 8 8' \
               'single 1 1 32 5 3 4 2 4 1 3 5'; do
  read -r name cols rows width dataaddr depth regs period total fuin tin tout <<<"$profile"
  if [[ -n ${RING_CTRL_PROFILES:-} && " $RING_CTRL_PROFILES " != *" $name "* ]]; then continue; fi
  params=("COLS $cols" "ROWS $rows" "DATA_W $width" "DATA_ADDR_W $dataaddr" "CTRL_DEPTH $depth"
          "REG_DEPTH $regs" "NUM_CTRL $period" "TOTAL_STEPS $total" "FU_INPUTS $fuin" "TILE_INPUTS $tin" "TILE_OUTPUTS $tout")
  vargs=(); yargs=''
  for pair in "${params[@]}"; do
    read -r param value <<<"$pair"
    vargs+=("-G$param=$value"); yargs+=" -set $param $value"
  done
  for legacy in 0 1; do
    build="$root/$name/legacy$legacy";mkdir -p "$build"
    sources=("${rtl[@]}");defines=()
    if [[ $mode == synth ]]; then
      "$YOSYS" -Q -T -p "read_verilog -defer $design; chparam $yargs -set LEGACY_PYTHON $legacy cgra_ring_multi_ctrl_mem; hierarchy -check -top cgra_ring_multi_ctrl_mem; proc; opt_clean; check -assert; synth -top cgra_ring_multi_ctrl_mem -flatten -noabc; check -assert; scc -expect 0; rename cgra_ring_multi_ctrl_mem cgra_ring_multi_ctrl_mem_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 45 "$build/yosys.log"; exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top cgra_ring_multi_ctrl_mem_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 40 "$build/scc.log"; exit 1; }
      sources=("$build/netlist.v");defines=(+define+RING_CTRL_POST_SYNTH)
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common --top-module tb_ring_ctrl_memory \
      --Mdir "$build/obj" "${vargs[@]}" -GLEGACY_PYTHON="$legacy" "${defines[@]}" \
      "${sources[@]}" tests/current/tb_ring_ctrl_memory.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log"; exit 1; }
    exe="$build/obj/Vtb_ring_ctrl_memory${EXEEXT}"
    args=();marker=RING_CTRL_NATIVE_PASS
    if [[ $legacy == 1 ]]; then
      vector="reference/current/ring_ctrl_memory/$name/vectors.txt"
      args=("+VECTORS=$vector" "+SAMPLES=$(wc -l <"$vector")");marker=RING_CTRL_REPLAY_PASS
    fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
    grep "$marker" "$build/run.log"
    negative 'RING_CTRL_CHECK\|RING_CTRL_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $legacy == 1 ]]; then
      negative RING_CTRL_UNEXPECTED_RETURN "$build/dummy-defect.log" "$exe"
      if [[ $name == original ]]; then
        vector=reference/current/ring_ctrl_memory/original_test/vectors.txt
        "$exe" "+VECTORS=$vector" "+SAMPLES=$(wc -l <"$vector")" >"$build/original-test.log" 2>&1 || { cat "$build/original-test.log";exit 1; }
        grep RING_CTRL_REPLAY_PASS "$build/original-test.log"
        negative RING_CTRL_REPLAY_MISMATCH "$build/original-negative.log" "$exe" "+VECTORS=$vector" "+SAMPLES=$(wc -l <"$vector")" +EXPECT_FAILURE
      fi
    elif [[ $mode == rtl ]]; then
      if [[ $name == original ]]; then negative RING_CTRL_DESTINATION "$build/invalid-dest.log" "$exe" +INVALID_DEST; fi
      if [[ $name == nonpower ]]; then negative RING_CTRL_ADDRESS "$build/invalid-address.log" "$exe" +INVALID_ADDRESS; fi
    fi
    echo "RING_CTRL_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done
if [[ $mode == rtl && -z ${RING_CTRL_PROFILES:-} ]]; then
  build="$root/invalid-param";mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common --top-module tb_ring_ctrl_memory \
    --Mdir "$build/obj" -GFU_OUTPUTS=3 "${rtl[@]}" tests/current/tb_ring_ctrl_memory.sv \
    >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  negative RING_CTRL_PARAMETER "$build/run.log" "$build/obj/Vtb_ring_ctrl_memory${EXEEXT}"
  echo RING_CTRL_INVALID_PARAMETER_PASS
fi
