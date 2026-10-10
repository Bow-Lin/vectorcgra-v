#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
out=build/phase4/template/heterogeneous
mkdir -p "$out"
{ grep -v '^+' filelists/phase4.f | grep -v '^$'; printf '%s\n' tests/phase4/template/tb_template.sv tests/phase4/template/heterogeneous/architecture.svh; } | xargs sha256sum > "$out/compiled_sources.sha256"
sha256sum rtl/common/*.svh >> "$out/compiled_sources.sha256"
"$VERILATOR" --cc --main --exe --timing --compiler "$COMPILER" --top-module tb_template \
  --Mdir "$out" -o template_test -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD \
  -GCOLS=3 -GROWS=3 -GTILE_PORTS=8 -GMULTI_COLS=2 -GMULTI_ROWS=2 \
  +incdir+tests/phase4/template -f filelists/phase4.f \
  reference/phase4/template/heterogeneous/original.v tests/phase4/template/tb_template.sv \
  > "$out/verilate.log" 2>&1 || { tail -n 40 "$out/verilate.log"; exit 1; }
make -C "$out" -f Vtb_template.mk -j "$JOBS" "CXX=$CXX" "LINK=env -u LINK $CXX" LDLIBS=-pthread \
  > "$out/compile.log" 2>&1 || { tail -n 30 "$out/compile.log"; exit 1; }
"$out/template_test${EXEEXT}" "+VECTORS=$PWD/tests/phase4/template/heterogeneous" > "$out/run.log" 2>&1 || { cat "$out/run.log"; exit 1; }
grep -q PHASE4_TEMPLATE_PASS "$out/run.log"
cat "$out/run.log"
set +e
"$out/template_test${EXEEXT}" "+VECTORS=$PWD/tests/phase4/template/heterogeneous" +NEGATIVE > "$out/negative.log" 2>&1
negative=$?
set -e
[[ $negative != 0 ]]
grep -q 'Template Python mismatch sample=20' "$out/negative.log"
echo PHASE4_TEMPLATE_NEGATIVE_PASS
