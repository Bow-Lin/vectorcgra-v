#!/usr/bin/env bash
# Native SV-only regressions. The frozen phase-one hierarchy is test-only gold.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/.."
seed=31415926
files=(rtl/common/cgra_register_file.sv rtl/common/cgra_queue.sv
  rtl/common/cgra_channel.sv rtl/mem/const_queue.sv rtl/mem/ctrl_mem.sv
  rtl/mem/register_bank.sv rtl/mem/register_cluster.sv
  rtl/fu/tile_adder.sv rtl/fu/tile_multiplier.sv rtl/fu/tile_memory_fu.sv
  rtl/fu/tile_nah.sv rtl/fu/tile_flexible_fu.sv
  rtl/tile/tile_static_crossbar.sv rtl/tile/tile_link_or.sv rtl/tile/tile_core.sv)
mkdir -p build/native_tile
for kind in tile units; do
  if [[ "$kind" == tile ]]; then
    top=tb_tile_compare
    bench=tests/tb_native_tile.sv
    marker=TILE_COMPARE_PASS
  else
    top=tb_tile_units
    bench=tests/tb_native_tile_units.sv
    marker=TILE_UNITS_PASS
  fi
  out="build/native_tile/$kind"
  mkdir -p "$out"
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang \
    --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
    -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common "${files[@]}" \
    rtl/fixed/cgra_2x2_core.sv "$bench" > "$out/verilate.log" 2>&1
  make -C "$out" -f "V${top}.mk" -j 2 CXX=clang++ \
    'LINK=env -u LINK clang++' LDLIBS=-pthread > "$out/compile.log" 2>&1
  "$out/native_test.exe" "+verilator+seed+$seed" > "$out/run.log" 2>&1
  grep -q "$marker" "$out/run.log"
  cat "$out/run.log"
done
sha256sum "${files[@]}" rtl/common/cgra_profile_defs.svh rtl/common/cgra_profile.svh \
  rtl/fixed/cgra_2x2_core.sv tests/tb_native_tile.sv tests/tb_native_tile_units.sv \
  tests/run_native_tile.sh build/native_tile/{tile,units}/{verilate,compile,run}.log \
  > build/native_tile/SHA256SUMS
