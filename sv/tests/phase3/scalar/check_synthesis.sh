#!/usr/bin/env bash
# Process lowering and optimized structural checks; no area or Fmax claim.
set -euo pipefail
export PATH="/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/../../.."
eda="${CGRA_OSS_TOOLS:-/d/work/VectorCGRA/sys_lib/tools}"
export PATH="$eda/oss-cad-suite/bin:$eda/oss-cad-suite/lib:$PATH"
sv2v="$eda/sv2v-v0.0.13/sv2v-Windows/sv2v.exe"
yosys="$eda/oss-cad-suite/bin/yosys.exe"
build=build/phase3/scalar/synthesis
mkdir -p "$build"
"$sv2v" -Irtl/common rtl/fu/scalar/*.sv >"$build/scalar.v" 2>"$build/sv2v.log"
for profile in w32 w64; do
  for name in const comp logic shifter sel phi grant gep extract_predicate ret loop_counter loop_control div inclusive_div exclusive_div; do
    parameters=''
    if [ "$profile" = w64 ]; then
      case "$name" in inclusive_div|exclusive_div) continue;; esac
      parameters="chparam -set DATA_W 64 -set CTRL_DEPTH 16 -set REG_DEPTH 8 scalar_$name;"
    fi
    "$yosys" -Q -T -p "read_verilog $build/scalar.v; $parameters hierarchy -check -top scalar_$name; proc; opt; check -assert; stat" \
      >"$build/${profile}_$name.log" 2>&1
    grep 'Found and reported' "$build/${profile}_$name.log" | tail -1
    printf 'SCALAR_STRUCTURAL_PASS profile=%s module=scalar_%s\n' "$profile" "$name"
  done
done
