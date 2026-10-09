#!/usr/bin/env bash
# SV-only tests. Python exporters are never invoked by this entry point.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/../../.."
for kind in context_switch streaming_memory; do
  top="tb_${kind}"
  out="build/phase3/tile_variants/$kind"
  mkdir -p "$out"
  if [[ "$kind" == context_switch ]]; then
    files=(rtl/common/cgra_queue.sv rtl/tile/variants/tile_context_switch.sv)
    marker=CONTEXT_SWITCH_PASS
  else
    files=(rtl/fu/streaming/tile_streaming_memory_fu.sv
      reference/phase3/tile_variants/streaming-w32-c8-r16/Phase3StreamingW32C8R16.v)
    marker=STREAMING_MEMORY_PASS
  fi
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang \
    --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
    -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common "${files[@]}" \
    "tests/phase3/tile_variants/$top.sv" > "$out/verilate.log" 2>&1
  make -C "$out" -f "V${top}.mk" -j2 CXX=clang++ \
    'LINK=env -u LINK clang++' LDLIBS=-pthread > "$out/compile.log" 2>&1
  "$out/native_test.exe" +verilator+seed+31415926 > "$out/run.log" 2>&1
  grep -q "$marker" "$out/run.log"
  cat "$out/run.log"
  set +e
  "$out/native_test.exe" +verilator+seed+31415926 +EXPECT_FAILURE > "$out/negative.log" 2>&1
  status=$?
  set -e
  if [[ $status -eq 0 ]] || ! grep -Eq '(context mismatch|stream mismatch).*cycle=20' "$out/negative.log"; then
    echo 'Component negative control did not reach its deliberately corrupted bit' >&2
    exit 1
  fi
  sha256sum "${files[@]}" rtl/common/cgra_profile_defs.svh rtl/common/cgra_profile.svh \
    "tests/phase3/tile_variants/$top.sv" "$out/"{verilate,compile,run,negative}.log > "$out/SHA256SUMS"
done
