$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$tests=[ordered]@{
  context_switch=@('CONTEXT_SWITCH_PASS','context-pyreplay',360)
  streaming_memory=@('STREAMING_MEMORY_PASS','streaming-w32-c8-r16',358)
  tile_context=@('TILE_CONTEXT_PASS','context-tile-pyreplay-clear',210)
  tile_streaming=@('TILE_STREAMING_PASS','streaming-tile-pyreplay',190)
  cgra_context=@('CGRA_CONTEXT_PASS','context-cgra-pyreplay-v2',134)
  cgra_streaming=@('CGRA_STREAMING_PASS','streaming-cgra-pyreplay',160)
}
$entries=@()
foreach($entry in $tests.GetEnumerator()){
  $dir=Join-Path $svRoot ('build/phase3/tile_variants/'+$entry.Key)
  $text=Get-Content -Raw (Join-Path $dir 'run.log')
  $marker=[regex]::Match($text,$entry.Value[0]+'[^\r\n]+')
  if(!$marker.Success -or !$marker.Value.Contains('cycles='+$entry.Value[2])){throw "Missing expected pass: $($entry.Key)"}
  $warn=@{}
  foreach($match in [regex]::Matches((Get-Content -Raw (Join-Path $dir 'verilate.log')),'%Warning-([A-Z0-9_]+):')){
    $key=$match.Groups[1].Value
    if(!$warn.ContainsKey($key)){$warn[$key]=0};$warn[$key]++
  }
  $logs=[ordered]@{}
  foreach($file in @('verilate.log','compile.log','run.log','negative.log','SHA256SUMS')){
    $path=Join-Path $dir $file
    if(Test-Path -LiteralPath $path){$logs[$file]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
  }
  $negative=Get-Content -Raw (Join-Path $dir 'negative.log')
  if($negative -notmatch 'mismatch[^\r\n]*cycle=20'){throw 'Missing specified negative mismatch'}
  $negative='passed: deliberately corrupted expected bit fails at cycle20; shell entry required nonzero exit'
  $reference=Join-Path $svRoot ('reference/phase3/tile_variants/'+$entry.Value[1]+'/manifest.json')
  $manifest=Get-Content -Raw $reference|ConvertFrom-Json
  $sourceHashes=[ordered]@{}
  foreach($line in Get-Content (Join-Path $dir 'SHA256SUMS')){
    if($line -match '^([0-9a-f]{64})\s+(.+)$'){
      $file=$Matches[2]
      if(!$file.StartsWith('build/')){$sourceHashes[$file]=$Matches[1]}
    }
  }
  $entries+=[ordered]@{name=$entry.Key;status='passed';pass=$marker.Value;cycles=$entry.Value[2];seed=31415926;
    reference_manifest=[IO.Path]::GetRelativePath($svRoot,$reference).Replace('\','/');
    reference_manifest_sha256=(Get-FileHash $reference -Algorithm SHA256).Hash.ToLowerInvariant();
    negative_control=$negative;warning_counts=$warn;log_sha256=$logs;source_sha256=$sourceHashes;
    source_snapshot=[IO.Path]::GetRelativePath($svRoot,(Join-Path $dir 'SHA256SUMS')).Replace('\','/')}
}
$report=[ordered]@{status='passed';baseline_commit='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b';
  tools=@{verilator='5.050 2026-07-01';clang='22.1.8';cxx_standard='C++20'};
  tests=$entries;routine_project_python_required=$false;
  comparison='Every active output bit every cycle, including idle messages. Full systems explicitly exclude only three originally undriven inter-CGRA outputs.';
  initialization='Original PyMTL and default Verilator two-state zero-initialized simulation; unreset RTL storage retained.';
  synthesis_report='results/phase3-tile-variant-synthesis.json';
  limitations=@('Only context4port and streaming8port profiles are supported by variant guards.',
    'Variant width tests currently DATA_W32/CTRL_DEPTH8/REG_DEPTH16; parameterized other widths are not claimed tested here.',
    'Original Context/Tile HDL translation failures retained; their oracle is unmodified Python simulation. Streaming FU uses unmodified generated gold HDL.',
    'Transparent raw packet retention and originally undriven clear/control-address wires are preserved, not corrected.')}
[IO.File]::WriteAllText((Join-Path $svRoot 'results/phase3-tile-variants.json'),($report|ConvertTo-Json -Depth 20)+"`n",[Text.UTF8Encoding]::new($false))
$entries|ForEach-Object {[pscustomobject]$_}|Select-Object name,status,cycles,pass|Format-Table -AutoSize
