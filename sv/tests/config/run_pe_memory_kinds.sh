#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/config-tools/memory-kinds
for config in '0 2 4 pass' '1 2 4 pass' '2 32 8 pass' '1 0 4 pass' '2 0 8 pass' '1 32 4 fail' '2 2 8 fail';do
  read -r variant kind ports expected <<< "$config"
  build=$root/v$variant-k$kind;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_pe_memory_kind --Mdir "$build/obj" \
    -Irtl/common -f filelists/native.f -GVARIANT="$variant" -GKIND="$kind" -GTILE_PORTS="$ports" \
    tests/config/tb_pe_memory_kind.sv >"$build/compile.log" 2>&1 || { tail -n 25 "$build/compile.log";exit 1; }
  set +e
  "$build/obj/Vtb_pe_memory_kind${EXEEXT}" >"$build/run.log" 2>&1
  status=$?
  set -e
  if [[ $expected == pass ]];then
    [[ $status == 0 ]] && grep CONFIG_PE_MEMORY_KIND_PASS "$build/run.log" || { cat "$build/run.log";exit 1; }
  else
    [[ $status != 0 ]] && grep -q PE_MEMORY_VARIANT "$build/run.log" || { cat "$build/run.log";exit 1; }
    echo "CONFIG_PE_MEMORY_KIND_REJECT_PASS variant=$variant kind=$kind"
  fi
done
