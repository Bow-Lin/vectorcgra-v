#!/usr/bin/env bash
# Shared native HDL tool selection. Source after enabling strict shell mode.
# All tools can be overridden; no project Python/PyMTL is used here.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    export PATH="/clang64/bin:/ucrt64/bin:$PATH"
    : "${EXEEXT:=.exe}"
    : "${CXX:=clang++}"
    : "${COMPILER:=clang}"
    ;;
  *)
    : "${EXEEXT:=}"
    : "${CXX:=c++}"
    : "${COMPILER:=gcc}"
    ;;
esac
: "${VERILATOR:=verilator}"
: "${SV2V:=sv2v}"
: "${YOSYS:=yosys}"
: "${JOBS:=2}"
export VERILATOR SV2V YOSYS CXX COMPILER EXEEXT JOBS
# Negative controls deliberately abort; do not leave large core dumps.
ulimit -c 0 2>/dev/null || true
