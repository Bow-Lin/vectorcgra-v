#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
build=build/current/synth
mkdir -p "$build"
mapfile -t files < <(grep -vE '^\+|^$' filelists/native.f)
"$SV2V" -Irtl/common -Irtl/vendor/hardfloat -Irtl/fu/combo/vendor \
  "${files[@]}" --top=cgra_pe --write="$build/pe.v" >"$build/sv2v.log" 2>&1
# Defer elaboration: the catalog contains modules whose standalone defaults
# intentionally fail parameter guards; only the selected PE hierarchy is used.
"$YOSYS" -Q -T -p "read_verilog -defer $build/pe.v; hierarchy -check -top cgra_pe; proc; opt_clean; check -assert; synth -top cgra_pe -noabc; check -assert; stat" >"$build/yosys.log" 2>&1
echo CURRENT_PE_SYNTH_PASS
