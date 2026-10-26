<#
.SYNOPSIS
  Gui click truc tiep vao cua so bang PostMessage (khong can focus).
.DESCRIPTION
  SetForegroundWindow bi Windows chan khi tien trinh goi khong phai foreground.
  PostMessage WM_LBUTTONDOWN/WM_LBUTTONUP voi toa do CLIENT khong can focus.
.EXAMPLE
  .\tools\test\post-click.ps1 -ProcessName godot.windows.editor.x86_64 -X 287 -Y 458
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProcessName,
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [int]$WaitMs = 2000,
    [switch]$Double,
    [long]$Hwnd = 0
)

$ErrorActionPreference = "Stop"
$src = @'
using System;
using System.Runtime.InteropServices;
public class PostClick {
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr hWnd, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

    public const uint WM_MOUSEMOVE = 0x0200;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
    public const uint MK_LBUTTON = 0x0001;

    public static IntPtr LP(int x, int y) { return (IntPtr)((y << 16) | (x & 0xFFFF)); }

    public static void Click(IntPtr h, int x, int y, bool dbl) {
        SendMessage(h, WM_MOUSEMOVE, IntPtr.Zero, LP(x, y));
        System.Threading.Thread.Sleep(80);
        SendMessage(h, WM_LBUTTONDOWN, (IntPtr)MK_LBUTTON, LP(x, y));
        System.Threading.Thread.Sleep(70);
        SendMessage(h, WM_LBUTTONUP, IntPtr.Zero, LP(x, y));
        if (dbl) {
            System.Threading.Thread.Sleep(70);
            SendMessage(h, WM_LBUTTONDOWN, (IntPtr)MK_LBUTTON, LP(x, y));
            System.Threading.Thread.Sleep(70);
            SendMessage(h, WM_LBUTTONUP, IntPtr.Zero, LP(x, y));
        }
    }
}
'@
Add-Type -TypeDefinition $src

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { throw "Khong tim thay tien trinh: $ProcessName" }

if ($Hwnd -ne 0) {
    $h = [IntPtr]$Hwnd
    Write-Host ("target: HWND=" + $h + " (chi dinh)")
} else {
    $p2 = $proc | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $p2) { throw "Khong tim thay cua so chinh" }
    $h = $p2.MainWindowHandle
    Write-Host ("target: HWND=" + $h + " (main window)")
}

$r = New-Object PostClick+RECT
[PostClick]::GetClientRect($h, [ref]$r) | Out-Null
Write-Host ("client rect: " + $r.Right + "x" + $r.Bottom)

[PostClick]::Click($h, $X, $Y, [bool]$Double)
Write-Host ("posted click at client(" + $X + "," + $Y + ")")
Start-Sleep -Milliseconds $WaitMs