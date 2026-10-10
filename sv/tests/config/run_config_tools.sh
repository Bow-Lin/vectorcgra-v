#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
root=build/current/config-tools;mkdir -p "$root"
"${PYTHON:-python3}" -I -S tests/config/test_config.py >"$root/unit.log" 2>&1 || { cat "$root/unit.log";exit 1; }
tail -4 "$root/unit.log"
bash tests/config/run_config_profiles.sh
bash tests/config/run_pe_memory_kinds.sh
bash tests/config/run_config_kernel.sh
