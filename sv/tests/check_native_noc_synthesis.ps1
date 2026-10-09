param(
  [string]$ToolRoot = (Join-Path $PSScriptRoot '../../../../sys_lib/tools')
)
$ErrorActionPreference = 'Stop'
$svRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = Join-Path $svRoot 'build/native_noc_synthesis'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$sv2v = Join-Path $ToolRoot 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys = Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$files = @('common/cgra_register_file.sv', 'common/cgra_queue.sv',
  'common/cgra_channel.sv', 'common/cgra_round_robin.sv',
  'noc/cgra_switch.sv', 'noc/cgra_xbar.sv', 'noc/cgra_credit_send.sv',
  'noc/cgra_credit_input.sv', 'noc/cgra_credit_recv.sv',
  'noc/cgra_ring_route.sv', 'noc/cgra_ring_router.sv', 'noc/cgra_credit_ring.sv') |
  ForEach-Object { Join-Path $svRoot "rtl/$_" }
$converted = Join-Path $build 'native_noc.v'
& $sv2v "--write=$converted" @files 2> (Join-Path $build 'sv2v.log')
if ($LASTEXITCODE -ne 0) { throw "sv2v failed: $LASTEXITCODE" }
$nativeV = $converted.Replace('\', '/')
$commands = @()
# Elaborate independently: retain public parameters rather than flatten a
# single default design. This is a front-end/synthesis sanity check, not PPA.
$profiles = @(
  'cgra_queue -chparam WIDTH 35 -chparam DEPTH 1 -chparam BYPASS 0',
  'cgra_queue -chparam WIDTH 35 -chparam DEPTH 3 -chparam BYPASS 1',
  'cgra_queue -chparam WIDTH 67 -chparam DEPTH 16 -chparam BYPASS 0',
  'cgra_channel -chparam WIDTH 35 -chparam LATENCY 0',
  'cgra_channel -chparam WIDTH 35 -chparam LATENCY 1',
  'cgra_channel -chparam WIDTH 67 -chparam LATENCY 3',
  'cgra_register_file -chparam WIDTH 35 -chparam DEPTH 16 -chparam RD_PORTS 2 -chparam WR_PORTS 2',
  'cgra_xbar -chparam WIDTH 195 -chparam INPUTS 7 -chparam OUTPUTS 1 -chparam DST_LSB 194 -chparam DST_WIDTH 1',
  'cgra_xbar -chparam WIDTH 52 -chparam INPUTS 3 -chparam OUTPUTS 4 -chparam DST_LSB 48 -chparam DST_WIDTH 2 -chparam INPUT_BYPASS 1',
  'cgra_credit_ring -chparam WIDTH 191 -chparam NODES 5 -chparam DST_WIDTH 3',
  'cgra_credit_ring -chparam WIDTH 191 -chparam NODES 7 -chparam DST_WIDTH 3',
  'cgra_credit_ring -chparam WIDTH 195 -chparam NODES 17 -chparam DST_WIDTH 5'
)
foreach ($profile in $profiles) {
  $commands += 'design -reset'
  $commands += "read_verilog -defer `"$nativeV`""
  $top, $parameters = $profile.Split(' ', 2)
  $parameters = $parameters.Replace('-chparam', '-set')
  $commands += "chparam $parameters $top"
  $commands += "hierarchy -check -top $top"
  $commands += 'proc'
  $commands += 'opt'
  $commands += 'memory_collect'
  $commands += 'check -assert'
  $commands += 'stat'
}
$scriptPath = Join-Path $build 'check.ys'
$commands | Set-Content -LiteralPath $scriptPath -Encoding ascii
$savedPath = $env:PATH
try {
  $env:PATH = "$(Join-Path $ToolRoot 'oss-cad-suite/bin');$(Join-Path $ToolRoot 'oss-cad-suite/lib');$savedPath"
  & $yosys -Q -T -l (Join-Path $build 'yosys.log') -s $scriptPath *> (Join-Path $build 'console.log')
  if ($LASTEXITCODE -ne 0) { throw "Yosys failed: $LASTEXITCODE" }
} finally { $env:PATH = $savedPath }
Write-Output "NATIVE_NOC_SYNTHESIS_CHECK_PASS profiles=$($profiles.Count)"
