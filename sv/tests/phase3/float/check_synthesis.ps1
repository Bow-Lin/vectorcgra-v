param([string]$ToolRoot='D:/work/VectorCGRA/sys_lib/tools')
$ErrorActionPreference='Stop'
$svRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sv2v=Join-Path $ToolRoot 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$savedPath=$env:PATH
$env:PATH=(Join-Path $ToolRoot 'oss-cad-suite/bin')+';'+(Join-Path $ToolRoot 'oss-cad-suite/lib')+';'+$savedPath
Push-Location $svRoot
try {
  $out=Join-Path $svRoot 'build/phase3/float-synthesis'
  New-Item -ItemType Directory -Force $out | Out-Null
  $files=@(Get-Content filelists/phase3_float.f | Where-Object { $_ -notmatch '^\+' })
  $hashes=[ordered]@{}
  foreach($path in $files + @('filelists/phase3_float.f','rtl/common/cgra_profile.svh','rtl/common/cgra_profile_defs.svh')) {
    $hashes[$path]=(Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $converted=(Join-Path $out 'native.v').Replace('\','/')
  & $sv2v -Irtl/common -Irtl/vendor/hardfloat @files "--write=$converted" *> (Join-Path $out 'sv2v.log')
  if($LASTEXITCODE -ne 0) { throw 'FP sv2v failed' }
  $results=@()
  foreach($config in @(@('add',32,8,23),@('mul',32,8,23),@('add',16,4,11),@('mul',16,4,11))) {
    $name="$($config[0])-e$($config[2])-s$($config[3])"
    $top='tile_fp_'+$config[0]
    $stat=(Join-Path $out "$name-stat.json").Replace('\','/')
    $script=Join-Path $out "$name.ys"
    $commands=@("read_verilog -defer $converted", "chparam -set DATA_W $($config[1]) -set FP_EXP_W $($config[2]) -set FP_SIG_W $($config[3]) $top", "hierarchy -check -top $top", "synth -noabc -top $top",'check -assert',"tee -o $stat stat -json")
    [IO.File]::WriteAllText($script,($commands -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $log=Join-Path $out "$name.log"
    & $yosys -Q -T -s $script *> $log
    if($LASTEXITCODE -ne 0) { throw "FP synthesis failed: $name" }
    $checks=[regex]::Matches((Get-Content $log -Raw),'Found and reported (\d+) problems')
    if(!$checks.Count -or $checks[$checks.Count-1].Groups[1].Value -ne '0') { throw "Missing final zero-problem check: $name" }
    $results+=@{profile=$name;status='passed';log_sha256=(Get-FileHash $log).Hash.ToLowerInvariant();stat_sha256=(Get-FileHash $stat).Hash.ToLowerInvariant();final_problems=0}
    Write-Output "PHASE3_FLOAT_SYNTHESIS_PASS $name"
  }
  @{schema=1;timestamp_utc=[DateTime]::UtcNow.ToString('o');status='passed';source_sha256=$hashes;profiles=$results;flow='sv2v -> Yosys synth -noabc -> check -assert';area_measured=$false;frequency_measured=$false} | ConvertTo-Json -Depth 10 | Set-Content results/phase3-float-synthesis.json -Encoding utf8
} finally { Pop-Location; $env:PATH=$savedPath }
