#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
root=build/current/program-tools;mkdir -p "$root"
"${PYTHON:-python3}" -I -S tests/config/test_program.py >"$root/unit.log" 2>&1 || { cat "$root/unit.log";exit 1; }
tail -4 "$root/unit.log"
bash tests/config/run_program_packing.sh
bash tests/config/run_program_kernel.sh
