<#
.SYNOPSIS
  Chup anh mot cua so Windows theo ten tien trinh, ke ca khi bi che khuat.
.DESCRIPTION
  Thu PrintWindow (PW_RENDERFULLCONTENT) truoc; neu tra ve anh trong/den thi
  thu ha tat ca cua so khac roi chup man hinh.
.EXAMPLE
  .\tools\test\capture-window.ps1 -ProcessName godot.windows.editor.x86_64 -Out docs/reports/img/pm.png
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProcessName,
    [Parameter(Mandatory=$true)][string]$Out,
    [int]$WaitMs = 1200,
    [long]$Hwnd = 0,
    [switch]$Largest
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

$src = @'
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class WinCapEnum {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr p);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out WinCap.RECT r);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr p);
    public static System.Collections.Generic.List<string> List(uint pid) {
        var res = new System.Collections.Generic.List<string>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) {
                WinCap.RECT r; GetWindowRect(h, out r);
                res.Add(h.ToInt64() + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
}

public class WinCap {
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public static bool Print(IntPtr hWnd, string path, uint flags) {
        RECT r;
        if (!GetWindowRect(hWnd, out r)) return false;
        int w = r.Right - r.Left, h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return false;
        using (Bitmap bmp = new Bitmap(w, h))
        using (Graphics g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            bool ok = PrintWindow(hWnd, hdc, flags);
            g.ReleaseHdc(hdc);
            bmp.Save(path, ImageFormat.Png);
            return ok;
        }
    }

    public static void Screen(IntPtr hWnd, string path) {
        RECT r;
        GetWindowRect(hWnd, out r);
        int w = r.Right - r.Left, h = r.Bottom - r.Top;
        using (Bitmap bmp = new Bitmap(w, h))
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(w, h));
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public static int NonBlackPixels(string path) {
        using (Bitmap bmp = new Bitmap(path)) {
            int n = 0;
            for (int y = 0; y < bmp.Height; y += 4)
                for (int x = 0; x < bmp.Width; x += 4) {
                    Color c = bmp.GetPixel(x, y);
                    if (c.R > 12 || c.G > 12 || c.B > 12) n++;
                }
            return n;
        }
    }
}
'@
# PowerShell 5.1 = .NET Framework: dung System.Drawing (KHONG phai System.Drawing.Common).
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { throw "Khong tim thay tien trinh: $ProcessName" }

if ($Hwnd -ne 0) {
    $h = [IntPtr]$Hwnd
    Write-Host ("window: HWND=" + $h + " (chi dinh)")
} elseif ($Largest) {
    # Chon cua so visible LON NHAT cua tien trinh (thuong la cua so chinh).
    $best = [IntPtr]::Zero; $bestArea = 0
    foreach ($w in [WinCapEnum]::List([uint32]$proc.Id)) {
        $parts = $w -split '\|'
        $rc = $parts[1] -split ','
        $area = ([int]$rc[2] - [int]$rc[0]) * ([int]$rc[3] - [int]$rc[1])
        if ($area -gt $bestArea) { $bestArea = $area; $best = [IntPtr][long]$parts[0] }
    }
    if ($best -eq [IntPtr]::Zero) { throw "Khong tim thay cua so visible nao" }
    $h = $best
    Write-Host ("window: HWND=" + $h + " (lon nhat, area=" + $bestArea + ")")
} else {
    $p2 = $proc | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $p2) { throw "Khong tim thay cua so chinh: $ProcessName" }
    $h = $p2.MainWindowHandle
    Write-Host ("window: PID=" + $proc.Id + " HWND=" + $h + " title='" + $p2.MainWindowTitle + "'")
}

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

# 1) Thu PrintWindow
foreach ($flag in @(2, 0)) {
    $ok = [WinCap]::Print($h, $Out, [uint32]$flag)
    if (Test-Path $Out) {
        $nb = [WinCap]::NonBlackPixels($Out)
        Write-Host ("  PrintWindow flag=$flag ok=$ok nonBlack=$nb")
        if ($nb -gt 200) { Write-Host ("  -> dung PrintWindow (flag=$flag)"); exit 0 }
    }
}

# 2) Fallback: dua cua so len truoc roi chup man hinh
Write-Host "  PrintWindow khong dung duoc, thu dua cua so len truoc..."
[WinCap]::ShowWindow($h, 9) | Out-Null
Start-Sleep -Milliseconds 300
[WinCap]::BringWindowToTop($h) | Out-Null
[WinCap]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds $WaitMs
[WinCap]::Screen($h, $Out)
$nb2 = [WinCap]::NonBlackPixels($Out)
Write-Host ("  Screen capture nonBlack=$nb2")
Write-Host ("  -> " + $Out)