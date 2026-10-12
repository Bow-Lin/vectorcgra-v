#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
compile() {
  mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -f filelists/native.f \
    --top-module tb_arithmetic_boundaries_pe --Mdir "$build/obj" \
    -GKIND="$kind" -GVARIANT="$variant" -GTILE_PORTS="$ports" -GDATA_W="$width" "$@" \
    tests/current/tb_arithmetic_boundaries_pe.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_arithmetic_boundaries_pe${EXEEXT}"
}
negative() {
  local marker=$1 log=$2
  shift 2
  set +e
  "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
matched=0
for kind in 0 1 2 3 4 5 6;do
  [[ -z ${ARITHMETIC_PE_KIND_FILTER:-} || $kind == "$ARITHMETIC_PE_KIND_FILTER" ]] || continue
  width=32;if [[ $kind == 3 || $kind == 6 ]];then width=16;fi
  for variant in 0 1 2;do
    [[ -z ${ARITHMETIC_PE_VARIANT_FILTER:-} || $variant == "$ARITHMETIC_PE_VARIANT_FILTER" ]] || continue
    matched=$((matched+1));ports=4;if [[ $variant == 2 ]];then ports=8;fi
    build=build/current/arithmetic-boundaries/pe/kind$kind-variant$variant
    compile
    "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep ARITHMETIC_PE_PASS "$build/run.log"
    negative ARITHMETIC_PE_RESULT "$build/negative.log" "$exe" +EXPECT_FAILURE
    if [[ $kind == 5 && $variant == 0 ]];then
      # The PE's output/step gating masks the standalone FU's early-ready defect.
      # Keep this as an integration compatibility probe, not a required failure.
      build=build/current/arithmetic-boundaries/pe/legacy-vector-control-probe
      compile -GLEGACY_VECTOR=1
      "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
      grep ARITHMETIC_PE_PASS "$build/run.log"
      negative ARITHMETIC_PE_RESULT "$build/negative.log" "$exe" +EXPECT_FAILURE
    fi
  done
done
[[ $matched != 0 ]] || { echo 'No arithmetic PE profile matched';exit 2; }
