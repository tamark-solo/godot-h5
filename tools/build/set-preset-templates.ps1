<#
.SYNOPSIS
  F05 — Noi preset Web toi cap template dong goi (debug + release).
.DESCRIPTION
  Thay custom_template/debug va custom_template/release trong export_presets.cfg
  bang duong dan TUYET DOI toi cap ZIP da dong goi, sau khi da kiem tra:
    - manifest (F04) ton tai va khop source SHA
    - ca hai ZIP ton tai, SHA256 khop manifest
    - debug != release

  Chay kiem tra F06 truoc khi ghi, nen preset khong bao gio bi tro sai.

  KHONG dung duong dan may developer co dinh: duong dan lay tu -TemplateDir
  hoac tu goi portable (builds/portable/<product>/web_templates).
.EXAMPLE
  .\tools\build\set-preset-templates.ps1 -Project projects\h5-demo -Label fork
  .\tools\build\set-preset-templates.ps1 -Project projects\h5-demo -TemplateDir builds\portable\GodotH5-20261026\web_templates
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [string]$Label = "",
    [string]$TemplateDir = "",
    [string]$Preset = "Web",
    [string]$ManifestPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if (-not (Test-Path $Project)) { throw "Khong tim thay project: $Project" }
$projFull = (Resolve-Path $Project).Path
$cfgPath = Join-Path $projFull "export_presets.cfg"
if (-not (Test-Path $cfgPath)) { throw "Khong tim thay export_presets.cfg trong $projFull" }

# --- Xac dinh cap template ---
$dbgZip = ""
$relZip = ""

if (-not [string]::IsNullOrEmpty($TemplateDir)) {
    if (-not (Test-Path $TemplateDir)) { throw "Khong tim thay TemplateDir: $TemplateDir" }
    $d = Get-ChildItem (Join-Path $TemplateDir "debug") -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 1
    $r = Get-ChildItem (Join-Path $TemplateDir "release") -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($d) { $dbgZip = $d.FullName }
    if ($r) { $relZip = $r.FullName }
} else {
    if ([string]::IsNullOrEmpty($Label)) { throw "Can -Label hoac -TemplateDir" }
    $d = Get-ChildItem (Join-Path $root ("builds/web-debug-" + $Label)) -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 1
    $r = Get-ChildItem (Join-Path $root ("builds/web-release-" + $Label)) -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($d) { $dbgZip = $d.FullName }
    if ($r) { $relZip = $r.FullName }
}

if ([string]::IsNullOrEmpty($dbgZip)) { throw "Khong tim thay template DEBUG. Build F02 truoc." }
if ([string]::IsNullOrEmpty($relZip)) { throw "Khong tim thay template RELEASE. Build F03 truoc." }

Write-Host "=== F05: noi preset toi cap template ==="
Write-Host ("project  : " + $projFull)
Write-Host ("debug    : " + (Split-Path $dbgZip -Leaf))
Write-Host ("release  : " + (Split-Path $relZip -Leaf))

# --- Kiem tra F06 truoc khi ghi (neu co manifest) ---
if ([string]::IsNullOrEmpty($ManifestPath)) {
    if (-not [string]::IsNullOrEmpty($Label)) {
        $ManifestPath = Join-Path $root ("docs/manifests/web-templates-" + $Label + ".json")
    }
}
if (-not [string]::IsNullOrEmpty($ManifestPath) -and (Test-Path $ManifestPath)) {
    Write-Host ""
    Write-Host "--- F06 preflight truoc khi ghi ---"
    $chkScript = Join-Path $root "tools/build/check-template-manifest.ps1"
    $chkArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $chkScript, "-ManifestPath", $ManifestPath)
    if (-not [string]::IsNullOrEmpty($Label)) { $chkArgs += @("-Label", $Label) }
    $chk = & powershell @chkArgs 2>&1
    $chkCode = $LASTEXITCODE
    $chk | Select-Object -Last 16 | ForEach-Object { Write-Host ("  " + $_) }
    if ($chkCode -ne 0 -and -not $Force) {
        throw "F06 preflight THAT BAI — khong ghi preset. Dung -Force de bo qua (khong khuyen khich)."
    }
    Write-Host "  => F06 PASS"
} else {
    Write-Host "(khong co manifest — bo qua F06; nen chay F04 truoc)"
}

# --- Ghi preset ---
$enc = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($cfgPath)
$dbgFwd = $dbgZip.Replace('\','/')
$relFwd = $relZip.Replace('\','/')

$before = $text
$text = [regex]::Replace($text, 'custom_template/debug="[^"]*"',   'custom_template/debug="'   + $dbgFwd + '"')
$text = [regex]::Replace($text, 'custom_template/release="[^"]*"', 'custom_template/release="' + $relFwd + '"')

if ($text -eq $before) {
    Write-Warning "Khong thay doi nao duoc ghi (preset thieu truong custom_template?)"
} else {
    [System.IO.File]::WriteAllText($cfgPath, $text, $enc)
    Write-Host ""
    Write-Host "--- preset sau khi ghi ---"
    Select-String -Path $cfgPath -Pattern 'custom_template|variant/thread_support|variant/extensions_support' |
        ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
}

# --- Xac minh lai bang validator cua project ---
Write-Host ""
Write-Host "--- xac minh bang H5 validator ---"
$editor = ""
foreach ($cand in @("builds/editor-fork-e08", "builds/editor-control")) {
    $dd = Join-Path $root $cand
    if (Test-Path $dd) {
        $e = Get-ChildItem $dd -Filter "*console.exe" | Select-Object -First 1
        if ($e) { $editor = $e.FullName; break }
    }
}
if ($editor) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $vout = & $editor --headless --path $projFull --script res://addons/h5/h5_validate_cli.gd 2>&1
    $vcode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $vout | Select-String -Pattern 'kết quả|PREFLIGHT|template' | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
    if ($vcode -ne 0) { throw "Validator bao loi sau khi ghi preset (exit $vcode)" }
    Write-Host "  => validator PASS"
} else {
    Write-Host "  (khong tim thay editor de xac minh)"
}

Write-Host ""
Write-Host "=== OK ===" -ForegroundColor Green
