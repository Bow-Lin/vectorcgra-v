param(
  [string]$ToolRoot=(Join-Path $PSScriptRoot '../../../../../../sys_lib/tools'),
  [string]$Python=(Join-Path $PSScriptRoot '../../../../../../sys_lib/.venv/Scripts/python.exe')
)
$ErrorActionPreference='Stop'
$checker=Join-Path $PSScriptRoot '../../../migration_tools/phase4_noc_check.py'
& $Python $checker --tool-root $ToolRoot
if($LASTEXITCODE -ne 0){throw "NoC synthesis evidence failed: $LASTEXITCODE"}
