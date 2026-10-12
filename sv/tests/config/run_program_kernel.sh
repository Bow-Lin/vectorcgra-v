#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/program-tools/kernel;mkdir -p "$root"
rm -rf "$root/architecture" "$root/program"
"${PYTHON:-python3}" -I -S tools/cgra_config.py examples/config/heterogeneous.json --output "$root/architecture" >"$root/architecture.log" 2>&1
"${PYTHON:-python3}" -I -S tools/cgra_program.py --config examples/config/heterogeneous.json --program examples/program/heterogeneous.json --output "$root/program" >"$root/program.log" 2>&1
env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
  -MAKEFLAGS "CXX=$CXX LINK=$CXX" --top-module tb_native_template --Mdir "$root/obj" \
  -Wno-fatal -Irtl/common -I"$root/architecture" -f filelists/native.f +define+CGRA_GENERATED_ARCH \
  -GCOLS=3 -GROWS=3 -GTILE_PORTS=8 -GMULTI_COLS=2 -GMULTI_ROWS=2 \
  tests/current/tb_native_template.sv >"$root/compile.log" 2>&1 || { tail -n 30 "$root/compile.log";exit 1; }
exe="$root/obj/Vtb_native_template${EXEEXT}";args=("+VECTORS=$root/program" "+BARRIERS=$root/program/barriers.txt")
"$exe" "${args[@]}" >"$root/run.log" 2>&1 || { cat "$root/run.log";exit 1; }
grep -E 'NATIVE_TEMPLATE_PASS|PROGRAM_BARRIERS_PASS' "$root/run.log"
"$exe" +VECTORS=tests/phase4/template/heterogeneous >"$root/historical-driver.log" 2>&1 || { cat "$root/historical-driver.log";exit 1; }
grep NATIVE_TEMPLATE_PASS "$root/historical-driver.log"
for negative in NEGATIVE STALL_FOREVER;do
  set +e
  "$exe" "${args[@]}" "+$negative" >"$root/$negative.log" 2>&1
  status=$?
  set -e
  marker='Heterogeneous result/address/owner mismatch'
  if [[ $negative == STALL_FOREVER ]];then marker=NATIVE_TEMPLATE_TIMEOUT;fi
  [[ $status != 0 ]] && grep -q "$marker" "$root/$negative.log" || { cat "$root/$negative.log";exit 1; }
done
printf '0 21\n' > "$root/impossible-barrier.txt"
set +e
"$exe" "+VECTORS=$root/program" "+BARRIERS=$root/impossible-barrier.txt" >"$root/barrier-negative.log" 2>&1
status=$?
set -e
[[ $status != 0 ]] && grep -q NATIVE_TEMPLATE_TIMEOUT "$root/barrier-negative.log" || { cat "$root/barrier-negative.log";exit 1; }
echo CGRA_PROGRAM_KERNEL_PASS
