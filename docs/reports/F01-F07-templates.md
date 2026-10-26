# F01–F07 — Cặp Web templates cùng fork revision

> Ngày: 2026-10-26 · Fork revision: `e6a2176fb565c6fb098825e35c29010dc28a788d`
> **Kết luận: PASS** — cặp template từ fork boot thật, manifest chặn được mismatch, GUI và CLI cho ra artifact **byte-identical**.

## 1. Artifact

| Flavor | File | Bytes | SHA256 |
|---|---|---:|---|
| debug | `godot.web.template_debug.wasm32.nothreads.zip` | 9,760,667 | `801427C85DC920DC0369D150E11E7A2144293169114E934F23BC0903849AC113` |
| release | `godot.web.template_release.wasm32.nothreads.zip` | 9,858,000 | `ED121804A7D6C2777FAB0A445C61655C6EEAFF8DD1220B64C81B4656792AE7CE` |

Build time: debug **3:21**, release **~4:00**. Cả hai đều có hậu tố `.nothreads` — chứng minh `threads=no` được áp đúng.

## 2. F01 — Web product profile (đã khóa)

```text
platform=web  target=template_{debug,release}  arch=wasm32
threads=no    dlink_enabled=no    wasm_simd=yes (mặc định)
renderer=gl_compatibility
texture: desktop=vram_compressed, mobile=lossless
```

## 3. F04 — Compatibility manifest

[tools/build/make-template-manifest.ps1](<../../tools/build/make-template-manifest.ps1>) → [docs/manifests/web-templates-fork.json](<../manifests/web-templates-fork.json>)

Manifest ghi: upstream SHA, branch, dirty count, profile (platform/arch/threads/dlink/renderer/SIMD/texture policy), shell version + hash, và **SHA256 của từng template**.

