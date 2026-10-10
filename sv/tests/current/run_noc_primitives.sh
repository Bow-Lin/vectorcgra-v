#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/noc-handshakes/primitives
files=(rtl/common/cgra_queue.sv rtl/common/cgra_round_robin.sv rtl/noc/cgra_switch.sv rtl/noc/cgra_credit_send.sv rtl/noc/cgra_credit_recv.sv)
compile() {
  mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module "$top" --Mdir "$build/obj" \
    "${files[@]}" "tests/current/$top.sv" "$@" >"$build/compile.log" 2>&1 || { tail -n 35 "$build/compile.log";exit 1; }
  exe=$build/obj/V$top${EXEEXT}
}
negative() {
  local marker=$1 log=$2;shift 2
  set +e
  "$exe" "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
for inputs in 1 2 3 5;do
  top=tb_noc_switch;build=$root/switch$inputs;compile -GINPUTS="$inputs"
  "$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; };grep NOC_SWITCH_PASS "$build/run.log"
  negative NOC_SWITCH_RESULT "$build/negative.log" +EXPECT_FAILURE
done
top=tb_noc_switch;build=$root/switch-legacy;compile -GINPUTS=3 -GLEGACY=1
negative NOC_SWITCH_RESULT "$build/stall-defect.log"
top=tb_noc_credit;build=$root/credit;compile
"$exe" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; };grep NOC_CREDIT_PASS "$build/run.log"
negative NOC_CREDIT_RESULT "$build/negative.log" +EXPECT_FAILURE
negative NOC_CREDIT_OVERFLOW "$build/overflow.log" +BAD_CREDIT
top=tb_noc_credit;build=$root/credit-legacy;compile -GLEGACY=1
negative NOC_CREDIT_STALL_CHANGED "$build/stall-defect.log"
echo NOC_PRIMITIVES_PASS
