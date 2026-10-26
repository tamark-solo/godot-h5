<#
.SYNOPSIS
  G04 — Browser Preview: preflight -> export moi -> build ID -> serve -> mo URL.
.DESCRIPTION
  Day la luong "CHAN THAT" (khac duong GUI chi canh bao):
    1. Chay H5 preflight validator. Co ERROR => DUNG, KHONG export, KHONG mo browser.
    2. Export debug MOI (output duoc don truoc).
    3. Export that bai => KHONG mo output cu.
    4. Ghi build ID.
    5. Start/reuse static server — CO XAC MINH NOI DUNG.
    6. Mo URL that.

  Quy tac G05 duoc thuc thi trong script nay:
    - export fail        -> khong mo browser
    - port ban           -> bao ro, khong im lang doi port
    - server cu (stale)  -> bi tu choi vi noi dung KHAC ban vua export
    - template thieu     -> preflight bat truoc khi export
    - duong dan co dau/khoang trang -> khong dung chuoi shell khong quote

  XAC MINH NOI DUNG (quan trong):
    Chi "co server tra HTTP 200" la KHONG du — server cu co the van phuc vu
    ban export TRUOC DO. Vi vay so sanh SHA256 cua index.html ma server tra ve
    voi file vua export. Khac => tu choi, khong mo browser.
.EXAMPLE
  .\tools\preview\browser-preview.ps1 -Project projects\h5-demo
  .\tools\preview\browser-preview.ps1 -Project projects\h5-demo -Port 8060 -NoOpen
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [string]$Preset = "Web",
    [int]$Port = 8060,
    [string]$EditorExe = "",
    [switch]$NoOpen,
    [switch]$SkipPreflight,
    [switch]$ReuseAnyServer
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if (-not (Test-Path $Project)) { throw "Khong tim thay project: $Project" }
$projFull = (Resolve-Path $Project).Path
$projName = Split-Path $projFull -Leaf

# --- Tim editor ---
if ([string]::IsNullOrEmpty($EditorExe)) {
    foreach ($cand in @("builds/editor-fork-e08", "builds/editor-control")) {
        $d = Join-Path $root $cand
        if (Test-Path $d) {
            $e = Get-ChildItem $d -Filter "godot.windows.editor.x86_64*.exe" | Where-Object { $_.Name -like "*console.exe" } | Select-Object -First 1
            if ($e) { $EditorExe = $e.FullName; break }
        }
    }
}
if ([string]::IsNullOrEmpty($EditorExe) -or -not (Test-Path $EditorExe)) {
    throw "Khong tim thay editor EXE. Chay C02/E08 truoc."
}

$outDir = Join-Path $root ("builds/web/" + $projName + "-debug")
$url = "http://127.0.0.1:" + $Port + "/index.html"

Write-Host "=== G04: Browser Preview ==="
Write-Host "project : $projFull"
Write-Host "editor  : $EditorExe"
Write-Host "output  : $outDir"
Write-Host "url     : $url"
Write-Host ""

$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"

# --- Helper: SHA256 cua du lieu server tra ve vs file local ---
function Get-Sha256OfBytes([byte[]]$bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "")
}

function Test-ServedMatches([int]$p, [string]$localIndex) {
    # Tra ve hashtable: ok (bool), reason (string), servedHash
    $u = "http://127.0.0.1:" + $p + "/index.html"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Cache-Control", "no-cache")
        $bytes = $wc.DownloadData($u)
        $wc.Dispose()
        $servedHash = Get-Sha256OfBytes $bytes
        $localHash = (Get-FileHash $localIndex -Algorithm SHA256).Hash
        if ($servedHash -eq $localHash) {
            return @{ ok = $true; reason = "noi dung KHOP ban vua export"; servedHash = $servedHash }
        }
        return @{ ok = $false; reason = "noi dung KHAC ban vua export (server cu/stale?)"; servedHash = $servedHash }
    } catch {
        return @{ ok = $false; reason = ("khong phan hoi HTTP: " + $_.Exception.Message); servedHash = $null }
    }
}

function Test-PortListening([int]$p) {
    $conn = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($conn) { return $true }
    try {
        $t = New-Object System.Net.Sockets.TcpClient
        $t.Connect("127.0.0.1", $p)
        $t.Close()
        return $true
    } catch { return $false }
}

# ---------- BUOC 1: PREFLIGHT (chan that) ----------
if (-not $SkipPreflight) {
    Write-Host "--- [1/5] Preflight validator ---"
    $pfLog = & $EditorExe --headless --path $projFull --script res://addons/h5/h5_validate_cli.gd 2>&1
    $pfCode = $LASTEXITCODE
    $summary = ($pfLog | Select-String -Pattern 'kết quả|PREFLIGHT' | ForEach-Object { $_.Line.Trim() }) -join ' | '
    Write-Host ("  " + $summary)

    if ($pfCode -ne 0) {
        Write-Host ""
        Write-Host "PREFLIGHT THAT BAI (exit $pfCode) — DUNG, khong export, khong mo browser." -ForegroundColor Red
        $pfLog | Select-String -Pattern '\[ERROR\]|    ' | Select-Object -First 20 | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
        $ErrorActionPreference = $prevEap
        exit 1
    }
    Write-Host "  => preflight PASS"
} else {
    Write-Host "--- [1/5] Preflight BO QUA (-SkipPreflight) ---"
}

