#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build_one() {
  local label=$1 top=$2
  shift 2
  local build="build/native/math/$label"
  mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module "$top" --Mdir "$build" \
    -Wno-fatal -Irtl/common -f filelists/native.f "$@" "tests/current/$top.sv" >"$build/compile.log" 2>&1 || { tail -n 25 "$build/compile.log"; exit 1; }
  "$build/V$top${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; exit 1; }
  grep -q 'NATIVE_.*_PASS' "$build/run.log"
  cat "$build/run.log"
  if [[ "$top" == tb_native_fp || "$top" == tb_native_phi ]]; then
    set +e
    "$build/V$top${EXEEXT}" +EXPECT_FAILURE >"$build/negative.log" 2>&1
    local result=$?
    set -e
    [[ $result != 0 ]]
    if [[ "$top" == tb_native_fp ]]; then
      grep -q 'FP arithmetic' "$build/negative.log"
      echo "NATIVE_IEEE_FP_NEGATIVE_PASS profile=$label"
    else
      grep -q PHI_RESULT "$build/negative.log"
      echo "NATIVE_PHI_NEGATIVE_PASS profile=$label"
    fi
  fi
}
for width in 32 64; do build_one "sub$width" tb_sub_const -GDATA_W="$width"; done
for width in 32 64; do build_one "phi$width" tb_native_phi -GDATA_W="$width"; done
for profile in '16 5 10' '32 8 23' '64 11 52'; do
  read -r width exp frac <<<"$profile"
  for multiply in 0 1; do
    build_one "fp${width}_$multiply" tb_native_fp -GDATA_W="$width" -GEXP="$exp" -GFRAC="$frac" -GMULTIPLY="$multiply"
  done
done
