#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build=build/current/memory-boundaries/im2col-system-synth;mkdir -p "$build"
# Keep synthesis primitives explicit: reimport with -icells avoids reconstructing
# tens of thousands of flip-flops as independent behavioral processes.
: "${YOSYS_SIMCELLS:=$(dirname "$(command -v "$YOSYS")")/../share/yosys/simcells.v}"
[[ -f "$YOSYS_SIMCELLS" ]] || { echo 'Set YOSYS_SIMCELLS to the installed Yosys simcells.v';exit 1; }
cp "$YOSYS_SIMCELLS" "$build/simcells.v"
mapfile -t files < <(grep -vE '^\+|^$' filelists/native.f)
"$SV2V" -DSYNTHESIS -Irtl/common -Irtl/vendor/hardfloat -Irtl/fu/combo/vendor "${files[@]}" \
  --top=cgra_integrated_im2col --write="$build/converted.v" >"$build/sv2v.log" 2>&1
# Match the complete public-IO configuration in tb_im2col_boundary_system.
cat >"$build/synthesis.ys" <<EOF
read_verilog -defer $build/converted.v
chparam -set NUM_BANKS 4 -set GLOBAL_ADDR_W 6 -set NUM_CTRL 1 -set TOTAL_STEPS 1 -set HAS_IM2COL 1 -set PRELOAD_IMAGE 2048'h19b0000018a0000017900000168000001570000014600000135000001240000011300000102000000f1000000e0000000cf000000be000000ad0000009c0000008b0000007a00000069000000580000004700000036000000250000001400000003 cgra_integrated_im2col
hierarchy -check -top cgra_integrated_im2col
proc
opt
check -assert
synth -top cgra_integrated_im2col -flatten -noabc
splitnets
opt_clean
check -assert
scc -expect 0
rename cgra_integrated_im2col im2col_system_netlist
rename -hide
write_verilog -noattr -noexpr $build/netlist.v
EOF
"$YOSYS" -Q -T -s "$build/synthesis.ys" >"$build/yosys.log" 2>&1 || { tail -n 45 "$build/yosys.log";exit 1; }
"$YOSYS" -Q -T -p "read_verilog -icells $build/netlist.v; hierarchy -check -top im2col_system_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1
 env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_im2col_boundary_system --Mdir "$build/obj" \
  +define+MEMORY_SYSTEM_POST_SYNTH "$build/simcells.v" "$build/netlist.v" tests/current/tb_im2col_boundary_system.sv >"$build/compile.log" 2>&1 || { tail -n 45 "$build/compile.log";exit 1; }
exe="$build/obj/Vtb_im2col_boundary_system${EXEEXT}"
"$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
grep IM2COL_BOUNDARY_SYSTEM_PASS "$build/run.log"
set +e
"$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
status=$?
set -e
[[ $status != 0 ]] && grep -q 'Integrated load' "$build/negative.log" || { cat "$build/negative.log";exit 1; }
echo IM2COL_BOUNDARY_SYSTEM_SYNTH_PASS