> **Lý do cần manifest:** Godot chỉ kiểm tra **file tồn tại** ([export_plugin.cpp:441-452](<../../engine/godot-h5/platform/web/export/export_plugin.cpp#L441-L452>)). Manifest bổ sung đúng thứ Godot thiếu: revision, toolchain, flags, flavor, hash.

## 4. F06 — Chặn mismatch/missing (3 negative test PASS)

[tools/build/check-template-manifest.ps1](<../../tools/build/check-template-manifest.ps1>) — 11 kiểm tra.

| # | Ca cố tình làm sai | Kết quả | Exit |
|---|---|---|---|
| — | Manifest gốc (đối chứng) | `PREFLIGHT: PASS` (11/11 OK) | 0 |
| 1 | Thêm 1 byte vào ZIP debug (không đổi manifest) | `[FAIL] debug : SHA256 KHONG khop` + in cả 2 hash | **1** |
| 2 | Debug và release trỏ cùng một file | `[FAIL] debug va release co CUNG SHA256` | **1** |
| 3 | Sửa `source.upstreamSha` thành `deadbeef…` | `[FAIL] source SHA lech` | **1** |

Sau mỗi ca đã **khôi phục** và xác nhận manifest gốc vẫn PASS.

> Đây chính là điều kế hoạch yêu cầu: "file tồn tại/version string giống nhau chưa đủ".

## 5. F05 — Nối preset tới cặp đóng gói

[tools/build/set-preset-templates.ps1](<../../tools/build/set-preset-templates.ps1>) chạy **F06 trước khi ghi**, nên preset không bao giờ bị trỏ sai.

Kết quả trong [export_presets.cfg](<../../projects/h5-demo/export_presets.cfg>):

```ini
custom_template/debug="<AppGame>/builds/web-debug-fork/godot.web.template_debug.wasm32.nothreads.zip"
custom_template/release="<AppGame>/builds/web-release-fork/godot.web.template_release.wasm32.nothreads.zip"
variant/extensions_support=false
variant/thread_support=false
```

Validator sau khi nối: **0 lỗi · 0 cảnh báo** (trước đó có cảnh báo `template.incomplete`).

## 6. F07 — GUI/CLI parity (ĐÃ CHỨNG MINH byte-identical)

### Cách kiểm chứng

1. **CLI:** `--export-debug Web <path>` → `index.html` = `DAD3390FC9655F92…`
2. **GUI:** mở editor → menu **Project → Export…** → chọn preset `Web` → **Export Project…** → xác nhận ghi đè → export chạy.
3. So hash.

| Đường | `index.html` SHA256 |
|---|---|
| CLI | `DAD3390FC9655F92D4FBCA42…` |
| GUI | `DAD3390FC9655F92D4FBCA42…` |
| **Giống nhau?** | ✅ **TRUE** |

**9/10 file byte-identical.** File khác duy nhất là `h5_build_id.json` — khác là **đúng thiết kế** vì chứa timestamp.

### Tính xác định (determinism)

Xuất 2 lần bằng CLI với cùng preset: **9/10 file giống hệt**, chỉ `h5_build_id.json` khác (timestamp). Artifact có tính xác định.

### Không fallback về template global

Cả hai đường đều đọc `export_presets.cfg`, mà preset trỏ `custom_template` **tuyệt đối** → không đường nào dùng template global của Godot.

### Ảnh bằng chứng

| Ảnh | Nội dung |
|---|---|
| [f07-editor-open.png](<img/f07-editor-open.png>) | Editor mở project h5-demo, tiêu đề "MainMenu.tscn - H5 Demo — Hứng Sao - Godot H5" |
| [f07-project-menu.png](<img/f07-project-menu.png>) | Menu Project với **Export…** |
| [f07-export-dialog.png](<img/f07-export-dialog.png>) | Dialog Export: preset "Web (Runnable)", Thread Support **Off**, Extensions Support **Off**, VRAM desktop On / mobile Off |
| [f07-export-result.png](<img/f07-export-result.png>) | Hộp thoại lưu file với **"Export With Debug"** |
| [f07-export-done.png](<img/f07-export-done.png>) | Xác nhận ghi đè |
| [f07-fork-boot.png](<img/f07-fork-boot.png>) | Game boot trong Chrome với template FORK |

## 7. Boot thật với cặp template FORK

| Chỉ số | Kết quả |
|---|---|
| Banner engine | **`Godot H5 v4.7.2.stable.custom_build.e6a2176fb`** |
| Renderer | `OpenGL ES 3.0 (WebGL 2.0) - Compatibility` |
| Cấu hình | `Emscripten 4.0.23, single-threaded, no GDExtension support` |
| `isSecureContext` | true |
| Exceptions | **0** |
| Request thất bại | **0** |
| MIME sai | **0** |
| Overlay ẩn (boot xong) | **true** |

> **Đáng chú ý:** banner giờ ghi **"Godot H5"** thay vì "Godot Engine" — branding E02 đã đi cả vào **web runtime**, không chỉ editor.

### Test tương tác trên bản fork: 6/6 PASS

Boot xong · overlay audio hiện · bấm → overlay ẩn · `H5Bridge` v1.1.0 · bấm CHƠI không exception · IndexedDB `/userfs` truy cập được.

## 8. Phát hiện: cảnh báo "No export template found" là **dương tính giả của upstream**

Dialog Export hiển thị:

```text
- No export template found at the expected path:
- %APPDATA%/GodotH5/export_templates/4.7.2.stable/web_nothreads_debug.zip
```

**Đây KHÔNG phải lỗi của fork.** Đọc [export_plugin.cpp:437-459](<../../engine/godot-h5/platform/web/export/export_plugin.cpp#L437-L459>):

```cpp
// Look for export templates (first official, and if defined custom templates).
bool dvalid = exists_export_template(_get_template_name(...true), &err);   // <- LUON chay, ghi vao err
bool rvalid = exists_export_template(_get_template_name(...false), &err);

if (p_preset->get("custom_template/debug") != "") {
    dvalid = FileAccess::exists(p_preset->get("custom_template/debug"));   // <- ghi de ket qua
}
...
valid = dvalid || rvalid;   // <- TRUE khi custom template hop le
if (!err.is_empty()) { r_error = err; }   // <- nhung err KHONG duoc xoa
```

Hai lần gọi `exists_export_template()` **luôn chạy trước** và **luôn ghi lỗi vào `err`**, kể cả khi sau đó `custom_template` hợp lệ và `valid = true`. Chuỗi `err` **không bao giờ được xóa**, nên cảnh báo vẫn hiện.

**Bằng chứng đây là dương tính giả:** export qua GUI **thành công** (hash khớp CLI) và validator của fork báo **0 lỗi · 0 cảnh báo**.

**Khuyến nghị:** ghi vào known limitations. Nếu muốn dọn, có thể patch nhỏ để xóa `err` khi `custom_template` hợp lệ — nhưng đây là hành vi upstream, không chặn chức năng.

## 9. Sự cố: port 8080 bị Docker Desktop chiếm

Boot test đầu tiên trả **404** dù server của ta đang chạy. Nguyên nhân: **`com.docker.backend.exe` (Docker Desktop) đã chiếm port 8080**, nên request đi vào Docker chứ không tới server của ta.

Đây **đúng là ca "port bận"** mà G04/G05 phải xử lý — và `browser-preview.ps1` đã phát hiện đúng (kiểm tra nội dung, từ chối reuse). Bài học thực tế: **không mặc định port 8080 là trống trên máy này**.

## 10. Trạng thái

| Task | Trạng thái |
|---|---|
| F01 | ✅ profile khóa |
| F02 | ✅ debug ZIP, hash + manifest |
| F03 | ✅ release ZIP, hash + manifest |
| F04 | ✅ manifest JSON đầy đủ |
| F05 | ✅ preset nối đúng, validator 0 lỗi |
| F06 | ✅ 3/3 negative test chặn thật |
| F07 | ✅ **GUI == CLI byte-identical** |

**Gate F: ĐẠT.**

### Chạy lại F06 trên gói portable (2026-10-26, sau lỗi #18)

Lỗi #18: `web-templates-manifest.json` trong gói ghi `templates.*.path` **tuyệt đối trên máy dev** và `engineDir=engine\godot-h5` → trên máy sạch `check-template-manifest.ps1` báo "file không tồn tại". Sửa:
- `assemble-portable.ps1` ghi path **tương đối** (`web_templates/<flavor>/<file>`), xóa `engineDir`, và tự kiểm path tồn tại trước khi đóng ZIP.
- `check-template-manifest.ps1` tính path tương đối từ thư mục chứa manifest; không có engine checkout thì đối chiếu `engineSha` trong `VERSION.json` của gói.

Test: giải nén ZIP mới vào thư mục tạm, chạy **không** có engine checkout (giả lập máy sạch):

| Ca | Kết quả | Exit |
|---|---|---|
| Đối chứng | PASS (SHA khớp qua VERSION.json) | 0 |
| Thêm 1 byte vào ZIP debug | `SHA256 KHONG khop` | **1** |
| Debug và release cùng file | `CUNG SHA256` | **1** |
| `upstreamSha=deadbeef…` | `source SHA lech` | **1** |

## 11. Giới hạn — CHƯA nghiệm thu

- Toàn bộ test trên **Chrome desktop headless**. Chưa chứng minh gì cho mobile.
- Chưa test qua **tunnel HTTPS**.
- Chưa test **touch thật**.
- Chưa đo **frame time / memory** (H01).
