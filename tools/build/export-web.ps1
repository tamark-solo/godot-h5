<#
.SYNOPSIS
  C07 / G04 — Export Web qua CLI, có kiểm soát output sạch và build ID.
.DESCRIPTION
  Quy tắc (theo G04/G05):
   - Output folder được DỌN trước khi export (tránh stale output).
   - Export thất bại => KHÔNG để lại artifact cũ như thể thành công.
   - Ghi build ID + manifest cạnh artifact.
   - Không tự mở browser (việc mở là của luồng preview).
.EXAMPLE
  .\tools\build\export-web.ps1 -Project projects\h5-demo -Flavor debug
  .\tools\build\export-web.ps1 -Project projects\h5-demo -Flavor release -Preset Web
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [Parameter(Mandatory=$true)][ValidateSet("debug","release")][string]$Flavor,
    [string]$Preset = "Web",
    [string]$EditorExe = "",
    [string]$OutRoot = "builds\web",
    [switch]$KeepOld
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if (-not (Test-Path $Project)) { throw "Khong tim thay project: $Project" }
$projFull = (Resolve-Path $Project).Path

# --- Tim editor EXE ---
if ([string]::IsNullOrEmpty($EditorExe)) {
    $cands = @(
        (Join-Path $root "builds\editor-control\godot.windows.editor.x86_64.exe"),
        (Join-Path $root "builds\editor-fork-e08\godot.windows.editor.x86_64.exe")
    )
    $EditorExe = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ([string]::IsNullOrEmpty($EditorExe)) {
        $found = Get-ChildItem (Join-Path $root "builds") -Recurse -Filter "godot.windows.editor.x86_64*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $EditorExe = $found.FullName }
    }
}
if ([string]::IsNullOrEmpty($EditorExe) -or -not (Test-Path $EditorExe)) {
    throw "Khong tim thay editor EXE. Chay C02 truoc, hoac truyen -EditorExe."
}

$outDir = Join-Path $root (Join-Path $OutRoot ((Split-Path $projFull -Leaf) + "-" + $Flavor))
$htmlPath = Join-Path $outDir "index.html"

Write-Host "=== Export Web ($Flavor) ==="
Write-Host "project : $projFull"
Write-Host "preset  : $Preset"
Write-Host "editor  : $EditorExe"
Write-Host "output  : $outDir"

# --- Don output (tranh stale artifact) ---
if (Test-Path $outDir) {
    if ($KeepOld) {
        Write-Host "Giu output cu (-KeepOld)."
    } else {
        Write-Host "Don output cu..."
        Remove-Item $outDir -Recurse -Force
    }
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$logDir = Join-Path $root "docs\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $logDir ("export-web-" + $Flavor + "-" + $stamp + ".log")

$flag = if ($Flavor -eq "debug") { "--export-debug" } else { "--export-release" }

$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $EditorExe --headless --path $projFull $flag $Preset $htmlPath 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap

Add-Content -Path $log -Value ""
Add-Content -Path $log -Value ("export exit: $code")

# --- Kiem tra artifact THAT SU ton tai ---
# Kiem tra artifact THAT SU, khong chi dua vao exit code.
#
# Ly do (da gap thuc te): editor co the crash LUC THOAT SAU khi export xong
# (exit 0xC0000005, "Parameter singleton is null" tai EditorNode::is_cmdline_mode).
# Artifact khi do VAN DAY DU. Neu chi nhin exit code thi bao that bai gia,
# va luong Browser Preview se khong mo ban vua export — sai.
#
# Nguoc lai, export hong that su thi artifact se THIEU hoac CUT.
# Vi vay: xac minh tung file (ton tai + kich thuoc toi thieu + magic bytes).
$required = @("index.html", "index.js", "index.wasm", "index.pck")
# Kich thuoc toi thieu (byte) — duoi nguong nay coi nhu file cut/hong.
# wasm cua Godot ~35 MB; dat nguong 1 MB de bat truong hop bi cat ngan.
$minSizes = @{ "index.html" = 200; "index.js" = 10000; "index.wasm" = 1048576; "index.pck" = 1024 }
$missing = @()
$bad = @()
foreach ($f in $required) {
    $p = Join-Path $outDir $f
    if (-not (Test-Path $p)) { $missing += $f; continue }
    $len = (Get-Item $p).Length
    if ($len -lt $minSizes[$f]) { $bad += ("$f ($len B < " + $minSizes[$f] + " B)") }
}
# WebAssembly magic: 0x00 0x61 0x73 0x6D
$wasmPath = Join-Path $outDir "index.wasm"
if (Test-Path $wasmPath) {
    $head = [System.IO.File]::ReadAllBytes($wasmPath)[0..3]
    if (-not ($head[0] -eq 0 -and $head[1] -eq 97 -and $head[2] -eq 115 -and $head[3] -eq 109)) {
        $bad += "index.wasm (magic bytes sai, khong phai file WASM hop le)"
    }
}

$artifactOk = ($missing.Count -eq 0 -and $bad.Count -eq 0)

if (-not $artifactOk) {
    Write-Host ""
    Write-Host "EXPORT THAT BAI (exit=$code, missing=$($missing -join ', '), bad=$($bad -join '; '))" -ForegroundColor Red
    $failNote = Join-Path $outDir "EXPORT_FAILED.txt"
    @(
        "Export that bai.",
        "exit code : $code",
        "missing   : $($missing -join ', ')",
        "bad       : $($bad -join '; ')",
        "log       : $log",
        "time      : $(Get-Date -Format o)"
    ) | Set-Content -Path $failNote -Encoding UTF8
    throw "Export that bai. Xem log: $log"
}

# Artifact day du nhung exit code khac 0 => nghi ngo crash LUC THOAT (sau export).
# Ghi ro de khong che giau, nhung KHONG coi la that bai.
if ($code -ne 0) {
    Write-Host ""
    Write-Host ("CANH BAO: editor thoat voi exit code " + $code + " nhung artifact DAY DU va HOP LE.") -ForegroundColor Yellow
    Write-Host "  => coi nhu export THANH CONG; day la loi luc THOAT, khong phai loi export."
    Write-Host ("  => xem log: " + $log)
    Add-Content -Path $log -Value ""
    Add-Content -Path $log -Value ("GHI CHU: exit code " + $code + " nhung artifact day du -> loi luc thoat, khong phai loi export.")
}

# --- Build ID + manifest ---
$engineVer = ""
try {
    $vi = (& $EditorExe --version 2>&1 | Select-Object -First 1)
    $engineVer = "$vi"
} catch { }

$files = Get-ChildItem $outDir -File | Sort-Object Name
$fileList = @()
foreach ($f in $files) {
    $fileList += [ordered]@{
        name   = $f.Name
        bytes  = $f.Length
        sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    }
}
$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum

$buildId = "$engineVer-$Flavor-$stamp"
$manifest = [ordered]@{
    buildId       = $buildId
    flavor        = $Flavor
    preset        = $Preset
    project       = $projFull
    exportedAt    = (Get-Date -Format o)
    editorExe     = $EditorExe
    editorVersion = $engineVer
    outputDir     = $outDir
    totalBytes    = $totalBytes
    files         = $fileList
    log           = $log
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $outDir "build-manifest.json") -Encoding UTF8

Write-Host ""
Write-Host "=== OK ===" -ForegroundColor Green
Write-Host "build ID    : $buildId"
Write-Host "output      : $outDir"
Write-Host "total bytes : $totalBytes"
Write-Host "manifest    : $(Join-Path $outDir 'build-manifest.json')"
