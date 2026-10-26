# C03 — Native smoke test: control editor

> Ngày: 2026-10-25 · Editor: `builds/editor-control/godot.windows.editor.x86_64.exe`
> **Kết luận: PASS** — control editor build từ source chạy được, import và chạy project sạch.

## 1. Danh tính build (chứng minh KHÔNG phải file tải sẵn đổi tên)

| Trường | Giá trị |
|---|---|
| Artifact GUI | `builds/editor-control/godot.windows.editor.x86_64.exe` (167.6 MB) |
| Artifact console | `builds/editor-control/godot.windows.editor.x86_64.console.exe` (0.3 MB) |
| SHA256 (GUI) | `CF8955D7DDBEC220…` |
| SHA256 (console) | `4DD14FEC188BA72C…` |
| `--version` | `4.7.2.stable.custom_build.ed1daf0bf` |
| Source SHA | `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Branch | `indie/h5-platform` (dirty files = 0) |
| Build time | **00:11:52** (19 cores) |
| SCons args | `platform=windows target=editor arch=x86_64` |
| Log | `docs/logs/build-editor-control-20261025-215*.log` |

**Bằng chứng then chốt:** chuỗi `custom_build.ed1daf0bf` trong `--version` khớp **chính xác** SHA đã khóa. Đây là build từ source, không phải bản tải sẵn.

## 2. Import project fixture (headless)

```powershell
godot.windows.editor.x86_64.console.exe --headless --path projects/h5-demo --import
```

| Hạng mục | Kết quả |
|---|---|
| Exit code | **0** |
| Class đăng ký từ addon | `H5Config`, `H5Validator` ✅ |
| Asset import | `basket.svg`, `star.svg`, `icon.svg` ✅ |
| Lỗi script GDScript | **không có** |
| Editor layout load | OK |
| Plugin `_exit_tree()` | `"H5 Platform: plugin đã tắt."` ✅ |

> Việc `_exit_tree()` chạy sạch là **bằng chứng đầu tiên** cho lifecycle E06 (không nhân dock/action khi tắt).

## 3. Chạy game fixture (headless, 300 frame)

```powershell
godot.windows.editor.x86_64.console.exe --headless --path projects/h5-demo --quit-after 300
```

| Hạng mục | Kết quả |
|---|---|
| Exit code | **0** |
| Banner engine | `Godot Engine v4.7.2.stable.custom_build.ed1daf0bf` |
| Lỗi runtime / script | **không có** |
| Cảnh báo | không có |

→ Vòng chơi (autoload `GameState`, `MainMenu` → `Game` → `Result`) khởi động được, 7 script parse sạch.

## 4. Phát hiện trong quá trình test

| # | Vấn đề | Xử lý |
|---|---|---|
| 1 | `build-editor.ps1` chọn nhầm `.console.exe` do glob `*.exe` | Đã sửa: ưu tiên bản GUI, copy kèm bản console |
| 2 | PowerShell 5.1 biến stderr của native (cl.exe/SCons) thành terminating error | Đã sửa: hạ `$ErrorActionPreference` quanh lời gọi native |
| 3 | Detector **thoát 255** khi thiếu D3D12 SDK (accesskit chỉ cảnh báo) | Đã cài `install_d3d12_sdk_windows.py` (+ accesskit, ANGLE) |

## 5. Việc CHƯA làm ở C03 (cần GUI tương tác)

Các mục sau cần người ngồi trước màn hình, **chưa** được nghiệm thu tự động:

- [ ] Mở Project Manager bằng GUI, thấy project trong danh sách
- [ ] Sửa scene bằng editor UI rồi save/reopen
- [ ] Chạy native Preview (cửa sổ game thật, có render)
- [ ] Bật/tắt plugin nhiều lần trong UI, xác nhận dock không nhân đôi

> Đây là **giới hạn thật** của smoke test headless. Gate C vẫn cần một lượt GUI do người thực hiện.
