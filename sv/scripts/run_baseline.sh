#!/usr/bin/env bash
# Re-run historical acceptance against its original native RTL. The current
# implementation has a new opcode/behavior contract and is tested separately.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
snapshot="$PWD/build/baseline-cd7aad878915"
if [[ ! -f "$snapshot/.complete" ]]; then
  mkdir -p "$snapshot"
  git -C .. archive cd7aad878915e389cecf8cc01ff6987d156bd019 sv | tar -x -C "$snapshot"
  touch "$snapshot/.complete"
fi
# Port only the runners, preserving baseline DUT, stimulus and oracle bytes.
cp scripts/toolchain.sh "$snapshot/sv/scripts/toolchain.sh"
while IFS= read -r runner; do
  if [[ -f "$snapshot/sv/$runner" ]]; then
    cp "$runner" "$snapshot/sv/$runner"
  fi
done < <(find tests -name '*.sh' -not -path 'tests/current/*' -not -path 'tests/pe/*')
make -C "$snapshot/sv" "${@:-all}"
