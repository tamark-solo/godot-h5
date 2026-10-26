<#
.SYNOPSIS
  J01 - Build single-EXE Godot H5: Web template pair -> manifest -> embed input -> editor.
.DESCRIPTION
  Thu tu BAT BUOC (khong song song, debug/release dung chung bin/.web_zip):
    1. Web template debug  (scons platform=web target=template_debug ...)
    2. Web template release
    3. Manifest (make-template-manifest.ps1), source SHA = engine HEAD
    4. Dung thu muc embed: builds/embed-input/
         web-templates-manifest.json (path tuong doi)
         web_templates/{debug,release}/<zip>
         h5_template/  (copy tu tools/h5_template, NGUON DUY NHAT)
    5. Editor voi h5_embed_dir=builds/embed-input
  Builder trong engine (editor/h5/h5_embed_builders.py) se FAIL neu cap template
  khong khop manifest, debug==release, sai engine HEAD hoac tree dirty.
  Engine phai sach (git status rong) truoc khi chay.
.EXAMPLE
  .\tools\build\build-single-exe.ps1 -Label embed
  .\tools\build\build-single-exe.ps1 -Label embed -SkipWeb   # template da build tu cung HEAD
#>
[CmdletBinding()]
param(
    [string]$Label = "embed",
    [switch]$SkipWeb,
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
. (Join-Path $root "tools/lib/resolve-engine.ps1")
$engDir = Resolve-H5EngineDir $root

$dirty = (& git -C $engDir status --porcelain | Measure-Object -Line).Lines
if ($dirty -ne 0) { throw "Engine co $dirty file chua commit: commit truoc (manifest phai khop HEAD sach)." }
$head = (& git -C $engDir rev-parse HEAD).Trim()
Write-Host "=== J01 single-EXE build: $Label @ $($head.Substring(0,10)) ==="

# Ban sao template phai khop nguon truoc khi nhung.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools/package/sync-template.ps1") -Check | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Ban sao h5_template lech nguon. Chay tools/package/sync-template.ps1 truoc." }

# Profile strip da giu o H06 (chi ap cho template, khong ap cho editor).
$strip = @(
    "disable_3d=yes", "disable_navigation_2d=yes",
    "module_gltf_enabled=no", "module_visual_shader_enabled=no", "module_lightmapper_rd_enabled=no",
    "module_openxr_enabled=no", "module_mobile_vr_enabled=no", "module_webxr_enabled=no",
    "module_csg_enabled=no", "module_gridmap_enabled=no", "module_camera_enabled=no",
    "module_vhacd_enabled=no", "module_xatlas_unwrap_enabled=no", "module_webrtc_enabled=no",
    "module_websocket_enabled=no", "module_upnp_enabled=no", "module_jsonrpc_enabled=no",
    "module_theora_enabled=no", "module_interactive_music_enabled=no",
    "module_objectdb_profiler_enabled=no", "module_betsy_enabled=no"
)
if ($Full) { $strip = @() }

# Goi cung process (&), KHONG qua "powershell -File": -File lam vo mang -ExtraArgs
# (loi da gap: "A positional parameter cannot be found that accepts argument ...").
if (-not $SkipWeb) {
    foreach ($fl in @("debug", "release")) {
        & (Join-Path $root "tools/build/build-web.ps1") -Flavor $fl -Label $Label -ExtraArgs $strip
    }
}
& (Join-Path $root "tools/build/make-template-manifest.ps1") -Label $Label | Out-Host

$mfSrc = Join-Path $root ("docs/manifests/web-templates-" + $Label + ".json")
$mf = Get-Content $mfSrc -Raw | ConvertFrom-Json
if ($mf.source.upstreamSha -ne $head) { throw "Manifest $Label build tu $($mf.source.upstreamSha), engine HEAD la $head. Build lai template (bo -SkipWeb)." }

# Thu muc embed
$emb = Join-Path $root "builds/embed-input"
if (Test-Path $emb) { Remove-Item $emb -Recurse -Force }
New-Item -ItemType Directory -Force -Path $emb | Out-Null
foreach ($fl in @("debug", "release")) {
    $t = $mf.templates.$fl
    $d = Join-Path $emb ("web_templates/" + $fl)
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Copy-Item $t.path (Join-Path $d $t.file) -Force
    $t.path = "web_templates/" + $fl + "/" + $t.file
}
$mf.source.engineDir = ""
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $emb "web-templates-manifest.json"), ($mf | ConvertTo-Json -Depth 10), $enc)
robocopy (Join-Path $root "tools/h5_template") (Join-Path $emb "h5_template") /E /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy h5_template loi ($LASTEXITCODE)" }

& (Join-Path $root "tools/build/build-editor.ps1") -Label $Label -ExtraArgs @("h5_embed_dir=" + $emb)

$exe = Join-Path $root ("builds/editor-" + $Label + "/godot.windows.editor.x86_64.exe")
Write-Host ""
Write-Host "=== SINGLE EXE OK ===" -ForegroundColor Green
Write-Host ("exe    : " + $exe + " (" + [math]::Round((Get-Item $exe).Length / 1MB, 1) + " MB)")
Write-Host ("source : " + $head)
Write-Host "Chi can copy file EXE nay; template Web + H5 template da nam trong EXE."
