[CmdletBinding()]
param(
  [string]$ToolRoot='D:/work/VectorCGRA/sys_lib/tools',
  [string[]]$Profiles=@('base','logic','float','vector','context','streaming')
)
$ErrorActionPreference='Stop'
$svRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sv2v=Join-Path $ToolRoot 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$table=[ordered]@{
  base=@{FU_COUNT=4;FU_KINDS="32'h03020100";TILE_VARIANT=0;TILE_PORTS=4}
  logic=@{FU_COUNT=5;FU_KINDS="40'h0306020100";TILE_VARIANT=0;TILE_PORTS=4}
  float=@{FU_COUNT=4;FU_KINDS="32'h03021d1c";TILE_VARIANT=0;TILE_PORTS=4}
  vector=@{FU_COUNT=4;FU_KINDS="32'h03020113";TILE_VARIANT=0;TILE_PORTS=4}
  context=@{FU_COUNT=5;FU_KINDS="40'h0302010009";TILE_VARIANT=1;TILE_PORTS=4}
  streaming=@{FU_COUNT=4;FU_KINDS="32'h03200100";TILE_VARIANT=2;TILE_PORTS=8}
}
foreach($profile in $Profiles) { if(!$table.Contains($profile)) { throw "Unknown profile: $profile" } }
$savedPath=$env:PATH
$env:PATH=(Join-Path $ToolRoot 'oss-cad-suite/bin')+';'+(Join-Path $ToolRoot 'oss-cad-suite/lib')+';'+$savedPath
Push-Location $svRoot
try {
  $out=Join-Path $svRoot 'build/phase3/system-synthesis'
  New-Item -ItemType Directory -Force $out | Out-Null
  $files=@(); $includes=@()
  foreach($line in Get-Content filelists/phase3.f) {
    if($line.StartsWith('+incdir+')) { $includes+='--incdir='+$line.Substring(8) }
    elseif($line.Trim() -and !$line.StartsWith('#')) { $files+=$line.Trim() }
  }
  $hashes=[ordered]@{}
  $sources=$files + @('filelists/phase3.f',$PSCommandPath) + @(Get-ChildItem rtl/common/*.svh,rtl/vendor/hardfloat/*.vi | ForEach-Object {$_.FullName})
  foreach($path in $sources) {
    $key=[IO.Path]::GetRelativePath($svRoot,(Resolve-Path $path).Path).Replace('\','/')
    $hashes[$key]=(Get-FileHash $path).Hash.ToLowerInvariant()
  }
  $converted=(Join-Path $out 'native.v').Replace('\','/')
  & $sv2v @includes @files "--write=$converted" *> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0) { throw 'Whole-CGRA phase3 sv2v failed' }
  $report=[ordered]@{schema=1;timestamp_utc=[DateTime]::UtcNow.ToString('o');source_sha256=$hashes;
    tools=@{sv2v=(& $sv2v --numeric-version | Out-String).Trim();yosys=(& $yosys -V | Out-String).Trim()};
    converted_sha256=(Get-FileHash $converted).Hash.ToLowerInvariant();
    flow='Maintained DUT only: sv2v -> chparam -> hierarchy -check -> synth -noabc -> check -assert';
    area_measured=$false;frequency_measured=$false;profiles=@();
    limitations=@('Two-by-two single CGRA profiles only.','Baseline undriven signals and latches retained; final zero check does not prove all source signals defined.','Generic cell counts are not standard-cell area or frequency.')}
  foreach($profile in $Profiles) {
    $dir=Join-Path $out $profile
    New-Item -ItemType Directory -Force $dir | Out-Null
    $parameters=$table[$profile]
    $argsText=($parameters.GetEnumerator() | Sort-Object Name | ForEach-Object {"-set $($_.Key) $($_.Value)"}) -join ' '
    $stat=(Join-Path $dir 'stat.json').Replace('\','/')
    $interface=(Join-Path $dir 'top-interface.il').Replace('\','/')
    $script=Join-Path $dir 'synth.ys'
    $commands=@("read_verilog -defer `"$converted`"", "chparam $argsText cgra_programmable",'hierarchy -check -top cgra_programmable',
      'synth -noabc -top cgra_programmable','check -assert',"tee -o `"$stat`" stat -json","tee -o `"$interface`" dump cgra_programmable")
    [IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $log=Join-Path $dir 'yosys.log'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -s $script *> $log
    $code=$LASTEXITCODE; $watch.Stop()
    if($code -ne 0) { throw "Whole-CGRA synthesis failed for $profile (exit $code)" }
    $counts=@([regex]::Matches((Get-Content $log -Raw),'Found and reported (\d+) problems') | ForEach-Object {[int]$_.Groups[1].Value})
    if(!$counts.Count -or $counts[-1] -ne 0) { throw "Missing final successful check for $profile" }
    $ports=@(Get-Content $interface | Where-Object {$_ -match '^\s+wire .*\b(input|output)\b'})
    if($ports.Count -ne 41) { throw "Unexpected top port count for $profile" }
    $inputBits=0; $outputBits=0
    foreach($port in $ports) {
      $width=1; if($port -match '\bwidth (\d+)') {$width=[int]$Matches[1]}
      if($port -match '\binput\b') {$inputBits+=$width} else {$outputBits+=$width}
    }
    $ctrlBits=39+($parameters.TILE_PORTS+4)*6+32
    $hostBits=72+$ctrlBits; $nocBits=$hostBits+3
    $expectedOutputs=8*37+$hostBits+2+$nocBits+2
    if($outputBits -ne $expectedOutputs -or $inputBits -ne $expectedOutputs+17) {throw "Unexpected top bit widths for $profile"}
    $report.profiles+=@{profile=$profile;parameters=$parameters;status='passed';elapsed_seconds=$watch.Elapsed.TotalSeconds;
      checks=$counts;top_ports=$ports;top_input_bits=$inputBits;top_output_bits=$outputBits;
      log_sha256=(Get-FileHash $log).Hash.ToLowerInvariant();stat_sha256=(Get-FileHash $stat).Hash.ToLowerInvariant()}
    $report | ConvertTo-Json -Depth 12 | Set-Content results/phase3-system-synthesis.json -Encoding utf8
    Write-Output "PHASE3_SYSTEM_SYNTHESIS_PASS $profile ports=41 input_bits=$inputBits output_bits=$outputBits seconds=$($watch.Elapsed.TotalSeconds)"
  }
} finally {Pop-Location; $env:PATH=$savedPath}
