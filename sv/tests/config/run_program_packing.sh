#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/program-tools/packing
for name in system context64 streaming ring heterogeneous;do
  build=$root/$name;mkdir -p "$build"
  rm -rf "$build/generated"
  "${PYTHON:-python3}" -I -S tools/cgra_config.py "examples/config/$name.json" --output "$build/generated" >"$build/config.log" 2>&1
  "${PYTHON:-python3}" -I -S tests/config/prepare_program_packing.py "examples/config/$name.json" "$build" >"$build/vectors.log" 2>&1
  mapfile -t params < "$build/params.txt"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_program_packing --Mdir "$build/obj" \
    -Wno-fatal -Irtl/common -I"$build/generated" "${params[@]}" "$build/tb_program_packing.sv" \
    >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  exe="$build/obj/Vtb_program_packing${EXEEXT}"
  "$exe" "+VECTORS=$build/vectors.txt" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep PROGRAM_PACKING_PASS "$build/run.log"
  set +e
  "$exe" "+VECTORS=$build/vectors.txt" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q PROGRAM_PACKING_MISMATCH "$build/negative.log" || { cat "$build/negative.log";exit 1; }
done
