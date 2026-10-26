<#
.SYNOPSIS
  G05 — Dung static server cua Browser Preview (khong de lai process rac).
.EXAMPLE
  .\tools\preview\stop-preview-server.ps1
  .\tools\preview\stop-preview-server.ps1 -Port 8060
#>
[CmdletBinding()]
param(
    [int]$Port = 0
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$stopped = 0

# 1) Theo PID da ghi
$pidFile = Join-Path $root "builds/web/.preview-server.pid"
if (Test-Path $pidFile) {
    $srvPid = (Get-Content $pidFile -Raw).Trim()
    if ($srvPid) {
        $p = Get-Process -Id $srvPid -ErrorAction SilentlyContinue
        if ($p) {
            Stop-Process -Id $p.Id -Force
            Write-Host ("  da dung server PID " + $p.Id)
            $stopped++
        } else {
            Write-Host ("  PID " + $srvPid + " khong con chay (stale pid file)")
        }
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  khong co pid file"
}

# 2) Quet tien trinh python dang chay serve-web.py
$procs = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*serve-web.py*" }
foreach ($p in $procs) {
    if ($Port -gt 0 -and $p.CommandLine -notlike ("*" + $Port + "*")) { continue }
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host ("  da dung python serve-web.py PID " + $p.ProcessId)
    $stopped++
}

Write-Host ""
Write-Host ("tong da dung: " + $stopped + " process")
