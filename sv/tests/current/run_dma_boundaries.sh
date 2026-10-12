#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_dma_boundaries.sh [rtl|synth]';exit 2;;esac
root=build/current/memory-boundaries/dma-$mode;mkdir -p "$root"
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS rtl/peripheral/cgra_dma_engine.sv --top=cgra_dma_engine --write="$root/converted.v" >"$root/sv2v.log" 2>&1
fi
for width in 32 96 128 256;do
  for legacy in 0 1;do
    build=$root/w$width-legacy$legacy;mkdir -p "$build"
    sources=(rtl/peripheral/cgra_dma_engine.sv);defines=()
    if [[ $mode == synth ]];then
      "$YOSYS" -Q -T -p "read_verilog -defer $root/converted.v; chparam -set DRAM_DATA_W $width -set LEGACY_PYTHON $legacy cgra_dma_engine; hierarchy -check -top cgra_dma_engine; proc; opt_clean; check -assert; synth -top cgra_dma_engine -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename cgra_dma_engine dma_boundaries_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 35 "$build/yosys.log";exit 1; }
      "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top dma_boundaries_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1 || { tail -n 35 "$build/scc.log";exit 1; }
      sources=("$build/netlist.v");defines=(+define+DMA_BOUNDARIES_POST_SYNTH)
    fi
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_dma_boundaries --Mdir "$build/obj" \
      -GDRAM_DATA_W="$width" -GLEGACY_PYTHON="$legacy" "${defines[@]}" "${sources[@]}" tests/current/tb_dma_boundaries.sv \
      >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    exe="$build/obj/Vtb_dma_boundaries${EXEEXT}";args=()
    if [[ $legacy == 1 ]];then args=("+VECTORS=reference/current/memory_boundaries/dma_w$width/vectors.txt");fi
    "$exe" "${args[@]}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep 'DMA_BOUNDARIES_PASS\|DMA_REPLAY_PASS' "$build/run.log"
    negative 'DMA word write\|DMA_REPLAY_MISMATCH' "$build/negative.log" "$exe" "${args[@]}" +EXPECT_FAILURE
    if [[ $legacy == 0 ]];then
      for invalid in length opcode;do
        if [[ $mode == rtl ]];then
          negative DMA_NATIVE_COMMAND "$build/invalid-$invalid.log" "$exe" "+INVALID=$invalid"
        else
          "$exe" "+INVALID=$invalid" >"$build/invalid-$invalid.log" 2>&1 || { cat "$build/invalid-$invalid.log";exit 1; }
          grep DMA_INVALID_COMMAND_REJECT_PASS "$build/invalid-$invalid.log"
        fi
      done
    else
      negative DMA_RESET_ISOLATION "$build/reset-defect.log" "$exe"
    fi
  done
done
build=$root/invalid-spm-width;mkdir -p "$build"
if [[ $mode == rtl ]];then
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module cgra_dma_engine --Mdir "$build/obj" \
    -GSPM_DATA_W=64 rtl/peripheral/cgra_dma_engine.sv >"$build/compile.log" 2>&1
  negative DMA_NATIVE_WORD_WIDTH "$build/run.log" "$build/obj/Vcgra_dma_engine${EXEEXT}"
else
  grep -q DMA_NATIVE_WORD_WIDTH "$root/converted.v"
  negative '\$finish' "$build/run.log" "$YOSYS" -Q -T -p "read_verilog -defer $root/converted.v; chparam -set SPM_DATA_W 64 cgra_dma_engine; hierarchy -check -top cgra_dma_engine"
fi
echo "DMA_BOUNDARIES_VALIDATION_PASS mode=$mode"
