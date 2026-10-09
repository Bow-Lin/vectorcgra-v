#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/../../.."
build=build/phase3/vector_combo/vector_adder_w32_l4_b8_v0
if [[ ! -f "$build/simulation.exe" ]]; then
  echo 'First run vector_adder_w32_l4_b8_v0 with run.sh' >&2
  exit 2
fi
set +e
"./$build/simulation.exe" +EXPECT_FAILURE > "$build/negative.log" 2>&1
status=$?
set -e
[[ "$status" != 0 ]]
grep -q 'intentional negative control: corrupt independent expected result' "$build/negative.log"
grep -q 'independent leaf arithmetic cycle=64' "$build/negative.log"
printf 'P3_VECTOR_NEGATIVE_PASS exit_code=%s checker=independent_arithmetic\n' "$status"
