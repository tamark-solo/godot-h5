<#
  Tim thu muc engine fork (Godot H5) cho moi script build/package.
  Thu tu uu tien:
    1. bien moi truong H5_ENGINE_DIR
    2. file tools/engine-dir.txt (rieng tung may, KHONG commit)
    3. mac dinh: <workspace>/engine/godot-h5
#>
function Resolve-H5EngineDir([string]$root) {
    if ($env:H5_ENGINE_DIR) { $p = $env:H5_ENGINE_DIR }
    else {
        $cfg = Join-Path $root "tools/engine-dir.txt"
        if (Test-Path $cfg) { $p = (Get-Content $cfg -Raw).Trim() }
        else { $p = Join-Path $root "engine\godot-h5" }
    }
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
    if (-not (Test-Path (Join-Path $p "version.py"))) { throw "Khong tim thay engine fork tai: $p (dat H5_ENGINE_DIR hoac tools/engine-dir.txt)" }
    return $p
}
