#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
matched=0
for header in tests/phase4/noc/*/profile.svh;do
  profile=$(basename "$(dirname "$header")")
  [[ -z ${NOC_PROFILE_FILTER:-} || $profile =~ $NOC_PROFILE_FILTER ]] || continue
  for legacy in 0 1;do
    [[ -z ${NOC_LEGACY_FILTER:-} || $legacy == "$NOC_LEGACY_FILTER" ]] || continue
    matched=$((matched+1));build=build/current/noc-handshakes/network/$profile-legacy$legacy
    mkdir -p "$build"
    env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
      -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_inter_cgra_noc --Mdir "$build/obj" \
      -GLEGACY="$legacy" "+incdir+$(dirname "$header")" -f filelists/phase4_noc.f \
      "reference/phase4/noc/$profile/reference.v" tests/phase4/noc/tb_inter_cgra_noc.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
    exe=$build/obj/Vtb_inter_cgra_noc${EXEEXT}
    "$exe" "+RESULT=$build/result.json" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
    grep -E 'NOC_MODE_PASS|PHASE4_NOC_PASS' "$build/run.log"
    set +e
    "$exe" +EXPECT_FAILURE "+RESULT=$build/unexpected-negative.json" >"$build/negative.log" 2>&1
    status=$?
    set -e
    [[ $status != 0 ]] && grep -q NOC_PACKET_MISMATCH "$build/negative.log" || { cat "$build/negative.log";exit 1; }
  done
done
[[ $matched != 0 ]] || { echo 'No NoC profile matched';exit 2; }
