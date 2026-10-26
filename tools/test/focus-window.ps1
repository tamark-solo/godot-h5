<#
.SYNOPSIS
  Dua cua so len truoc bang cach pha foreground lock (gui phim ALT truoc).
.DESCRIPTION
  Windows chan SetForegroundWindow tu tien trinh khong phai foreground.
  Gui mot lan ALT (keybd_event) se mo khoa cho phep doi foreground.
.EXAMPLE
  .\tools\test\focus-window.ps1 -ProcessName godot.windows.editor.x86_64
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProcessName,
    [int]$WaitMs = 900
)

$ErrorActionPreference = "Stop"
$src = @'
using System;
using System.Runtime.InteropServices;
public class FocusWin {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);

    public const byte VK_MENU = 0x12;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    public static void Nudge() {
        keybd_event(VK_MENU, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(40);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, IntPtr.Zero);
    }

    public static bool Force(IntPtr h) {
        // Cach 1: ALT nudge roi SetForegroundWindow
        Nudge();
        System.Threading.Thread.Sleep(120);
        ShowWindow(h, 9);
        BringWindowToTop(h);
        if (SetForegroundWindow(h)) return true;

        // Cach 2: AttachThreadInput voi cua so dang foreground
        IntPtr fg = GetForegroundWindow();
        uint fgPid, myTid = GetCurrentThreadId(), fgTid = GetWindowThreadProcessId(fg, out fgPid);
        uint targetPid, targetTid = GetWindowThreadProcessId(h, out targetPid);
        AttachThreadInput(myTid, fgTid, true);
        AttachThreadInput(myTid, targetTid, true);
        bool ok = SetForegroundWindow(h);
        AttachThreadInput(myTid, fgTid, false);
        AttachThreadInput(myTid, targetTid, false);
        return ok;
    }
}
'@
Add-Type -TypeDefinition $src

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { throw "Khong tim thay tien trinh: $ProcessName" }
$h = $proc.MainWindowHandle

$ok = [FocusWin]::Force($h)
Start-Sleep -Milliseconds $WaitMs
$fg = [FocusWin]::GetForegroundWindow()
Write-Host ("force ok=" + $ok + "  fg=" + $fg + "  target=" + $h + "  match=" + ($fg -eq $h))
