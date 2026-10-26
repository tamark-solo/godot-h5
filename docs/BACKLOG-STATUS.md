# BACKLOG STATUS — GODOT_H5_FORK_PLAN (61 việc)

> Cập nhật: 2026-10-26 12:15 (review lại trạng thái: chỉ tính ✅ khi tiêu chí trong kế hoạch đã đạt đủ) · Nguồn: [GODOT_H5_FORK_PLAN.vi.md](<C:/Users/Mark-TA/Desktop/AppGame/GODOT_H5_FORK_PLAN.vi.md>)
> Quy ước: ✅ xong (có bằng chứng) · 🔄 đã làm, chờ nghiệm thu thêm · ⏳ chờ · 🚫 chờ người dùng

## Tổng quan

| Giai đoạn | Việc | ✅ | 🔄 | ⏳ |
|---|---:|---:|---:|---:|
| A — Khóa phạm vi và tạo source fork | 6 | **6** | 0 | 0 |
| B — Khóa toolchain Windows và Web | 7 | **6** | 1 | 0 |
| C — Build đối chứng | 7 | **7** | 0 | 0 |
| D — Game mẫu và baseline | 7 | 0 | 6 | 1 |
| E — Editor EXE riêng | 8 | **7** | 1 | 0 |
| F — Cặp Web templates | 7 | **7** | 0 | 0 |
| G — Shell, Browser Preview, mobile | 8 | **5** | 0 | 3 |
| H — Tối ưu templates | 6 | **4** | 2 | 0 |
| I — Đóng gói, RC, bảo trì | 5 | **1** | 2 | 2 |
| **Tổng** | **61** | **43** | **12** | **6** |

**Gate đã đạt: A ✅ · C ✅ · F ✅** (3/9 gate)

Gate E và H: **đạt trên desktop, chờ thiết bị** (E08 chờ D07; H01/H06 cần số đo trên device floor).

---

## A — ✅ GATE A

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| A01 | Chốt phạm vi | ✅ | [scope-v0.1.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/scope-v0.1.md>) |
| A02 | Fingerprint | ✅ | [source-fingerprint.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/source-fingerprint.md>) |
| A03 | Clone full source | ✅ | `engine/godot-h5` @ `ed1daf0b` |
| A04 | Verify checkout | ✅ | shallow=false, sparse=off, filter=none, alternates=false, sạch |
| A05 | Branch + remote | ✅ | `upstream`=official; `origin`=`github.com/tamark-solo/godot-h5`; branch `indie/h5-platform` |
| A06 | Workspace + patch log | ✅ | [workspace-map.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/workspace-map.md>), [patch-log.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/patch-log.md>) |

