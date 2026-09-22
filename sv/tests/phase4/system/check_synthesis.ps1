[CmdletBinding()]
param(
  [string]$ToolRoot='D:/work/VectorCGRA/sys_lib/tools',
  [string[]]$Profiles=@('mesh4-tiles2','ring4-tiles2','mesh4-tiles2-registered','mesh4-tiles4','heterogeneous')
)
$ErrorActionPreference='Stop'
$svRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sv2v=Join-Path $ToolRoot 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$table=[ordered]@{
  'mesh4-tiles2'=@{MULTI_COLS=2;MULTI_ROWS=2;COLS=2;ROWS=2;TOPOLOGY=0;MEM_COMBINATIONAL=1}
  'ring4-tiles2'=@{MULTI_COLS=4;MULTI_ROWS=1;COLS=2;ROWS=2;TOPOLOGY=1;MEM_COMBINATIONAL=1}
  'mesh4-tiles2-registered'=@{MULTI_COLS=2;MULTI_ROWS=2;COLS=2;ROWS=2;TOPOLOGY=0;MEM_COMBINATIONAL=0}
  'mesh4-tiles4'=@{MULTI_COLS=2;MULTI_ROWS=2;COLS=4;ROWS=4;TOPOLOGY=0;MEM_COMBINATIONAL=1}
  'heterogeneous'=@{MULTI_COLS=2;MULTI_ROWS=2;COLS=3;ROWS=3;TILE_PORTS=8}
}
foreach($profile in $Profiles) {if(!$table.Contains($profile)) {throw "Unknown profile $profile"}}
$savedPath=$env:PATH
$env:PATH=(Join-Path $ToolRoot 'oss-cad-suite/bin')+';'+(Join-Path $ToolRoot 'oss-cad-suite/lib')+';'+$savedPath
Push-Location $svRoot
try {
  $out=Join-Path $svRoot 'build/phase4/system-synthesis'
  New-Item -ItemType Directory -Force $out | Out-Null
  $files=@();$includes=@()
  foreach($line in Get-Content filelists/phase4.f) {
    if($line.StartsWith('+incdir+')) {$includes+='--incdir='+$line.Substring(8)}
    elseif($line.Trim() -and !$line.StartsWith('#')) {$files+=$line.Trim()}
  }
  $files+='tests/phase4/template/synthesis_profile.sv'
  $includes+='--incdir=tests/phase4/template'
  $hashes=[ordered]@{}
  foreach($path in ($files+@('filelists/phase4.f','tests/phase4/template/heterogeneous/architecture.svh',$PSCommandPath)+@(Get-ChildItem rtl/common/*.svh,rtl/vendor/hardfloat/*.vi | ForEach-Object {$_.FullName}))) {
    $key=[IO.Path]::GetRelativePath($svRoot,(Resolve-Path $path).Path).Replace('\','/')
    $hashes[$key]=(Get-FileHash $path).Hash.ToLowerInvariant()
  }
  $converted=(Join-Path $out 'native.v').Replace('\','/')
  & $sv2v @includes @files "--write=$converted" *> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0) {throw 'Multi-CGRA sv2v failed'}
  foreach($entry in $hashes.GetEnumerator()) {
    if((Get-FileHash -LiteralPath $entry.Key).Hash.ToLowerInvariant() -ne $entry.Value) {
      throw "Source changed during conversion: $($entry.Key); rerun after edits finish"
    }
  }
  $report=[ordered]@{schema=1;timestamp_utc=[DateTime]::UtcNow.ToString('o');source_sha256=$hashes;
    tools=@{sv2v=(& $sv2v --numeric-version | Out-String).Trim();yosys=(& $yosys -V | Out-String).Trim()};
    converted_sha256=(Get-FileHash $converted).Hash.ToLowerInvariant();
    flow='Maintained DUT only: sv2v -> chparam -> hierarchy -check -> synth -noabc -> check -assert';
    area_measured=$false;frequency_measured=$false;profiles=@();
    limitations=@('Final zero-problem check is not a source-definedness or formal-equivalence proof.','Generic cells are not standard-cell area or Fmax.')}
  foreach($profile in $Profiles) {
    $dir=Join-Path $out $profile;New-Item -ItemType Directory -Force $dir | Out-Null
    $parameters=$table[$profile]
    $top=if($profile -eq 'heterogeneous') {'phase4_template_synth'} else {'cgra_multi'}
    $argsText=($parameters.GetEnumerator() | Sort-Object Name | ForEach-Object {"-set $($_.Key) $($_.Value)"}) -join ' '
    $stat=(Join-Path $dir 'stat.json').Replace('\','/');$interface=(Join-Path $dir 'top-interface.il').Replace('\','/')
    $script=Join-Path $dir 'synth.ys'
    $commands=@("read_verilog -defer `"$converted`"","chparam $argsText $top","hierarchy -check -top $top",
      "synth -noabc -top $top",'check -assert',"tee -o `"$stat`" stat -json","tee -o `"$interface`" dump $top")
    [IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $log=Join-Path $dir 'yosys.log';$watch=[Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -s $script *> $log
    $code=$LASTEXITCODE;$watch.Stop();if($code -ne 0) {throw "Synthesis failed: $profile (exit $code)"}
    $counts=@([regex]::Matches((Get-Content $log -Raw),'Found and reported (\d+) problems') | ForEach-Object {[int]$_.Groups[1].Value})
    if(!$counts.Count -or $counts[-1] -ne 0) {throw "Missing final check: $profile"}
    $ports=@(Get-Content $interface | Where-Object {$_ -match '^\s+wire .*\b(input|output)\b'})
    if($ports.Count -ne 8) {throw "Unexpected host-only interface: $profile"}
    $inputBits=0;$outputBits=0
    foreach($port in $ports) {
      $width=1;if($port -match '\bwidth (\d+)') {$width=[int]$Matches[1]}
      if($port -match '\binput\b') {$inputBits+=$width}else{$outputBits+=$width}
    }
    $tileIdBits=[int][Math]::Ceiling([Math]::Log2($parameters.COLS*$parameters.ROWS+1))
    $xBits=[Math]::Max(1,[int][Math]::Ceiling([Math]::Log2($parameters.MULTI_COLS)))
    $yBits=[Math]::Max(1,[int][Math]::Ceiling([Math]::Log2($parameters.MULTI_ROWS)))
    $ctrlBits=if($profile -eq 'heterogeneous') {143} else {119}
    $hostBits=($ctrlBits+51)+9+2*$tileIdBits+2*(2+$xBits+$yBits)
    if($inputBits -ne $hostBits+4 -or $outputBits -ne $hostBits+2) {throw "Unexpected host field width: $profile"}
    $report.profiles+=@{profile=$profile;top=$top;parameters=$parameters;status='passed';elapsed_seconds=$watch.Elapsed.TotalSeconds;
      checks=$counts;top_ports=$ports;top_input_bits=$inputBits;top_output_bits=$outputBits;
      log_sha256=(Get-FileHash $log).Hash.ToLowerInvariant();stat_sha256=(Get-FileHash $stat).Hash.ToLowerInvariant()}
    $report | ConvertTo-Json -Depth 12 | Set-Content results/phase4-system-synthesis.json -Encoding utf8
    Write-Output "PHASE4_SYSTEM_SYNTHESIS_PASS $profile ports=8 input_bits=$inputBits output_bits=$outputBits seconds=$($watch.Elapsed.TotalSeconds)"
  }
} finally {Pop-Location;$env:PATH=$savedPath}
