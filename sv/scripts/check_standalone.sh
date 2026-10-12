#!/usr/bin/env bash
# Acceptance of a fresh unpacked bundle using an already selected toolchain.
set -euo pipefail
cd "$(dirname "$0")/../.."
source sv/scripts/toolchain.sh
python3 sv/scripts/verify_bundle.py
[[ ! -e sv/build ]] || { echo 'Standalone acceptance requires a fresh unpacked bundle; select tools installed outside it.';exit 1; }
python3 -c 'import importlib.util; assert importlib.util.find_spec("pymtl3") is None; print("STANDALONE_NO_PYMTL_PASS")'
mkdir -p sv/build/standalone
"$VERILATOR" --version > sv/build/standalone/versions.log
"$YOSYS" -V >> sv/build/standalone/versions.log
"$SV2V" --version >> sv/build/standalone/versions.log
"$CXX" --version >> sv/build/standalone/versions.log
for target in current config-tools program-tools baseline; do
  echo "STANDALONE_TARGET_START $target"
  make -C sv "$target" >"sv/build/standalone/$target.log" 2>&1 || { tail -n 50 "sv/build/standalone/$target.log";exit 1; }
  echo "STANDALONE_TARGET_PASS $target"
done
KERNEL_MEMORY_MODES=1 bash sv/tests/current/run_kernel_boundaries.sh all axpy >sv/build/standalone/kernel.log 2>&1 || { tail -n 50 sv/build/standalone/kernel.log;exit 1; }
echo STANDALONE_AXPY_PASS
python3 sv/scripts/verify_bundle.py
echo STANDALONE_CLEAN_BUILD_PASS
