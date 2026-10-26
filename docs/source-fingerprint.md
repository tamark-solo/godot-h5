# A02 — Source fingerprint (Godot đối chiếu)

> Ghi lại **trước** khi tạo development checkout. Reference giữ **nguyên trạng**: không sửa, không build, không commit.
> Ngày ghi: 2026-10-25.

## 1. Reference checkout hiện có

| Trường | Giá trị |
|---|---|
| Đường dẫn | `reference/godot/` |
| Remote | `https://github.com/godotengine/godot.git` (fetch + push) |
| Partial clone filter | `blob:none` |
| HEAD commit | `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Commit date | 2026-08-16 20:18:38 -0500 |
| Tag | `4.7.2-stable` |
| Shallow | **true** (`grafted`) |
| Sparse checkout | **true** |
| Alternates | không có |
| `git status --porcelain` | sạch (0 dòng) |

## 2. Phiên bản engine (từ `reference/godot/version.py`)

```
short_name = "godot"
name = "Godot Engine"
major = 4
minor = 7
patch = 2
status = "stable"
module_config = ""
website = "https://godotengine.org"
docs = "4.7"
```

## 3. Sparse checkout hiện có (8 mục)

```text
core
drivers/gles3
editor/export
editor/import
main
modules/gdscript
platform/web
scene
servers
```

## 4. Hệ quả — vì sao reference KHÔNG đủ để build

Reference **thiếu** tối thiểu các vùng cần cho build sản phẩm:

| Vùng thiếu | Cần cho |
|---|---|
| `editor/` (ngoài `export`/`import`) | Editor EXE, Project Manager, branding (E01–E08) |
| `platform/windows/` | Build native Windows (B02, C02) |
| `thirdparty/` | Mọi build (native + web) |
| `modules/` (ngoài gdscript) | Web template, strip analysis (H03) |
| `misc/`, `.github/`, `SConstruct` phụ trợ | Toolchain detect, CI recipe |

→ Đã xác nhận bằng `Test-Path`: `platform/windows/detect.py` = **False**, `thirdparty` = **False**.
Do đó **không** thể đọc version lock của MSVC/Windows SDK từ reference; phải đọc từ full checkout (A03/A04) rồi mới chốt B02.

## 5. Quy tắc sử dụng

1. Reference chỉ dùng để **đọc/đối chiếu** (đường dẫn + số dòng trong kế hoạch).
2. Mọi thay đổi engine diễn ra trong `engine/godot-h5/` trên branch `indie/h5-platform`.
3. Không `git fetch`/`gc`/`repack` trong reference để tránh làm hỏng object store của partial clone.
4. Khi cần đối chiếu vùng thiếu, đọc từ `engine/godot-h5/` (full checkout) chứ không mở rộng sparse của reference.
