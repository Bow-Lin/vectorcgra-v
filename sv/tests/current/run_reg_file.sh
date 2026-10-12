#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
case "$mode" in rtl|synth) ;; *) exit 2;; esac
root="build/current/reg-file/$mode"; mkdir -p "$root"
if [[ $mode == synth ]]; then
  "$SV2V" -DSYNTHESIS rtl/common/cgra_register_file.sv rtl/common/cgra_reg_file.sv --top=cgra_reg_file --write="$root/design.v"
fi
for profile in '32 1' '67 3' '19 16'; do
  read -r bits depth <<<"$profile"
  build="$root/b${bits}_d${depth}"; mkdir -p "$build"
  sources=(rtl/common/cgra_register_file.sv rtl/common/cgra_reg_file.sv); defines=()
  if [[ $mode == synth ]]; then
    "$YOSYS" -Q -T -p "read_verilog -defer $root/design.v; chparam -set DATA_BITS $bits -set DEPTH $depth cgra_reg_file; hierarchy -check -top cgra_reg_file; proc; opt_clean; check -assert; synth -top cgra_reg_file -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename cgra_reg_file reg_file_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log"; exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top reg_file_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
    sources=("$build/netlist.v"); defines=(+define+REG_FILE_POST_SYNTH)
  fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 -Wno-fatal --top-module tb_reg_file --Mdir "$build/obj" \
    -GDATA_BITS="$bits" -GDEPTH="$depth" "${defines[@]}" "${sources[@]}" tests/current/tb_reg_file.sv \
    >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log"; exit 1; }
  "$build/obj/Vtb_reg_file${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
  grep REG_FILE_PASS "$build/run.log"
  set +e
  "$build/obj/Vtb_reg_file${EXEEXT}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  result=$?
  set -e
  [[ $result != 0 ]] && grep -q REG_FILE_CHECK "$build/negative.log"
  echo "REG_FILE_VALIDATION_PASS mode=$mode bits=$bits depth=$depth"
done
