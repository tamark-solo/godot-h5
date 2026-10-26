# E01 — Spike entry points của editor (BẢN ĐỒ SOURCE + QUYẾT ĐỊNH PATCH)

> Ngày: 2026-10-25 · Source: `engine/godot-h5` @ `ed1daf0b` (branch `indie/h5-platform`, chưa patch)
> Mục tiêu E01: xác định **file/hook thật** cho Project Manager / New Project, branding/about/build ID, paths và bootstrap, kèm **phương án patch nhỏ**.

## 1. Project Manager — New Project

| Thành phần | Vị trí | Ghi chú |
|---|---|---|
| Nút "New Project" (toolbar) | [project_manager.cpp:1536-1537](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/project_manager/project_manager.cpp#L1536-L1537>) | `create_btn` → `ProjectManager::_new_project` |
| Nút "Create" khi danh sách rỗng | [project_manager.cpp:1631](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/project_manager/project_manager.cpp#L1631>) | `empty_list_create_project` |
| Handler | [project_manager.cpp:762-765](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/project_manager/project_manager.cpp#L762-L765>) | Chỉ mở dialog: `set_mode(MODE_NEW)` + `show_dialog()` |
| **Nơi tạo project thật** | [project_dialog.cpp:544](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/project_manager/project_dialog.cpp#L544>) `ProjectDialog::ok_pressed()` | Nhánh `MODE_NEW` ở [561-634](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/project_manager/project_dialog.cpp#L561-L634>) |

### Trình tự `MODE_NEW` (đọc trực tiếp từ source)

1. **561-568** — tạo thư mục project nếu `create_dir` được bật (`DirAccess::make_dir`).
2. **570-577** — lấy `ProjectSettings::get_required_features()`, đặt `rendering/renderer/rendering_method` theo nút renderer đang chọn.
3. **579-580** — **ghi nhớ renderer vào EditorSettings** (`project_manager/default_renderer`) rồi `save()`.
4. **582-592** — thêm feature tag (`GL Compatibility`) và set `rendering_method.mobile = gl_compatibility`.
5. **595-602** — `application/config/features`, `application/config/name`, `application/config/icon = res://icon.svg`, merge `EditorNode::get_initial_settings()`.
6. **604-608** — `ProjectSettings::save_custom(path/project.godot, initial_settings, ...)`.
7. **610-616** — ghi `icon.svg` mặc định.
8. **618** — `EditorVCSInterface::create_vcs_metadata_files(...)`.
9. **620-633** — ghi `.editorconfig` (UTF-8).

### Quyết định patch cho E04/E05

**Hook chọn:** ngay **sau bước 6** (project.godot đã ghi thành công, dòng 608) và **trước** bước 7.

**Phương án patch nhỏ nhất:**
- Thêm một `OptionButton`/checkbox "H5 Project" vào `ProjectDialog` (chỉ hiện ở `MODE_NEW`).
- Nếu được chọn: gọi một hàm mới `_install_h5_template(path)` chép nội dung template H5 (addon + `h5_config.tres` + `export_presets.cfg` + scenes mẫu) vào `path`, **rồi** để luồng cũ chạy tiếp (icon, VCS, editorconfig).
- Template lấy từ **thư mục cài đặt sản phẩm** (cạnh EXE), không hard-code đường dẫn máy developer — phục vụ luôn yêu cầu E08/I01.

**Lý do không làm bằng addon:** Project Manager chạy **trước khi** có project, nên `EditorPlugin` (project-scoped) chưa thể tồn tại. Đây là patch C++ **bắt buộc** theo tiêu chí E04.

## 2. Branding / About / Build ID

| Thành phần | Vị trí |
|---|---|
| `GODOT_VERSION_FULL_NAME` | [core/version.h:79](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/core/version.h#L79>) |
| `GODOT_VERSION_HASH` | [core/version.h:82](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/core/version.h#L82>) |
| About dialog | `editor/gui/editor_about.h` (include tại [editor_node.cpp:84](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/editor_node.cpp#L84>)), gọi tại [editor_node.cpp:1077](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/editor/editor_node.cpp#L1077>) |
| Version nguồn | `version.py` (major/minor/patch/status) |

**Quyết định E02:** build ID của fork = `upstream SHA + fork revision`. Có thể sinh ở tầng build (script truyền `build_version`/`build_hash` cho SCons) thay vì sửa nhiều nơi trong C++ → giữ patch nhỏ. Tên hiển thị sửa ở `version.py` (`name`) hoặc `GODOT_VERSION_NAME`.

**Ràng buộc:** **không** đổi định dạng scene/project Godot.

## 3. Paths (user config / cache / data) — chuẩn bị cho E03

| Hàm | Vị trí | Windows |
|---|---|---|
| `OS::get_godot_dir_name()` | [os.cpp:294-297](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/core/os/os.cpp#L294-L297>) | trả `GODOT_VERSION_SHORT_NAME` viết thường = **"godot"** |
| `OS_Windows::get_config_path()` | [os_windows.cpp:2417-2421](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/os_windows.cpp#L2417-L2421>) | `%APPDATA%` |
| `OS_Windows::get_data_path()` | [os_windows.cpp:2424-2425](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/os_windows.cpp#L2424-L2425>) | = config path |
| `OS_Windows::get_cache_path()` | [os_windows.cpp:2428-2432](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/os_windows.cpp#L2428-L2432>) | `%LOCALAPPDATA%` |
| `OS_Windows::get_user_data_dir(dir)` | [os_windows.cpp:2508-2509](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/os_windows.cpp#L2508-L2509>) | `data_path + "/" + dir` |
| `OS::get_user_data_dir()` | [os.cpp:338-354](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/core/os/os.cpp#L338-L354>) | `<godot_dir>/app_userdata/<project>` |

**Hệ quả hiện tại:** editor settings và user data của fork **đè lên** official Godot (`%APPDATA%\Godot\...`).

**Phương án patch E03 (nhỏ nhất):** đổi **một chỗ** — `OS::get_godot_dir_name()` trả tên riêng của sản phẩm (ví dụ `"GodotH5"`). Toàn bộ config/cache/data tự tách theo, **không** đụng định dạng project, **không** đụng official Godot. Giữ `application/config/use_custom_user_dir` nguyên trạng cho project.

## 4. Bootstrap

| Bước | Vị trí |
|---|---|
| Vào editor | `editor/editor_node.cpp` |
| Project Manager ↔ Editor | `main/main.cpp` (chuyển giữa Project Manager và editor khi mở project) |

**Chưa cần patch** cho bootstrap ở bản đầu: New H5 Project đi qua `ProjectDialog` (mục 1), không cần sửa luồng khởi động.

## 5. Kết luận E01 — bản đồ patch dự kiến

| Task | File | Loại patch | Ước lượng |
|---|---|---|---|
| E02 | `version.py` / `core/version.h` / build args | Identity | Nhỏ |
| E03 | `core/os/os.cpp` — `get_godot_dir_name()` | 1 hàm | **Rất nhỏ** |
| E04 | `editor/project_manager/project_dialog.{h,cpp}` | UI + hàm chép template | Trung bình |
| E05 | Template files (dữ liệu, không phải C++) | — | — |
| E06/E07 | `addons/h5/*` (GDScript, **không** C++) | — | — |

**Tổng kết:** chỉ **E02–E04** cần C++; E05–E07 làm hoàn toàn bằng template + GDScript. Đúng tinh thần "giữ patch C++ nhỏ" của kế hoạch.

## 6. Trạng thái

- ✅ E01 **xong** — bản đồ source + quyết định patch đã ghi.
- ⏳ E02–E04 **chờ** control build (C02) hoàn tất để có mốc so sánh trước khi patch.
