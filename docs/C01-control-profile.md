# C01 — Control build profile (source chưa sửa)

> Mục tiêu: build **đối chứng** từ source nguyên bản, làm mốc so sánh trước mọi patch.
> Ngày tạo: 2026-10-25.

## 1. Định danh source

| Trường | Giá trị |
|---|---|
| Repo | `engine/godot-h5` |
| Remote | `upstream` = https://github.com/godotengine/godot.git |
| HEAD SHA | `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Tag | `4.7.2-stable` |
| Branch | `indie/h5-platform` (tạo từ SHA khóa; **chưa** patch) |
| Shallow | false |
| Sparse | off |
| Partial clone filter | không |
| Alternates | không |
| `git status` trước build | sạch (0 dòng) |
| Working tree | 329.9 MB |

## 2. SCons args (control)

### Native — Windows editor (C02)

```text
platform=windows
target=editor
arch=x86_64
```

Không thêm: branding, custom module, strip flag, `dev_build`, `production`, `lto`, `threads`, `dlink`.
Mọi thứ giữ **mặc định của upstream** để control thật sự là control.

### Web — debug (C05) / release (C06)

```text
platform=web
target=template_debug      # rồi template_release
arch=wasm32
threads=no
dlink_enabled=no
```

Chưa strip module nào ở bước control.

## 3. Toolchain (đã khóa — xem [docs/toolchain-lock.md](<toolchain-lock.md>))

| Thành phần | Version |
|---|---|
| Python | 3.13.9 |
| SCons | 4.11.1 |
| MSVC toolset | 14.51.36231 (VS 2026, `msvc_ver=14.5`) |
| Windows SDK | 10.0.26100.0 |
| Emscripten | 4.0.23 |

## 4. Cấu hình kế thừa (không đặt gì)

- **Không** có `custom.py` trong source tree.
- **Không** đặt `SCONSFLAGS` trong môi trường.
- **Không** dùng `cache_path` (mặc định `""` = tắt cache).
- **Không** có `~/.scons` config ảnh hưởng profile.

> Kiểm tra: nếu tồn tại `engine/godot-h5/custom.py` hoặc biến `SCONSFLAGS` thì control build **không hợp lệ**.

## 4b. Native build dependencies (bắt buộc — đã cài)

Godot yêu cầu một số SDK tải sẵn **ngoài** MSVC/Windows SDK. Detector **thoát 255** nếu thiếu (trừ ANGLE chỉ cảnh báo):

| Dependency | Script cài | Hành vi khi thiếu | Trạng thái |
|---|---|---|---|
| AccessKit (screen reader) | `misc/scripts/install_accesskit.py` | `print_error` rồi **tự tắt** `accesskit` (không thoát) | ✅ đã cài (accesskit-c 0.22.3) |
| Direct3D 12 (Mesa NIR + PIX + Agility SDK) | `misc/scripts/install_d3d12_sdk_windows.py` | **`sys.exit(255)`** — build dừng | ✅ đã cài (Mesa NIR, PIX 1.0.240308001, Agility 1.618.5) |
| ANGLE | `misc/scripts/install_angle.py` | `print_warning` — chỉ tắt driver ANGLE | ✅ đã cài |

Vị trí cài: `%LOCALAPPDATA%\Godot\build_deps\`.

> Đã cài **đủ** để control build giữ **mặc định upstream** (không phải thêm `d3d12=no`/`accesskit=no`). Điều này quan trọng: control phải là control.

## 5. Lệnh chạy

```powershell
# Native (C02)
.\tools\build\build-editor.ps1 -Label control

# Web (C05, C06) — chạy TUẦN TỰ, không song song
.\tools\build\build-web.ps1 -Flavor debug   -Label control
.\tools\build\build-web.ps1 -Flavor release -Label control
```

Script tự ghi log vào `docs/logs/`, xuất SHA256 và `manifest.json` vào `builds/<kind>-<label>/`.

## 6. Bằng chứng cần lưu (Gate C)

- [ ] `docs/logs/build-editor-control-*.log` — log đầy đủ + exit code
- [ ] `builds/editor-control/manifest.json` — SHA, args, hash, size
- [ ] `builds/web-debug-control/manifest.json`
- [ ] `builds/web-release-control/manifest.json`
- [ ] `docs/reports/C03-native-smoke.md` — smoke test editor
- [ ] `docs/reports/C07-export-smoke.md` — boot cả hai flavor trong browser