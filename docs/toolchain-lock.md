# B02–B06 — Toolchain lock (Windows native + Web)

> Ngày khóa: 2026-10-25. Mọi version dưới đây đã **xác minh trên máy build**.
> Nguyên tắc (B07): **không** dùng `custom.py` hay `SCONSFLAGS` ngầm để đổi profile.

## 1. Bảng version đã khóa

| Thành phần | Version khóa | Đường dẫn / cách xác minh | Task |
|---|---|---|---|
| Windows | 10.0.26100 (Windows 11 24H2+) | `[System.Environment]::OSVersion` | B01 |
| Visual Studio | 18.10.3 Community | `vswhere -latest -property catalog_productDisplayVersion` | B02 |
| MSVC toolset | **14.51.36231** | `...\VC\Tools\MSVC\14.51.36231\bin\Hostx64\x64\cl.exe` | B02 |
| Windows SDK | **10.0.26100.0** | `C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0` | B02 |
| Python | **3.13.9** | `%LOCALAPPDATA%\Programs\Python\Python313\python.exe` | B03 |
| SCons | **4.11.1** | `python -m SCons --version` → `v4.11.1.b97f32b9` | B04 |
| Emscripten | **4.0.23** (pin) | `third_party/emsdk` → `emcc 4.0.23 (7a5d93b5)` | B05 |
| emsdk Node | 24.19.0 | `third_party\emsdk\node\24.19.0_64bit\node.exe` | B05 |
| Git | 2.56.0.windows.1 | `git --version` | A03 |

## 2. B02 — Đối chiếu với detector native (ĐÃ XÁC MINH)

Detector native: [platform/windows/detect.py](<../engine/godot-h5/platform/windows/detect.py>) trong full checkout.

| Ràng buộc trong source | Dòng | Yêu cầu | Thực tế | Kết luận |
|---|---|---:|---|---|
| `msvc_ver == "14.5"` (Visual Studio 2026) | [190-192](<../engine/godot-h5/platform/windows/detect.py#L190-L192>) | SCons **≥ 4.10.1** | SCons 4.11.1 | ✅ |
| `msvc_ver == "14.3"` (VS 2022) | [187-189](<../engine/godot-h5/platform/windows/detect.py#L187-L189>) | SCons ≥ 4.8.0 | — | n/a |
| WinRT: `ver_parse(mssdk)[2] < 22621` | [164-169](<../engine/godot-h5/platform/windows/detect.py#L164-L169>) | Windows SDK **≥ 10.0.22621.0** | 10.0.26100.0 | ✅ |
| `check_mssdk_version` | [131-172](<../engine/godot-h5/platform/windows/detect.py#L131-L172>) | SDK phải nằm trong danh sách SCons dò được | 10.0.26100.0 | ✅ |

**Kết luận B02:** MSVC toolset **14.51.36231** (Visual Studio 2026, `msvc_ver = "14.5"`) + Windows SDK **10.0.26100.0** + SCons **4.11.1** thỏa **mọi** ràng buộc version trong detector. Không cần `winrt=no` vì SDK đã ≥ 10.0.22621.0.

## 3. B03 — Python

- Interpreter khóa: `%LOCALAPPDATA%\Programs\Python\Python313\python.exe`
- Gọi bằng `py -3.13` hoặc đường dẫn tuyệt đối; **không** dựa vào `python` trôi nổi trong PATH khi chạy CI.
- Yêu cầu tối thiểu của engine: `EnsurePythonVersion(3, 9)` (SConstruct dòng 5) → 3.13.9 thỏa.
- **Lưu ý:** emsdk kèm Python 3.13.3 riêng (`EMSDK_PYTHON`). SCons **không** cài trong Python của emsdk; build web vẫn dùng Python hệ thống đã cài SCons. Không để `EMSDK_PYTHON` ghi đè interpreter chạy SCons.

## 4. B04 — SCons

- Version khóa: **4.11.1** (pip `scons>=4.4,<5`).
- Yêu cầu tối thiểu của engine: `EnsureSConsVersion(4, 4)` (SConstruct dòng 4) → thỏa.
- Gọi bằng `python -m SCons` (không phụ thuộc `scons.exe` có trong PATH hay không).

## 5. B05 — Emscripten

- Version khóa: **4.0.23**; yêu cầu tối thiểu `(4, 0, 0)` theo `platform/web/detect.py`.
- Cài đặt: `third_party/emsdk` (đã `install` + `activate`).
- Kích hoạt: `. .\tools\env\Enter-WebShell.ps1` (gọi `emsdk_env.ps1`).
- **Không** ghi `latest`; mọi lần build đều đi qua script có pin version.

## 6. B06 — Quyết định WASM SIMD / device floor

| Trường | Giá trị |
|---|---|
| Mặc định của source | `wasm_simd=yes` |
| Quyết định bản đầu | **Giữ `wasm_simd=yes`** (theo mặc định upstream) |
| Lý do | SIMD đã phổ cập trên Chrome/Edge desktop, Android Chrome và Safari iOS trong dải thiết bị mục tiêu; giữ mặc định giúp giảm rủi ro lệch hành vi so với upstream |
| Device floor | Xác nhận lại bằng số đo thực tế ở D07/H01; **nếu** phát hiện thiết bị mục tiêu không hỗ trợ thì chuyển thành profile `wasm_simd=no` **rõ ràng** và build lại **cả hai** flavor |
| Ràng buộc | Policy SIMD phải **đồng nhất** giữa debug và release; ghi vào manifest (F04) |

## 7. B07 — Script môi trường

| Script | Chức năng |
|---|---|
| `tools/env/env-report.ps1` | In + ghi `docs/logs/env-report-*.txt`: Python, SCons, MSVC, SDK, Emscripten, trạng thái engine checkout, dung lượng đĩa |
| `tools/env/Enter-NativeShell.ps1` | Nạp `vcvars64.bat` vào phiên hiện tại (dot-source) |
| `tools/env/Enter-WebShell.ps1` | Kích hoạt `emsdk_env.ps1` với version pin |
| `tools/build/build-editor.ps1` | Build `platform=windows target=editor arch=x86_64`, ghi log + SHA256 + manifest |
| `tools/build/build-web.ps1` | Build `platform=web target=template_<flavor> arch=wasm32 threads=no dlink_enabled=no`, ghi log + SHA256 + manifest |

### Ràng buộc profile (không được vi phạm)

1. `threads=no` **chỉ** áp cho `platform=web`. Editor Windows giữ thread mặc định.
2. `dlink_enabled=no` cho Web (không GDExtension trong MVP).
3. Debug và release Web dùng **chung** `bin/.web_zip` → **không build song song**.
4. Không strip flag (`disable_3d`…) cho target editor — bị SConstruct cấm.