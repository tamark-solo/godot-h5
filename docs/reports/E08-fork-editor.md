# E08 — Build và test fork editor

> Ngày: 2026-10-25 · Artifact: `builds/editor-fork-e08/`
> **Kết luận: PASS** — fork editor build được, có identity riêng, tách user data, và tạo được H5 project qua GUI.

## 1. Danh tính build

| Trường | Giá trị |
|---|---|
| Artifact | `builds/editor-fork-e08/godot.windows.editor.x86_64.exe` |
| SHA256 | `8411088B5392936EEF6B6EF67FE93DD76D79A76930B8942913B1458AA0EDDC97` |
| `--version` | `4.7.2.stable.custom_build.45fa8fc15` |
| Build time | **00:13:10** |
| SCons args | `platform=windows target=editor arch=x86_64` |
| Log | `docs/logs/build-editor-fork-e08-20261025-225428.log` (lần 1 fail), `…-225808` (lần 2 OK) |

### ⚠️ Sai lệch cần biết: version hash không khớp code

| | |
|---|---|
| EXE báo version | `45fa8fc15a` (commit **E02/E03**) |
| Code thực tế trong EXE | E02 + E03 + **E04** (E04 còn **chưa commit** tại thời điểm build) |
| Commit E04 sau đó | `e6a2176fb5` |

**Nguyên nhân:** build E08 chạy khi patch E04 đã nằm trong working tree nhưng **chưa commit**, nên `version_hash.gen.cpp` sinh từ commit cũ.

**Hệ quả:** EXE **hoạt động đúng** (checkbox H5 xuất hiện, template được chép — xem mục 3), nhưng **chuỗi version không phản ánh đúng revision**.

**Cần làm trước khi đóng gói (I01):** **rebuild** để version hash = `e6a2176fb5`. Manifest F04/I01 phải khớp revision — nếu không, cơ chế chống mismatch (F06) sẽ **từ chối chính artifact của mình**.

## 2. E02 — Product identity

| Bằng chứng | Giá trị |
|---|---|
| Tiêu đề cửa sổ | **"Godot H5 - Project Manager"** |
| Thanh trạng thái | `v4.7.2.stable.custom_build [45fa8fc15]` |
| Ảnh | [e04-project-manager.png](<img/e04-project-manager.png>) |

## 3. E03 — Tách user config/cache/data (ĐÃ KIỂM CHỨNG)

Chạy probe trên fork editor:

```text
USER_DIR   = %APPDATA%/GodotH5/app_userdata/H5 Demo — Hứng Sao
CONFIG_DIR = %APPDATA%
DATA_DIR   = %APPDATA%
CACHE_DIR  = %LOCALAPPDATA%
```

| Kiểm tra | Kết quả |
|---|---|
| Fork dùng `%APPDATA%/GodotH5` | ✅ **CO** |
| Official Godot `%APPDATA%/Godot` **vẫn tồn tại nguyên vẹn** | ✅ **không bị đụng** |
| Official Godot `%LOCALAPPDATA%/Godot` | ✅ **không bị đụng** |

→ Yêu cầu E03 ("không đè thiết lập của official Godot") **đã được chứng minh bằng thực nghiệm**, không chỉ bằng đọc code.

## 4. E04/E05 — New H5 Project qua GUI (ĐÃ KIỂM CHỨNG)

### Dialog

Ảnh: [e04-new-project-dialog.png](<img/e04-new-project-dialog.png>)

Checkbox **"Create H5 Project (Web export ready)"** xuất hiện trong dialog New Project, **mặc định bật**, cùng hàng với "Version Control Metadata" và "Edit Now".

### Kết quả tạo project (thao tác GUI thật)

Đã chọn renderer **Compatibility**, đặt tên "New Game Project", bấm **Create**. Kết quả: **39 file**.

| Kiểm tra | Kết quả thực tế |
|---|---|
| `application/config/name` | `"New Game Project"` ✅ **tên người dùng nhập được giữ** (patch khôi phục tên hoạt động) |
| `renderer/rendering_method` | `"gl_compatibility"` ✅ |
| `renderer/rendering_method.mobile` | `"gl_compatibility"` ✅ |
| `[editor_plugins] enabled` | `PackedStringArray("res://addons/h5/plugin.cfg")` ✅ **addon tự bật** |
| `addons/h5/` | 6 script + `plugin.cfg` ✅ |
| `h5_config.tres` | ✅ |
| `export_presets.cfg` | preset `Web`, `thread_support=false`, `extensions_support=false`, `custom_html_shell="res://h5_shell.html"` ✅ |
| `h5_shell.html` | ✅ |
| scenes/scripts/assets | 5 scene, 6 script, 2 SVG ✅ |

### Chạy tiếp trên project vừa tạo (fork editor)

| Bước | Kết quả |
|---|---|
| `--import` | **0 lỗi script** |
| `--quit-after 300` (chạy game) | **0 lỗi** |
| Validator CLI | `0 lỗi · 1 cảnh báo` → **PREFLIGHT: PASS** (exit 0) |

> Cảnh báo duy nhất là `template.incomplete` — **đúng**, vì cặp template chưa được nối (việc của F05).

## 5. Tổng diff fork so với upstream

```text
 core/os/os.cpp                            |  11 ++-
 core/version.h                            |   7 ++
 editor/project_manager/project_dialog.cpp | 109 +++++++++++++++++++++++
 editor/project_manager/project_dialog.h   |  11 +++
 platform/windows/os_windows.cpp           |   9 ++-
 version.py                                |   2 +-
 6 files changed, 145 insertions(+), 4 deletions(-)
```

**6 file, +145 / −4 dòng** — đúng mục tiêu "giữ patch C++ nhỏ" của kế hoạch.

## 6. Lỗi đã gặp và sửa

| # | Lỗi | Nguyên nhân | Sửa |
|---|---|---|---|
| 1 | `error C2065: 'GODOT_H5_PRODUCT_DIR_NAME' undeclared` | `os_windows.cpp` + `core/os/os.cpp` chỉ include `version_generated.gen.h`, không include `core/version.h` | Thêm `#include "core/version.h"` vào cả hai |
| 2 | (quy trình) `os_windows.cpp` bị cắt cụt 1430 dòng | Đọc mặc định chỉ trả 2000 dòng đầu của file 2543 dòng, rồi ghi lại | Khôi phục bằng `git checkout --`; chuyển sang sửa đổi có mục tiêu |

## 7. Trạng thái

| Task | Trạng thái |
|---|---|
| E01 | ✅ |
| E02 | ✅ đã kiểm chứng |
| E03 | ✅ đã kiểm chứng bằng thực nghiệm |
| E04 | ✅ **đã kiểm chứng qua GUI** |
| E05 | ✅ template 37 file, tạo project đúng |
| E06 | ✅ lifecycle sạch (1 bật/1 tắt mỗi lần import, lặp 4 lần) |
| E07 | ✅ validator 3 negative test + dock hiển thị |
| **E08** | ✅ **PASS** (còn: rebuild để version hash khớp E04) |

### Việc còn lại của E08

- [ ] **Rebuild** sau commit `e6a2176fb5` để `--version` khớp revision (bắt buộc cho I01/F06)
- [ ] Test tạo project với checkbox **tắt** → phải ra project Godot thường
- [ ] Test đường dẫn có dấu/khoảng trắng/ổ đĩa khác (một phần của I02)
