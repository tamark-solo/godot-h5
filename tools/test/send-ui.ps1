<#
.SYNOPSIS
  Gui chuot/to phim toi cua so Windows (dung cho test GUI thu cong tu dong hoa).
.DESCRIPTION
  Dua cua so len truoc, roi gui su kien chuot tai toa do TUONG DOI trong cua so.
.EXAMPLE
  .\tools\test\send-ui.ps1 -ProcessName godot.windows.editor.x86_64 -ClickX 287 -ClickY 458
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProcessName,
    [int]$ClickX = -1,
    [int]$ClickY = -1,
    [string]$TypeText = "",
    [switch]$DoubleClick,
    [int]$WaitMs = 1200
)

$ErrorActionPreference = "Stop"

$src = @'
using System;
using System.Runtime.InteropServices;
public class UiSend {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, IntPtr dwExtraInfo);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP = 0x0004;

    public static void Click(int x, int y, bool dbl) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(LEFTUP, 0, 0, 0, IntPtr.Zero);
        if (dbl) {
            System.Threading.Thread.Sleep(80);
            mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
            System.Threading.Thread.Sleep(60);
            mouse_event(LEFTUP, 0, 0, 0, IntPtr.Zero);
        }
    }
}
'@
Add-Type -TypeDefinition $src

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { throw "Khong tim thay tien trinh: $ProcessName" }
$h = $proc.MainWindowHandle

[UiSend]::ShowWindow($h, 9) | Out-Null
Start-Sleep -Milliseconds 300
[UiSend]::BringWindowToTop($h) | Out-Null
[UiSend]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 800

$r = New-Object UiSend+RECT
[UiSend]::GetWindowRect($h, [ref]$r) | Out-Null
Write-Host ("window at " + $r.Left + "," + $r.Top)

if ($ClickX -ge 0 -and $ClickY -ge 0) {
    $ax = $r.Left + $ClickX
    $ay = $r.Top + $ClickY
    Write-Host ("click window(" + $ClickX + "," + $ClickY + ") -> screen(" + $ax + "," + $ay + ")")
    [UiSend]::Click($ax, $ay, [bool]$DoubleClick)
    Start-Sleep -Milliseconds $WaitMs
}

if ($TypeText -ne "") {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait($TypeText)
    Start-Sleep -Milliseconds 400
}

Write-Host "done"
