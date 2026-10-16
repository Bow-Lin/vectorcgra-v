#!/usr/bin/env bash
# Run the same public-interface program against the actual synthesized PE.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/post-synth
mkdir -p "$root"
mapfile -t files < <(grep -vE '^\+|^$' filelists/native.f)
"$SV2V" -Irtl/common -Irtl/vendor/hardfloat \
  "${files[@]}" --top=cgra_pe --write="$root/pe.v" >"$root/sv2v.log" 2>&1
for profile in "${@:-base}"; do
  variant=0; ports=4; width=32; ctrl=8; regs=16
  case "$profile" in
    base) ;;
    base64) width=64; ctrl=16; regs=8 ;;
    context) variant=1 ;;
    context8) variant=1; ports=8 ;;
    streaming) variant=2; ports=8 ;;
    *) echo "Unknown PE synthesis profile: $profile" >&2; exit 2 ;;
  esac
  build="$root/$profile"
  mkdir -p "$build"
  cat >"$build/synth.ys" <<EOF
read_verilog -defer $root/pe.v
chparam -set VARIANT $variant -set TILE_PORTS $ports -set DATA_W $width -set CTRL_DEPTH $ctrl -set REG_DEPTH $regs -set NUM_CTRL 2 -set TOTAL_STEPS 4 -set FU_COUNT 5 -set FU_KINDS 40'h03000b070a cgra_pe
hierarchy -check -top cgra_pe
proc
opt_clean
check -assert
synth -top cgra_pe -flatten -noabc
check -assert
rename cgra_pe cgra_pe_netlist
write_verilog -noattr $build/netlist.v
stat
EOF
  "$YOSYS" -Q -T -s "$build/synth.ys" >"$build/yosys.log" 2>&1 || { tail -n 30 "$build/yosys.log"; exit 1; }
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_current_pe \
    --Mdir "$build/obj" -Wno-fatal -Irtl/common +define+CURRENT_POST_SYNTH \
    -GVARIANT="$variant" -GTILE_PORTS="$ports" -GDATA_W="$width" \
    -GCTRL_DEPTH="$ctrl" -GREG_DEPTH="$regs" -GNUM_CTRL=2 -GTOTAL_STEPS=4 \
    "$build/netlist.v" tests/current/current_pe_synth_adapter.sv tests/current/tb_current_pe.sv \
    >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log"; exit 1; }
  "$build/obj/Vtb_current_pe${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
  cat "$build/run.log"
  echo "CURRENT_PE_POST_SYNTH_PASS profile=$profile"
done
