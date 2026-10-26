# E04/E05 — New H5 Project: patch + template

> Ngày: 2026-10-25 · Source: `engine/godot-h5` branch `indie/h5-platform`
> **Trạng thái: patch đã viết, đang chờ build E08 để kiểm chứng.**

## 1. Thiết kế (theo E01 spike)

| Thành phần | Quyết định | Lý do |
|---|---|---|
| Hook | `ProjectDialog::ok_pressed()`, nhánh `MODE_NEW`, **ngay sau** `ProjectSettings::save_custom()` | Project Manager chạy **trước khi** có project → `EditorPlugin` chưa thể tồn tại. Patch C++ là **bắt buộc**. |
| UI | `CheckBox` "Create H5 Project (Web export ready)", mặc định **bật**, chỉ hiện ở `MODE_NEW` | Không đổi hành vi tạo project Godot thường |
| Nguồn template | `<thư mục chứa EXE>/h5_template` | **Không** dùng đường dẫn máy developer, **không** dùng template global của Godot → chạy được trên máy Windows sạch (I02) |
| Thứ tự | Chép template **trước** icon/VCS/.editorconfig | Template có thể ghi đè `project.godot`; các file mặc định còn lại vẫn được áp dụng |

## 2. Patch

| File | Thay đổi |
|---|---|
| `editor/project_manager/project_dialog.h` | Thêm member `h5_project_check`, khai báo `_install_h5_template()` |
| `editor/project_manager/project_dialog.cpp` | Tạo checkbox; show/hide theo mode; gọi template sau khi ghi `project.godot`; cài đặt hàm chép đệ quy |

**Diff:** 2 file, +99 dòng (xem `git diff` của commit `[E04]`).

### Hàm `_install_h5_template()`

- Kiểm tra `h5_template` tồn tại; **thiếu thư mục = lỗi rõ ràng** (không im lặng).
- Duyệt cây bằng stack (không đệ quy C++), tạo thư mục bằng `DirAccess::make_dir_recursive_absolute`, chép file bằng `DirAccess::copy`.
- Giữ nguyên cấu trúc thư mục con.
- **Khôi phục tên project** người dùng đã nhập: template có `project.godot` riêng, nếu không khôi phục thì tên project bị ghi đè.

## 3. Nội dung template (`tools/h5_template`, 37 file, 74.6 KB)

```text
h5_template/
├─ project.godot            # H5 defaults: input actions, stretch, autoload, Compatibility
├─ export_presets.cfg       # preset "Web": threads=off, extensions=off, PWA=off, custom shell
├─ h5_config.tres           # H5Config schema v1
├─ h5_shell.html            # custom HTML shell v1.1.0
├─ icon.svg
├─ addons/h5/               # EditorPlugin + dock + validator + export plugin + CLI validator
├─ scenes/                  # MainMenu, Game, Result, Player, Star
├─ scripts/                 # game_state, main_menu, game, player, star, result
└─ assets/                  # star.svg, basket.svg
```

**Đã dọn trước khi đóng gói:**
- Xóa `.import` (Godot tự import lại cho project mới).
- Xóa đường dẫn `custom_template/*` trỏ vào `builds/` của máy developer → để trống; **F05** sẽ nối vào cặp ZIP đóng gói.

## 4. Tiêu chí xong (E04/E05)

- [ ] Mở Project Manager bằng GUI, thấy checkbox "Create H5 Project"
- [ ] Tạo project mới với checkbox bật → có `addons/h5/`, `h5_config.tres`, `export_presets.cfg`, `h5_shell.html`
- [ ] `project.godot` giữ **đúng tên project** người dùng nhập
- [ ] Preset "Web" có `threads=false`, `extensions=false`, `pwa=false`
- [ ] Mở project → addon tự bật, dock H5 xuất hiện
- [ ] Tạo project với checkbox **tắt** → project Godot thường, không có addon
- [ ] Test đường dẫn có dấu/khoảng trắng/ổ đĩa khác

> Tất cả mục trên cần **GUI tương tác** — không kiểm chứng được bằng headless.

## 5. Lỗi đã gặp và sửa

| # | Lỗi | Nguyên nhân | Sửa |
|---|---|---|---|
| 1 | `error C2065: 'GODOT_H5_PRODUCT_DIR_NAME' undeclared` | `os_windows.cpp` và `core/os/os.cpp` chỉ include `version_generated.gen.h`, **không** include `core/version.h` nơi macro được định nghĩa | Thêm `#include "core/version.h"` vào **cả hai** file |

## 6. Trạng thái

| Task | Trạng thái |
|---|---|
| E01 | ✅ xong |
| E02 | ✅ đã patch + commit |
| E03 | ✅ đã patch + commit |
| E04 | 🔄 patch viết xong, **chờ build + test GUI** |
| E05 | 🔄 template đã tạo (37 file), **chờ test** |
| E06 | 🔄 lifecycle đã kiểm chứng qua import lặp (1 bật/1 tắt mỗi lần) |
| E07 | 🔄 validator đã kiểm chứng bằng negative test; dock chờ GUI |
| E08 | 🔄 **đang build** |
