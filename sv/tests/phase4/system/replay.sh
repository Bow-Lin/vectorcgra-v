#!/usr/bin/env bash
# Replay an already compiled final model with hashed runtime oracle inputs.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/../../.."
label=${1:?Specify a system profile or heterogeneous}
case "$label" in
  heterogeneous) family=template; exe=template_test; marker=PHASE4_TEMPLATE_PASS;;
  mesh4-tiles2|ring4-tiles2|mesh4-tiles2-registered|mesh4-tiles4) family=system;exe=multi_test;marker=PHASE4_MULTI_PASS;;
  *) echo "Unknown profile: $label" >&2;exit 2;;
esac
out="build/phase4/$family/$label"
vectors="tests/phase4/$family/$label"
[[ -f "$out/$exe.exe" ]]
# Compile provenance is checked before replay as well as by the collector.
sha256sum -c "$out/compiled_sources.sha256" > "$out/replay-source-check.log"
find "$vectors" -maxdepth 1 -type f \( -name '*.hex' -o -name '*.txt' -o -name 'results.json' \) -print0 |
  sort -z | xargs -0 -r sha256sum > "$out/runtime_inputs.sha256"
# 64Tile HDL/math mode intentionally does not read its partial Python assets.
if [[ "$label" == mesh4-tiles4 ]]; then
  printf '%s\n' 'No runtime Python vectors consumed: SV builds packets and HDL/math is the oracle.' > "$out/runtime-input-scope.txt"
else
  printf '%s\n' 'Frozen vectors and Python trace files under this profile are hashed before/after replay.' > "$out/runtime-input-scope.txt"
fi
"$out/$exe.exe" "+VECTORS=$PWD/$vectors" > "$out/run.log" 2>&1 || { cat "$out/run.log";exit 1; }
grep -q "$marker" "$out/run.log"
cat "$out/run.log"
if [[ "$family" == system ]]; then
  bash tests/phase4/system/run_negative.sh "$label"
else
  set +e
  "$out/$exe.exe" "+VECTORS=$PWD/$vectors" +NEGATIVE > "$out/negative.log" 2>&1
  negative=$?
  set -e
  [[ $negative != 0 ]]
  grep -q 'Template Python mismatch sample=20' "$out/negative.log"
  echo PHASE4_TEMPLATE_NEGATIVE_PASS
fi
sha256sum -c "$out/runtime_inputs.sha256" > "$out/replay-input-check.log"
echo "PHASE4_HASHED_REPLAY_PASS profile=$label"
