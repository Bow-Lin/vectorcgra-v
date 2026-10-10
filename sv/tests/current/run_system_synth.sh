#!/usr/bin/env bash
# Synthesize whole multi-CGRA fabrics and run the public host program on emitted gates.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
if [[ $# == 0 ]]; then set -- mesh ring; fi
root=build/current/system-acceptance/synth
mkdir -p "$root"
: "${YOSYS_SIMCELLS:=$(dirname "$(command -v "$YOSYS")")/../share/yosys/simcells.v}"
[[ -f "$YOSYS_SIMCELLS" ]] || { echo 'Set YOSYS_SIMCELLS to the installed Yosys simcells.v';exit 1; }
mapfile -t files < <(grep -vE '^\+|^$' filelists/native.f)
"$SV2V" -DSYNTHESIS -Irtl/common -Irtl/vendor/hardfloat -Irtl/fu/combo/vendor "${files[@]}" \
  --top=cgra_multi --write="$root/converted.v" >"$root/sv2v.log" 2>&1
negative() {
  local marker=$1 log=$2; shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
for profile in "$@"; do
  rows=2; topology=0
  case "$profile" in mesh) ;; ring) rows=1;topology=1;; *) exit 2;; esac
  build="$root/$profile";mkdir -p "$build"
  cp "$YOSYS_SIMCELLS" "$build/simcells.v"
  args=(-GMULTI_COLS=2 -GMULTI_ROWS="$rows" -GTOPOLOGY="$topology" -GCTRL_DEPTH=2 -GREG_DEPTH=2 -GNUM_CTRL=2 -GTOTAL_STEPS=2)
  printf '%s\n' "${args[@]}" >"$build/verilator.args"
  { printf '%s\n' "${files[@]}";printf '%s\n' tests/current/tb_native_multi.sv; } | xargs sha256sum >"$build/compiled_sources.sha256"
  sha256sum rtl/common/*.svh >>"$build/compiled_sources.sha256"
  cat >"$build/synthesis.ys" <<EOS
read_verilog -defer $root/converted.v
chparam -set MULTI_COLS 2 -set MULTI_ROWS $rows -set TOPOLOGY $topology -set CTRL_DEPTH 2 -set REG_DEPTH 2 -set NUM_CTRL 2 -set TOTAL_STEPS 2 cgra_multi
hierarchy -check -top cgra_multi
proc
opt
check -assert
synth -top cgra_multi -flatten -noabc
splitnets
opt_clean
check -assert
scc -expect 0
rename cgra_multi cgra_multi_netlist
rename -hide
write_verilog -noattr -noexpr $build/netlist.v
stat
EOS
  "$YOSYS" -Q -T -s "$build/synthesis.ys" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
  "$YOSYS" -Q -T -p "read_verilog -icells $build/netlist.v; hierarchy -check -top cgra_multi_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/scc.log" 2>&1 || { tail -n 40 "$build/scc.log";exit 1; }
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 --output-split 10000 --output-split-cfuncs 2000 \
    -Wno-fatal -Irtl/common --top-module tb_native_multi --Mdir "$build/obj" \
    +define+NATIVE_MULTI_POST_SYNTH "${args[@]}" "$build/simcells.v" "$build/netlist.v" \
    tests/current/tb_native_multi.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_native_multi${EXEEXT}"
  "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep NATIVE_MULTI_PASS "$build/run.log"
  negative 'Independent result/owner failure' "$build/negative.log" "$exe" +NEGATIVE
  negative 'TIMEOUT multi-CGRA' "$build/timeout-negative.log" "$exe" +STALL_FOREVER
  echo "CURRENT_SYSTEM_SYNTH_PASS profile=$profile"
done
