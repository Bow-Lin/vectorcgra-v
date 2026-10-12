#!/usr/bin/env bash
# Run an already mapped 4x4/II5/32-word ReLU YAML on the maintained native RTL.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo 'usage: run_relu_yaml.sh YAML [NEW_OUTPUT_DIRECTORY] [INPUT_JSON]'
  exit 2
fi
yaml=$1; [[ $yaml = /* ]] || yaml="$PWD/$yaml"
output=${2:-}; if [[ -n $output && $output != /* ]]; then output="$PWD/$output"; fi
input=${3:-}; if [[ -n $input && $input != /* ]]; then input="$PWD/$input"; fi
cd "$(dirname "$0")/../.."
source scripts/toolchain.sh
if [[ -z $output ]]; then output="$PWD/build/current/yaml-relu/run-$(date +%Y%m%d-%H%M%S)-$$"; fi
extra=(); if [[ -n $input ]]; then extra=(--input "$input"); fi
python3 tests/current/gen_relu_yaml.py --yaml "$yaml" --output "$output" --memory "${RELU_MEMORY:-1}" "${extra[@]}"
mapfile -t args < "$output/verilator.args"
build="build/current/yaml-relu/memory${RELU_MEMORY:-1}"
mkdir -p "$build"
stamp_args=(--path "$build/build-stamp.json" --source tests/current/tb_native_kernel.sv
  --source tests/current/run_relu_yaml.sh --argument="COMPILER=$COMPILER")
for argument in "${args[@]}"; do stamp_args+=("--argument=$argument"); done
exe="$build/obj/Vtb_native_kernel${EXEEXT}"
if [[ ! -x $exe ]] || ! python3 scripts/build_stamp.py check "${stamp_args[@]}" >"$build/cache-check.log" 2>&1; then
  echo 'Compiling native 4x4 CGRA (first run or changed sources/tools)...'
  env -u LINK "$VERILATOR" --binary --timing --compiler "$COMPILER" -j "$JOBS" \
    -MAKEFLAGS "CXX=$CXX LINK=$CXX" -CFLAGS -O0 --output-split 10000 --output-split-cfuncs 2000 \
    --top-module tb_native_kernel --Mdir "$build/obj" -Wno-fatal -Irtl/common \
    -f filelists/native.f "${args[@]}" tests/current/tb_native_kernel.sv >"$build/compile.log" 2>&1 || {
      tail -n 35 "$build/compile.log"; exit 1;
    }
  python3 scripts/build_stamp.py write "${stamp_args[@]}"
fi
cp "$build/build-stamp.json" "$output/build-stamp.json"
for pacing in normal backpressure; do
  extra=(); if [[ $pacing == backpressure ]]; then extra=(+BACKPRESSURE +HOST_GAPS); fi
  "$exe" "+PROGRAM=$output" "+STORE_COUNTS=$output/stores.txt" "+RESULTS=$output/results-$pacing.csv" \
    "${extra[@]}" >"$output/$pacing.log" 2>&1 || { cat "$output/$pacing.log"; exit 1; }
  grep -q NATIVE_STORE_COUNTS_PASS "$output/$pacing.log"
  grep NATIVE_KERNEL_MATH_PASS "$output/$pacing.log"
done
echo "RELU_YAML_PASS output=$output"
