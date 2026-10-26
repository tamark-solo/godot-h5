<#
.SYNOPSIS
  C05/C06 / F02/F03 / H04/H05 — Build Web export template (debug hoac release).
.DESCRIPTION
  Nap emsdk env, chay scons platform=web target=template_<flavor> arch=wasm32
  threads=no dlink_enabled=no, ghi log va xuat hash cua ZIP.
  LUU Y: debug va release dung chung bin/.web_zip -> KHONG chay song song.
.EXAMPLE
  .\tools\build\build-web.ps1 -Flavor debug   -Label control
  .\tools\build\build-web.ps1 -Flavor release -Label fork-f03
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet("debug","release")][string]$Flavor,
    [Parameter(Mandatory=$true)][string]$Label,
    [string[]]$ExtraArgs = @(),
    [string]$EmsdkVersion = "4.0.23",
    [string]$EngineDir = "",
    [string]$OutDir = "builds",
    [switch]$NoCache,
    [switch]$CollectOnly
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
$log = Join-Path $logDir ("build-web-" + $Flavor + "-" + $Label + "-" + $stamp + ".log")

Write-Host "=== Build Web template ($Flavor): $Label ==="
Write-Host "source SHA : $sha"
Write-Host "branch     : $branch"
Write-Host "dirty files: $dirty"

if (-not $CollectOnly) {
    # Nap emsdk env (cham: emsdk chay sanity check). Bo qua khi chi thu thap artifact.
    $ErrorActionPreference = "Continue"
    . (Join-Path $root "tools\env\Enter-WebShell.ps1") -EmsdkVersion $EmsdkVersion | Out-Null
    $ErrorActionPreference = "Stop"
    if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) { throw "emcc khong co trong PATH sau khi activate emsdk" }
} else {
    Write-Host "CollectOnly: bo qua emsdk activation va buoc build."
}

$sconsArgs = @("platform=web", ("target=template_" + $Flavor), "arch=wasm32", "threads=no", "dlink_enabled=no") + $ExtraArgs
if ($NoCache) { $sconsArgs += "cache_path=" }

$header = @(
    "=== build-web ($Flavor) ===",
    "label      : $Label",
    "started    : $(Get-Date -Format o)",
    "source SHA : $sha",
    "branch     : $branch",
    "dirty      : $dirty",
    "scons args : $($sconsArgs -join ' ')",
    "python     : $(& python --version 2>&1)",
    "scons      : $(& python -m SCons --version 2>&1 | Select-Object -First 1)",
    "emcc       : $(if (Get-Command emcc -ErrorAction SilentlyContinue) { (Get-Content (Join-Path (Split-Path (Get-Command emcc).Source) 'emscripten-version.txt') -Raw -ErrorAction SilentlyContinue).Trim() } else { 'chua activate' })",
    ""
)
$header | Set-Content -Path $log -Encoding UTF8

# QUAN TRONG: SCons/cl.exe ghi nhieu thong tin ra stderr. Trong PowerShell 5.1,
# native stderr tro thanh terminating error khi $ErrorActionPreference='Stop'.
# Phai ha xuong 'Continue' va tu kiem tra $LASTEXITCODE.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
if ($CollectOnly) {
    $code = 0
} else {
    Push-Location $EngineDir
    try {
        & python -m SCons @sconsArgs 2>&1 | Tee-Object -FilePath $log -Append
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
        $ErrorActionPreference = $prevEap
    }
}

Add-Content -Path $log -Value ""
Add-Content -Path $log -Value ("scons exit : $code")
Add-Content -Path $log -Value ("finished   : $(Get-Date -Format o)")

if ($code -ne 0) { throw "Build that bai (exit $code). Xem log: $log" }

# Thu thap artifact.
# Godot archive template ra: bin/godot.web.template_<flavor>.wasm32[.nothreads].zip
# (bin/.web_zip/ chi la thu muc staging da giai nen, KHONG chua ZIP.)
$binDir = Join-Path $EngineDir "bin"
$zip = Get-ChildItem (Join-Path $binDir ("godot.web.template_" + $Flavor + "*.zip")) -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) {
    # Du phong: tim bat ky zip template nao khop flavor
    $zip = Get-ChildItem $binDir -Filter "*.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match ("template_" + $Flavor) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $zip) { throw "Khong tim thay web template ZIP trong $binDir" }

$hash = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash
$destDir = Join-Path $root (Join-Path $OutDir ("web-" + $Flavor + "-" + $Label))
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$dest = Join-Path $destDir $zip.Name
Copy-Item $zip.FullName $dest -Force

# Lay version emcc mot lan.
#
# KHONG goi "emcc --version" tu day: emcc phan giai thanh emcc.ps1 (ExternalScript),
# va cmd /c khong chay duoc .ps1; goi truc tiep thi PowerShell 5.1 lai bien
# dong "Running sanity checks" tren stderr thanh terminating error.
# Nguon on dinh nhat la file version do chinh emsdk ghi ra.
$emccVersion = "n/a"

# Nguon 1: PATH (khi da activate emsdk)
$emccCmd = Get-Command emcc -ErrorAction SilentlyContinue
if ($emccCmd) {
    $verFile = Join-Path (Split-Path $emccCmd.Source) "emscripten-version.txt"
    if (Test-Path $verFile) { $emccVersion = (Get-Content $verFile -Raw).Trim().Trim('"') }
}

# Nguon 2: truc tiep trong cay emsdk (CollectOnly KHONG activate emsdk, nen
# emcc khong co trong PATH — van phai ghi duoc version vao manifest).
if ($emccVersion -eq "n/a") {
    $verFile2 = Join-Path $root "third_party/emsdk/upstream/emscripten/emscripten-version.txt"
    if (Test-Path $verFile2) { $emccVersion = (Get-Content $verFile2 -Raw).Trim().Trim('"') }
}

# Nguon 3: .emscripten cua emsdk
if ($emccVersion -eq "n/a") {
    $emFile = Join-Path $root "third_party/emsdk/.emscripten"
    if (Test-Path $emFile) {
        $m = Select-String -Path $emFile -Pattern 'EMSCRIPTEN_VERSION\s*=\s*[\x27"]([^\x27"]+)' | Select-Object -First 1
        if ($m -and $m.Matches.Count -gt 0) { $emccVersion = $m.Matches[0].Groups[1].Value }
    }
}

if ($emccVersion -eq "n/a") { $emccVersion = "khong xac dinh duoc" }

$manifest = [ordered]@{
    label       = $Label
    kind        = "web-template"
    flavor      = $Flavor
    builtAt     = (Get-Date -Format o)
    sourceSha   = $sha
    branch      = $branch
    dirtyFiles  = $dirty
    sconsArgs   = $sconsArgs
    emcc        = $emccVersion
    artifact    = $dest
    sha256      = $hash
    sizeBytes   = (Get-Item $dest).Length
    log         = $log
}
$mfPath = Join-Path $destDir "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $mfPath -Encoding UTF8

Write-Host ""
Write-Host "=== OK ==="
Write-Host "artifact : $dest"
Write-Host "sha256   : $hash"
Write-Host "manifest : $mfPath"