#!/usr/bin/env bash
# Exercise native and frozen PHI semantics on the actual synthesized module.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/post-synth/phi
mkdir -p "$root"
"$SV2V" -Irtl/common rtl/fu/scalar/scalar_phi.sv --top=scalar_phi \
  --write="$root/phi.v" >"$root/sv2v.log" 2>&1
for width in 32 64; do
  build="$root/$width"
  mkdir -p "$build"
  "$YOSYS" -Q -T -p "read_verilog -defer $root/phi.v; chparam -set DATA_W $width scalar_phi; hierarchy -check -top scalar_phi; proc; opt_clean; check -assert; synth -top scalar_phi -flatten -noabc; check -assert; rename scalar_phi scalar_phi_netlist; write_verilog -noattr $build/netlist.v" >"$build/yosys.log" 2>&1
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_phi \
    --Mdir "$build/obj" -Wno-fatal -Irtl/common +define+NATIVE_PHI_POST_SYNTH \
    -GDATA_W="$width" "$build/netlist.v" tests/current/tb_native_phi.sv \
    >"$build/compile.log" 2>&1 || { tail -n 25 "$build/compile.log"; exit 1; }
  "$build/obj/Vtb_native_phi${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
  grep NATIVE_PHI_PASS "$build/run.log"
  echo "NATIVE_PHI_POST_SYNTH_PASS width=$width"
done
