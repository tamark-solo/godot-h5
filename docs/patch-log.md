# A06 — Patch log (thay đổi engine so với upstream)

> Mỗi patch phải ghi: ID task, file, mục đích, và **lý do không làm được bằng addon/plugin**.
> Nguyên tắc (E01): giữ patch C++ **nhỏ nhất có thể**; chỉ sửa product identity, H5 entry và bootstrap khi plugin không thể làm.

| # | Task | Ngày | File | Mục đích | Trạng thái |
|---|---|---|---|---|---|
| 1 | E02 | 2026-10-25 | `version.py` | Đổi tên hiển thị thành "Godot H5". Build ID vẫn mang SHA upstream. | ✅ commit |
| 2 | E03 | 2026-10-25 | `core/version.h` | Thêm macro `GODOT_H5_PRODUCT_DIR_NAME = "GodotH5"`. | ✅ commit |
| 3 | E03 | 2026-10-25 | `core/os/os.cpp` | `OS::get_godot_dir_name()` trả tên sản phẩm thay vì "godot". | ✅ commit |
| 4 | E03 | 2026-10-25 | `platform/windows/os_windows.cpp` | **Override của Windows** cũng phải sửa — đây mới là hàm thực sự chạy trên Windows. | ✅ commit |

## Chi tiết patch 1–4 (commit `[E02][E03]`)

**Vấn đề:** mặc định engine dùng `GODOT_VERSION_SHORT_NAME` (= "godot") cho `get_godot_dir_name()`,
nên fork sẽ đọc/ghi `%APPDATA%\Godot\...` và `%LOCALAPPDATA%\Godot\...` — **đè lên** cài đặt
và dữ liệu người dùng của official Godot trên cùng máy.

**Cách sửa:** đổi **một chỗ** (giá trị trả về) để config + cache + user data **cùng dịch chuyển**,
không đụng định dạng project/scene.

**Bẫy đã phát hiện:** `OS_Windows` **override** `get_godot_dir_name()`
([os_windows.cpp:2466](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/os_windows.cpp#L2466>)).
Chỉ sửa lớp cơ sở `OS::get_godot_dir_name()` sẽ **không có tác dụng gì trên Windows**.
Đã sửa **cả hai**.

**Diff tổng:** 4 file, +23 / −4.

## Sự cố trong quá trình patch (ghi lại để tránh lặp)

`os_windows.cpp` dài **2543 dòng**, nhưng thao tác đọc mặc định chỉ trả **2000 dòng đầu**.
Ghi lại nội dung đã đọc làm **cắt cụt** file (mất ~1430 dòng). Đã phát hiện ngay qua `git diff --stat`
và khôi phục bằng `git checkout --`. **Bài học: với file dài phải dùng sửa đổi có mục tiêu
(edit theo đoạn), không đọc-rồi-ghi-lại toàn bộ.**

## Quy ước

- Patch được commit trên branch `indie/h5-platform`, mỗi patch một commit có message `[<ID>] <mô tả>`.
- Trước khi patch: `git status` phải sạch và có control build (C02/C03) làm mốc so sánh.
- Sau mỗi patch ảnh hưởng Web: phải rebuild **cả** editor và cặp template, cập nhật manifest (F04).
- Xuất diff tổng hợp: `git diff upstream/4.7.2-stable..indie/h5-platform > docs/logs/fork-patches.diff`.