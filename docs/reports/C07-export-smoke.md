# C07 — Export smoke test: cặp control templates

> Ngày: 2026-10-25 · Editor: `builds/editor-control` · Templates: `builds/web-{debug,release}-control`
> **Kết luận: PASS** — cả debug và release boot **thật** trong Chrome, vòng chơi chạy, save tồn tại qua reload.

## 1. Cấu hình export

| Trường | Giá trị |
|---|---|
| Preset | `Web` ([export_presets.cfg](<../../projects/h5-demo/export_presets.cfg>)) |
| `custom_template/debug` | `builds/web-debug-control/godot.web.template_debug.wasm32.nothreads.zip` |
| `custom_template/release` | `builds/web-release-control/godot.web.template_release.wasm32.nothreads.zip` |
| `variant/thread_support` | `false` |
| `variant/extensions_support` | `false` |
| `html/custom_html_shell` | `res://h5_shell.html` (shell v1.1.0) |
| `progressive_web_app/enabled` | `false` |
| Renderer | `gl_compatibility` (+ mobile) |

## 2. Artifact đã xuất

| Flavor | Output | Tổng bytes | Build ID |
|---|---|---:|---|
| debug | `builds/web/h5-demo-debug` | 37,208,857 | `4.7.2.stable.custom_build.ed1daf0bf-debug-20261025-223825` |
| release | `builds/web/h5-demo-release` | 38,823,699 | `4.7.2.stable.custom_build.ed1daf0bf-release-20261025-223835` |

Cả hai đều có đủ: `index.html`, `index.js`, `index.wasm` (35.06 MB), `index.pck`, icon, audio worklets.

**Placeholder:** kiểm tra bằng regex `\$GODOT_[A-Z_]+` trên `index.html` → **0 placeholder còn sót**. `GODOT_THREADS_ENABLED = false` ✅. Thứ tự script **đúng** (dòng 91 loader → dòng 243 `new Engine`).

## 3. Boot test trong Chrome (CDP)

Harness: [tools/test/browser-boot-test.mjs](<../../tools/test/browser-boot-test.mjs>) — dùng Chrome DevTools Protocol qua WebSocket có sẵn trong Node ≥ 22, **không cần dependency ngoài**.

| Chỉ số | debug | release |
|---|---|---|
| `isSecureContext` | true | true |
| `Engine` có mặt | true | true |
| `H5Bridge` | v1.1.0 | v1.1.0 |
| Overlay ẩn (boot xong) | **true** | **true** |
| Exceptions | **0** | **0** |
| Request thất bại | **0** | **0** |
| MIME sai | **0** | **0** |

Console log từ engine (nguồn sự thật):

```text
Godot Engine v4.7.2.stable.custom_build.ed1daf0bf (2026-08-17 01:18:38 UTC)
OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility
Build configuration: Emscripten 4.0.23, single-threaded, no GDExtension support.
```

> Dòng `single-threaded, no GDExtension support` xác nhận **đúng profile MVP** (threads=no, dlink=no).

Ảnh: [boot-debug.png](<img/boot-debug.png>), [boot-release.png](<img/boot-release.png>)

## 4. Test tương tác (D02/D04/G03)

Harness: [tools/test/browser-interact-test.mjs](<../../tools/test/browser-interact-test.mjs>)

| # | Kiểm tra | Kết quả |
|---|---|---|
| 1 | Boot xong (overlay ẩn) | ✅ PASS |
| 2 | Overlay "Chạm để bật âm thanh" hiện | ✅ PASS |
| 3 | Bấm → overlay audio ẩn (gesture unlock) | ✅ PASS |
| 4 | `H5Bridge` tồn tại (v1.1.0) | ✅ PASS |
| 5 | Bấm CHƠI → không exception | ✅ PASS |
| 6 | IndexedDB truy cập được (`/userfs`) | ✅ PASS |

**6/6 PASS.**

### Bằng chứng hình ảnh vòng chơi

| Ảnh | Nội dung chứng minh |
|---|---|
| [interact-2-after-play.png](<img/interact-2-after-play.png>) | **Gameplay chạy**: sao đang rơi, giỏ người chơi, HUD `Điểm: 0` / `Bỏ lỡ: 0/3` / `Thời gian: 43`, nút tạm dừng |
| [interact-3-gameplay.png](<img/interact-3-gameplay.png>) | **Màn kết quả**: `KẾT QUẢ`, `Điểm: 0`, `Điểm cao: 0`, **`Đã lưu (local)`**, nút CHƠI LẠI / VỀ MENU |

