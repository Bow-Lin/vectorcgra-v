#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/config-tools/profiles;mkdir -p "$root"
for name in system context64 streaming ring heterogeneous;do
  build=$root/$name;mkdir -p "$build"
  rm -rf "$build/generated"
  "${PYTHON:-python3}" -I -S tools/cgra_config.py "examples/config/$name.json" --output "$build/generated" >"$build/generate.log" 2>&1
  "${PYTHON:-python3}" -I -S tests/config/prepare_hdl_checks.py "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_config_elaboration --Mdir "$build/obj" \
    -Irtl/common -I"$build/generated" -f filelists/native.f "$build/tb_config_elaboration.sv" \
    >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  "$build/obj/Vtb_config_elaboration${EXEEXT}" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep CGRA_CONFIG_ELAB_PASS "$build/run.log"
done
