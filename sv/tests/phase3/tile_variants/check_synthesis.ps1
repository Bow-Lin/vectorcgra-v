[CmdletBinding()]
param([string]$ToolRoot=(Join-Path $PSScriptRoot '../../../../../../sys_lib/tools'),[switch]$ElaborateOnly)
$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$toolPath=[IO.Path]::GetFullPath($ToolRoot)
$sv2v=Join-Path $toolPath 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $toolPath 'oss-cad-suite/bin/yosys.exe'
$out=Join-Path $svRoot ('build/phase3/tile_variants/'+$(if($ElaborateOnly){'final-elaboration'}else{'synthesis'}))
New-Item -ItemType Directory -Force $out | Out-Null
$files=@('rtl/common/cgra_register_file.sv','rtl/common/cgra_queue.sv','rtl/common/cgra_channel.sv',
  'rtl/mem/register_bank.sv','rtl/mem/register_cluster.sv','rtl/tile/tile_link_or.sv',
  'rtl/fu/tile_adder.sv','rtl/fu/tile_multiplier.sv','rtl/fu/tile_memory_fu.sv','rtl/fu/tile_nah.sv',
  'rtl/fu/scalar/scalar_phi.sv','rtl/fu/streaming/tile_streaming_memory_fu.sv',
  'rtl/fu/tile_flexible_fu_configurable.sv')
$files+=Get-ChildItem (Join-Path $svRoot 'rtl/tile/variants') -Filter '*.sv' | ForEach-Object { 'rtl/tile/variants/'+$_.Name }
$native=Join-Path $out 'native.v'
$savedPath=$env:PATH
$results=@()
try {
  $env:PATH="$(Join-Path $toolPath 'oss-cad-suite/bin');$(Join-Path $toolPath 'oss-cad-suite/lib');$savedPath"
  $versions=[ordered]@{sv2v=(& $sv2v --numeric-version | Out-String).Trim();yosys=(& $yosys -V | Out-String).Trim()}
  $arguments=@('--incdir='+(Join-Path $svRoot 'rtl/common'))+@($files | ForEach-Object {Join-Path $svRoot $_})
  & $sv2v @arguments > $native 2> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0){throw 'sv2v failed; original diagnostic preserved'}
  foreach($kind in @('context','streaming')){
    $top='tile_'+$kind
    $profile=Join-Path $out $kind
    New-Item -ItemType Directory -Force $profile | Out-Null
    $parameters=if($kind -eq 'context'){'-set FU_COUNT 5 -set FU_KINDS 40''h0302010009 -set NUM_CTRL 1 -set TOTAL_STEPS 6'}else{'-set TILE_PORTS 8 -set FU_COUNT 4 -set FU_KINDS 32''h03200100 -set NUM_CTRL 2 -set TOTAL_STEPS 2'}
    $commands=@(('read_verilog -defer "'+$native.Replace('\','/')+'"'),
      "chparam $parameters $top", "hierarchy -check -top $top")
    if(!$ElaborateOnly){$commands+=@("synth -top $top -noabc",'check -assert',
      ('tee -o "'+(Join-Path $profile 'stat.json').Replace('\','/')+'" stat -json'))}
    $script=Join-Path $profile 'run.ys'
    [IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    & $yosys -Q -T -l (Join-Path $profile 'yosys.log') -s $script *> (Join-Path $profile 'console.log')
    $exit=$LASTEXITCODE;$watch.Stop()
    $log=Get-Content -Raw (Join-Path $profile 'yosys.log')
    $checks=@([regex]::Matches($log,'Found and reported (\d+) problems') | ForEach-Object {[int]$_.Groups[1].Value})
    $results+=[ordered]@{kind=$kind;exit_code=$exit;seconds=$watch.Elapsed.TotalSeconds;check_problem_counts=$checks;output=[IO.Path]::GetRelativePath($svRoot,$profile).Replace('\','/');parameters=$parameters}
    if($exit -ne 0){throw "$kind synthesis failed; no check disabled"}
    if(!$ElaborateOnly -and (!$checks.Count -or $checks[-1] -ne 0)){throw "$kind missing final check0"}
  }
} finally {
  $env:PATH=$savedPath
  $hashes=[ordered]@{}
  foreach($f in $files+@('rtl/common/cgra_profile.svh','rtl/common/cgra_profile_defs.svh','rtl/common/cgra_fu_catalog.svh')){
    $hashes[$f]=(Get-FileHash (Join-Path $svRoot $f) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $flow=if($ElaborateOnly){'Final source sv2v; Yosys deferred read/chparam/hierarchy -check only. Not a repeated synthesis.'}else{'sv2v; Yosys deferred read/chparam/hierarchy; synth -noabc; check -assert; stat -json. No mapping or timing.'}
  $report=[ordered]@{tool_versions=$versions;source_sha256=$hashes;profiles=$results;flow=$flow}
  if($ElaborateOnly){
    $previous=Get-Content -Raw (Join-Path $svRoot 'results/phase3-tile-variant-synthesis.json')|ConvertFrom-Json
    $key='rtl/fu/tile_flexible_fu_configurable.sv'
    $current=Get-Content -Raw (Join-Path $svRoot $key)
    $without=$current.Replace("    // Original FlexibleFuRTL constructs every child with its default factor.`n",'').Replace("    // Standalone FUs expose this parameter; the original composed Tile does not.`n",'').Replace('    if(VECTOR_FACTOR_POWER!=0) $fatal(1,"ac96 composed FU clusters require VECTOR_FACTOR_POWER=0");'+"`n",'')
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($without))).ToLowerInvariant()
    $otherChanges=@($hashes.Keys | Where-Object {$_ -ne $key -and $hashes[$_] -ne $previous.source_sha256.$_})
    $report.guard_delta_audit=[ordered]@{original_synthesis_sha=$previous.source_sha256.$key;final_source_sha=$hashes[$key];remove_exact_guard_sha=$hash;matches_original=($hash -eq $previous.source_sha256.$key);other_source_changes=$otherChanges;
      change='Two comments and an initial fatal for VECTOR_FACTOR_POWER!=0; both tested Tile profiles use 0. Original synthesis hashes remain unchanged in its report.'}
  }
  $name=if($ElaborateOnly){'phase3-tile-variant-final-elaboration.json'}else{'phase3-tile-variant-synthesis.json'}
  [IO.File]::WriteAllText((Join-Path $svRoot ('results/'+$name)),($report|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))
}
$results|ConvertTo-Json -Depth 8
