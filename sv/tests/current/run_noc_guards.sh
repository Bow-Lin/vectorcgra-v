#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/noc-handshakes/guards
negative(){
  local marker=$1 log=$2;shift 2
  set +e
  "$exe" "$@" >"$log" 2>&1
  local status=$?
  set -e
  [[ $status != 0 ]] && grep -q "$marker" "$log" || { cat "$log";exit 1; }
}
for eject in 0 1;do
  build=$root/receiver$eject;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_noc_credit_guard --Mdir "$build/obj" \
    -GEJECTION="$eject" -f filelists/phase4_noc.f tests/current/tb_noc_credit_guard.sv >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  exe=$build/obj/Vtb_noc_credit_guard${EXEEXT}
  negative NOC_INVALID_CREDIT_VC "$build/invalid-vc.log" +BAD_VC
  negative NOC_CREDIT_INPUT_OVERFLOW "$build/overflow.log"
done
echo NOC_RECEIVER_GUARDS_PASS
for profile in vcs credits;do
  args=(-GVCS=3);if [[ $profile == credits ]];then args=(-GCREDITS=3);fi
  build=$root/ring-$profile;mkdir -p "$build"
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_noc_ring_guard --Mdir "$build/obj" \
    "${args[@]}" -f filelists/phase4_noc.f tests/current/tb_noc_ring_guard.sv >"$build/compile.log" 2>&1 || { tail -n 30 "$build/compile.log";exit 1; }
  exe=$build/obj/Vtb_noc_ring_guard${EXEEXT}
  negative 'ac96 ring profile requires VCS=2 and CREDITS=2' "$build/invalid-profile.log"
done
echo NOC_RING_GUARDS_PASS
