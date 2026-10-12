#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=${PE_BUILD_ROOT:-build/current/pe-interfaces/attachment}
for profile in mem-base mem-base-last mem-context mem-context64 fp-native fp-legacy;do
  [[ -z ${PE_ATTACHMENT_FILTER:-} || $profile == "$PE_ATTACHMENT_FILTER" ]] || continue
  top=tb_pe_memory;args=(-GNUM_CTRL=1 -GTOTAL_STEPS=1)
  case $profile in
    mem-base) args+=(-GVARIANT=0 -GMEM_SLOT=0);;
    mem-base-last) args+=(-GVARIANT=0 -GMEM_SLOT=2 -GTILE_PORTS=8);;
    mem-context) args+=(-GVARIANT=1 -GMEM_SLOT=0);;
    mem-context64) args+=(-GVARIANT=1 -GMEM_SLOT=2 -GDATA_W=64 -GTILE_PORTS=8 -GCTRL_DEPTH=16 -GREG_DEPTH=8);;
    fp-native) top=tb_pe_fp_system;args+=(-GLEGACY_FP=0);;
    fp-legacy) top=tb_pe_fp_system;args+=(-GLEGACY_FP=1);;
  esac
  build=$root/$profile;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal -Irtl/common --top-module "$top" --Mdir "$build/obj" \
    -f "${PE_FILELIST:-filelists/native.f}" "tests/current/$top.sv" "${args[@]}" >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe=$build/obj/V$top${EXEEXT}
  "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep -E 'PE_(MEMORY|FP_SYSTEM)_PASS' "$build/run.log"
  set +e
  "$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -Eq 'PE_(MEMORY|FP_SYSTEM)_RESULT' "$build/negative.log" || { cat "$build/negative.log";exit 1; }
done
