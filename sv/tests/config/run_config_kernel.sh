#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/config-tools/kernel;mkdir -p "$root"
# Only runner-owned generated output is refreshed; user CLI outputs refuse overwrite.
rm -rf "$root/generated"
"${PYTHON:-python3}" -I -S tools/cgra_config.py examples/config/heterogeneous.json --output "$root/generated" >"$root/generate.log" 2>&1
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_template --Mdir "$root/obj" \
  -Wno-fatal -Irtl/common -I"$root/generated" -f filelists/native.f +define+CGRA_GENERATED_ARCH \
  -GCOLS=3 -GROWS=3 -GTILE_PORTS=8 -GMULTI_COLS=2 -GMULTI_ROWS=2 \
  tests/current/tb_native_template.sv >"$root/compile.log" 2>&1 || { tail -n 30 "$root/compile.log";exit 1; }
exe="$root/obj/Vtb_native_template${EXEEXT}"
"$exe" +VECTORS=tests/phase4/template/heterogeneous >"$root/run.log" 2>&1 || { cat "$root/run.log";exit 1; }
grep NATIVE_TEMPLATE_PASS "$root/run.log"
for negative in NEGATIVE STALL_FOREVER;do
  set +e
  "$exe" +VECTORS=tests/phase4/template/heterogeneous "+$negative" >"$root/$negative.log" 2>&1
  status=$?
  set -e
  marker='Heterogeneous result/address/owner mismatch'
  if [[ $negative == STALL_FOREVER ]];then marker=NATIVE_TEMPLATE_TIMEOUT;fi
  [[ $status != 0 ]] && grep -q "$marker" "$root/$negative.log" || { cat "$root/$negative.log";exit 1; }
done
echo CGRA_CONFIG_KERNEL_PASS
