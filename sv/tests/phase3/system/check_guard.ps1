param([string]$ToolRoot='D:/work/VectorCGRA/sys_lib/tools')
$ErrorActionPreference='Stop'
$svRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$converted=Join-Path $svRoot 'build/phase3/system-synthesis/native.v'
if(!(Test-Path $converted)) {throw 'Run system/check_synthesis.ps1 to produce the maintained-DUT Verilog first.'}
$yosys=Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$dir=Join-Path $svRoot 'build/phase3/system-guard'
New-Item -ItemType Directory -Force $dir | Out-Null
$script=Join-Path $dir 'guard.ys'
@("read_verilog -defer `"$($converted.Replace('\','/'))`"",
  'chparam -set VECTOR_FACTOR_POWER 1 cgra_programmable',
  'hierarchy -check -top cgra_programmable') | Set-Content $script -Encoding ascii
$log=Join-Path $dir 'yosys.log'
$oldPath=$env:PATH
try {
  $env:PATH=(Join-Path $ToolRoot 'oss-cad-suite/bin')+';'+(Join-Path $ToolRoot 'oss-cad-suite/lib')+';'+$oldPath
  & $yosys -Q -T -s $script *> $log
  $code=$LASTEXITCODE
} finally {$env:PATH=$oldPath}
$match=[regex]::Match((Get-Content $log -Raw),'native\.v:(\d+): ERROR: System task .*\$finish.*executed\.')
if($code -eq 0 -or !$match.Success) {throw 'Expected nonzero parameter-guard failure was not observed.'}
$line=[int]$match.Groups[1].Value
$source=[IO.File]::ReadAllLines($converted)
$expected='ac96 composed FU clusters require VECTOR_FACTOR_POWER=0'
if(!$source[$line-2].Contains($expected) -or $source[$line-1] -notmatch '\$finish\(1\)') {
  throw 'The failure was not at the specified vector-factor guard.'
}
@{status='passed';parameter=@{VECTOR_FACTOR_POWER=1};exit_code=$code;
  specified_fatal=$expected;diagnostic=$match.Value;context=@($source[$line-2],$source[$line-1]);
  converted_sha256=(Get-FileHash $converted).Hash.ToLowerInvariant();
  source_sha256=@{'rtl/fu/tile_flexible_fu_configurable.sv'=(Get-FileHash (Join-Path $svRoot 'rtl/fu/tile_flexible_fu_configurable.sv')).Hash.ToLowerInvariant()};
  log_sha256=(Get-FileHash $log).Hash.ToLowerInvariant()} |
  ConvertTo-Json -Depth 8 | Set-Content (Join-Path $svRoot 'results/phase3-system-guard.json') -Encoding utf8
Write-Output 'PHASE3_SYSTEM_GUARD_PASS VECTOR_FACTOR_POWER=1 rejected at the specified guard'
