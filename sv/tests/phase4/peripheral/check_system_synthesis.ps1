[CmdletBinding()]
param([string]$ToolRoot=(Join-Path $PSScriptRoot '../../../../../../sys_lib/tools'))
$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$toolPath=[IO.Path]::GetFullPath($ToolRoot)
$sv2v=Join-Path $toolPath 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $toolPath 'oss-cad-suite/bin/yosys.exe'
$out=Join-Path $svRoot 'build/phase4/peripheral/system-synthesis'
New-Item -ItemType Directory -Force $out | Out-Null
$files=@();$includes=@()
foreach($list in @('filelists/phase4.f','filelists/phase4_peripheral.f')){
  foreach($line in Get-Content (Join-Path $svRoot $list)){
    $line=$line.Trim();if(!$line -or $line.StartsWith('#')){continue}
    if($line.StartsWith('+incdir+')){$includes+=Join-Path $svRoot $line.Substring(8)}else{$files+=$line}
  }
}
$files+=@('rtl/peripheral/cgra_integrated_dma.sv','rtl/peripheral/cgra_integrated_im2col.sv')
$files=@($files|Select-Object -Unique);$includes=@($includes|Select-Object -Unique)
$savedPath=$env:PATH;$profiles=@();$versions=@{};$hashes=[ordered]@{}
foreach($f in $files){$hashes[$f]=(Get-FileHash (Join-Path $svRoot $f) -Algorithm SHA256).Hash.ToLowerInvariant()}
foreach($directory in $includes){
  foreach($header in Get-ChildItem $directory -File){
    $relative=[IO.Path]::GetRelativePath($svRoot,$header.FullName).Replace('\','/')
    $hashes[$relative]=(Get-FileHash $header.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
}
try {
  $env:PATH="$(Join-Path $toolPath 'oss-cad-suite/bin');$(Join-Path $toolPath 'oss-cad-suite/lib');$savedPath"
  $versions=[ordered]@{sv2v=(& $sv2v --numeric-version|Out-String).Trim();yosys=(& $yosys -V|Out-String).Trim()}
  $native=Join-Path $out 'native.v'
  $conversionArgs=@($includes|ForEach-Object{'--incdir='+$_})+@($files|ForEach-Object{Join-Path $svRoot $_})
  & $sv2v @conversionArgs > $native 2> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0){throw 'System sv2v failed; original diagnostic retained'}
  foreach($kind in @('dma','im2col')){
    $case=Join-Path $out $kind;New-Item -ItemType Directory -Force $case|Out-Null
    $top='cgra_integrated_'+$kind
    $bench=Get-Content -Raw (Join-Path $PSScriptRoot "tb_${kind}_system.sv")
    $parameterBlock=[regex]::Match($bench,"(?s)$top\s*#\((.*?)\)\s+dut").Groups[1].Value
    if(!$parameterBlock){throw "Missing actual simulation profile: $kind"}
    $params=(@([regex]::Matches($parameterBlock,'\.(\w+)\(([^)]*)\)'))|ForEach-Object{'-set '+$_.Groups[1].Value+' '+$_.Groups[2].Value}) -join ' '
    $commands=@(('read_verilog -defer "'+$native.Replace('\','/')+'"'),"chparam $params $top","hierarchy -check -top $top",
      ('tee -o "'+(Join-Path $case 'ports.txt').Replace('\','/')+'" dump '+$top+'/x:*'),
      "synth -top $top -noabc",'check -assert',('tee -o "'+(Join-Path $case 'stat.json').Replace('\','/')+'" stat -json'))
    $script=Join-Path $case 'run.ys';[IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -l (Join-Path $case 'yosys.log') -s $script *> (Join-Path $case 'console.log')
    $code=$LASTEXITCODE;$watch.Stop();$log=Get-Content -Raw (Join-Path $case 'yosys.log')
    $checks=@([regex]::Matches($log,'Found and reported (\d+) problems')|ForEach-Object{[int]$_.Groups[1].Value})
    $stat=$null;if(Test-Path (Join-Path $case 'stat.json')){$stat=Get-Content -Raw (Join-Path $case 'stat.json')|ConvertFrom-Json}
    $profiles+=[ordered]@{kind=$kind;top=$top;parameters=$params;exit_code=$code;seconds=$watch.Elapsed.TotalSeconds;check_problem_counts=$checks;
      generic_num_cells=$stat.design.num_cells;output=[IO.Path]::GetRelativePath($svRoot,$case).Replace('\','/');
      script_sha256=(Get-FileHash $script -Algorithm SHA256).Hash.ToLowerInvariant();
      yosys_log_sha256=(Get-FileHash (Join-Path $case 'yosys.log') -Algorithm SHA256).Hash.ToLowerInvariant()}
    if($code -ne 0 -or !$checks.Count -or $checks[-1] -ne 0){throw "$kind system synth/check failed; no checks suppressed"}
  }
} finally {
  $env:PATH=$savedPath;$changed=@()
  foreach($f in $hashes.Keys){if($hashes[$f] -ne (Get-FileHash (Join-Path $svRoot $f) -Algorithm SHA256).Hash.ToLowerInvariant()){$changed+=$f}}
  $report=[ordered]@{tool_versions=$versions;flow='DUT-only sv2v; read_verilog -defer; exact simulation chparam profile; hierarchy -check; synth -noabc; check -assert; stat -json. All top ports remain exposed; no mapping or timing; no whole-netlist JSON.';source_sha256=$hashes;source_changes_during_run=$changed;profiles=$profiles}
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'system-synthesis-results.json'),($report|ConvertTo-Json -Depth 12).Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
}
if($changed.Count){throw "Sources changed during system synthesis: $($changed -join ', ')"}
$profiles|ConvertTo-Json -Depth 8
