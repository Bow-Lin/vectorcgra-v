#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
for variant in 0 1 2;do
  ports=4;if [[ $variant == 2 ]];then ports=8;fi
  for legacy in 0 1;do
    build=build/current/vector-arithmetic/pe/variant$variant-legacy$legacy
    mkdir -p "$build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common -f filelists/native.f \
      --top-module tb_vector_arithmetic_pe --Mdir "$build/obj" \
      -GVARIANT="$variant" -GTILE_PORTS="$ports" -GLEGACY_PYTHON="$legacy" \
      tests/current/tb_vector_arithmetic_pe.sv >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log";exit 1; }
    exe="$build/obj/Vtb_vector_arithmetic_pe${EXEEXT}"
    "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep VECTOR_ARITHMETIC_PE_PASS "$build/run.log"
    set +e
    "$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
    result=$?
    set -e
    [[ $result != 0 ]] && grep -q VECTOR_ARITHMETIC_PE_RESULT "$build/negative.log"
  done
done
