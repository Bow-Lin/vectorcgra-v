#!/usr/bin/env bash
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/../../.."
label=${1:-mesh4-tiles2}
out="build/phase4/system/$label"
[[ -f "$out/multi_test.exe" ]] || { echo "Run the positive profile first: $label" >&2; exit 2; }
set +e
"$out/multi_test.exe" "+VECTORS=$PWD/tests/phase4/system/$label" +NEGATIVE > "$out/negative.log" 2>&1
incorrect=$?
"$out/multi_test.exe" "+VECTORS=$PWD/tests/phase4/system/$label" +STALL_FOREVER > "$out/timeout-negative.log" 2>&1
stalled=$?
set -e
[[ $incorrect != 0 && $stalled != 0 ]]
grep -Eq '(Python mismatch|HDL oracle mismatch) sample=20' "$out/negative.log"
grep -q 'TIMEOUT multi-CGRA' "$out/timeout-negative.log"
echo "PHASE4_MULTI_NEGATIVE_PASS profile=$label"
