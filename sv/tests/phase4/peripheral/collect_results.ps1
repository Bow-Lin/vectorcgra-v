[CmdletBinding()]
param([switch]$IncludeSystems,[switch]$Historical)
$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$cases=@('dma','dma-small','dma-python','dma-small-python','im2col','im2col-wide')
if($IncludeSystems){$cases+=@('dma-system','im2col-system')}
$results=@()
foreach($kind in $cases){
  $out=Join-Path $svRoot "build/phase4/peripheral/$kind"
  $run=Get-Content -Raw (Join-Path $out 'run.log');$negative=Get-Content -Raw (Join-Path $out 'negative.log')
  $referenceKind=$kind.Replace('-python','');$top='tb_'+$referenceKind.Replace('-','_')
  $pass=@($run -split "`r?`n"|Where-Object{$_ -match '^(DMA|IM2COL)(_SYSTEM)?_PASS'})
  if(!$pass.Count -or $negative -notmatch "$referenceKind mismatch cycle=20"){throw "$kind missing positive or deliberate-negative evidence"}
  $warningCounts=[ordered]@{}
  foreach($match in [regex]::Matches((Get-Content -Raw (Join-Path $out 'verilate.log')),'%Warning-([A-Z0-9_]+)')){
    $key=$match.Groups[1].Value;if(!$warningCounts.Contains($key)){$warningCounts[$key]=0};$warningCounts[$key]++
  }
  $hashes=[ordered]@{}
  $paths=@("tests/phase4/peripheral/$top.sv","tests/phase4/peripheral/run_components.sh",
    'rtl/peripheral/cgra_dma_engine.sv','rtl/peripheral/cgra_im2col_engine.sv',
    "reference/phase4/peripheral/$referenceKind/manifest.json")
  if($kind.EndsWith('-python')){$paths+=@("reference/phase4/peripheral/$referenceKind-pytrace/manifest.json","reference/phase4/peripheral/$referenceKind-pytrace/trace.hex")}
  foreach($p in $paths){$hashes[$p]=(Get-FileHash (Join-Path $svRoot $p) -Algorithm SHA256).Hash.ToLowerInvariant()}
  foreach($log in @('verilate.log','compile.log','run.log','negative.log')){
    $p="build/phase4/peripheral/$kind/$log";$hashes[$p]=(Get-FileHash (Join-Path $svRoot $p) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $compiledInputs=[ordered]@{};$changedAfterCompile=@()
  if($kind.EndsWith('-system')){
    # Verilator itself records the input paths for this particular compile.
    # Check timestamps before associating current SHA256 with that run.
    $database=Join-Path $out "V${top}__verFiles.dat"
    $generatedAt=(Get-Item $database).LastWriteTimeUtc
    $hashes["build/phase4/peripheral/$kind/V${top}__verFiles.dat"]=(Get-FileHash $database -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach($line in Get-Content $database){
      if($line -notmatch '^S .*"([^"]+)"$'){continue}
      $source=$Matches[1]
      if(![IO.Path]::IsPathRooted($source)){$source=Join-Path $svRoot $source}
      $source=[IO.Path]::GetFullPath($source)
      if(!$source.StartsWith($svRoot,[StringComparison]::OrdinalIgnoreCase)){continue}
      $relative=[IO.Path]::GetRelativePath($svRoot,$source).Replace('\','/')
      if((Get-Item $source).LastWriteTimeUtc -gt $generatedAt){$changedAfterCompile+=$relative}
      else {$compiledInputs[$relative]=(Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    if($changedAfterCompile.Count -and !$Historical){throw "$kind inputs changed after Verilator: $($changedAfterCompile -join ', ')"}
  }
  $oracle=if($kind.EndsWith('-python')){'Unmodified ac96 Python frozen input/output trace; independent mathematically correct transfers. Explicit BASELINE_TRANSLATED_SLICES=0 extension.'}else{'Unmodified ac96 frozen generated HDL, every external output bit including idle messages.'}
  $status=if($changedAfterCompile.Count){'passed_historical_inputs_final_source_rerun_required'}else{'passed'}
  $results+=[ordered]@{case=$kind;status=$status;oracle=$oracle;summary=$pass[0];negative_control='Nonzero exit at deliberately corrupted output bit cycle 20';warning_counts=$warningCounts;sha256=$hashes;compiled_input_sha256=$compiledInputs;inputs_changed_after_verilator=$changedAfterCompile}
}
$report=[ordered]@{baseline_commit='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b';seed=31415926;
  tools=[ordered]@{verilator='Verilator 5.050 2026-07-01 rev vUNKNOWN-built20260702';compiler='MSYS2 clang64 clang++ 22.1.8';yosys='Yosys 0.69+62 (0edda7a3a)';sv2v='0.0.13'};
  dma_contract='Default BASELINE_TRANSLATED_SLICES=1 retains frozen HDL lane-selection defect; correctness of all unique words is NOT claimed. Explicit 0 matches original Python and is not hardware-equivalent to the frozen HDL.';
  unsupported_dma_domain='nbytes must be a multiple of 4 for supported complete transfers; bounded 1-byte baseline-underflow trace is diagnostic only.';
  results=$results;synthesis='synthesis-results.json';
  limitations=@('Verilator two-state comparison; no claim of four-state power-on determinism for original unreset Im2col RAM/init/config state.','No mapping, PPA or timing results.','HDL default DMA test counts preserved incorrect MVIN words explicitly.','Historical collection never assigns current SHA256 to files changed after Verilator. Its original input record is hashed; final source regression remains required for those runs.')}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'component-results.json'),($report|ConvertTo-Json -Depth 14).Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
$results|ForEach-Object{[pscustomobject]$_}|Select-Object case,status,summary|Format-Table -AutoSize
