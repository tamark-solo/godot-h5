<#
.SYNOPSIS
  B07 — Báo cáo môi trường build (native + web) và ghi manifest.
.DESCRIPTION
  Kiểm version Python/SCons/MSVC/Windows SDK/Emscripten, in ra màn hình và ghi
  docs/logs/env-report-<timestamp>.txt. Không thay đổi cấu hình hệ thống.
.NOTES
  PowerShell 5.1 compatible. Chạy từ root AppGame.
#>
[CmdletBinding()]
param(
    [string]$OutDir = "docs/logs"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$text) { $lines.Add($text); Write-Host $text }

Add-Line "=== ENV REPORT ==="
Add-Line ("Generated : " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Add-Line ("Host      : " + $env:COMPUTERNAME + " / " + [System.Environment]::OSVersion.VersionString)
Add-Line ("Arch      : " + $env:PROCESSOR_ARCHITECTURE)
Add-Line ("Root      : " + $root)
Add-Line ""

Add-Line "--- Python (B03) ---"
$py = (Get-Command python -ErrorAction SilentlyContinue)
if ($py) {
    Add-Line ("path      : " + $py.Source)
    Add-Line ("version   : " + (& python --version 2>&1))
    Add-Line ("exe real  : " + (& python -c "import sys;print(sys.executable)" 2>&1))
} else { Add-Line "NOT FOUND" }
Add-Line ""

Add-Line "--- SCons (B04) ---"
$sc = (& python -m SCons --version 2>&1 | Select-Object -First 1)
if ($LASTEXITCODE -eq 0) { Add-Line ("version   : " + $sc) } else { Add-Line "NOT INSTALLED (python -m SCons failed)" }
Add-Line ""

Add-Line "--- MSVC / Windows SDK (B02) ---"
$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    Add-Line ("vs install: " + (& $vswhere -latest -products * -property installationPath 2>&1))
    Add-Line ("vs version: " + (& $vswhere -latest -property catalog_productDisplayVersion 2>&1))
} else { Add-Line "vswhere.exe NOT FOUND" }
$msvcRoot = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\*\*\VC\Tools\MSVC" -Directory -ErrorAction SilentlyContinue
if ($msvcRoot) { foreach ($m in $msvcRoot) { Add-Line ("MSVC tools: " + $m.Name + "  (" + $m.FullName + ")") } } else { Add-Line "MSVC tools NOT FOUND" }
$sdk = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\Include" -Directory -ErrorAction SilentlyContinue
if ($sdk) { foreach ($s in $sdk) { Add-Line ("Win SDK   : " + $s.Name) } } else { Add-Line "Windows SDK NOT FOUND" }
Add-Line ""

Add-Line "--- Emscripten (B05) ---"
$emsdkBat = Join-Path $root "third_party\emsdk\emsdk.bat"
if (Test-Path $emsdkBat) {
    $emcc = Join-Path $root "third_party\emsdk\upstream\emscripten\emcc.bat"
    if (Test-Path $emcc) { Add-Line ("emcc      : " + (& $emcc --version 2>&1 | Select-Object -First 1)) } else { Add-Line "emcc NOT INSTALLED (chua emsdk install)" }
    $verFile = Join-Path $root "third_party\emsdk\.emscripten"
    if (Test-Path $verFile) { Add-Line (".emscripten: " + (Get-Content $verFile -Raw).Trim()) }
} else { Add-Line "emsdk NOT FOUND" }
Add-Line ""

Add-Line "--- Git / engine checkout (A03/A04) ---"
Add-Line ("git       : " + (& git --version 2>&1))
. (Join-Path $root "tools/lib/resolve-engine.ps1")
try { $eng = Resolve-H5EngineDir $root } catch { $eng = Join-Path $root "engine\godot-h5" }
if (Test-Path (Join-Path $eng ".git")) {
    Add-Line ("engine HEAD: " + (& git -C $eng rev-parse HEAD 2>&1))
    Add-Line ("branch     : " + (& git -C $eng rev-parse --abbrev-ref HEAD 2>&1))
    Add-Line ("shallow    : " + (& git -C $eng rev-parse --is-shallow-repository 2>&1))
    Add-Line ("sparse     : " + (& git -C $eng config --get core.sparseCheckout 2>&1))
} else { Add-Line "engine/godot-h5 NOT CLONED YET" }
Add-Line ""

Add-Line "--- Disk ---"
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    if ($_.Free -ne $null) { Add-Line ("  " + $_.Name + ": free=" + [math]::Round($_.Free/1GB,1) + "GB used=" + [math]::Round($_.Used/1GB,1) + "GB") }
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$outFile = Join-Path $OutDir ("env-report-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
$lines | Set-Content -Path $outFile -Encoding UTF8
Write-Host ""
Write-Host ("Saved: " + $outFile)
