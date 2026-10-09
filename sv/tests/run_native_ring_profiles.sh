#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/.."
files=(rtl/common/cgra_register_file.sv rtl/common/cgra_queue.sv rtl/common/cgra_round_robin.sv rtl/noc/cgra_switch.sv rtl/noc/cgra_credit_send.sv rtl/noc/cgra_credit_input.sv rtl/noc/cgra_credit_recv.sv rtl/noc/cgra_ring_route.sv rtl/noc/cgra_ring_router.sv rtl/noc/cgra_credit_ring.sv)
for nodes in 7 17; do
  build="build/native_ring_${nodes}"
  mkdir -p "$build"
  defines=()
  if [[ "$nodes" == 17 ]]; then
    reference=reference/phase2/4x4/Phase2Reference4x4.v
    defines=(-DRING_17)
  else
    reference=reference/phase2/3x2/Phase2Reference3x2.v
  fi
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang --top-module tb_native_ring_profiles --prefix Vnative_ring --Mdir "$build" -o native_ring -CFLAGS -std=c++20 -Wno-fatal -Wno-TIMESCALEMOD "${defines[@]}" "${files[@]}" "$reference" tests/tb_native_ring_profiles.sv > "$build/verilate.log" 2>&1
  make -C "$build" -f Vnative_ring.mk -j 2 CXX=clang++ 'LINK=env -u LINK clang++' LDLIBS=-pthread > "$build/compile.log" 2>&1
  "./$build/native_ring.exe" > "$build/run.log" 2>&1
  grep -q NATIVE_RING_PASS "$build/run.log"
  cat "$build/run.log"
done
