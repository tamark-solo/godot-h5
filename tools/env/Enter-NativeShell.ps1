<#
.SYNOPSIS
  B07 — Nạp môi trường MSVC (vcvars64) vào phiên PowerShell hiện tại.
.DESCRIPTION
  Dot-source script này để có cl.exe/link.exe trong PATH trước khi chạy scons:
      . .\tools\env\Enter-NativeShell.ps1
.NOTES
  PowerShell 5.1 compatible.
#>
[CmdletBinding()]
param(
    [string]$VsRoot = "C:\Program Files\Microsoft Visual Studio\18\Community",
    [string]$Arch = "x64"
)

$vcvars = Join-Path $VsRoot ("VC\Auxiliary\Build\vcvars" + $(if ($Arch -eq "x64") { "64" } else { $Arch }) + ".bat")
if (-not (Test-Path $vcvars)) {
    throw "Khong tim thay vcvars: $vcvars"
}

Write-Host ("Loading MSVC env from: " + $vcvars)
$raw = cmd /c "`"$vcvars`" >nul 2>&1 && set"
foreach ($line in $raw) {
    if ($line -match '^([^=]+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2]
        if ($name -match '^(PATH|INCLUDE|LIB|LIBPATH)$' -or $name -like 'VSCMD_*' -or $name -like 'VC*' -or $name -like 'WindowsSdk*' -or $name -like 'UCRT*') {
            Set-Item -Path ("env:" + $name) -Value $value -ErrorAction SilentlyContinue
        }
    }
}

# LUU Y: cl.exe ghi banner ra stderr. Trong PowerShell 5.1, native stderr co the bi
# bien thanh terminating error khi caller dat $ErrorActionPreference='Stop'.
# Vi vay phai ha ErrorActionPreference ve 'Continue' trong pham vi script nay.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $cl = Get-Command cl.exe -ErrorAction SilentlyContinue
    if ($cl) {
        Write-Host ("OK  cl.exe : " + $cl.Source)
        $clVer = (& cmd /c "`"$($cl.Source)`" 2>&1" | Select-Object -First 1)
        Write-Host ("OK  cl ver : " + $clVer)
    } else {
        Write-Warning "cl.exe van chua co trong PATH"
    }
} finally {
    $ErrorActionPreference = $prevEap
}