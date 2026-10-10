#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
files=(rtl/common/cgra_register_file.sv rtl/common/cgra_queue.sv rtl/common/cgra_channel.sv
  rtl/mem/register_bank.sv rtl/mem/register_cluster.sv rtl/tile/tile_link_or.sv
  rtl/fu/tile_adder.sv rtl/fu/tile_multiplier.sv rtl/fu/tile_memory_fu.sv rtl/fu/tile_nah.sv
  rtl/fu/scalar/scalar_phi.sv rtl/fu/streaming/tile_streaming_memory_fu.sv
  rtl/fu/tile_flexible_fu_configurable.sv rtl/tile/variants/*.sv)
for kind in "${@:-context streaming}"; do
  # An explicit argument selects one kind; the default is expanded below.
  for selected in $kind; do
    top="tb_tile_$selected"; out="build/phase3/tile_variants/tile_$selected"
    mkdir -p "$out"
    "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" \
      --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
      -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common "${files[@]}" \
      "tests/phase3/tile_variants/$top.sv" > "$out/verilate.log" 2>&1
    make -C "$out" -f "V${top}.mk" -j "$JOBS" "CXX=$CXX" \
      "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$out/compile.log" 2>&1
    "$out/native_test${EXEEXT}" +verilator+seed+31415926 > "$out/run.log" 2>&1
    grep -q "TILE_${selected^^}_PASS" "$out/run.log"
    cat "$out/run.log"
    set +e
    "$out/native_test${EXEEXT}" +verilator+seed+31415926 +EXPECT_FAILURE > "$out/negative.log" 2>&1
    status=$?
    set -e
    if [[ $status -eq 0 ]] || ! grep -q 'tile replay mismatch cycle=20' "$out/negative.log"; then
      echo "Tile negative control did not fail at the deliberately corrupted expected bit" >&2
      exit 1
    fi
    sha256sum "${files[@]}" rtl/common/cgra_profile{,_defs}.svh rtl/common/cgra_fu_catalog.svh \
      "tests/phase3/tile_variants/$top.sv" "$out/"{verilate,compile,run,negative}.log > "$out/SHA256SUMS"
  done
done
