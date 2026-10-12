#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
for kind in im2col dma128 dma256;do
  args=()
  if [[ $kind == im2col ]];then top=tb_im2col_boundary_system;marker=IM2COL_BOUNDARY_SYSTEM_PASS;negative_arg=EXPECT_FAILURE;negative_marker='Integrated load';
  else top=tb_current_dma_system;args=(-GDRAM_DATA_W="${kind#dma}");marker=CURRENT_DMA_SYSTEM_PASS;negative_arg=EXPECT_FAILURE;negative_marker='DMA';fi
  build=build/current/memory-boundaries/$kind-system;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module "$top" --Mdir "$build/obj" \
    -f filelists/native.f "tests/current/$top.sv" "${args[@]}" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe="$build/obj/V$top${EXEEXT}"
  "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep "$marker" "$build/run.log"
  if [[ $kind == im2col ]];then
    set +e
    "$exe" "+$negative_arg" >"$build/negative.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q "$negative_marker" "$build/negative.log" || { cat "$build/negative.log";exit 1; }
    legacy_build=build/current/memory-boundaries/im2col-system-legacy;mkdir -p "$legacy_build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module "$top" --Mdir "$legacy_build/obj" \
      -GLEGACY_SYSTEM=1 -f filelists/native.f "tests/current/$top.sv" >"$legacy_build/compile.log" 2>&1 || { tail -n 40 "$legacy_build/compile.log";exit 1; }
    set +e
    "$legacy_build/obj/V$top${EXEEXT}" >"$legacy_build/run.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q 'Integrated load 0' "$legacy_build/run.log" || { cat "$legacy_build/run.log";exit 1; }
  fi
done
echo MEMORY_BOUNDARY_SYSTEMS_PASS
