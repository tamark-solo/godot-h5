<#
.SYNOPSIS
  I01 — Dong goi portable ZIP tu fork editor + templates + shell + addon + samples.
.DESCRIPTION
  Cau truc goi (theo ke hoach I01):
    <product>/
      godot.windows.editor.x86_64.exe      # editor build tu fork
      godot.windows.editor.x86_64.console.exe
      h5_template/                          # template cho New H5 Project (E04/E05)
      web_templates/                        # cap Web ZIP debug/release (F05)
        debug/*.zip
        release/*.zip
      web-templates-manifest.json           # manifest (F04)
      docs/                                 # quickstart + known limitations
      VERSION.json
  KHONG dung duong dan template tren may developer.
.EXAMPLE
  .\tools\package\assemble-portable.ps1 -EditorLabel fork-e08 -TemplateLabel fork
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EditorLabel,
    [string]$TemplateLabel = "",
    [string]$OutDir = "builds/portable",
    [string]$ProductName = "GodotH5"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$editorDir = Join-Path $root ("builds/editor-" + $EditorLabel)
if (-not (Test-Path $editorDir)) { throw "Khong tim thay editor: $editorDir" }

$stamp = Get-Date -Format "yyyyMMdd"
$dest = Join-Path $root (Join-Path $OutDir ($ProductName + "-" + $stamp))
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "=== I01: dong goi portable ==="
Write-Host "editor  : $editorDir"
Write-Host "dest    : $dest"

# --- 1. Editor ---
$exe = Get-ChildItem $editorDir -Filter "godot.windows.editor.x86_64*.exe" | Where-Object { $_.Name -notlike "*.console.exe" } | Select-Object -First 1
if (-not $exe) { throw "Khong tim thay editor EXE trong $editorDir" }
Copy-Item $exe.FullName $dest -Force
$console = Get-ChildItem $editorDir -Filter "*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($console) { Copy-Item $console.FullName $dest -Force }
Write-Host ("  editor   : " + $exe.Name + " (" + [math]::Round($exe.Length/1MB,1) + " MB)")

# --- 2. H5 template (cho New H5 Project) ---
$tplSrc = Join-Path $root "tools/h5_template"
if (-not (Test-Path $tplSrc)) { throw "Khong tim thay h5_template: $tplSrc" }
$tplDst = Join-Path $dest "h5_template"
robocopy $tplSrc $tplDst /E /NFL /NDL /NJH /NJS /NP | Out-Null
$tplCount = (Get-ChildItem $tplDst -Recurse -File | Measure-Object).Count
Write-Host "  h5_template: $tplCount file"

# --- 3. Web templates ---
$webRoot = Join-Path $dest "web_templates"
$webFound = 0
foreach ($flavor in @("debug","release")) {
    $label = if ($TemplateLabel) { $TemplateLabel } else { "control" }
    $src = Join-Path $root ("builds/web-" + $flavor + "-" + $label)
    if (Test-Path $src) {
        $d = Join-Path $webRoot $flavor
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Get-ChildItem $src -Filter *.zip | ForEach-Object { Copy-Item $_.FullName $d -Force; $webFound++ }
        Write-Host ("  web " + $flavor + " : " + (Get-ChildItem $d -Filter *.zip | Select-Object -First 1).Name)
    } else {
        Write-Warning ("  thieu web template " + $flavor + " (label=" + $label + ")")
    }
}

# --- 4. Manifest ---
$mfLabel = if ($TemplateLabel) { $TemplateLabel } else { "control" }
$mfSrc = Join-Path $root ("docs/manifests/web-templates-" + $mfLabel + ".json")
if (Test-Path $mfSrc) {
    Copy-Item $mfSrc (Join-Path $dest "web-templates-manifest.json") -Force
    Write-Host "  manifest : web-templates-$mfLabel.json"
} else {
    Write-Warning "  thieu manifest: $mfSrc"
}

# --- 5. Docs ---
$docsDst = Join-Path $dest "docs"
New-Item -ItemType Directory -Force -Path $docsDst | Out-Null
foreach ($f in @("scope-v0.1.md","game-spec-h5-demo.md","toolchain-lock.md")) {
    $p = Join-Path $root ("docs/" + $f)
    if (Test-Path $p) { Copy-Item $p $docsDst -Force }
}

# --- 6. VERSION.json ---
. (Join-Path $root "tools/lib/resolve-engine.ps1")
$engDir = Resolve-H5EngineDir $root
$sha = (& git -C $engDir rev-parse HEAD).Trim()
$branch = (& git -C $engDir rev-parse --abbrev-ref HEAD).Trim()
$editorVer = ""
$prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
try { $editorVer = (& cmd /c "`"$($exe.FullName)`" --version 2>&1" | Select-Object -First 1) } catch { }
$ErrorActionPreference = $prevEap

$version = [ordered]@{
    product        = $ProductName
    packagedAt     = (Get-Date -Format o)
    engineSha      = $sha
    engineBranch   = $branch
    editorLabel    = $EditorLabel
    editorExe      = $exe.Name
    editorSha256   = (Get-FileHash $exe.FullName -Algorithm SHA256).Hash
    editorVersion  = $editorVer
    templateLabel  = $mfLabel
    webTemplates   = $webFound
    templateFiles  = $tplCount
    notes          = "Portable ZIP. Khong co installer/updater/signing (ngoai scope)."
}
$version | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $dest "VERSION.json") -Encoding UTF8

# --- 7. ZIP ---
$zipPath = Join-Path $root (Join-Path $OutDir ($ProductName + "-" + $stamp + ".zip"))
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $dest "*") -DestinationPath $zipPath -CompressionLevel Optimal
$zipSize = (Get-Item $zipPath).Length

Write-Host ""
Write-Host "=== OK ===" -ForegroundColor Green
Write-Host "folder : $dest"
Write-Host "zip    : $zipPath"
Write-Host ("size   : " + [math]::Round($zipSize/1MB,1) + " MB")
Write-Host "editor : $editorVer"
Write-Host "sha    : $sha"
