<#
.SYNOPSIS
  Dong bo tools/h5_template (NGUON DUY NHAT) sang cac ban sao, roi so hash.
.DESCRIPTION
  Hai loai dich:
    1. Ban sao template day du (vd builds/editor-fork-e08/h5_template):
       MIRROR toan bo cay (xoa file thua), bo qua .godot/.
    2. Project game (projects/*):
       CHI dong bo phan dung chung: addons/h5/** va h5_shell.html.
       KHONG dung toi project.godot, export_presets.cfg, h5_config.tres,
       scenes/scripts/assets -- day la du lieu rieng tung game.

  -Check : chi kiem tra, khong ghi. Exit 1 neu co ban sao lech.
  Sau khi ghi, script tu chay lai buoc kiem tra; lech => exit 1.

  Goi portable KHONG nam trong danh sach: no duoc tao lai bang
  assemble-portable.ps1 (script do copy tu tools/h5_template).
.EXAMPLE
  .\tools\package\sync-template.ps1 -Check
  .\tools\package\sync-template.ps1
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string[]]$TemplateCopies = @("builds/editor-fork-e08/h5_template"),
    [string[]]$Projects = @("projects/h5-demo", "projects/h5-puzzle")
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$src = Join-Path $root "tools/h5_template"
if (-not (Test-Path (Join-Path $src "addons/h5/plugin.cfg"))) { throw "Khong tim thay nguon: $src" }

# Phan dung chung cho project game (dau '/' = thu muc)
$shared = @("addons/h5/", "h5_shell.html")

function Get-RelFiles([string]$base, [string]$rel) {
    $p = Join-Path $base $rel
    if (-not (Test-Path $p)) { return @() }
    if ((Get-Item $p).PSIsContainer) {
        $baseFull = (Resolve-Path $base).Path.TrimEnd('\') + '\'
        return @(Get-ChildItem $p -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.godot\\' } |
            ForEach-Object { $_.FullName.Substring($baseFull.Length).Replace('\', '/') })
    }
    return @($rel)
}

function Compare-Set([string]$dst, [string[]]$relList) {
    $issues = @()
    foreach ($rel in $relList) {
        $want = @(Get-RelFiles $src $rel)
        $have = @(Get-RelFiles $dst $rel)
        foreach ($f in $want) {
            $d = Join-Path $dst $f
            if (-not (Test-Path $d)) { $issues += "THIEU  $f"; continue }
            $hs = (Get-FileHash (Join-Path $src $f) -Algorithm SHA256).Hash
            $hd = (Get-FileHash $d -Algorithm SHA256).Hash
            if ($hs -ne $hd) { $issues += "KHAC   $f" }
        }
        foreach ($f in $have) { if ($want -notcontains $f) { $issues += "THUA   $f" } }
    }
    return ,$issues
}

$allRel = @(Get-ChildItem $src -Force | Where-Object { $_.Name -ne ".godot" } |
    ForEach-Object { if ($_.PSIsContainer) { $_.Name + "/" } else { $_.Name } })

$targets = @()
foreach ($t in $TemplateCopies) { $targets += [pscustomobject]@{ Path = $t; Kind = "template"; Rel = $allRel } }
foreach ($p in $Projects)       { $targets += [pscustomobject]@{ Path = $p; Kind = "project";  Rel = $shared } }

$ver = (Select-String -Path (Join-Path $src "addons/h5/plugin.cfg") -Pattern '^version="(.+)"').Matches[0].Groups[1].Value
Write-Host "=== sync-template (addon v$ver) ==="
Write-Host "nguon: $src"

if (-not $Check) {
    foreach ($t in $targets) {
        $dst = Join-Path $root $t.Path
        if (-not (Test-Path $dst)) { Write-Warning "bo qua (khong ton tai): $($t.Path)"; continue }
        if ($t.Kind -eq "template") {
            robocopy $src $dst /MIR /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "robocopy loi ($LASTEXITCODE) -> $dst" }
        } else {
            robocopy (Join-Path $src "addons/h5") (Join-Path $dst "addons/h5") /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "robocopy loi ($LASTEXITCODE) -> $dst/addons/h5" }
            Copy-Item (Join-Path $src "h5_shell.html") (Join-Path $dst "h5_shell.html") -Force
        }
        Write-Host ("  ghi  : " + $t.Path + " (" + $t.Kind + ")")
    }
}

$bad = 0
foreach ($t in $targets) {
    $dst = Join-Path $root $t.Path
    if (-not (Test-Path $dst)) { continue }
    $issues = Compare-Set $dst $t.Rel
    if ($issues.Count -eq 0) {
        Write-Host ("  OK   : " + $t.Path)
    } else {
        $bad++
        Write-Host ("  LECH : " + $t.Path + " (" + $issues.Count + ")") -ForegroundColor Red
        $issues | Select-Object -First 20 | ForEach-Object { Write-Host ("         " + $_) }
    }
}
if ($bad -gt 0) { exit 1 }
Write-Host "=== tat ca ban sao khop nguon ===" -ForegroundColor Green
exit 0
