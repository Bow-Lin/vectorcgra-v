[CmdletBinding()]
param([string]$ToolRoot=(Join-Path $PSScriptRoot '../../../../../../sys_lib/tools'))
$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$toolPath=[IO.Path]::GetFullPath($ToolRoot)
$sv2v=Join-Path $toolPath 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $toolPath 'oss-cad-suite/bin/yosys.exe'
$out=Join-Path $svRoot 'build/phase4/peripheral/synthesis'
New-Item -ItemType Directory -Force $out | Out-Null
$files=@('rtl/peripheral/cgra_dma_engine.sv','rtl/peripheral/cgra_im2col_engine.sv')
$savedPath=$env:PATH;$profiles=@();$versions=@{}
try {
  $env:PATH="$(Join-Path $toolPath 'oss-cad-suite/bin');$(Join-Path $toolPath 'oss-cad-suite/lib');$savedPath"
  $versions=[ordered]@{sv2v=(& $sv2v --numeric-version|Out-String).Trim();yosys=(& $yosys -V|Out-String).Trim()}
  $native=Join-Path $out 'native.v'
  & $sv2v ('--incdir='+(Join-Path $svRoot 'rtl/common')) @($files|ForEach-Object{Join-Path $svRoot $_}) > $native 2> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0){throw 'sv2v failed; original diagnostic retained'}
  foreach($kind in @('dma','dma-small','dma-python','dma-small-python','im2col','im2col-wide')) {
    $case=Join-Path $out $kind;New-Item -ItemType Directory -Force $case|Out-Null
    $referenceKind=$kind.Replace('-python','')
    $manifest=Get-Content -Raw (Join-Path $svRoot "reference/phase4/peripheral/$referenceKind/manifest.json")|ConvertFrom-Json
    $p=$manifest.parameters
    if($kind.StartsWith('dma')) {
      $top='cgra_dma_engine'
      $params="-set DRAM_ADDR_W $($p.DRAM_ADDR_W) -set SPM_ADDR_W $($p.SPM_ADDR_W) -set BYTES_W $($p.BYTES_W) -set TAG_W $($p.TAG_W)"
      if($kind.EndsWith('-python')){$params+=' -set BASELINE_TRANSLATED_SLICES 0'}
    } else {
      $top='cgra_im2col_engine';$image=[Numerics.BigInteger]::Zero
      for($i=0;$i -lt $p.preload_image.Count;$i++){$image=$image -bor ([Numerics.BigInteger]$p.preload_image[$i] -shl ($i*$p.DATA_W))}
      $hex=$image.ToString('x');$imageBits=$p.DATA_W*$p.SCRATCH_DEPTH
      $params="-set DATA_W $($p.DATA_W) -set SCRATCH_DEPTH $($p.SCRATCH_DEPTH) -set PRELOAD_IMAGE ${imageBits}'h${hex}"
    }
    $commands=@(('read_verilog -defer "'+$native.Replace('\','/')+'"'),"chparam $params $top","hierarchy -check -top $top","synth -top $top -noabc",'check -assert',('tee -o "'+(Join-Path $case 'stat.json').Replace('\','/')+'" stat -json'))
    $script=Join-Path $case 'run.ys';[IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -l (Join-Path $case 'yosys.log') -s $script *> (Join-Path $case 'console.log')
    $code=$LASTEXITCODE;$watch.Stop();$log=Get-Content -Raw (Join-Path $case 'yosys.log')
    $checks=@([regex]::Matches($log,'Found and reported (\d+) problems')|ForEach-Object{[int]$_.Groups[1].Value})
    $profiles+=[ordered]@{kind=$kind;parameters=$params;exit_code=$code;seconds=$watch.Elapsed.TotalSeconds;check_problem_counts=$checks;
      output=[IO.Path]::GetRelativePath($svRoot,$case).Replace('\','/');script_sha256=(Get-FileHash $script -Algorithm SHA256).Hash.ToLowerInvariant();
      yosys_log_sha256=(Get-FileHash (Join-Path $case 'yosys.log') -Algorithm SHA256).Hash.ToLowerInvariant()}
    if($code -ne 0 -or !$checks.Count -or $checks[-1] -ne 0){throw "$kind synth/check failed; no checks suppressed"}
  }
} finally {
  $env:PATH=$savedPath;$hashes=[ordered]@{}
  foreach($f in $files+@('rtl/common/cgra_profile.svh','rtl/common/cgra_profile_defs.svh')){$hashes[$f]=(Get-FileHash (Join-Path $svRoot $f) -Algorithm SHA256).Hash.ToLowerInvariant()}
  $report=[ordered]@{tool_versions=$versions;flow='sv2v; read_verilog -defer; chparam; hierarchy -check; synth -noabc; check -assert; stat -json. No mapping or timing.';source_sha256=$hashes;profiles=$profiles}
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'synthesis-results.json'),($report|ConvertTo-Json -Depth 12).Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
}
$profiles|ConvertTo-Json -Depth 8
