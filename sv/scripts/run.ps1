[CmdletBinding()]
param(
  [ValidateSet('all', 'current', 'current-synth', 'current-post-synth', 'current-loop-controller', 'current-loop-controller-synth', 'current-static-memory', 'current-static-memory-synth', 'current-ring-ctrl-memory', 'current-ring-ctrl-memory-synth', 'current-data-memory', 'current-data-memory-synth', 'current-scalable-memory', 'current-scalable-memory-synth', 'current-or-link', 'current-or-link-synth', 'native-kernels', 'native-math', 'native-multi', 'native-template', 'current-migration', 'current-kernels', 'current-prefixes', 'baseline', 'probe', 'types', 'sim', 'negative', 'timeout-negative', 'synth', 'synth-generic', 'synth-mapped', 'versions', 'phase2', 'phase2-2x2', 'phase2-3x2', 'phase2-4x4', 'phase2-2x2-w64-c16-r8', 'phase2-negative', 'phase3', 'phase3-system', 'phase3-scalar', 'phase3-vector-combo', 'phase3-float', 'phase3-tiles', 'regression', 'phase4', 'phase4-noc', 'phase4-system', 'phase4-template', 'phase4-migration', 'phase4-peripheral', 'phase4-memory')]
  [string]$Task = 'all',
  [string]$MsysRoot = 'C:/msys64',
  [string]$OssCadSuite = $env:OSS_CAD_SUITE,
  [string]$Sv2v = $env:SV2V,
  [string]$Liberty = '',
  [ValidateRange(1, 64)][int]$Jobs = 2
)
$ErrorActionPreference = 'Stop'
$svRoot = Split-Path -Parent $PSScriptRoot
if (-not $OssCadSuite) {
  throw 'Pass -OssCadSuite <oss-cad-suite directory> or set OSS_CAD_SUITE.'
}
if (-not $Sv2v) { throw 'Pass -Sv2v <sv2v.exe path> or set SV2V.' }
$taskRequired = @(
  "$MsysRoot/usr/bin/bash.exe", "$MsysRoot/usr/bin/make.exe",
  "$MsysRoot/ucrt64/bin/verilator", "$MsysRoot/clang64/bin/clang++.exe",
  "$OssCadSuite/bin/yosys.exe", $Sv2v
)
foreach ($taskPath in $taskRequired) {
  if (-not (Test-Path -LiteralPath $taskPath)) { throw "Missing tool: $taskPath" }
}
if ($Liberty -and -not (Test-Path -LiteralPath $Liberty)) { throw "Missing Liberty: $Liberty" }
$taskOldPath = $env:PATH
$taskOldRoot = $env:VERILATOR_ROOT
try {
  # Prefer clang's matching C++ runtime; Verilator itself uses the UCRT build.
  $env:PATH = "$MsysRoot/clang64/bin;$MsysRoot/ucrt64/bin;$MsysRoot/usr/bin;$OssCadSuite/bin;$OssCadSuite/lib;$taskOldPath"
  $env:VERILATOR_ROOT = "$MsysRoot/ucrt64/share/verilator"
  $taskMakeArgs = @(
    '-C', $svRoot.Replace('\', '/'), $Task,
    "VERILATOR=$MsysRoot/ucrt64/bin/verilator",
    "YOSYS=$OssCadSuite/bin/yosys.exe", "SV2V=$Sv2v",
    'CXX=clang++', 'COMPILER=clang', 'EXEEXT=.exe', "JOBS=$Jobs",
    'MODEL_MAKE_FLAGS=LDLIBS=-pthread', "LIBERTY=$($Liberty.Replace('\', '/'))"
  )
  & "$MsysRoot/usr/bin/bash.exe" '-c' 'suite=$(/usr/bin/cygpath -u "$1"); shift; export PATH="$suite/bin:$suite/lib:/clang64/bin:/ucrt64/bin:/usr/bin:$PATH"; exec /usr/bin/make "$@"' 'native-sv' $OssCadSuite @taskMakeArgs
  $taskExit = $LASTEXITCODE
  if ($taskExit -ne 0) { throw "Native SV target '$Task' failed (exit $taskExit). See sv/build logs." }
} finally {
  $env:PATH = $taskOldPath
  if ($null -eq $taskOldRoot) { Remove-Item Env:VERILATOR_ROOT -ErrorAction SilentlyContinue }
  else { $env:VERILATOR_ROOT = $taskOldRoot }
}
