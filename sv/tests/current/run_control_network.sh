#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/control-network
if [[ ${1:-rtl} == synth ]]; then
  python3 tests/control_network/synth.py --output "$root/synth"
else
  python3 -m unittest discover -s tests/control_network -p 'test_*.py' -v
  python3 tests/control_network/system.py --baseline-rtl --cases 2x2:0:0,4x4:0:0 --output "$root/pinned-system" --jobs "$JOBS"
  python3 tests/control_network/run.py --output "$root/network-final" --jobs "$JOBS"
  python3 tests/control_network/run.py --output "$root/multicast-final" --backends 1,2 --multicast --geometries 2x2,3x3,4x4,2x3,3x2,2x17 --jobs "$JOBS"
  python3 tests/control_network/system.py --output "$root/system-stage-a" --cases 2x2:0:0,2x2:1:0,2x2:2:0 --jobs "$JOBS"
  python3 tests/control_network/system.py --output "$root/system-stage-b" --cases 2x2:1:1,2x2:2:1 --jobs "$JOBS"
  python3 tests/control_network/system.py --output "$root/system-large" --cases 4x4:0:0,4x4:1:1,4x4:2:1,2x3:0:0,2x3:1:1 --jobs "$JOBS"
  python3 tests/control_network/reduction.py --output "$root/reduction" --jobs "$JOBS"
  python3 tests/control_network/guards.py --output "$root/guards"
fi
