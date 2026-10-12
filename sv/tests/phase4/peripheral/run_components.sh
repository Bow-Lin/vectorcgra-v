#!/usr/bin/env bash
# SV-only. Frozen original Python-generated HDL is test-only input.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
for kind in ${*:-dma dma-small dma-python dma-small-python im2col im2col-wide}; do
  reference_kind="${kind%-python}"
  top="tb_${reference_kind//-/_}"
  out="build/phase4/peripheral/$kind"
  mkdir -p "$out"
  options=();run_options=()
  if [[ "$kind" == *-python ]];then
    options=(-GHDL_MODE=0)
    if [[ "${MIGRATION_STIMULUS:-0}" == 1 ]];then run_options=(+GENERATE_STIMULUS "+TRACE=$out/stimulus.hex");fi
  fi
  case "$reference_kind" in
    dma) gold=Phase4Dma;native=cgra_dma_engine;marker=DMA_PASS;;
    dma-small) gold=Phase4DmaSmall;native=cgra_dma_engine;marker=DMA_PASS;;
    im2col) gold=Phase4Im2Col;native=cgra_im2col_engine;marker=IM2COL_PASS;;
    im2col-wide) gold=Phase4Im2ColWide;native=cgra_im2col_engine;marker=IM2COL_PASS;;
    *)echo "Unknown case $kind" >&2;exit 2;;
  esac
  files=(rtl/mem/cgra_data_mem.sv "rtl/peripheral/$native.sv" "reference/phase4/peripheral/$reference_kind/$gold.v" "tests/phase4/peripheral/$top.sv")
  "$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" \
    --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
    -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common "${options[@]}" "${files[@]}" > "$out/verilate.log" 2>&1
  make -C "$out" -f "V${top}.mk" -j "$JOBS" "CXX=$CXX" \
    "LINK=env -u LINK $CXX" LDLIBS=-pthread > "$out/compile.log" 2>&1
  "$out/native_test${EXEEXT}" +verilator+seed+31415926 "${run_options[@]}" > "$out/run.log" 2>&1
  grep -q "$marker" "$out/run.log";cat "$out/run.log"
  if [[ "${MIGRATION_STIMULUS:-0}" == 1 ]];then continue;fi
  set +e
  "$out/native_test${EXEEXT}" +verilator+seed+31415926 +EXPECT_FAILURE > "$out/negative.log" 2>&1
  status=$?
  set -e
  if [[ $status -eq 0 ]] || ! grep -q "$reference_kind mismatch cycle=20" "$out/negative.log";then
    echo "Negative control did not reach deliberately corrupted bit: $kind" >&2;exit 1
  fi
  sha256sum "${files[@]}" rtl/common/cgra_profile{,_defs}.svh \
    "$out/"{verilate,compile,run,negative}.log > "$out/SHA256SUMS"
done
