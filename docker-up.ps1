# Compatibility shim: all logic lives in install.ps1.
param([Parameter(Position = 0)][string]$Action = "up", [Parameter(Position = 1)][string]$Arg = "")
& (Join-Path $PSScriptRoot "install.ps1") $Action $Arg
exit $LASTEXITCODE
