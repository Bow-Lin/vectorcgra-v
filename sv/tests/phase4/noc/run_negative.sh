#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/../../.."
build=build/phase4/noc/mesh_2x2_l1_w32
[[ -f "$build/simulation.exe" ]] || { echo 'Build mesh_2x2_l1_w32 first' >&2; exit 2; }
set +e
"./$build/simulation.exe" +EXPECT_FAILURE > "$build/negative.log" 2>&1
wrong_result=$?
"./$build/simulation.exe" +STALL_FOREVER > "$build/timeout.log" 2>&1
timeout_result=$?
set -e
[[ "$wrong_result" != 0 && "$timeout_result" != 0 ]]
grep -q 'intentional negative control' "$build/negative.log"
grep -q NOC_PACKET_MISMATCH "$build/negative.log"
grep -q NOC_TIMEOUT "$build/timeout.log"
printf 'PHASE4_NOC_NEGATIVE_PASS scoreboard_exit=%s timeout_exit=%s\n' "$wrong_result" "$timeout_result"