→ Chứng minh **toàn bộ vòng chơi menu → gameplay → kết quả** hoạt động trên web, và trạng thái save **trung thực** (hiện "Đã lưu (local)" chỉ khi read-back thành công).

### Tiếng Việt hiển thị ĐÚNG (giải quyết rủi ro D03)

Ảnh cho thấy dấu tiếng Việt hiển thị chính xác: `HỨNG SAO`, `Điểm`, `Bỏ lỡ`, `Thời gian`, `KẾT QUẢ`, `Đã lưu`, `Chạm để bật âm thanh`, `Chuột: kéo giữ chuột trái`.

→ **Font mặc định của Godot đủ glyph tiếng Việt.** Không cần nhúng font riêng cho fixture này.

## 5. Save tồn tại qua RELOAD (D06/G08) — bằng chứng cốt lõi

Harness: [tools/test/browser-save-test.mjs](<../../tools/test/browser-save-test.mjs>)

| Bước | Kết quả |
|---|---|
| Lần 1: boot + chơi + kết thúc | ✅ boot OK |
| Kiểm tra IndexedDB | `{"names":["/userfs"]}` |
| **Reload trang** | ✅ boot lại OK |
| Đọc `/userfs` sau reload | **33 key**, có `FILE_DATA` store |
| Đường dẫn save | `/userfs/godot/app_userdata/H5 Demo — Hứng Sao/h5demo_save.json` |
| Exceptions | 0 |

**Bằng chứng quyết định** — [save-3-after-reload-menu.png](<img/save-3-after-reload-menu.png>):

| | Trước khi chơi | **Sau khi reload** |
|---|---|---|
| Điểm cao | `Điểm cao: 0` | **`Điểm cao: 40`** |
| Trạng thái save | `Chưa có save — chỉ trong phiên này` | **`Đã lưu (local)`** |

→ Điểm 40 được ghi → lưu vào IndexedDB → **sống sót qua reload** → đọc lại đúng. Đây là chuỗi write + read-back + persistence **đầy đủ**, không chỉ dựa vào callback ghi file.

## 6. Lỗi THẬT phát hiện trong bước này

Export lần đầu **thất bại** và phơi ra 3 lỗi mà `--import` headless **không** bắt được:

| # | Lỗi | Nguyên nhân | Sửa |
|---|---|---|---|
| 1 | `Member "gravity" redefined (original in native class 'Area2D')` | `star.gd` khai báo `@export var gravity` trùng property native `Area2D.gravity` ([area_2d.cpp:661](<../../engine/godot-h5/scene/2d/physics/area_2d.cpp#L661>)) | Đổi tên thành `fall_gravity` |
| 2 | `Invalid argument for "run()": argument 2 should be EditorInterface but is null` | `h5_validator.gd` khai báo kiểu `EditorInterface` nhưng CLI truyền `null` | Bỏ type hint: `edit = null` |
| 3 | `Failed to load script h5_plugin.gd` | Hệ quả dây chuyền của #2 | Hết sau khi sửa #2 |

**Bài học:** `--import` **không** thay thế được export. Chỉ export mới nạp đủ đường dẫn script và bộc lộ lỗi biên dịch.

## 7. Trạng thái

| Task | Trạng thái |
|---|---|
| C01–C06 | ✅ |
| **C07** | ✅ **PASS** — debug + release boot, vòng chơi chạy, save qua reload |
| **Gate C** | ✅ **ĐẠT** (trừ 1 lượt GUI tương tác cho C03) |
| D02, D04 (một phần), D06 (một phần) | 🔄 có bằng chứng browser; **còn thiếu thiết bị thật** |
| G02, G03 | 🔄 shell v1.1.0 + bridge **đã chạy thật**, không còn chỉ là đối chiếu tĩnh |

## 8. Giới hạn — CHƯA được nghiệm thu

- **Thiết bị thật (Android/iPhone):** toàn bộ test trên là **Chrome desktop headless**. Chưa chứng minh gì cho mobile.
- **HTTPS tin cậy:** test chạy trên `http://127.0.0.1` (localhost được coi là secure context). Chưa test qua tunnel.
- **Touch thật:** dùng `Input.dispatchMouseEvent`; chưa test `InputEventScreenTouch`.
- **Audio thực tế:** mới xác nhận overlay unlock ẩn, **chưa** xác nhận có tiếng.
- **Frame time / memory:** chưa đo (H01).
