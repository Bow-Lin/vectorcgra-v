#!/usr/bin/env bash
# Native acceptance of the frozen current Python contract; no PyMTL at runtime.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
build_one() {
  local top="$1"; shift
  local build="build/current/${CASE_LABEL:-$top}"
  mkdir -p "$build"
  : >"$build/run.log"
  if ! env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" \
    --top-module "$top" --Mdir "$build" -Wno-fatal -Irtl/common \
    -f filelists/native.f "tests/current/$top.sv" "$@" >"$build/compile.log" 2>&1; then
    tail -n 60 "$build/compile.log"; return 1
  fi
  "$build/V$top${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log"; return 1; }
  cat "$build/run.log"
}
build_one tb_current_fu
set +e
"build/current/tb_current_fu/Vtb_current_fu${EXEEXT}" +NEGATIVE >build/current/tb_current_fu/negative.log 2>&1
status=$?
set -e
test "$status" -ne 0
grep -q 'CURRENT_FU_MISMATCH unit=Grant cycle=1' build/current/tb_current_fu/negative.log
echo CURRENT_FU_NEGATIVE_PASS
build_one tb_current_state
# Native functionality beyond the frozen Python comparator/logic coverage.
for width in 32 64; do
  CASE_LABEL="unsigned$width" build_one tb_unsigned_comp -GDATA_W="$width"
  CASE_LABEL="const_logic$width" build_one tb_const_logic -GDATA_W="$width"
done
for variant in 0 1 2; do
  ports=4; if [[ "$variant" == 2 ]]; then ports=8; fi
  CASE_LABEL="pe$variant" build_one tb_current_pe -GVARIANT="$variant" -GTILE_PORTS="$ports" -GNUM_CTRL=2 -GTOTAL_STEPS=4
done
CASE_LABEL=pe64 build_one tb_current_pe -GDATA_W=64 -GCTRL_DEPTH=16 -GREG_DEPTH=8 -GNUM_CTRL=2 -GTOTAL_STEPS=4
CASE_LABEL=pe_context8 build_one tb_current_pe -GVARIANT=1 -GTILE_PORTS=8 -GNUM_CTRL=2 -GTOTAL_STEPS=4
build_one tb_current_stream_load
for width in 32 96 128 256; do
  CASE_LABEL="dma$width" build_one tb_current_dma -GDRAM_DATA_W="$width"
done
# Full host-command -> SPM -> CPU/DRAM round trips at both deployed widths.
for width in 128 256; do
  CASE_LABEL="dma_system$width" build_one tb_current_dma_system -GDRAM_DATA_W="$width"
done
if CASE_LABEL=invalid_variant build_one tb_current_pe -GVARIANT=3 -GTILE_PORTS=8 \
    -GNUM_CTRL=2 -GTOTAL_STEPS=4 >build/current/invalid-variant.log 2>&1; then
  echo 'Invalid PE variant unexpectedly ran' >&2; exit 1
fi
grep -q 'cgra_pe VARIANT must be' build/current/invalid_variant/run.log
if CASE_LABEL=invalid_ctrl_count build_one tb_current_pe -GNUM_CTRL=9 \
    >build/current/invalid-ctrl-count.log 2>&1; then
  echo 'Invalid PE control count unexpectedly ran' >&2; exit 1
fi
grep -q 'cgra_pe requires storage depths' build/current/invalid_ctrl_count/run.log
echo CURRENT_PE_PARAMETER_NEGATIVE_PASS
echo CURRENT_REGRESSION_PASS
find rtl tests/current reference/current -type f -not -name '*.log' -not -path '*/__pycache__/*' -print0 | sort -z | xargs -0 sha256sum >build/current/SHA256SUMS
