#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/toolchain.sh"
cd "$(dirname "$0")/../.."
for profile in add-e8-s23 mul-e8-s23 add-e4-s11 mul-e4-s11; do
  unit="${profile%%-*}"
  if [[ "$profile" == *e8* ]]; then exp=8; sig=23; width=32; else exp=4; sig=11; width=16; fi
  if [[ "$unit" == add ]]; then multiply=0; title=Add; else multiply=1; title=Mul; fi
  out="build/native/fp-compat/$profile"
  mkdir -p "$out"
  # Old exported diagnostic paths contain Windows drive letters, which GNU
  # make parses as rule separators. Strip only nonfunctional line directives.
  sed '/^`line /d' "reference/phase3/float/$profile/gold_portable.v" > "$out/gold.v"
  "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_phase3_float \
    --Mdir "$out" -o float_test -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
    "-GDATA_W=$width" "-GFP_EXP_W=$exp" "-GFP_SIG_W=$sig" "-GMULTIPLY=$multiply" \
    "+define+FP_DUT=tile_fp_$unit" "+define+FP_GOLD=GoldFp${title}E${exp}S${sig}_Phase3Fp${title}E${exp}S${sig}" \
    -f filelists/phase3_float.f "$out/gold.v" tests/current/tb_fp_compat.sv \
    > "$out/verilate.log" 2>&1 || { tail -n 50 "$out/verilate.log"; exit 1; }
  make -C "$out" -f Vtb_phase3_float.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
    > "$out/compile.log" 2>&1 || { tail -n 30 "$out/compile.log"; exit 1; }
  "$out/float_test${EXEEXT}" > "$out/run.log" 2>&1 || { cat "$out/run.log"; exit 1; }
  grep -q 'NATIVE_FP_COMPAT_PASS' "$out/run.log"
  cat "$out/run.log"
done
set +e
build/native/fp-compat/add-e8-s23/float_test${EXEEXT} +EXPECT_FAILURE > build/native/fp-compat/add-e8-s23/negative.log 2>&1
result=$?
set -e
test "$result" -ne 0
grep -q 'FP arithmetic' build/native/fp-compat/add-e8-s23/negative.log
echo 'NATIVE_FP_COMPAT_NEGATIVE_PASS: incorrect independent expectation was rejected'
