<#
.SYNOPSIS
  B07 — Nạp môi trường Emscripten (emsdk) vào phiên PowerShell hiện tại.
.DESCRIPTION
  Dot-source script này trước khi build web:
      . .\tools\env\Enter-WebShell.ps1
.NOTES
  PowerShell 5.1 compatible.
#>
[CmdletBinding()]
param(
    [string]$EmsdkVersion = "4.0.23"
)

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$emsdkBat = Join-Path $root "third_party\emsdk\emsdk.bat"
if (-not (Test-Path $emsdkBat)) { throw "Khong tim thay emsdk: $emsdkBat" }

Write-Host ("Activating emsdk " + $EmsdkVersion)
$activate = Join-Path $root "third_party\emsdk\emsdk_env.ps1"
if (-not (Test-Path $activate)) { throw "Chua install emsdk (thieu emsdk_env.ps1). Chay: emsdk install $EmsdkVersion" }

& $activate | Out-Null

# emcc cung ghi "Running sanity checks" ra stderr -> xu ly nhu Enter-NativeShell.ps1
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $emcc = Get-Command emcc -ErrorAction SilentlyContinue
    if ($emcc) {
        Write-Host ("OK  emcc : " + $emcc.Source)
        $emccVer = (& cmd /c "`"$($emcc.Source)`" --version 2>&1" | Select-Object -First 1)
        Write-Host ("OK  ver  : " + $emccVer)
    } else {
        Write-Warning "emcc van chua co trong PATH"
    }
} finally {
    $ErrorActionPreference = $prevEap
}