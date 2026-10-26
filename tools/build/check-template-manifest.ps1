<#
.SYNOPSIS
  F06 — Preflight manifest: chan mismatch / missing template TRUOC khi export.
.DESCRIPTION
  Godot chi kiem tra file ton tai (export_plugin.cpp:441-448) -> KHONG du.
  Script nay kiem: manifest ton tai, flavor dung, SHA256 khop file thuc te,
  source SHA khop engine checkout, shell version, va debug != release.
  Exit 0 = PASS, 1 = FAIL.
.EXAMPLE
  .\tools\build\check-template-manifest.ps1 -Label control
#>
[CmdletBinding()]
param(
    # Label chi dung de SUY RA duong dan manifest khi khong truyen -ManifestPath.
    # Vi vay KHONG duoc bat buoc: goi voi -ManifestPath (vi du tu goi portable)
    # ma thieu -Label se lam script treo cho nhap lieu.
    [string]$Label = "",
    [string]$ManifestPath = "",
    [string]$EngineDir = "",
    [string]$ShellPath = "tools\shell\h5-shell.html"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tools/lib/resolve-engine.ps1")
if ([string]::IsNullOrEmpty($EngineDir)) {
    # Tren may sach khong co engine checkout: de trong, se doi chieu VERSION.json cua goi.
    try { $EngineDir = Resolve-H5EngineDir $root } catch { $EngineDir = "" }
}
Set-Location $root

if ([string]::IsNullOrEmpty($ManifestPath)) {
    if ([string]::IsNullOrEmpty($Label)) {
        Write-Host "LOI: can -Label hoac -ManifestPath." -ForegroundColor Red
        exit 2
    }
    $ManifestPath = Join-Path $root ("docs\manifests\web-templates-" + $Label + ".json")
}

$fail = 0
function Fail([string]$msg) { Write-Host ("  [FAIL] " + $msg) -ForegroundColor Red; $script:fail++ }
function Ok([string]$msg)   { Write-Host ("  [ OK ] " + $msg) -ForegroundColor Green }
function Warn([string]$msg) { Write-Host ("  [WARN] " + $msg) -ForegroundColor Yellow }

Write-Host "=== F06 template manifest preflight (label=$Label) ==="

if (-not (Test-Path $ManifestPath)) {
    Fail "Khong tim thay manifest: $ManifestPath"
    Write-Host "PREFLIGHT: FAIL"
    exit 1
}
Ok "manifest: $ManifestPath"

$mf = Get-Content $ManifestPath -Raw | ConvertFrom-Json

$mfDir = Split-Path -Parent (Resolve-Path $ManifestPath).Path

# 1. Source SHA phai khop engine checkout; khong co checkout -> VERSION.json canh manifest (goi portable)
$sha = ""
if ($EngineDir) {
    $sha = (& git -C $EngineDir rev-parse HEAD).Trim()
} else {
    $verFile = Join-Path $mfDir "VERSION.json"
    if (Test-Path $verFile) { $sha = [string](Get-Content $verFile -Raw | ConvertFrom-Json).engineSha }
}
if ([string]::IsNullOrEmpty($sha)) {
    Fail "khong xac dinh duoc engine SHA (khong co engine checkout va khong co VERSION.json)"
} elseif ($mf.source.upstreamSha -ne $sha) {
    Fail "source SHA lech: manifest=$($mf.source.upstreamSha) engine=$sha"
} else {
    Ok "source SHA khop: $sha"
}

# 2. Profile bat buoc
if ($mf.profile.threads -ne "no")        { Fail "profile.threads phai la 'no', dang la '$($mf.profile.threads)'" } else { Ok "threads=no" }
if ($mf.profile.dlinkEnabled -ne "no")   { Fail "profile.dlinkEnabled phai la 'no'" } else { Ok "dlinkEnabled=no" }
if ($mf.profile.arch -ne "wasm32")       { Fail "profile.arch phai la 'wasm32'" } else { Ok "arch=wasm32" }

# 3. Tung template: file ton tai + SHA256 khop + flavor dung
foreach ($flavor in @("debug","release")) {
    $t = $mf.templates.$flavor
    if ($null -eq $t) { Fail "manifest thieu templates.$flavor"; continue }

    if ($t.flavor -ne $flavor) { Fail "$flavor : truong flavor khai bao '$($t.flavor)'" } else { Ok "$flavor : flavor dung" }

    # Path tuong doi (goi portable) duoc tinh tu thu muc chua manifest, khong tu cwd.
    $tp = [string]$t.path
    if (-not [System.IO.Path]::IsPathRooted($tp)) { $tp = Join-Path $mfDir $tp }
    if (-not (Test-Path $tp)) {
        Fail "$flavor : file khong ton tai: $tp"
        continue
    }
    $actual = (Get-FileHash $tp -Algorithm SHA256).Hash
    if ($actual -ne $t.sha256) {
        Fail "$flavor : SHA256 KHONG khop (file bi doi/thay the)"
        Write-Host ("         manifest = " + $t.sha256)
        Write-Host ("         thuc te  = " + $actual)
    } else {
        Ok "$flavor : SHA256 khop ($($actual.Substring(0,16))...)"
    }
}

# 4. debug va release phai la HAI file khac nhau
$dSha = $mf.templates.debug.sha256
$rSha = $mf.templates.release.sha256
if ($dSha -eq $rSha) { Fail "debug va release co CUNG SHA256 -> khong phai hai flavor rieng" } else { Ok "debug != release" }

# 5. Shell version khop giua manifest va file thuc te
if (Test-Path $ShellPath) {
    $m = Select-String -Path $ShellPath -Pattern 'Shell version:\s*([0-9.]+)' | Select-Object -First 1
    if ($m -and $m.Matches.Count -gt 0) {
        $realShell = $m.Matches[0].Groups[1].Value
        if ($realShell -ne $mf.shell.version) {
            Fail "shell version lech: manifest=$($mf.shell.version) file=$realShell"
        } else {
            Ok "shell version khop: v$realShell"
        }
    } else { Warn "khong doc duoc shell version tu $ShellPath" }
} else { Warn "khong tim thay shell: $ShellPath" }

Write-Host ""
if ($fail -gt 0) {
    Write-Host "PREFLIGHT: FAIL ($fail van de)" -ForegroundColor Red
    exit 1
}
Write-Host "PREFLIGHT: PASS" -ForegroundColor Green
exit 0
