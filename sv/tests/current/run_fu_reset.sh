#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
for profile in 'catalog32 32 30 240\x27h201d1c1a191817161514131211100f0e0d0c0b0a09080706050403020100 0' 'mac16 16 2 16\x27h031b 0' 'legacy 32 2 16\x27h0300 1';do
  read -r name width count kinds legacy <<<"$profile"
  kinds=$(printf '%b' "$kinds")
  build=build/current/arithmetic-boundaries/reset/$name;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -f filelists/native.f \
    --top-module tb_fu_reset --Mdir "$build/obj" -GDATA_W="$width" -GFU_COUNT="$count" -GFU_KINDS="$kinds" \
    -GARITH_LEGACY_PYTHON="$legacy" tests/current/tb_fu_reset.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_fu_reset${EXEEXT}"
  if [[ $legacy == 0 ]];then
    "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; };grep FU_RESET_PASS "$build/run.log"
  else
    set +e
    "$exe" >"$build/run.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q 'DEFECT_RESET' "$build/run.log" || { cat "$build/run.log";exit 1; }
    echo FU_RESET_LEGACY_DEFECT_DETECTED
  fi
done
