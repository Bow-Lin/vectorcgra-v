#!/usr/bin/env bash
# SV-only: frozen reference and checked-in benches; no Python generation.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/../../.."
files=(rtl/fu/tile_adder.sv rtl/fu/tile_multiplier.sv
  rtl/fu/scalar/scalar_shifter.sv rtl/fu/scalar/scalar_comp.sv
  rtl/fu/scalar/scalar_logic.sv rtl/fu/scalar/scalar_grant.sv
  rtl/fu/vector/*.sv rtl/fu/combo/*.sv)
selected="${1:-all}"
for test in tests/phase3/vector_combo/*/tb.sv; do
  label="$(basename "$(dirname "$test")")"
  if [[ "$selected" != all && "$selected" != "$label" ]]; then continue; fi
  build="build/phase3/vector_combo/$label"
  mkdir -p "$build"
  reference="reference/phase3/vector_combo/$label/reference.v"
  # PyMTL placeholder pickling emits unescaped Windows paths in `line.
  # Remove only source-location directives in an ignored compile copy.
  sed '/^`line /d' "$reference" > "$build/reference_compile.v"
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang --top-module tb_phase3_vector --prefix Vp3vector --Mdir "$build" -o simulation -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD +incdir+rtl/common "${files[@]}" "$build/reference_compile.v" "$test" > "$build/verilate.log" 2>&1
  make -C "$build" -f Vp3vector.mk -j 2 CXX=clang++ 'LINK=env -u LINK clang++' LDLIBS=-pthread > "$build/compile.log" 2>&1
  "./$build/simulation.exe" "+RESULT=$build/result.json" > "$build/run.log" 2>&1
  grep -q P3_VECTOR_PASS "$build/run.log"
  cat "$build/run.log"
done
