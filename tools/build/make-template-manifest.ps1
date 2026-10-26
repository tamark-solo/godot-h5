<#
.SYNOPSIS
  F04 — Sinh compatibility manifest cho cặp Web template (debug + release).
.DESCRIPTION
  Godot chỉ kiểm tra FILE TỒN TẠI của custom template (export_plugin.cpp:441-448).
  Manifest này bổ sung thứ Godot thiếu: revision, toolchain, flags, flavor, SHA256.
  Đầu ra: docs/manifests/web-templates-<label>.json
.EXAMPLE
  .\tools\build\make-template-manifest.ps1 -Label control
  .\tools\build\make-template-manifest.ps1 -Label fork -DebugZip a.zip -ReleaseZip b.zip
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Label,
    [string]$DebugZip = "",
    [string]$ReleaseZip = "",
    [string]$EngineDir = "",
    [string]$ShellPath = "tools\shell\h5-shell.html",
    [string]$OutDir = "docs\manifests"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tools/lib/resolve-engine.ps1")
if ([string]::IsNullOrEmpty($EngineDir)) { $EngineDir = Resolve-H5EngineDir $root }
Set-Location $root

function Find-Zip([string]$flavor) {
    $d = Join-Path $root ("builds\web-" + $flavor + "-" + $Label)
    if (Test-Path $d) {
        $z = Get-ChildItem $d -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($z) { return $z.FullName }
    }
    return ""
}

if ([string]::IsNullOrEmpty($DebugZip))   { $DebugZip   = Find-Zip "debug" }
if ([string]::IsNullOrEmpty($ReleaseZip)) { $ReleaseZip = Find-Zip "release" }

if ([string]::IsNullOrEmpty($DebugZip) -or -not (Test-Path $DebugZip)) {
    throw "Khong tim thay debug ZIP cho label '$Label'. Build C05/F02 truoc."
}
if ([string]::IsNullOrEmpty($ReleaseZip) -or -not (Test-Path $ReleaseZip)) {
    throw "Khong tim thay release ZIP cho label '$Label'. Build C06/F03 truoc."
}

$sha = (& git -C $EngineDir rev-parse HEAD).Trim()
$branch = (& git -C $EngineDir rev-parse --abbrev-ref HEAD).Trim()
$dirty = (& git -C $EngineDir status --porcelain | Measure-Object -Line).Lines

# Shell version doc tu chinh file shell (tranh lech giua docs va code)
$shellVersion = "unknown"
$shellSha = ""
if (Test-Path $ShellPath) {
    $shellSha = (Get-FileHash $ShellPath -Algorithm SHA256).Hash
    $m = Select-String -Path $ShellPath -Pattern 'Shell version:\s*([0-9.]+)' | Select-Object -First 1
    if ($m -and $m.Matches.Count -gt 0) { $shellVersion = $m.Matches[0].Groups[1].Value }
}

$dInfo = Get-Item $DebugZip
$rInfo = Get-Item $ReleaseZip

$manifest = [ordered]@{
    manifestVersion = 1
    label           = $Label
    generatedAt     = (Get-Date -Format o)
    source = [ordered]@{
        upstreamSha = $sha
        branch      = $branch
        dirtyFiles  = $dirty
        engineDir   = $EngineDir
    }
    profile = [ordered]@{
        platform        = "web"
        arch            = "wasm32"
        threads         = "no"
        dlinkEnabled    = "no"
        renderer        = "gl_compatibility"
        wasmSimd        = "yes"
        texturePolicyDesktop = "vram_compressed"
        texturePolicyMobile  = "lossless"
    }
    shell = [ordered]@{
        version = $shellVersion
        path    = $ShellPath
        sha256  = $shellSha
    }
    templates = [ordered]@{
        debug = [ordered]@{
            file   = $dInfo.Name
            path   = $dInfo.FullName
            bytes  = $dInfo.Length
            sha256 = (Get-FileHash $dInfo.FullName -Algorithm SHA256).Hash
            flavor = "debug"
        }
        release = [ordered]@{
            file   = $rInfo.Name
            path   = $rInfo.FullName
            bytes  = $rInfo.Length
            sha256 = (Get-FileHash $rInfo.FullName -Algorithm SHA256).Hash
            flavor = "release"
        }
    }
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$outFile = Join-Path $OutDir ("web-templates-" + $Label + ".json")
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8

Write-Host "=== Template manifest ==="
Write-Host "label    : $Label"
Write-Host "source   : $sha ($branch, dirty=$dirty)"
Write-Host "shell    : v$shellVersion"
Write-Host "debug    : $($dInfo.Name) $([math]::Round($dInfo.Length/1MB,1)) MB"
Write-Host "release  : $($rInfo.Name) $([math]::Round($rInfo.Length/1MB,1)) MB"
Write-Host "manifest : $outFile"
