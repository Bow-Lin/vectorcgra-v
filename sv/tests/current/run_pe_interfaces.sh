#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
mode=${1:-rtl}
root=build/current/pe-interfaces
mkdir -p "$root"
if [[ $mode == synth ]];then
  mapfile -t files < <(grep -vE '^\+|^$' filelists/native.f)
  "$SV2V" -Irtl/common -Irtl/vendor/hardfloat "${files[@]}" \
    --top=cgra_pe --write="$root/pe.v" >"$root/sv2v.log" 2>&1
elif [[ $mode != rtl ]];then echo 'Usage: run_pe_interfaces.sh rtl|synth';exit 2;fi
profiles=(base base64 base8 context context8 streaming stream-load)
if [[ $mode == synth ]];then profiles=(base context8 stream-load mem-base-last mem-context64);fi
for profile in "${profiles[@]}";do
  [[ -z ${PE_PROFILE_FILTER:-} || $profile =~ $PE_PROFILE_FILTER ]] || continue
  variant=0;ports=4;width=32;ctrl=8;regs=16;top=tb_current_pe
  case $profile in
    base64) width=64;ctrl=16;regs=8;;
    base8) ports=8;;
    context) variant=1;;
    context8) variant=1;ports=8;;
    streaming) variant=2;ports=8;;
    stream-load) top=tb_current_stream_load;variant=2;ports=8;;
    mem-base-last) top=tb_pe_memory;ports=8;;
    mem-context64) top=tb_pe_memory;variant=1;ports=8;width=64;ctrl=16;regs=8;;
  esac
  build=$root/$mode/$profile;mkdir -p "$build"
  args=(-GVARIANT="$variant" -GTILE_PORTS="$ports" -GDATA_W="$width" -GCTRL_DEPTH="$ctrl" -GREG_DEPTH="$regs" -GNUM_CTRL=2 -GTOTAL_STEPS=4)
  count=5;kinds=03000b070a;steps=4;numctrl=2
  if [[ $profile == stream-load ]];then args=();count=4;kinds=03200100;steps=2;fi
  if [[ $profile == mem-* ]];then
    count=3;kinds=020003;steps=1;numctrl=1
    args=(-GVARIANT="$variant" -GTILE_PORTS="$ports" -GDATA_W="$width" -GCTRL_DEPTH="$ctrl" -GREG_DEPTH="$regs" -GNUM_CTRL=1 -GTOTAL_STEPS=1 -GMEM_SLOT=2)
  fi
  sources=(-f filelists/native.f)
  if [[ $mode == synth ]];then
    cat >"$build/synth.ys" <<EOF
read_verilog -defer $root/pe.v
chparam -set VARIANT $variant -set TILE_PORTS $ports -set DATA_W $width -set CTRL_DEPTH $ctrl -set REG_DEPTH $regs -set NUM_CTRL $numctrl -set TOTAL_STEPS $steps -set FU_COUNT $count -set FU_KINDS $((count*8))'h$kinds cgra_pe
hierarchy -check -top cgra_pe
proc
opt_clean
check -assert
synth -top cgra_pe -flatten -noabc
splitnets
opt_clean
check -assert
scc -expect 0
rename cgra_pe cgra_pe_netlist
write_verilog -noattr $build/netlist.v
stat
EOF
    "$YOSYS" -Q -T -s "$build/synth.ys" >"$build/yosys.log" 2>&1 || { tail -n 30 "$build/yosys.log";exit 1; }
    "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top cgra_pe_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/reread.log" 2>&1 || { tail -n 30 "$build/reread.log";exit 1; }
    sources=(+define+CURRENT_POST_SYNTH "$build/netlist.v" tests/current/current_pe_synth_adapter.sv)
  fi
  compile_jobs=$JOBS
  # Bound parallel compilation as well as generated C++ function size.
  if [[ $mode == synth && $profile == mem-context64 ]];then compile_jobs=1;fi
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$compile_jobs" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 --output-split 10000 --output-split-cfuncs 2000 -Wno-fatal -Irtl/common --top-module "$top" --Mdir "$build/obj" \
    "${sources[@]}" "tests/current/$top.sv" "${args[@]}" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  "$build/obj/V$top${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep -E 'CURRENT_(PE_PASS|STREAM_LOAD_PASS)|PE_MEMORY_PASS' "$build/run.log"
  if [[ $profile == mem-* ]];then
    set +e
    "$build/obj/V$top${EXEEXT}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q PE_MEMORY_RESULT "$build/negative.log" || { cat "$build/negative.log";exit 1; }
  fi
done
