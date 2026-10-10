#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
files=(rtl/common/cgra_register_file.sv rtl/common/cgra_queue.sv rtl/common/cgra_channel.sv
  rtl/common/cgra_round_robin.sv rtl/noc/*.sv
  rtl/mem/register_bank.sv rtl/mem/register_cluster.sv rtl/mem/cgra_data_bank.sv rtl/mem/cgra_data_memory.sv
  rtl/controller/cgra_global_reduce.sv rtl/controller/cgra_controller.sv rtl/tile/tile_link_or.sv
  rtl/fu/tile_adder.sv rtl/fu/tile_multiplier.sv rtl/fu/tile_memory_fu.sv rtl/fu/tile_nah.sv
  rtl/fu/scalar/scalar_phi.sv rtl/fu/streaming/tile_streaming_memory_fu.sv
  rtl/fu/tile_flexible_fu_configurable.sv rtl/tile/variants/*.sv rtl/cgra/cgra_programmable.sv)
for kind in "${@:-context streaming}"; do
  for selected in $kind; do
    top="tb_cgra_$selected"; out="build/phase3/tile_variants/cgra_$selected"
    mkdir -p "$out"
    "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" \
      --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
      -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common "${files[@]}" \
      "tests/phase3/tile_variants/$top.sv" > "$out/verilate.log" 2>&1
    make -C "$out" -f "V${top}.mk" -j "$JOBS" "CXX=$CXX" \
      "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$out/compile.log" 2>&1
    "$out/native_test${EXEEXT}" +verilator+seed+31415926 > "$out/run.log" 2>&1
    grep -q "CGRA_${selected^^}_PASS" "$out/run.log"
    cat "$out/run.log"
    set +e
    "$out/native_test${EXEEXT}" +verilator+seed+31415926 +EXPECT_FAILURE > "$out/negative.log" 2>&1
    status=$?
    set -e
    if [[ $status -eq 0 ]] || ! grep -q 'CGRA replay mismatch cycle=20' "$out/negative.log"; then
      echo 'CGRA negative control did not reach its deliberately corrupted bit' >&2
      exit 1
    fi
    sha256sum "${files[@]}" rtl/common/cgra_profile{,_defs}.svh rtl/common/cgra_fu_catalog.svh \
      "tests/phase3/tile_variants/$top.sv" "$out/"{verilate,compile,run,negative}.log > "$out/SHA256SUMS"
  done
done
