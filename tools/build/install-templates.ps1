<#
.SYNOPSIS
  F05 - Cai cap Web template (debug+release) vao thu muc export_templates cua editor GodotH5.
.DESCRIPTION
  Khi custom_template de trong, Godot tim template tai
  <export_templates>/<version>/web_nothreads_{debug,release}.zip.
  Cai vao day giup:
    - preset KHONG chua duong dan may developer (F05)
    - debug va release luon la MOT cap (cung manifest)
    - GUI Export va CLI dung cung template (F07)
  Kem h5_manifest.json de H5 validator doi chieu SHA256 + revision truoc moi lan export.
.EXAMPLE
  .\tools\build\install-templates.ps1 -Label stripped
  .\tools\build\install-templates.ps1 -Label stripped -TemplatesRoot "D:\GodotH5\editor_data\export_templates"
#>
[CmdletBinding()]
param(
    [string]$Label = "stripped",
    [string]$ManifestPath = "",
    [string]$TemplatesRoot = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if ([string]::IsNullOrEmpty($ManifestPath)) {
    $ManifestPath = Join-Path $root ("docs/manifests/web-templates-" + $Label + ".json")
}
if (-not (Test-Path $ManifestPath)) { throw "Khong tim thay manifest: $ManifestPath" }

Write-Host "=== Cai cap Web template: $Label ==="

# F06 truoc: khong cai cap sai.
$chk = Join-Path $root "tools/build/check-template-manifest.ps1"
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $chk -ManifestPath $ManifestPath -Label $Label 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = $prev
$out | ForEach-Object { Write-Host ("  " + $_) }
if ($code -ne 0) { throw "F06 FAIL - khong cai template." }

# Ten thu muc version = GODOT_VERSION_FULL_CONFIG (vd 4.7.2.stable)
. (Join-Path $root "tools/lib/resolve-engine.ps1")
$vp = Get-Content (Join-Path (Resolve-H5EngineDir $root) "version.py") -Raw
function V([string]$k) {
    if ($vp -match ('(?m)^' + $k + '\s*=\s*"?([A-Za-z0-9_]*)"?')) { return $Matches[1] }
    throw "version.py thieu $k"
}
$ver = (V "major") + "." + (V "minor")
if ((V "patch") -ne "0") { $ver += "." + (V "patch") }
$ver += "." + (V "status")

if ([string]::IsNullOrEmpty($TemplatesRoot)) { $TemplatesRoot = Join-Path $env:APPDATA "GodotH5/export_templates" }
$dest = Join-Path $TemplatesRoot $ver
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$mf = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$items = @(
    @{ src = $mf.templates.debug.path;   sha = $mf.templates.debug.sha256;   name = "web_nothreads_debug.zip" },
    @{ src = $mf.templates.release.path; sha = $mf.templates.release.sha256; name = "web_nothreads_release.zip" }
)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
foreach ($it in $items) {
    $target = Join-Path $dest $it.name
    if (Test-Path $target) {
        $old = (Get-FileHash $target -Algorithm SHA256).Hash
        if ($old -ne $it.sha) {
            $bk = Join-Path $dest ("_backup-" + $stamp)
            New-Item -ItemType Directory -Force -Path $bk | Out-Null
            Move-Item $target (Join-Path $bk $it.name)
            Write-Host ("  backup ban cu -> " + $bk)
        }
    }
    Copy-Item $it.src $target -Force
    $h = (Get-FileHash $target -Algorithm SHA256).Hash
    if ($h -ne $it.sha) { throw ("SHA256 sau khi copy KHONG khop: " + $it.name) }
    Write-Host ("  [ OK ] " + $it.name + "  " + $h.Substring(0, 16) + "...")
}

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dest "h5_manifest.json"), (Get-Content $ManifestPath -Raw), $enc)
[System.IO.File]::WriteAllText((Join-Path $dest "version.txt"), $ver, $enc)

Write-Host ""
Write-Host ("da cai vao : " + $dest)
Write-Host ("label      : " + $mf.label + "  source " + $mf.source.upstreamSha.Substring(0, 10))
Write-Host "=== OK ===" -ForegroundColor Green
