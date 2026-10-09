[CmdletBinding()]
param(
  [string]$ToolRoot = (Join-Path $PSScriptRoot '../../../../sys_lib/tools'),
  [string[]]$Profiles = @('4x4', '2x2-w64-c16-r8'),
  [switch]$GuardOnly
)
$ErrorActionPreference = 'Stop'
$svRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = Join-Path $svRoot 'build/phase2-synthesis'
$toolPath = [IO.Path]::GetFullPath($ToolRoot)
$sv2v = Join-Path $toolPath 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys = Join-Path $toolPath 'oss-cad-suite/bin/yosys.exe'
$profileTable = [ordered]@{
  '4x4' = [ordered]@{ COLS=4; ROWS=4; DATA_W=32; CTRL_DEPTH=8; REG_DEPTH=16; BANK_DEPTH=16; NUM_BANKS=2; GLOBAL_ADDR_W=7; NUM_CTRL=8; TOTAL_STEPS=8 }
  '2x2-w64-c16-r8' = [ordered]@{ COLS=2; ROWS=2; DATA_W=64; CTRL_DEPTH=16; REG_DEPTH=8; BANK_DEPTH=16; NUM_BANKS=2; GLOBAL_ADDR_W=7; NUM_CTRL=8; TOTAL_STEPS=8 }
}
foreach ($profile in $Profiles) {
  if (-not $profileTable.Contains($profile)) { throw "Unknown profile: $profile" }
}
foreach ($tool in @($sv2v, $yosys)) {
  if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$filelistPath = Join-Path $svRoot 'filelists/rtl.f'
$files = @()
$includes = @()
foreach ($rawLine in Get-Content -LiteralPath $filelistPath) {
  $line = $rawLine.Trim()
  if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('//')) { continue }
  if ($line.StartsWith('+incdir+')) {
    foreach ($include in $line.Substring(8).Split('+')) {
      $includes += '--incdir=' + (Join-Path $svRoot $include)
    }
  } elseif ($line.StartsWith('+') -or $line.StartsWith('-')) {
    throw "Unsupported filelist directive: $line"
  } else { $files += Join-Path $svRoot $line }
}
if ($files.Count -eq 0) { throw 'Native filelist is empty.' }
$sourceHashes = [ordered]@{}
foreach ($source in @($filelistPath) + $files + @(
  (Join-Path $svRoot 'rtl/common/cgra_profile_defs.svh'),
  (Join-Path $svRoot 'rtl/common/cgra_profile.svh')
)) {
  $key = [IO.Path]::GetRelativePath($svRoot, $source).Replace('\','/')
  $sourceHashes[$key] = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
}
$savedPath = $env:PATH
$results = @()
function Add-ProfileAudit($entry, [string]$out) {
  $log = Get-Content -Raw -LiteralPath (Join-Path $out 'yosys.log')
  $counts = @([regex]::Matches($log, 'Found and reported (\d+) problems') | ForEach-Object { [int]$_.Groups[1].Value })
  if ($counts.Count -eq 0 -or $counts[-1] -ne 0) { throw "Missing successful final check in $out" }
  $inputBits=0
  $outputBits=0
  foreach ($port in $entry.top_ports) {
    $width=1
    if ($port -match '\bwidth (\d+)') { $width=[int]$Matches[1] }
    if ($port -match '\binput\b') { $inputBits += $width }
    if ($port -match '\boutput\b') { $outputBits += $width }
  }
  $p=$entry.parameters
  $dataBits=$p.DATA_W+3
  $tileIdWidth=[int][Math]::Ceiling([Math]::Log2($p.COLS*$p.ROWS+1))
  $ctrlAddrWidth=[int][Math]::Ceiling([Math]::Log2($p.CTRL_DEPTH))
  $regAddrWidth=[int][Math]::Ceiling([Math]::Log2($p.REG_DEPTH))
  $memPortWidth=[int][Math]::Ceiling([Math]::Log2($p.COLS+$p.ROWS))
  $payloadBits=6+$dataBits+$p.GLOBAL_ADDR_W+87+8*$regAddrWidth+$ctrlAddrWidth
  $hostBits=2*$tileIdWidth+15+$payloadBits
  $nocBits=2*$tileIdWidth+$memPortWidth+16+$payloadBits
  $expectedOutputBits=2*($p.COLS+$p.ROWS)*($dataBits+2)+$hostBits+2+$nocBits+2
  $expectedInputBits=$expectedOutputBits+2*$p.GLOBAL_ADDR_W+3
  if ($entry.top_port_count -ne 41 -or $inputBits -ne $expectedInputBits -or $outputBits -ne $expectedOutputBits) {
    throw "Top interface mismatch in $out"
  }
  $audit=[ordered]@{check_problem_counts=$counts; final_check_problems=$counts[-1];
    top_input_bits=$inputBits; top_output_bits=$outputBits; all_top_ports_preserved=$true}
  foreach ($item in $audit.GetEnumerator()) {
    if ($entry -is [System.Collections.IDictionary]) { $entry[$item.Key]=$item.Value }
    else { $entry | Add-Member -Force NoteProperty $item.Key $item.Value }
  }
}
function Test-ParameterGuard([string]$converted) {
  $out=Join-Path $buildRoot 'invalid-total-steps'
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $nativeV=$converted.Replace('\','/')
  @("read_verilog -defer `"$nativeV`"", 'chparam -set TOTAL_STEPS 2048 cgra_scalar',
    'hierarchy -check -top cgra_scalar') | Set-Content -LiteralPath (Join-Path $out 'check.ys') -Encoding ascii
  & $yosys -Q -T -l (Join-Path $out 'yosys.log') -s (Join-Path $out 'check.ys') *> (Join-Path $out 'console.log')
  $code=$LASTEXITCODE
  $log=Get-Content -Raw -LiteralPath (Join-Path $out 'yosys.log')
  $expected='TOTAL_STEPS exceeds the ac96 eleven-bit counter'
  $match=[regex]::Match($log,'native\.v:(\d+): ERROR: System task .*\$finish.*executed\.')
  if ($code -eq 0 -or -not $match.Success) { throw 'Expected TOTAL_STEPS parameter guard was not reached.' }
  $line=[int]$match.Groups[1].Value
  $source=Get-Content -LiteralPath $converted
  if (-not $source[$line-2].Contains($expected) -or $source[$line-1] -notmatch '\$finish\(1\)') {
    throw 'Failure does not correspond to the specified TOTAL_STEPS fatal.'
  }
  return [ordered]@{
    parameters=@{TOTAL_STEPS=2048}; status='passed'; expected='nonzero elaboration exit at the specified parameter guard';
    tool_exit_code=$code; specified_fatal_message=$expected; converted_verilog_line=$line;
    match_method='Yosys reports the exact $finish file/line; its immediately preceding $display contains the specified fatal text. Yosys does not echo that display text.';
    diagnostic=$match.Value; source_context=@($source[$line-2],$source[$line-1]);
    log_sha256=(Get-FileHash -LiteralPath (Join-Path $out 'yosys.log') -Algorithm SHA256).Hash.ToLowerInvariant()
  }
}
try {
  $env:PATH = "$(Join-Path $toolPath 'oss-cad-suite/bin');$(Join-Path $toolPath 'oss-cad-suite/lib');$savedPath"
  $versions = [ordered]@{ sv2v=(& $sv2v --numeric-version | Out-String).Trim(); yosys=(& $yosys -V | Out-String).Trim() }
  $converted = Join-Path $buildRoot 'native.v'
  $reportPath=Join-Path $svRoot 'results/phase2-profile-synthesis.json'
  if ($GuardOnly) {
    $report=Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    if ((Get-FileHash -LiteralPath $converted -Algorithm SHA256).Hash.ToLowerInvariant() -ne $report.converted_verilog_sha256) {
      throw 'Existing converted source changed; rerun complete synthesis.'
    }
    foreach ($pair in $sourceHashes.GetEnumerator()) {
      if ($report.source_hashes.($pair.Key) -ne $pair.Value) { throw "Source changed: $($pair.Key); rerun complete synthesis." }
    }
    foreach ($entry in $report.profiles) { Add-ProfileAudit $entry (Join-Path $svRoot $entry.output_directory) }
    $negative=Test-ParameterGuard $converted
    $report | Add-Member -Force NoteProperty negative_controls @($negative)
    $report | Add-Member -Force NoteProperty entry_point_sha256 (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $reportPath
    Write-Output 'PHASE2_PARAMETER_GUARD_PASS TOTAL_STEPS=2048'
    return
  }
  $conversionClock = [Diagnostics.Stopwatch]::StartNew()
  & $sv2v "--write=$converted" @includes @files 2> (Join-Path $buildRoot 'sv2v.log')
  $conversionClock.Stop()
  if ($LASTEXITCODE -ne 0) { throw "sv2v failed: $LASTEXITCODE. See $buildRoot/sv2v.log" }
  $convertedHash = (Get-FileHash -LiteralPath $converted -Algorithm SHA256).Hash.ToLowerInvariant()
  foreach ($profile in $Profiles) {
    $out = Join-Path $buildRoot $profile
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $parameters = $profileTable[$profile]
    $parameterArgs = ($parameters.GetEnumerator() | ForEach-Object { "-set $($_.Key) $($_.Value)" }) -join ' '
    $nativeV = $converted.Replace('\','/')
    $statFile = (Join-Path $out 'stat.json').Replace('\','/')
    $interfaceFile = (Join-Path $out 'top-interface.il').Replace('\','/')
    $commands = @(
      "read_verilog -defer `"$nativeV`"",
      "chparam $parameterArgs cgra_scalar",
      'hierarchy -check -top cgra_scalar',
      'synth -top cgra_scalar -noabc',
      'check -assert',
      "tee -o `"$statFile`" stat -json",
      "tee -o `"$interfaceFile`" dump cgra_scalar"
    )
    $scriptPath = Join-Path $out 'synth.ys'
    $commands | Set-Content -LiteralPath $scriptPath -Encoding ascii
    $clock = [Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -l (Join-Path $out 'yosys.log') -s $scriptPath *> (Join-Path $out 'console.log')
    $toolExit = $LASTEXITCODE
    $clock.Stop()
    $entry = [ordered]@{ profile=$profile; parameters=$parameters; exit_code=$toolExit; elapsed_seconds=$clock.Elapsed.TotalSeconds; status='failed'; output_directory="build/phase2-synthesis/$profile" }
    if ($toolExit -eq 0) {
      $entry.status = 'passed'
      $stats = Get-Content -Raw -LiteralPath $statFile | ConvertFrom-Json
      $entry.design = $stats.design
      $entry.top = $stats.modules.'\cgra_scalar'
      $ports = @(Get-Content -LiteralPath $interfaceFile | Where-Object { $_ -match '^\s+wire .*\b(input|output)\b' })
      $entry.top_port_count = $ports.Count
      $entry.top_ports = $ports
      if ($ports.Count -eq 0) { throw "No top ports retained for $profile" }
      Add-ProfileAudit $entry $out
      $entry.stat_sha256 = (Get-FileHash -LiteralPath $statFile -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $entry.log_sha256 = (Get-FileHash -LiteralPath (Join-Path $out 'yosys.log') -Algorithm SHA256).Hash.ToLowerInvariant()
    $results += $entry
    $report = [ordered]@{
      schema=1; timestamp_utc=[DateTime]::UtcNow.ToString('o'); tools=$versions;
      flow='sv2v native-only filelist -> read_verilog -defer -> chparam -> hierarchy -check -> synth -noabc -> check -assert -> stat -json';
      top='cgra_scalar'; source_hashes=$sourceHashes; converted_verilog_sha256=$convertedHash;
      sv2v_elapsed_seconds=$conversionClock.Elapsed.TotalSeconds;
      limitations=@('Generic synthesis statistics are not standard-cell area or timing estimates.','Existing baseline undriven inputs/outputs are preserved; initial warnings and the final strict check are distinct.');
      profiles=$results
    }
    $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $svRoot 'results/phase2-profile-synthesis.json')
    if ($toolExit -ne 0) { throw "Yosys failed for $profile (exit $toolExit). Check retained logs in $out" }
    Write-Output "PHASE2_PROFILE_SYNTHESIS_PASS profile=$profile ports=$($ports.Count) seconds=$($clock.Elapsed.TotalSeconds)"
  }
  $report.negative_controls=@(Test-ParameterGuard $converted)
  $report.entry_point_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $reportPath
  Write-Output 'PHASE2_PARAMETER_GUARD_PASS TOTAL_STEPS=2048'
} finally { $env:PATH = $savedPath }
