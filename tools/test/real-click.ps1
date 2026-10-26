<#
.SYNOPSIS
  Focus mot cua so theo HWND va click that (SetCursorPos + mouse_event).
.DESCRIPTION
  PostMessage khong duoc Godot xu ly khi cua so khong active, nen phai:
    1. Pha foreground lock (ALT nudge) + AttachThreadInput
    2. SetForegroundWindow vao dung HWND
    3. Click that bang SetCursorPos + mouse_event
.EXAMPLE
  .\tools\test\real-click.ps1 -ProcessName godot.windows.editor.x86_64 -Hwnd 920552 -X 161 -Y 563
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProcessName,
    [Parameter(Mandatory=$true)][long]$Hwnd,
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [int]$WaitMs = 2500,
    [switch]$Double
)

$ErrorActionPreference = "Stop"
$src = @'
using System;
using System.Runtime.InteropServices;
public class RealClick {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint fl, IntPtr ex);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public const byte VK_MENU = 0x12;
    public const uint KEYUP = 0x0002, LEFTDOWN = 0x0002, LEFTUP = 0x0004;

    public static bool Focus(IntPtr h) {
        keybd_event(VK_MENU, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(50);
        keybd_event(VK_MENU, 0, KEYUP, IntPtr.Zero);
        System.Threading.Thread.Sleep(150);
        ShowWindow(h, 9);
        BringWindowToTop(h);
        if (SetForegroundWindow(h)) return true;

        IntPtr fg = GetForegroundWindow();
        uint fgPid, my = GetCurrentThreadId(), fgTid = GetWindowThreadProcessId(fg, out fgPid);
        uint tPid, tTid = GetWindowThreadProcessId(h, out tPid);
        AttachThreadInput(my, fgTid, true);
        AttachThreadInput(my, tTid, true);
        bool ok = SetForegroundWindow(h);
        AttachThreadInput(my, fgTid, false);
        AttachThreadInput(my, tTid, false);
        return ok;
    }

    public static void ClickScreen(int x, int y, bool dbl) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(180);
        mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(70);
        mouse_event(LEFTUP, 0, 0, 0, IntPtr.Zero);
        if (dbl) {
            System.Threading.Thread.Sleep(90);
            mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
            System.Threading.Thread.Sleep(70);
            mouse_event(LEFTUP, 0, 0, 0, IntPtr.Zero);
        }
    }
}
'@
Add-Type -TypeDefinition $src

$h = [IntPtr]$Hwnd
$ok = [RealClick]::Focus($h)
Start-Sleep -Milliseconds 700
$fg = [RealClick]::GetForegroundWindow()
Write-Host ("focus ok=" + $ok + "  foreground match=" + ($fg -eq $h))
if ($fg -ne $h) { Write-Warning "Khong dua duoc cua so len truoc; click co the di sai cho." }

$r = New-Object RealClick+RECT
[RealClick]::GetWindowRect($h, [ref]$r) | Out-Null
$sx = $r.Left + $X
$sy = $r.Top + $Y
Write-Host ("window at " + $r.Left + "," + $r.Top + "  click (" + $X + "," + $Y + ") -> screen (" + $sx + "," + $sy + ")")
[RealClick]::ClickScreen($sx, $sy, [bool]$Double)
Start-Sleep -Milliseconds $WaitMs
Write-Host "done"