## B — Toolchain

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| B01 | Host + device matrix | 🔄 | Host đầy đủ; **chờ model/OS Android + iPhone** |
| B02 | MSVC/SDK | ✅ | MSVC 14.51.36231 + SDK 10.0.26100.0, thỏa [detect.py:190-192](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/platform/windows/detect.py#L190-L192>) |
| B03 | Python | ✅ | 3.13.9 |
| B04 | SCons | ✅ | 4.11.1 |
| B05 | Emscripten | ✅ | 4.0.23 |
| B06 | SIMD/device floor | ✅ | `wasm_simd=yes` |
| B07 | Script env/build | ✅ | tools/env, tools/build, tools/serve, tools/test, tools/preview, tools/package |

## C — ✅ GATE C

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| C01–C06 | Control profile + editor + cặp template | ✅ | editor `custom_build.ed1daf0bf`; debug 6:58; release 8:14 |
| C07 | Export smoke | ✅ | [C07-export-smoke.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/C07-export-smoke.md>) — boot thật trong Chrome |

## D — Game mẫu

| ID | Việc | TT | Ghi chú |
|---|---|---|---|
| D01 | Fixture game 2D | 🔄 | [projects/h5-demo](<C:/Users/Mark-TA/Desktop/AppGame/projects/h5-demo>) |
| D02 | Vòng chơi | 🔄 | **Chạy thật trong Chrome**; thiếu test thiết bị |
| D03 | Hình/font/UI | 🔄 | SVG OK; **tiếng Việt hiển thị đúng**; thiếu atlas raster |
| D04 | Input mouse/touch | 🔄 | Chống double-fire; **chờ touch thật** |
| D05 | Âm thanh/lifecycle | 🔄 | Logic OK; chưa có audio asset |
| D06 | Save có version | 🔄 | **Chứng minh qua reload**; thiếu quota/private mode |
| D07 | Matrix baseline | ⏳ | **Chờ thiết bị + tunnel** |

## E — Editor EXE riêng (đạt trên desktop, chờ D07)

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| E01 | Spike entry points | ✅ | [E01-editor-entrypoints.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/E01-editor-entrypoints.md>) |
| E02 | Product identity | ✅ | "Godot H5 - Project Manager" |
| E03 | Tách user data | ✅ | `%APPDATA%/GodotH5`; official `Godot` nguyên vẹn |
| E04 | New H5 Project | ✅ | [E08-fork-editor.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/E08-fork-editor.md>) |
| E05 | Project H5 hợp lệ | ✅ | 39 file, addon tự bật |
| E06 | Nạp addon lần đầu | ✅ | 1 bật/1 tắt mỗi lần, lặp 4 lần sạch |
| E07 | Dock/config/validator | ✅ | [E07-validator-tests.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/E07-validator-tests.md>) — 3 negative test; addon v0.1.1 sửa lỗi #17 (dock ghi `design_resolution=(720, 1)`) |
| E08 | Fork editor | 🔄 | `e6a2176fb`, 13:10, rebuild khớp revision. **Kế hoạch: nghiệm thu E08 chờ D07** |

## F — ✅ GATE F

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| F01–F03 | Profile + cặp template fork | ✅ | debug 9.76 MB, release 9.86 MB, SHA256 đầy đủ |
| F04 | Manifest | ✅ | [web-templates-fork.json](<C:/Users/Mark-TA/Desktop/AppGame/docs/manifests/web-templates-fork.json>) |
| F05 | Nối preset | ✅ | preset trỏ cặp fork; validator **0 lỗi · 0 cảnh báo** |
| F06 | Chặn mismatch | ✅ | **3/3 negative test** (ZIP bị sửa, debug==release, sai source SHA) |
| F07 | GUI/CLI parity | ✅ | **byte-identical** `DAD3390FC9655F92…`; 9/10 file giống hệt |

Chi tiết: [F01-F07-templates.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/F01-F07-templates.md>)

## G — Shell, Browser Preview, mobile

| ID | Việc | TT | Ghi chú |
|---|---|---|---|
| G01 | HTML loader contract | ✅ | [G01-shell-contract.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/G01-shell-contract.md>) — phát hiện 2 lỗi nghiêm trọng |
| G02 | Loading/error/retry | ✅ | shell **v1.2.0** — **7/7 test nhánh lỗi PASS**; sửa 2 lỗi thật (spinner vô hạn, hộp lỗi ẩn) |
| G03 | Bridge/mock adapter | ✅ | `H5Bridge` v1.2.0 chạy thật |
| G04 | 3 luồng preview | ✅ | [G04-G05-preview.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/G04-G05-preview.md>) |
| G05 | Test lỗi + cleanup | ✅ | **7/7 ca PASS** (gồm 4 ca lỗi) |
| G06 | HTTPS/release host | ⏳ | **Chờ tunnel + thiết bị** |
| G07 | Input/viewport/audio | ⏳ | **Chờ thiết bị** |
| G08 | Save state/failure | ⏳ | **Chờ thiết bị** |

## H — Tối ưu templates

| ID | Việc | TT |
|---|---|---|
| H01 | Performance budgets | 🔄 | [H01-performance-budgets.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/matrix/H01-performance-budgets.md>) — số đo thật: cold 2.65 s, warm 1.24 s, p95 16.7 ms, memory +0.4 MB/60 s. **Chỉ Chrome desktop headless**, chưa phải device floor |
| H02 | Game mẫu thứ hai | ✅ | [H02-second-game.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/H02-second-game.md>) — puzzle kéo-thả, **7/7 PASS**, sửa **4 lỗi thật** |
| H03 | Phân tích module có thể bỏ | ✅ | [H03-strip-analysis.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/H03-strip-analysis.md>) |
| H04 | Build stripped debug | ✅ | 7.22 MB (từ 9.31 MB) |
| H05 | Build stripped release | ✅ | 7.31 MB (từ 9.40 MB) |
| H06 | Regression + quyết định | 🔄 | [H04-H06-strip-regression.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/H04-H06-strip-regression.md>) — **13/13 PASS trên desktop**, **GIỮ strip tạm thời**; chờ chạy trên thiết bị |

## I — Đóng gói, RC, bảo trì

| ID | Việc | TT | Bằng chứng |
|---|---|---|---|
| I01 | Portable ZIP | ✅ | Đóng lại 2026-10-26 12:10: 95.1 MB, addon v0.1.1, `VERSION.json` có hash cây template; chặn đóng gói nếu bản sao lệch nguồn |
| I02 | Test máy sạch | 🔄 | [I01-I02-portable.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/I01-I02-portable.md>) — đường dẫn Unicode/space/ổ D, export + boot OK. **Chưa phải máy sạch thật** (máy dev có Python/MSVC); Browser Preview hiện cần PowerShell + Python ngoài gói |
| I03 | Release hosting | ⏳ | Chờ tunnel |
| I04 | RC matrix | ⏳ | Chờ thiết bị |
| I05 | Maintenance + bàn giao | 🔄 | [RUNBOOK-maintenance.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/RUNBOOK-maintenance.md>) + [QUICKSTART.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/QUICKSTART.md>). **Chưa diễn tập upstream thật** (chưa có bản Godot mới hơn 4.7.2) |

---

## Bằng chứng then chốt

| Bằng chứng | Giá trị |
|---|---|
| Control editor | `4.7.2.stable.custom_build.ed1daf0bf` — khớp **chính xác** SHA |
| Fork editor | `4.7.2.stable.custom_build.e6a2176fb` — khớp commit E04 |
| Web template | hậu tố `.nothreads` |
| Boot (control) | `Godot Engine v4.7.2…ed1daf0bf` |
| Boot (fork) | **`Godot H5 v4.7.2…e6a2176fb`** — branding vào cả web runtime |
| Save qua reload | `Điểm cao: 40` + `Đã lưu (local)`; IndexedDB `/userfs` |
| Tách user data | `%APPDATA%/GodotH5`; official `Godot` nguyên vẹn |
| New H5 Project | 39 file, addon tự bật, tên giữ đúng |
| F06 negative tests | 3/3 chặn thật |
| F07 parity | GUI == CLI **byte-identical** |
| G05 negative tests | 4/4 (preset sai, port bận, stale server, preflight lỗi) |
| I02 clean-machine | Unicode + space + ổ D, export + boot OK |
| **Tổng patch fork** | **6 file, +145 / −4 dòng** |

## Lỗi thật đã phát hiện và sửa (17)

| # | Lỗi | Mức độ |
|---|---|---|
| 1 | Shell nạp `$GODOT_URL` sau script inline → không bao giờ boot | **Nghiêm trọng** |
| 2 | Shell tự set canvas size đánh nhau với `canvasResizePolicy=2` | Cao |
| 3 | Validator bỏ qua `[preset.N.options]` → **pass giả** | **Nghiêm trọng** |
| 4 | `star.gd` `gravity` trùng property native `Area2D` | Cao |
| 5 | `h5_validator.run()` nhận `null` nhưng khai báo `EditorInterface` | Cao |
| 6 | Validator false positive action dựng sẵn | Thấp |
| 7 | `build-web.ps1` tìm ZIP sai chỗ | Trung bình |
| 8 | `build-editor.ps1` chọn nhầm `.console.exe` | Thấp |
| 9 | PowerShell 5.1 biến stderr native thành terminating error | Trung bình |
| 10 | `os_windows.cpp` thiếu `#include "core/version.h"` | Cao |
| 11 | (quy trình) đọc-rồi-ghi cắt cụt file 2543 dòng | **Nghiêm trọng** |
| 12 | PowerShell 5.1 đọc .ps1 không BOM theo ANSI → lỗi cú pháp (12 script) | Cao |
| 13 | `export-web.ps1` phán xử chỉ bằng exit code → thất bại giả khi editor crash lúc thoát | Cao |
| 14 | `check-template-manifest.ps1` treo chờ nhập `-Label` | Trung bình |
| 15 | `build-web.ps1` gọi `emcc` trước khi activate → lỗi ở CollectOnly | Trung bình |
| 16 | Manifest `emcc` rỗng do `emcc` là `.ps1` | Thấp |
| 17 | Dock H5 gán ô X trước ô Y khi nạp config → commit `design_resolution=(720, 1)` vào cả 4 `h5_config.tres`; gói portable mang validator cũ (thiếu F06), e08 mang shell cũ (thiếu G02) do copy tay | **Cao** — sửa bằng `set_value_no_signal` + `tools/package/sync-template.ps1` |

## Việc cần người dùng

| # | Cần gì | Chặn |
|---|---|---|
| 1 | **Model + OS + browser version** Android và iPhone thật | B01, D07, G06–G08, I03–I04 |
| 2 | Xác nhận tunnel cụ thể (Cloudflare/ngrok) + hostname | G06, I03 |
| 3 | Thiết bị/máy Mac nếu làm giai đoạn J (macOS) | J |

## Việc tiếp theo (không cần người dùng)

| Ưu tiên | Việc |
|---|---|
| 1 | G04b — Browser Preview trong dock H5 bằng GDScript (preflight → export mới → xác minh artifact → server `TCPServer` 127.0.0.1 → so SHA256 → mở URL); bỏ phụ thuộc PowerShell/Python để I02 chạy được trên máy sạch |
| 2 | Chạy lại G05 (4 ca lỗi) và F06 (3 negative test) trên luồng mới, rồi đóng gói lại portable |
| 3 | Mở dock trên GUI xác nhận lỗi #17 không tái hiện |
| 4 | I05 — diễn tập maintenance khi có upstream candidate |

## Quyết định ghi nhận (2026-10-26)

- **Nguồn template duy nhất:** `tools/h5_template`. Bản sao (e08, projects, portable) chỉ cập nhật qua `tools/package/sync-template.ps1`; `assemble-portable.ps1` từ chối đóng gói nếu lệch.
- **Checkout engine chính:** `C:\Users\Mark-TA\Documents\godot-h5` (theo `tools/engine-dir.txt`). `AppGame/engine/godot-h5` là bản trùng cùng HEAD — **không commit ở đó**.
- **Browser Preview trong editor:** dùng server GDScript thay vì `EditorHTTPServer` (C++), vì cần chạy không Python, không tăng patch C++ fork, và dùng chung cho mọi nền tảng editor. Lệch khuyến nghị mục 8 của kế hoạch có chủ ý.
- **macOS:** ngoài scope v0.1. Nếu làm sẽ là **giai đoạn J** riêng (build editor trên Mac/Xcode, ký/notarize, đường dẫn `h5_template` trong `.app/Contents/Resources`, kiểm tra E03 trên macOS), cần estimate riêng.
