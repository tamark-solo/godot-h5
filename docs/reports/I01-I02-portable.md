# I01/I02 — Đóng gói portable và test máy sạch

> Ngày: 2026-10-26 · Package: `builds/portable/GodotH5-20261026.zip` (99.3 MB)
> **Kết luận: PASS** — gói chạy từ đường dẫn có khoảng trắng + dấu tiếng Việt, tạo H5 project và export thành công **chỉ bằng thành phần trong gói**.

## 1. I01 — Nội dung gói

```text
GodotH5-20261026/
├─ godot.windows.editor.x86_64.exe          (172.8 MB)
├─ godot.windows.editor.x86_64.console.exe  (294 KB)
├─ h5_template/                              (37 file)  <- cho New H5 Project
├─ web_templates/
│   ├─ debug/godot.web.template_debug.wasm32.nothreads.zip    (9.3 MB)
│   └─ release/godot.web.template_release.wasm32.nothreads.zip (9.4 MB)
├─ web-templates-manifest.json               <- F04 manifest
├─ docs/                                     <- scope, game spec, toolchain lock
└─ VERSION.json
```

[VERSION.json](<C:/Users/Mark-TA/Desktop/AppGame/builds/portable/GodotH5-20261026/VERSION.json>) ghi: engine SHA `e6a2176fb565…`, branch `indie/h5-platform`, editor SHA256 `A52D7018…`, editor version `4.7.2.stable.custom_build.e6a2176fb`, template label `fork`, số template (2) và số file template (37).

**Không** dùng đường dẫn template trên máy developer: gói mang theo template riêng, và `h5_template` nằm **cạnh EXE** đúng như chính sách E04.

## 2. I02 — Test trên đường dẫn khó

Giải nén vào: `D:\Test Portable\Godot H5 — Bản thử`

Đường dẫn này cố tình chứa **khoảng trắng**, **dấu tiếng Việt** (`Bản thử`) và **em-dash** (`—`), đồng thời nằm ở **ổ đĩa khác** (D: thay vì C:).

| Bước | Kết quả |
|---|---|
| Giải nén | ✅ 46 file |
| Chạy `--version` từ gói | ✅ `4.7.2.stable.custom_build.e6a2176fb` |
| `h5_template` cạnh EXE | ✅ 37 file |
| `web_templates` | ✅ debug + release |
| Mở Project Manager | ✅ tiêu đề **"Godot H5 - Project Manager"** |
| Dialog New Project | ✅ có **"Create H5 Project (Web export ready)"** |
| Tạo project | ✅ **39 file**, addon tự bật |
| `config/name` | ✅ `"New Game Project"` (tên giữ đúng) |
| Renderer | ✅ `gl_compatibility` |
| Nối preset tới template trong gói | ✅ F06 PASS, ghi đường dẫn Unicode đúng |
| **Export bằng editor trong gói** | ✅ **exit 0**, `H5 export: 0 error, 0 warning` |
| Artifact | ✅ đủ 10 file (index.html/js/wasm/pck + icon + worklets) |
| **Boot trong Chrome** | ✅ **PASS**, 0 exception, 0 request lỗi, 0 MIME sai |

### Bằng chứng boot

```text
title          : New Game Project (DEBUG)
Godot H5 v4.7.2.stable.custom_build.e6a2176fb
OpenGL ES 3.0 (WebGL 2.0) - Compatibility
Emscripten 4.0.23, single-threaded, no GDExtension support
booted (overlay an) : true
exceptions : 0
```

Ảnh: [i02-pm-package.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/i02-pm-package.png>), [i02-new-project.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/i02-new-project.png>), [i02-boot.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/i02-boot.png>)

> **Ý nghĩa:** chuỗi "giải nén → mở EXE → tạo H5 project → export → chạy trên browser" hoạt động **chỉ với thành phần trong gói**, không cần Godot/Python/compiler cài sẵn, không cần đường dẫn máy developer.

## 3. Lỗi đã phát hiện và sửa

| # | Lỗi | Nguyên nhân | Sửa |
|---|---|---|---|
| 1 | `check-template-manifest.ps1` **treo** chờ nhập liệu | `-Label` khai báo `Mandatory=$true` nhưng chỉ dùng để **suy ra** đường dẫn manifest; khi gọi với `-ManifestPath` (từ gói portable) thì không có Label → treo | Đổi `-Label` thành tùy chọn; nếu thiếu **cả hai** thì báo lỗi rõ và exit 2 |
| 2 | `build-web.ps1` lỗi `emcc not recognized` ở chế độ `-CollectOnly` | Dòng header log gọi `emcc --version` **trước** khi emsdk được kích hoạt (CollectOnly bỏ qua bước kích hoạt) | Đọc `emscripten-version.txt`; thêm chuỗi dự phòng 3 tầng (PATH → cây emsdk → `.emscripten`) |
| 3 | `manifest.json` có `"emcc": {}` rỗng | `emcc` phân giải thành `emcc.ps1` (ExternalScript) — `cmd /c` không chạy được `.ps1` | Như trên |

## 4. Sự cố môi trường: port 8080 bị Docker Desktop chiếm

Boot test đầu tiên trả **404** dù server của ta đang chạy. Nguyên nhân: `com.docker.backend.exe` đã chiếm port 8080.

Đây **đúng là ca "port bận"** mà G04/G05 phải xử lý, và `browser-preview.ps1` đã phát hiện đúng nhờ **kiểm tra nội dung** (so SHA256 `index.html`), không chỉ "HTTP 200".

## 5. Trạng thái

| Task | Trạng thái |
|---|---|
| I01 — Portable ZIP | ✅ 99.3 MB, đầy đủ thành phần, VERSION.json |
| I02 — Test máy sạch | ✅ **PASS** trên đường dẫn Unicode/space/ổ khác |
| I03 — Release hosting | ⏳ chờ tunnel HTTPS |
| I04 — RC matrix | ⏳ chờ thiết bị thật |
| I05 — Maintenance rehearsal | ⏳ |

## 6. Giới hạn — CHƯA nghiệm thu

- Test trên **máy này**, không phải máy Windows sạch thật sự (máy vẫn có Python/MSVC/Docker). Chưa chứng minh được trường hợp **user mới hoàn toàn** và **thư mục cài không ghi được**.
- Chưa test **ổ đĩa chỉ đọc** hoặc quyền hạn chế.
- Chưa test trên **thiết bị thật** (Android/iPhone) — cần tunnel HTTPS.
- Chưa test **upgrade/rollback** bundle (I04).
