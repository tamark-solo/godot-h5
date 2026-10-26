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
# Ban sao lech nguon => khong dong goi (tranh lap lai loi goi mang validator cu).
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools/package/sync-template.ps1") -Check | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Ban sao h5_template lech nguon. Chay tools/package/sync-template.ps1 truoc." }
$addonVer = (Select-String -Path (Join-Path $tplSrc "addons/h5/plugin.cfg") -Pattern '^version="(.+)"').Matches[0].Groups[1].Value
$tplDst = Join-Path $dest "h5_template"
robocopy $tplSrc $tplDst /E /NFL /NDL /NJH /NJS /NP | Out-Null
$tplCount = (Get-ChildItem $tplDst -Recurse -File | Measure-Object).Count
# Hash cua ca cay template: so sanh nhanh goi nay voi nguon ma khong can giai nen.
$tplDstFull = (Resolve-Path $tplDst).Path.TrimEnd('\') + '\'
$tplLines = Get-ChildItem $tplDst -Recurse -File | Sort-Object FullName | ForEach-Object {
    $_.FullName.Substring($tplDstFull.Length).Replace('\','/') + ":" + (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
$sha = [System.Security.Cryptography.SHA256]::Create()
$tplTreeHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($tplLines -join "`n")))).Replace("-","")
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
    # Loi #18: manifest goc ghi duong dan TUYET DOI tren may dev -> tren may sach
    # check-template-manifest.ps1 bao "file khong ton tai". Ban trong goi ghi path
    # TUONG DOI so voi chinh file manifest, va bo engineDir (khong co nghia ngoai may dev).
    $mfObj = Get-Content $mfSrc -Raw | ConvertFrom-Json
    foreach ($fl in @("debug","release")) {
        $t = $mfObj.templates.$fl
        if ($null -ne $t) { $t.path = "web_templates/" + $fl + "/" + $t.file }
    }
    $mfObj.source.engineDir = ""
    $mfObj | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $dest "web-templates-manifest.json") -Encoding UTF8
    foreach ($fl in @("debug","release")) {
        $p = Join-Path $dest $mfObj.templates.$fl.path
        if (-not (Test-Path $p)) { throw "Manifest trong goi tro toi file khong co: $p" }
    }
    Write-Host "  manifest : web-templates-$mfLabel.json (path tuong doi trong goi)"
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
$engSha = (& git -C $engDir rev-parse HEAD).Trim()
$branch = (& git -C $engDir rev-parse --abbrev-ref HEAD).Trim()
$editorVer = ""
$prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
try { $editorVer = (& cmd /c "`"$($exe.FullName)`" --version 2>&1" | Select-Object -First 1) } catch { }
$ErrorActionPreference = $prevEap

$version = [ordered]@{
    product        = $ProductName
    packagedAt     = (Get-Date -Format o)
    engineSha      = $engSha
    engineBranch   = $branch
    editorLabel    = $EditorLabel
    editorExe      = $exe.Name
    editorSha256   = (Get-FileHash $exe.FullName -Algorithm SHA256).Hash
    editorVersion  = $editorVer
    templateLabel  = $mfLabel
    webTemplates   = $webFound
    templateFiles  = $tplCount
    addonVersion   = $addonVer
    h5TemplateTree = $tplTreeHash
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
Write-Host "sha    : $engSha"
Write-Host "addon  : v$addonVer  tree=$($tplTreeHash.Substring(0,16))..."
