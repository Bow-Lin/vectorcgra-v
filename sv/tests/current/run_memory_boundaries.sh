#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) echo 'usage: run_memory_boundaries.sh [rtl|synth]';exit 2;;esac
root=build/current/memory-boundaries/controller-$mode;mkdir -p "$root"
sources=(rtl/common/cgra_round_robin.sv rtl/common/cgra_queue.sv rtl/common/cgra_channel.sv rtl/noc/cgra_switch.sv rtl/noc/cgra_xbar.sv rtl/mem/cgra_data_bank.sv rtl/mem/cgra_data_memory.sv)
if [[ $mode == synth ]];then
  "$SV2V" -DSYNTHESIS -Irtl/common "${sources[@]}" --top=cgra_data_memory --write="$root/converted.v" >"$root/sv2v.log" 2>&1
fi
for config in '3 1 32 1 0' '1 3 32 0 0' '3 1 64 0 0' '1 3 64 1 0' '2 2 32 1 1' '2 2 32 0 1' '2 2 64 0 1';do
  read -r reads writes width combinational dma <<< "$config"
  build=$root/r$reads-w$writes-d$width-c$combinational-dma$dma;mkdir -p "$build"
  compile_sources=("${sources[@]}");defines=()
  if [[ $mode == synth ]];then
    "$YOSYS" -Q -T -p "read_verilog -defer $root/converted.v; chparam -set MEM_PORTS $reads -set MEM_WRITE_PORTS $writes -set MAX_MEM_PORTS $reads -set DATA_W $width -set MEM_COMBINATIONAL $combinational -set HAS_DMA $dma -set MULTI_COLS 2 -set MULTI_ROWS 2 cgra_data_memory; hierarchy -check -top cgra_data_memory; proc; opt; check -assert; synth -top cgra_data_memory -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename cgra_data_memory memory_boundaries_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top memory_boundaries_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
    compile_sources=("$build/netlist.v");defines=(+define+MEMORY_BOUNDARIES_POST_SYNTH)
  fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_memory_boundaries --Mdir "$build/obj" \
    -GMEM_PORTS="$reads" -GMEM_WRITE_PORTS="$writes" -GMAX_MEM_PORTS="$reads" -GDATA_W="$width" \
    -GMEM_COMBINATIONAL="$combinational" -GHAS_DMA="$dma" -GMULTI_COLS=2 -GMULTI_ROWS=2 +incdir+rtl/common \
    "${defines[@]}" "${compile_sources[@]}" tests/current/tb_memory_boundaries.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_memory_boundaries${EXEEXT}"
  "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep MEMORY_BOUNDARIES_PASS "$build/run.log"
  set +e
  "$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q MEM_WORD_MISMATCH "$build/negative.log" || { cat "$build/negative.log";exit 1; }
  if [[ $dma == 1 ]];then
    set +e
    "$exe" +INVALID_MASK >"$build/invalid-mask.log" 2>&1
    status=$?
    set -e
    if [[ $mode == rtl ]];then
      [[ $status != 0 ]] && grep -q MEM_DMA_MASK "$build/invalid-mask.log" || { cat "$build/invalid-mask.log";exit 1; }
    else
      [[ $status == 0 ]] && grep -q MEM_DMA_MASK_REJECT_PASS "$build/invalid-mask.log" || { cat "$build/invalid-mask.log";exit 1; }
    fi
  fi
done
echo "MEMORY_BOUNDARIES_VALIDATION_PASS mode=$mode"
