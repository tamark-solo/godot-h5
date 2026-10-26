<#
.SYNOPSIS
  C02 / E08 — Build Windows editor tu fork (control hoac candidate).
.DESCRIPTION
  Nap MSVC env, chay scons platform=windows target=editor arch=x86_64, ghi log,
  va xuat hash cua artifact. Khong tu dong patch source.
.EXAMPLE
  .\tools\build\build-editor.ps1 -Label control
  .\tools\build\build-editor.ps1 -Label fork-e08 -ExtraArgs @("module_...=no")
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Label,
    [string[]]$ExtraArgs = @(),
    [string]$EngineDir = "",
    [string]$OutDir = "builds",
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tools/lib/resolve-engine.ps1")
if ([string]::IsNullOrEmpty($EngineDir)) { $EngineDir = Resolve-H5EngineDir $root }
Set-Location $root

if (-not (Test-Path (Join-Path $EngineDir ".git"))) { throw "Khong tim thay engine checkout: $EngineDir" }

$sha = (& git -C $EngineDir rev-parse HEAD).Trim()
$branch = (& git -C $EngineDir rev-parse --abbrev-ref HEAD).Trim()
$dirty = (& git -C $EngineDir status --porcelain | Measure-Object -Line).Lines
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $root "docs\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$log = Join-Path $logDir ("build-editor-" + $Label + "-" + $stamp + ".log")

Write-Host "=== Build Windows editor: $Label ==="
Write-Host "source SHA : $sha"
Write-Host "branch     : $branch"
Write-Host "dirty files: $dirty"
Write-Host "log        : $log"

# Nap MSVC env
$ErrorActionPreference = "Continue"
. (Join-Path $root "tools\env\Enter-NativeShell.ps1") | Out-Null
$ErrorActionPreference = "Stop"
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw "cl.exe khong co trong PATH sau khi nap vcvars" }

$sconsArgs = @("platform=windows", "target=editor", "arch=x86_64") + $ExtraArgs
if ($NoCache) { $sconsArgs += "cache_path=" }

$header = @(
    "=== build-editor ===",
    "label      : $Label",
    "started    : $(Get-Date -Format o)",
    "source SHA : $sha",
    "branch     : $branch",
    "dirty      : $dirty",
    "scons args : $($sconsArgs -join ' ')",
    "python     : $(& python --version 2>&1)",
    "scons      : $(& python -m SCons --version 2>&1 | Select-Object -First 1)",
    "cl.exe     : $((Get-Command cl.exe).Source)",
    ""
)
$header | Set-Content -Path $log -Encoding UTF8

# QUAN TRONG: SCons/cl.exe ghi nhieu thong tin ra stderr. Trong PowerShell 5.1,
# native stderr tro thanh terminating error khi $ErrorActionPreference='Stop'.
# Phai ha xuong 'Continue' va tu kiem tra $LASTEXITCODE.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
Push-Location $EngineDir
try {
    & python -m SCons @sconsArgs 2>&1 | Tee-Object -FilePath $log -Append
    $code = $LASTEXITCODE
} finally {
    Pop-Location
    $ErrorActionPreference = $prevEap
}

Add-Content -Path $log -Value ""
Add-Content -Path $log -Value ("scons exit : $code")
Add-Content -Path $log -Value ("finished   : $(Get-Date -Format o)")

if ($code -ne 0) { throw "Build that bai (exit $code). Xem log: $log" }

# Thu thap artifact
$binDir = Join-Path $EngineDir "bin"
# Uu tien ban GUI (khong co hau to .console); van giu ban console cho CLI.
$exe = Get-ChildItem (Join-Path $binDir "godot.windows.editor.x86_64.exe") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) {
    $exe = Get-ChildItem (Join-Path $binDir "godot.windows.editor.x86_64*.exe") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $exe) { throw "Khong tim thay editor EXE trong $binDir" }

$hash = (Get-FileHash $exe.FullName -Algorithm SHA256).Hash
$destDir = Join-Path $root (Join-Path $OutDir ("editor-" + $Label))
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$dest = Join-Path $destDir $exe.Name
Copy-Item $exe.FullName $dest -Force
# Copy kem ban console (dung cho export CLI --headless)
$console = Get-ChildItem (Join-Path $binDir "godot.windows.editor.x86_64.console.exe") -ErrorAction SilentlyContinue | Select-Object -First 1
if ($console) { Copy-Item $console.FullName (Join-Path $destDir $console.Name) -Force }

$manifest = [ordered]@{
    label        = $Label
    kind         = "windows-editor"
    builtAt      = (Get-Date -Format o)
    sourceSha    = $sha
    branch       = $branch
    dirtyFiles   = $dirty
    sconsArgs    = $sconsArgs
    artifact     = $dest
    sha256       = $hash
    sizeBytes    = (Get-Item $dest).Length
    log          = $log
}
$mfPath = Join-Path $destDir "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $mfPath -Encoding UTF8

Write-Host ""
Write-Host "=== OK ==="
Write-Host "artifact : $dest"
Write-Host "sha256   : $hash"
Write-Host "manifest : $mfPath"