# ---------- BUOC 2: EXPORT MOI ----------
Write-Host ""
Write-Host "--- [2/5] Export debug moi ---"
$exportScript = Join-Path $root "tools/build/export-web.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $exportScript -Project $projFull -Flavor debug -Preset $Preset -EditorExe $EditorExe 2>&1 |
    Select-Object -Last 12 | ForEach-Object { Write-Host ("  " + $_) }
$exportCode = $LASTEXITCODE

if ($exportCode -ne 0) {
    Write-Host ""
    Write-Host "EXPORT THAT BAI (exit $exportCode) — KHONG mo browser, KHONG dung output cu." -ForegroundColor Red
    $ErrorActionPreference = $prevEap
    exit 2
}
Write-Host "  => export OK"

# ---------- BUOC 3: BUILD ID + XAC MINH ARTIFACT ----------
Write-Host ""
Write-Host "--- [3/5] Build ID ---"
$buildIdFile = Join-Path $outDir "h5_build_id.json"
$buildId = "(khong co)"
if (Test-Path $buildIdFile) {
    $bid = Get-Content $buildIdFile -Raw | ConvertFrom-Json
    $buildId = $bid.build_id
    Write-Host ("  build_id : " + $buildId)
    Write-Host ("  flavor   : " + $bid.flavor)
    Write-Host ("  errors   : " + $bid.errors)
} else {
    Write-Host "  (canh bao: khong co h5_build_id.json — plugin export chua chay?)" -ForegroundColor Yellow
}

$required = @("index.html", "index.js", "index.wasm", "index.pck")
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $outDir $_)) })
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host ("ARTIFACT THIEU: " + ($missing -join ', ') + " — KHONG mo browser.") -ForegroundColor Red
    $ErrorActionPreference = $prevEap
    exit 3
}
$localIndex = Join-Path $outDir "index.html"
$localIndexHash = (Get-FileHash $localIndex -Algorithm SHA256).Hash
Write-Host "  artifact : du bo (index.html/js/wasm/pck)"
Write-Host ("  sha256   : " + $localIndexHash.Substring(0, 16) + "...  (index.html)")

# ---------- BUOC 4: SERVER (co xac minh noi dung) ----------
Write-Host ""
Write-Host "--- [4/5] Static server ---"

$listening = Test-PortListening $Port
if ($listening) {
    $chk = Test-ServedMatches $Port $localIndex
    if ($chk.ok -or $ReuseAnyServer) {
        Write-Host ("  port " + $Port + " da co server phuc vu DUNG ban vua export -> REUSE")
        if ($ReuseAnyServer -and -not $chk.ok) {
            Write-Host ("  (bo qua kiem tra noi dung do -ReuseAnyServer: " + $chk.reason + ")") -ForegroundColor Yellow
        }
    } else {
        Write-Host ("  port " + $Port + " co server nhung " + $chk.reason) -ForegroundColor Red
        if ($chk.servedHash) {
            Write-Host ("    server tra ve : " + $chk.servedHash.Substring(0, 16) + "...")
            Write-Host ("    ban vua export: " + $localIndexHash.Substring(0, 16) + "...")
        }
        Write-Host "  => TU CHOI mo browser (tranh phuc vu ban CU)."
        Write-Host "     Dung server cu: .\tools\preview\stop-preview-server.ps1 -Port $Port"
        Write-Host "     Hoac chon port khac: -Port 8070"
        $ErrorActionPreference = $prevEap
        exit 4
    }
} else {
    Write-Host ("  port " + $Port + " trong -> start server moi")
    $serveScript = Join-Path $root "tools/serve/serve-web.py"
    $srv = Start-Process -FilePath "python" -ArgumentList @($serveScript, $outDir, "$Port", "127.0.0.1") -PassThru -WindowStyle Hidden

    # Cho server len va XAC MINH no phuc vu dung artifact cua ta
    $verified = $false
    for ($i = 1; $i -le 10; $i++) {
        Start-Sleep -Milliseconds 800
        if ($srv.HasExited) { break }
        $chk = Test-ServedMatches $Port $localIndex
        if ($chk.ok) { $verified = $true; break }
    }

    if ($srv.HasExited) {
        Write-Host "  server thoat ngay — khong mo browser." -ForegroundColor Red
        $ErrorActionPreference = $prevEap
        exit 5
    }
    if (-not $verified) {
        Write-Host "  server chay nhung KHONG xac minh duoc noi dung — dung server, khong mo browser." -ForegroundColor Red
        Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEap
        exit 6
    }
    Write-Host ("  server PID " + $srv.Id + " — da xac minh phuc vu DUNG ban vua export")
    Write-Host ("  dung server: .\tools\preview\stop-preview-server.ps1 -Port " + $Port)
    $srv.Id | Set-Content (Join-Path $root "builds/web/.preview-server.pid")
}

# ---------- BUOC 5: MO URL ----------
Write-Host ""
Write-Host "--- [5/5] Mo URL ---"
Write-Host ("  " + $url)
if (-not $NoOpen) {
    Start-Process $url
    Write-Host "  da mo browser"
} else {
    Write-Host "  (-NoOpen: khong mo browser)"
}

Write-Host ""
Write-Host "=== BROWSER PREVIEW SAN SANG ===" -ForegroundColor Green
Write-Host ("build_id : " + $buildId)
Write-Host ("url      : " + $url)
$ErrorActionPreference = $prevEap
exit 0
