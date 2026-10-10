#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/toolchain.sh"
cd "$(dirname "$0")/../../.."
for profile in base logic float; do
  out="build/phase3/system/$profile"
  if [[ "$profile" == base ]]; then vectors="$PWD/vectors/phase2/2x2"; else vectors="$PWD/vectors/phase3/system/$profile/2x2"; fi
  test -f "$out/system_test${EXEEXT}" || { echo "Run run_$profile.sh first"; exit 1; }
  set +e
  "$out/system_test${EXEEXT}" "+VECTORS=$vectors" +EXPECT_FAILURE > "$out/negative.log" 2>&1
  wrong_result=$?
  "$out/system_test${EXEEXT}" "+VECTORS=$vectors" +STALL_FOREVER +MAX_CYCLES=200 > "$out/timeout.log" 2>&1
  timeout_result=$?
  set -e
  test "$wrong_result" -ne 0
  test "$timeout_result" -ne 0
  grep -q 'intentional negative control' "$out/negative.log"
  grep -q 'TIMEOUT scenario=' "$out/timeout.log"
  echo "PHASE3_SYSTEM_NEGATIVE_PASS $profile: arithmetic corruption and permanent backpressure rejected"
done
