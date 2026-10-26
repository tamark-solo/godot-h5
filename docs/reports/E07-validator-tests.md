# E07 — Kiểm thử H5 validator (preflight)

> Ngày: 2026-10-25 · Chạy qua `res://addons/h5/h5_validate_cli.gd` trên control editor.
> **Kết luận: PASS** — validator bắt đúng lỗi thật, và **đã bị bắt lỗi chính nó** trong quá trình test.

## 1. Cách chạy

```powershell
godot.windows.editor.x86_64.console.exe --headless --path projects/h5-demo `
  --script res://addons/h5/h5_validate_cli.gd
```

Exit code: `0` = không lỗi · `1` = có ít nhất một `error`.

## 2. Trạng thái hợp lệ (baseline)

```text
kết quả : 0 lỗi · 1 cảnh báo · 0 thông tin
[WARNING] template.incomplete — Preset 'Web' chưa trỏ đủ CẢ HAI template debug và release.
PREFLIGHT: PASS
```

Cảnh báo này **đúng**: chưa build cặp template (C05/C06) nên preset còn để trống.

## 3. Negative test — chứng minh validator thật sự chặn

| # | Cấu hình cố tình làm sai | Kết quả mong đợi | Kết quả thực tế |
|---|---|---|---|
| 1 | `variant/thread_support=true` | error | ✅ `[ERROR] preset.threads` |
| 1 | `variant/extensions_support=true` | error | ✅ `[ERROR] preset.extensions` |
| 1 | `progressive_web_app/enabled=true` | warning | ✅ `[WARNING] preset.pwa` |
| 2 | `rendering_method="forward_plus"` | error | ✅ `[ERROR] renderer.desktop` |
| 3 | debug và release trỏ cùng một file | error | ✅ `[ERROR] template.same_file` |

Mọi ca đều trả **exit code 1** và `PREFLIGHT: FAIL`. Sau test đã **khôi phục** cấu hình gốc (đã xác minh lại các dòng `thread_support=false`, `extensions_support=false`).

## 4. Hai lỗi THẬT của validator, bị bắt khi chạy thử

### Lỗi 1 — false positive với action dựng sẵn của Godot

- **Triệu chứng:** báo thiếu `ui_accept`, `ui_cancel` dù đây là action **dựng sẵn** của engine, không cần khai báo trong `project.godot`.
- **Nguyên nhân:** chỉ đọc mục `[input]` của `project.godot`.
- **Sửa:** thêm danh sách `BUILTIN_ACTIONS` (~65 action UI của Godot) và bỏ qua chúng.

### Lỗi 2 — preset options bị bỏ qua HOÀN TOÀN (nghiêm trọng)

- **Triệu chứng:** `preset.shell` vẫn báo "chưa dùng custom HTML shell" **dù đã set** `html/custom_html_shell="res://h5_shell.html"`.
- **Nguyên nhân:** `export_presets.cfg` có **hai tầng**:
  ```ini
  [preset.0]          ; name, platform, runnable, export_path
  [preset.0.options]  ; custom_template/*, variant/*, html/*, progressive_web_app/*
  ```
  Hàm đọc cũ chỉ lấy `[preset.0]` → **mọi** kiểm tra option (threads, extensions, template, shell, PWA) đều **âm thầm PASS**.
- **Mức độ:** đây là dạng lỗi tệ nhất của validator — **pass giả**. Nếu không chạy thử, preset bật thread support sẽ lọt qua preflight và chỉ vỡ khi lên thiết bị.
- **Sửa:** gộp `[preset.N]` + `[preset.N].options` khi đọc.
- **Xác minh:** negative test 1 và 3 **chỉ bắt đầu hoạt động sau khi sửa** — trước đó chúng đều PASS sai.

## 5. Ghi chú kỹ thuật

- `EditorExportPlugin` **không có API hủy export** (`_export_begin` trả `void`). Vì vậy "chặn export" ở đường GUI chỉ là **cảnh báo** qua `_get_export_option_warning`; **chặn thật** do preflight CLI này đảm nhiệm (dùng trong G04).
- Ghi file cấu hình bằng PowerShell phải **không có BOM**: `Set-Content -Encoding UTF8` (PS 5.1) thêm BOM làm `ConfigFile` không đọc được → validator báo `preset.missing`. Dùng `UTF8Encoding($false)`.

## 6. Trạng thái

✅ E07 validator: **đã kiểm chứng bằng negative test** (phần `_get_export_option_warning` + dock UI vẫn cần một lượt GUI thao tác tay).

## 7. Lỗi #17 — dock ghi `design_resolution=(720, 1)` (2026-10-26)

- **Nguyên nhân:** `_refresh_fields()` gán `_res_x.value` trước `_res_y.value`; `value_changed` của ô X gọi `_commit()` khi ô Y còn giá trị min=1 → config bị ghi đè thành 720×1. Lỗi đã lọt vào cả 4 `h5_config.tres`.
- **Sửa (addon v0.1.1):** dùng `set_value_no_signal` / `set_pressed_no_signal` khi nạp config; dữ liệu sai đã khôi phục về 720×1280.
- **Regression test (fork editor e08, headless `--editor --quit-after 600`, bản sao h5-demo):**

| Bản dock | Trước | Sau khi dock nạp config |
|---|---|---|
| Cũ (`88916f8`) | 720×1280 | **720×1** — tái hiện lỗi |
| Mới (v0.1.1) | 720×1280 | **720×1280** |

Plugin bật/tắt sạch, không có SCRIPT ERROR. Chưa thao tác tay trên GUI.
