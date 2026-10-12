#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
root=build/current/noc-handshakes/network-synth;mkdir -p "$root"
mapfile -t files < <(grep -vE '^\+|^$' filelists/phase4_noc.f)
for top in cgra_inter_mesh cgra_inter_ring;do
  "$SV2V" -DSYNTHESIS "${files[@]}" --top="$top" --write="$root/$top.v" >"$root/$top-sv2v.log" 2>&1
done
matched=0
for config in 'mesh_2x2_l0_w32 0' 'mesh_3x2_l1_w64 0' 'ring_3_l1_w32 0' 'ring_6_l1_w64 0' 'mesh_2x2_l1_w32 1' 'ring_4_l1_w32 1';do
  read -r profile legacy <<< "$config"
  [[ -z ${NOC_SYNTH_FILTER:-} || $profile =~ $NOC_SYNTH_FILTER ]] || continue
  matched=$((matched+1));header=tests/phase4/noc/$profile/profile.svh
  param(){ sed -nE "s/localparam int $1=([^;]*);/\1/p" "$header"; }
  build=$root/$profile-legacy$legacy;mkdir -p "$build"
  args="-set WIDTH $(param WIDTH) -set LEGACY_PYTHON $legacy -set CHANNEL_LATENCY $(param CHANNEL_LATENCY)"
  if [[ $profile == mesh* ]];then
    top=cgra_inter_mesh
    for p in COLS ROWS X_WIDTH Y_WIDTH DST_X_LSB DST_Y_LSB;do args+=" -set $p $(param "$p")";done
  else
    top=cgra_inter_ring
    for p in NODES DST_LSB DST_WIDTH VC_LSB VC_WIDTH;do args+=" -set $p $(param "$p")";done
  fi
  "$YOSYS" -Q -T -p "read_verilog -defer $root/$top.v; chparam $args $top; hierarchy -check -top $top; proc; opt; check -assert; synth -top $top -flatten -noabc; splitnets; opt_clean; check -assert; scc -expect 0; rename $top noc_network_netlist; write_verilog -noattr $build/netlist.v; stat" >"$build/yosys.log" 2>&1 || { tail -n 40 "$build/yosys.log";exit 1; }
  "$YOSYS" -Q -T -p "read_verilog $build/netlist.v; hierarchy -check -top noc_network_netlist; proc; opt_clean; check -assert; scc -expect 0" >"$build/reread.log" 2>&1 || { tail -n 30 "$build/reread.log";exit 1; }
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -Wno-fatal --top-module tb_inter_cgra_noc --Mdir "$build/obj" \
    -GLEGACY="$legacy" -GRAW_INVALID_MESSAGES=0 +define+NOC_POST_SYNTH "+incdir+$(dirname "$header")" \
    "$build/netlist.v" "reference/phase4/noc/$profile/reference.v" tests/phase4/noc/tb_inter_cgra_noc.sv >"$build/compile.log" 2>&1 || { tail -n 40 "$build/compile.log";exit 1; }
  exe=$build/obj/Vtb_inter_cgra_noc${EXEEXT}
  "$exe" "+RESULT=$build/result.json" >"$build/run.log" 2>&1 || { cat "$build/run.log";exit 1; }
  grep -E 'NOC_MODE_PASS|PHASE4_NOC_PASS' "$build/run.log"
  set +e
  "$exe" +EXPECT_FAILURE >"$build/negative.log" 2>&1
  status=$?
  set -e
  [[ $status != 0 ]] && grep -q NOC_PACKET_MISMATCH "$build/negative.log" || { cat "$build/negative.log";exit 1; }
done
[[ $matched != 0 ]] || { echo 'No NoC synthesis profile matched';exit 2; }
