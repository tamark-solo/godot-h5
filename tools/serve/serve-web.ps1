<#
.SYNOPSIS
  G06 — Static server cho artifact Web (wrapper goi serve-web.py).
.EXAMPLE
  .\tools\serve\serve-web.ps1 -Dir builds\web\h5-demo-debug -Port 8060
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [int]$Port = 8060,
    [string]$Bind = "0.0.0.0"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if (-not (Test-Path $Dir)) { throw "Khong tim thay thu muc: $Dir" }

$py = Join-Path $root "tools\serve\serve-web.py"
& python $py $Dir $Port $Bind
