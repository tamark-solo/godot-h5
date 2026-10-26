param([Parameter(Mandatory=$true)][string]$ProcessName)
$ErrorActionPreference = "Continue"
$src = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class WinEnum {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public static List<string> List(uint targetPid) {
        var res = new List<string>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == targetPid && IsWindowVisible(h)) {
                var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
                var c = new StringBuilder(256); GetClassNameW(h, c, 256);
                RECT r; GetWindowRect(h, out r);
                res.Add(h.ToInt64() + "|" + c.ToString() + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom + "|" + t.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
}
'@
Add-Type -TypeDefinition $src
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "khong co tien trinh"; exit 1 }
Write-Output ("PID " + $proc.Id + " - cac cua so visible:")
foreach ($w in [WinEnum]::List([uint32]$proc.Id)) {
    $p = $w -split '\|'
    Write-Output ("  HWND=" + $p[0] + "  class=" + $p[1] + "  rect=" + $p[2] + "  title='" + $p[3] + "'")
}
