#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_ROOT="$(cygpath -m /ucrt64/share/verilator)"
cd "$(dirname "$0")/../../.."
for kind in ${*:-dma-system im2col-system};do
  top="tb_${kind//-/_}";out="build/phase4/peripheral/$kind";mkdir -p "$out"
  if [[ "$kind" == dma-system ]];then gold=Phase4DmaSystem;marker=DMA_SYSTEM_PASS;else gold=Phase4Im2ColSystem;marker=IM2COL_SYSTEM_PASS;fi
  /ucrt64/bin/verilator --cc --main --exe --timing --compiler clang \
    --top-module "$top" --Mdir "$out" -o native_test -CFLAGS -std=c++20 \
    -Wno-fatal -Wno-TIMESCALEMOD -Irtl/common -f filelists/phase4.f -f filelists/phase4_peripheral.f \
    rtl/peripheral/cgra_integrated_dma.sv rtl/peripheral/cgra_integrated_im2col.sv \
    "reference/phase4/peripheral/$kind/$gold.v" "tests/phase4/peripheral/$top.sv" > "$out/verilate.log" 2>&1
  make -C "$out" -f "V${top}.mk" -j2 CXX=clang++ 'LINK=env -u LINK clang++' LDLIBS=-pthread > "$out/compile.log" 2>&1
  "$out/native_test.exe" +verilator+seed+31415926 > "$out/run.log" 2>&1
  grep -q "$marker" "$out/run.log";cat "$out/run.log"
  set +e
  "$out/native_test.exe" +verilator+seed+31415926 +EXPECT_FAILURE > "$out/negative.log" 2>&1
  status=$?
  set -e
  if [[ $status -eq 0 ]] || ! grep -q "$kind mismatch cycle=20" "$out/negative.log";then
    echo "Integrated negative did not reach corrupted output bit" >&2;exit 1
  fi
  sha256sum "tests/phase4/peripheral/$top.sv" rtl/peripheral/*.sv rtl/common/cgra_profile*.svh \
    "$out/"{verilate,compile,run,negative}.log > "$out/SHA256SUMS"
done
