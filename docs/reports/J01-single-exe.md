# J01 — Single-EXE: nhúng cặp Web template + H5 template vào editor

> Ngày: 2026-10-26 · Engine: nhánh `indie/h5-embed` @ `51762b4` · Script: [build-single-exe.ps1](<../../tools/build/build-single-exe.ps1>)
> **Kết luận: PASS headless** — chỉ copy 1 file EXE là export được game web. Còn chờ thử "New H5 Project" trên GUI.

## 1. Thiết kế

| Thành phần | Trước (I01) | Sau (J01) |
|---|---|---|
| Cặp Web template | `web_templates/` cạnh EXE + script cài | Nhúng trong EXE; editor tự cài vào `%APPDATA%/GodotH5/export_templates/<ver>` lúc khởi động, kiểm SHA256 |
| `h5_template/` | Thư mục cạnh EXE | Nhúng thành ZIP; **ưu tiên** thư mục cạnh EXE nếu có (sửa addon không cần build lại) |
| Kích thước EXE | 172.8 MB | **187.4 MB** |

Builder [h5_embed_builders.py](<../../engine/godot-h5/editor/h5/h5_embed_builders.py>) **dừng build** thay vì nhúng sai nếu: SHA256 ZIP ≠ manifest, debug == release, manifest ≠ engine HEAD, template build từ tree dirty, `h5_template` thiếu `plugin.cfg`. Không truyền `h5_embed_dir` thì build fork như cũ.

Thứ tự build (tuần tự): template debug (5:09) → release (5:59) → manifest → editor `h5_embed_dir=builds/embed-input` (11:59).

## 2. Kết quả (máy giả lập sạch)

Thư mục app `Ứng dụng H5` (Unicode + space), `APPDATA`/`LOCALAPPDATA` trống, **chỉ có EXE**.

| Ca | Kết quả |
|---|---|
| Version | `4.7.2.stable.custom_build.51762b436` |
| Mở lần đầu | ✅ cài 4 file (2 ZIP + `h5_manifest.json` + `version.txt`), SHA256 khớp manifest |
| Preflight h5-demo | ✅ 0 lỗi, `template.ok` |
| Export debug | ✅ đủ 10 file, build ID `51762b436ed2-debug-…` |
| Sửa ZIP debug đã cài → preflight CLI | ✅ `template.hash_mismatch`, exit 1 |
| Sửa ZIP debug → mở lại editor | ✅ tự khôi phục, bản bị sửa chuyển vào `_backup-<unix>` |
| Mở lần 2 | ✅ không ghi lại, không tạo backup mới |

## 3. Chưa kiểm chứng

- **New H5 Project lấy từ bản nhúng** (cần GUI Project Manager).
- Browser Preview + boot Chrome trên bản single-EXE.
- macOS (giai đoạn J sau).

## 4. Lưu ý vận hành

- Sửa addon/shell/template → **phải build lại editor** (~12 phút) để bản phát hành có bản mới. Lúc phát triển đặt `h5_template/` cạnh EXE để dùng ngay.
- Sửa C++ engine → build lại cả 3 bước (~23 phút), vì manifest phải khớp HEAD mới.
- Lỗi #20 (quy trình): gọi `build-web.ps1` qua `powershell -File` làm vỡ mảng `-ExtraArgs`. Script mới gọi trong cùng process.

## Nghiệm thu GUI (người dùng, 2026-10-26 14:45)

- Copy riêng `godot.windows.editor.x86_64.exe` (bản embed) vào thư mục trống, mở, tạo project mới với "Create H5 Project": ✅ project tạo từ **template nhúng**, dock H5 hiện ở cột phải.
- Bấm "Preview trên trình duyệt" trong dock: ✅ game chạy trên trình duyệt.
- Đã merge `indie/h5-embed` vào `indie/h5-platform` (fast-forward, `51762b4`) và push cả hai nhánh.
