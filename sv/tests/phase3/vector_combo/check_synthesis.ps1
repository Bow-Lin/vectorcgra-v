param([string]$ToolRoot=(Join-Path $PSScriptRoot '../../../../../../sys_lib/tools'),[switch]$MacOnly,[switch]$HierarchicalOnly)
$ErrorActionPreference='Stop'
$svRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$build=Join-Path $svRoot 'build/phase3/vector_combo/synthesis'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$sv2v=Join-Path $ToolRoot 'sv2v-v0.0.13/sv2v-Windows/sv2v.exe'
$yosys=Join-Path $ToolRoot 'oss-cad-suite/bin/yosys.exe'
$files=@('cgra_multp.sv','cgra_alu_gen_mac_core.sv','cgra_alu_gen_mac.sv','tile_alu_gen_mac.sv') |
  ForEach-Object {Join-Path $svRoot "rtl/fu/combo/$_"}
$converted=Join-Path $build 'mac.v'
& $sv2v "-I$(Join-Path $svRoot 'rtl/common')" "--write=$converted" @files 2> (Join-Path $build 'sv2v.log')
if($LASTEXITCODE -ne 0){throw "sv2v failed: $LASTEXITCODE"}
$v=$converted.Replace('\','/')
$commands=@()
$cases=@(
  @('cgra_multp','-set A_W 1 -set B_W 1 -set OUT_W 4'),
  @('cgra_multp','-set A_W 5 -set B_W 3 -set OUT_W 16'),
  @('cgra_multp','-set A_W 16 -set B_W 16 -set OUT_W 34'),
  @('cgra_multp','-set A_W 17 -set B_W 11 -set OUT_W 32'),
  @('cgra_alu_gen_mac_core',''),
  @('cgra_alu_gen_mac',''),
  @('tile_alu_gen_mac','-set DATA_W 16')
)
foreach($case in $cases){
  $commands+='design -reset'
  $commands+="read_verilog -defer `"$v`""
  if($case[1]){$commands+="chparam $($case[1]) $($case[0])"}
  $commands+="hierarchy -check -top $($case[0])"
  $commands+=@('proc','opt','check -assert','stat')
}
$script=Join-Path $build 'check.ys'
$commands | Set-Content -LiteralPath $script -Encoding ascii
$saved=$env:PATH
try{
  $env:PATH="$(Join-Path $ToolRoot 'oss-cad-suite/bin');$(Join-Path $ToolRoot 'oss-cad-suite/lib');$saved"
  & $yosys -Q -T -l (Join-Path $build 'yosys.log') -s $script *> (Join-Path $build 'console.log')
  if($LASTEXITCODE -ne 0){throw "Yosys failed: $LASTEXITCODE"}
}finally{$env:PATH=$saved}
Write-Output 'P3_NATIVE_MAC_SYNTHESIS_PASS profiles=7'
if($MacOnly){exit 0}

# Elaborate every non-MAC tested profile independently; file parsing alone is
# not evidence that a parameterized module is synthesizable. Preserve failures.
$extended=Join-Path $build $(if($HierarchicalOnly){'extended'}else{'extended_flat'})
New-Item -ItemType Directory -Force -Path $extended | Out-Null
$extra=@('rtl/fu/tile_adder.sv','rtl/fu/tile_multiplier.sv',
  'rtl/fu/scalar/scalar_shifter.sv','rtl/fu/scalar/scalar_comp.sv',
  'rtl/fu/scalar/scalar_logic.sv','rtl/fu/scalar/scalar_grant.sv') |
  ForEach-Object {Join-Path $svRoot $_}
$allFiles=@($extra)+@(Get-ChildItem (Join-Path $svRoot 'rtl/fu/vector/*.sv') | ForEach-Object FullName)+
  @(Get-ChildItem (Join-Path $svRoot 'rtl/fu/combo/*.sv') | ForEach-Object FullName)
$extendedV=Join-Path $extended 'native.v'
& $sv2v "-I$(Join-Path $svRoot 'rtl/common')" "--write=$extendedV" @allFiles 2> (Join-Path $extended 'sv2v.log')
if($LASTEXITCODE -ne 0){throw "Extended sv2v failed: $LASTEXITCODE"}
$nativeV=$extendedV.Replace('\','/')
$results=@()
$sourceHashes=[ordered]@{}
foreach($file in $allFiles + @((Join-Path $svRoot 'rtl/common/cgra_profile.svh'),(Join-Path $svRoot 'rtl/common/cgra_profile_defs.svh'))){
  $sourceHashes[[IO.Path]::GetRelativePath($svRoot,$file).Replace('\','/')]=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()
}
try{
  $env:PATH="$(Join-Path $ToolRoot 'oss-cad-suite/bin');$(Join-Path $ToolRoot 'oss-cad-suite/lib');$saved"
  foreach($definition in Get-ChildItem (Join-Path $PSScriptRoot '*/test.json') | Sort-Object FullName){
    $config=Get-Content -LiteralPath $definition.FullName -Raw | ConvertFrom-Json
    if($config.case -like 'alu_gen_mac*'){continue}
    $parameters="-set DATA_W $($config.parameters.DATA_W)"
    if($config.case -eq 'vector_adder' -or $config.case -eq 'vector_mul'){
      $parameters+=" -set LANE_W $($config.parameters.LANE_W)"
    }elseif($config.case -like 'vector_*'){
      $parameters+=" -set LANES $($config.parameters.LANES) -set VECTOR_FACTOR_POWER $($config.parameters.VECTOR_FACTOR_POWER)"
    }
    $scriptPath=Join-Path $extended "$($config.label).ys"
    $logPath=Join-Path $extended "$($config.label).log"
    $beforeJson=(Join-Path $extended "$($config.label)-before.json").Replace('\','/')
    $afterJson=(Join-Path $extended "$($config.label)-after.json").Replace('\','/')
    $flow=@("read_verilog -defer `"$nativeV`"","chparam $parameters $($config.native_module)",
      "hierarchy -check -top $($config.native_module)",'proc')
    if($HierarchicalOnly){$flow+=@('opt','check -assert','stat')}
    else{$flow+=@("write_json `"$beforeJson`"",'flatten','opt','check',
      "synth -noabc -top $($config.native_module)",'check -assert',"write_json `"$afterJson`"",'stat')}
    [IO.File]::WriteAllText($scriptPath,($flow -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    & $yosys -Q -T -s $scriptPath *> $logPath
    $code=$LASTEXITCODE
    $logText=Get-Content -LiteralPath $logPath -Raw
    $problems=[regex]::Matches($logText,'Found and reported (\d+) problems')
    $messages=@([regex]::Matches($logText,'(?m)^(?:Warning:|ERROR:).*$') |
      ForEach-Object { $_.Value -replace ' \[\d+\]',' [*]' } | Sort-Object -Unique)
    $portsPreserved=$null
    $blackboxes=$null
    if(-not $HierarchicalOnly -and $code -eq 0){
      $before=Get-Content -LiteralPath $beforeJson -Raw | ConvertFrom-Json
      $after=Get-Content -LiteralPath $afterJson -Raw | ConvertFrom-Json
      $beforePorts=$before.modules.($config.native_module).ports
      $afterPorts=$after.modules.($config.native_module).ports
      $portsPreserved=$true
      if(@($beforePorts.PSObject.Properties).Count -ne @($afterPorts.PSObject.Properties).Count){$portsPreserved=$false}
      foreach($port in $beforePorts.PSObject.Properties){
        $new=$afterPorts.($port.Name)
        if(!$new -or $new.direction -ne $port.Value.direction -or $new.bits.Count -ne $port.Value.bits.Count){$portsPreserved=$false}
      }
      $blackboxes=@($after.modules.PSObject.Properties | Where-Object { $_.Value.attributes.blackbox -match '1' }).Count
      if(-not $portsPreserved -or $blackboxes){$code=2}
    }
    $results+=@{label=$config.label;module=$config.native_module;parameters=$parameters;
      exit_code=$code;status=$(if($code -eq 0){'pass'}else{'fail'});
      final_problems=$(if($problems.Count){[int]$problems[$problems.Count-1].Groups[1].Value}else{$null});
      top_ports_preserved=$portsPreserved;blackbox_modules=$blackboxes;
      diagnostics=$messages;log_sha256=(Get-FileHash -LiteralPath $logPath).Hash.ToLowerInvariant()}
    Write-Output "P3_EXTENDED_SYNTHESIS $($config.label) exit=$code"
  }
}finally{$env:PATH=$saved}
$failed=@($results | Where-Object exit_code -ne 0)
$summary=@{schema=1;status=$(if($failed.Count){'failed'}else{'pass'});mac_profiles_passed=7;
  extended_profiles=$results;source_sha256=$sourceHashes;
  flow=$(if($HierarchicalOnly){'sv2v -> hierarchy -check -> proc -> opt -> check -assert -> stat'}else{'sv2v -> hierarchy -check -> proc -> flatten -> opt -> check -> synth -noabc -> check -assert -> stat'});
  failed_profiles=$failed.Count;area_measured=$false;frequency_measured=$false}
$jsonPath=Join-Path $PSScriptRoot $(if($HierarchicalOnly){'synthesis_hierarchical_results.json'}else{'synthesis_results.json'})
[IO.File]::WriteAllText($jsonPath,($summary | ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))
if($failed.Count){throw "$($failed.Count) extended profiles failed; see synthesis_results.json and preserved logs"}
Write-Output "P3_VECTOR_SYNTHESIS_PASS mac=7 extended=$($results.Count)"
