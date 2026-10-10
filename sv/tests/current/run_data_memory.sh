#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
api=${2:-plain}
scalable=0; synth_top=data_mem_synth; reference=data_memory
native_sources=(rtl/mem/cgra_data_mem.sv tests/current/data_mem_synth.sv)
case "$api" in
  plain) ;;
  scalable) scalable=1;synth_top=data_mem_scalable_synth;reference=data_memory_scalable
    native_sources+=(rtl/mem/cgra_data_mem_scalable.sv tests/current/data_mem_scalable_synth.sv);;
  *) echo "unknown data-memory API: $api";exit 2;;
esac
case "$mode" in rtl|synth) ;; *) echo 'usage: run_data_memory.sh [rtl|synth] [plain|scalable]'; exit 2;; esac
root=build/current/data-memory/$mode
if [[ $scalable == 1 ]]; then root=build/current/data-memory-scalable/$mode;fi
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
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS -Itests/current "${native_sources[@]}" \
    --top="$synth_top" --write="$root/design.v" >"$root/sv2v.log" 2>&1
fi
for profile in 'original 19 20 1 1 1 1' 'multi 35 5 3 2 1 0' 'wide 67 3 2 3 0 0' 'single 8 1 1 1 1 0'; do
  read -r name bits depth rd wr preload original <<<"$profile"
  if [[ -n ${DATA_MEM_PROFILES:-} && " $DATA_MEM_PROFILES " != *" $name "* ]]; then continue; fi
  for legacy in 0 1; do
    if [[ $name == single && $legacy == 1 ]]; then continue; fi
    build="$root/$name/legacy$legacy";mkdir -p "$build"
    sources=("${native_sources[@]}");defines=()
    if [[ $mode == synth ]]; then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_BITS $bits -set DEPTH $depth -set RD_PORTS $rd -set WR_PORTS $wr -set PRELOAD_ENABLE $preload -set ORIGINAL $original -set LEGACY_PYTHON $legacy $synth_top; hierarchy -check -top $synth_top; proc; opt_clean; check -assert; synth -top $synth_top -flatten -noabc; check -assert; scc -expect 0; rename $synth_top data_mem_netlist; write_verilog -noattr $build/netlist.v" \
        >"$build/yosys.log" 2>&1 || { tail -n 45 "$build/yosys.log"; exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top data_mem_netlist; proc; opt_clean; check -assert; scc -expect 0" \
        >"$build/scc.log" 2>&1 || { tail -n 45 "$build/scc.log"; exit 1; }
      sources=("$build/netlist.v");defines=(+define+DATA_MEM_POST_SYNTH)
      if [[ $scalable == 1 ]]; then defines+=(+define+DATA_MEM_SCALABLE_NETLIST);fi
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Itests/current \
      --top-module tb_data_mem --Mdir "$build/obj" -GDATA_BITS="$bits" -GDEPTH="$depth" \
      -GRD_PORTS="$rd" -GWR_PORTS="$wr" -GPRELOAD_ENABLE="$preload" -GORIGINAL="$original" \
      -GLEGACY_PYTHON="$legacy" -GSCALABLE="$scalable" "${defines[@]}" "${sources[@]}" tests/current/tb_data_mem.sv \
      >"$build/compile.log" 2>&1 || { tail -n 45 "$build/compile.log"; exit 1; }
    exe="$build/obj/Vtb_data_mem${EXEEXT}"
    args=();marker=DATA_MEM_NATIVE_PASS
    if [[ $legacy == 1 ]]; then args=("+VECTORS=reference/current/$reference/$name/vectors.txt");marker=DATA_MEM_REPLAY_PASS;fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
    grep "$marker" "$build/run.log"
    negative 'DATA_MEM_CHECK\|DATA_MEM_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $name == multi ]]; then
      for defect in preload unpaired held reset; do
        if [[ $legacy == 1 ]]; then
          negative "DEFECT_${defect^^}" "$build/defect-$defect.log" "$exe" "+DEFECT=$defect"
        else
          "$exe" "+DEFECT=$defect" >"$build/defect-$defect.log" 2>&1
          grep DATA_MEM_DEFECT_FIXED "$build/defect-$defect.log"
        fi
      done
      if [[ $legacy == 0 && $mode == rtl ]]; then
        negative DATA_MEM_ADDRESS "$build/invalid-address.log" "$exe" +INVALID_ADDRESS
      fi
    fi
    echo "DATA_MEM_VALIDATION_PASS mode=$mode profile=$name legacy=$legacy"
  done
done
if [[ $mode == rtl && $scalable == 0 && -z ${DATA_MEM_PROFILES:-} ]]; then
  for bad in 0 1; do
    build="$root/invalid-param-$bad";mkdir -p "$build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal \
      --top-module tb_data_mem_invalid --Mdir "$build/obj" -GBAD_CASE="$bad" \
      rtl/mem/cgra_data_mem.sv tests/current/tb_data_mem_invalid.sv >"$build/compile.log" 2>&1 \
      || { tail -n 45 "$build/compile.log"; exit 1; }
    negative 'DATA_MEM_PARAM\|DATA_MEM_LEGACY_DOMAIN' "$build/run.log" "$build/obj/Vtb_data_mem_invalid${EXEEXT}"
    echo "DATA_MEM_INVALID_PARAM_DETECTED case=$bad"
  done
fi
