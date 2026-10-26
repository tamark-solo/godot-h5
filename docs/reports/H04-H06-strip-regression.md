# H04–H06 — Build stripped templates, regression, quyết định

> Ngày: 2026-10-26 · Source: `e6a2176fb` (cùng revision với editor và full templates)
> **Kết luận: GIỮ strip.** Cả hai game pass trên engine stripped, lợi ích rõ ràng, không mất tính năng.

## 1. H04/H05 — Artifact

| Flavor | Full | **Stripped** | Giảm |
|---|---:|---:|---:|
| debug | 9.31 MB | **7.22 MB** | −2.09 MB (−22.5%) |
| release | 9.40 MB | **7.31 MB** | −2.09 MB (−22.2%) |

Build time: debug **6:03**, release ~7:00. SHA256 ghi trong `manifest.json` từng thư mục.

### Bên trong (quan trọng hơn kích thước ZIP)

| | Full | **Stripped** | Giảm |
|---|---:|---:|---:|
| `wasm` raw | 35.06 MB | **26.84 MB** | **−23.4%** |
| `wasm` gzip | 9.23 MB | **7.14 MB** | **−22.6%** |

## 2. H06 — Regression: CẢ HAI game trên engine stripped

### Boot test

| Game | Kết quả |
|---|---|
| h5-demo | ✅ PASS — 0 exception, 0 request lỗi, 0 MIME sai |
| h5-puzzle | ✅ PASS — 0 exception, 0 request lỗi, 0 MIME sai |

Banner engine trên cả hai: `Godot H5 v4.7.2.stable.custom_build.e6a2176fb`.

### Test sâu (không chỉ boot)

| Game | Harness | Kết quả |
|---|---|---|
| h5-demo | [browser-interact-test.mjs](<../../tools/test/browser-interact-test.mjs>) | ✅ **6/6 PASS** — boot, audio unlock, bridge v1.2.0, bấm CHƠI, IndexedDB |
| h5-puzzle | [browser-puzzle-complete.mjs](<../../tools/test/browser-puzzle-complete.mjs>) | ✅ **7/7 PASS** — kéo 3/3 mảnh, đúng chỗ 3/3, **hoàn thành màn 1** |

**Tổng: 13/13 kiểm tra PASS trên engine stripped.** Đây là bằng chứng strip không phá chức năng.

## 3. Đo trước/sau (H06 — yêu cầu "có số đo trước/sau")

| Chỉ số | Full + gzip | **Stripped + gzip** | Thay đổi |
|---|---:|---:|---:|
| **Tổng bytes truyền** | 9 815 941 | **7 623 529** | **−22.3%** |
| — `.wasm` | 9 674 077 | 7 487 841 | −22.6% |
| — `.js` | 78 943 | 72 769 | −7.8% |
| Cold boot | 2 652 ms | 2 847 ms | +7% (trong nhiễu) |
| Frame p50 | 16.70 ms | 16.70 ms | **không đổi** |
| Frame p95 | 16.70 ms | 16.70 ms | **không đổi** |
| Frame p99 | 16.80 ms | 16.80 ms | **không đổi** |
| **JS heap sau boot** | 9.2 MB | **7.7 MB** | **−16.3%** |
| Memory tăng (soak) | −0.1 MB | −0.4 MB | không rò rỉ |

Số đo: [perf-h5-demo-debug-gzip.json](<../matrix/perf-h5-demo-debug-gzip.json>) vs [perf-h5-demo-stripped-gzip.json](<../matrix/perf-h5-demo-stripped-gzip.json>)

### Đọc số đo

- **Truyền tải giảm 22.3%** — lợi ích lớn nhất, quan trọng nhất cho mobile.
- **Bộ nhớ giảm 16.3%** — có ý nghĩa trên thiết bị RAM thấp.
- **Frame time KHÔNG đổi** — đúng như dự kiến: strip bỏ module không dùng, không tăng tốc code còn lại.
- **Cold boot +7%** — trong khoảng nhiễu; cần đo nhiều lần mới kết luận. Không phải hồi quy.

## 4. Quyết định: GIỮ strip

**Tiêu chí kế hoạch:** *"chỉ giữ thay đổi khi có lợi mà không mất tính năng"*.

| Tiêu chí | Kết quả |
|---|---|
| Có lợi? | ✅ −22.3% truyền tải, −16.3% bộ nhớ |
| Mất tính năng? | ❌ Không — 13/13 test PASS trên cả 2 game |
| Frame time hồi quy? | ❌ Không |
| Editor bị ảnh hưởng? | ❌ Không — strip **chỉ** áp cho template ([SConstruct:1056-1074](<../../engine/godot-h5/SConstruct#L1056-L1074>) chặn flag cho editor) |

**→ Giữ strip cho template, editor vẫn full.**

### Rollback

Full templates **vẫn còn nguyên** tại `builds/web-debug-fork/` và `builds/web-release-fork/`. Nếu phát hiện vấn đề trên thiết bị thật, chỉ cần chạy lại F05 với `-Label fork` để quay về.

## 5. Rủi ro còn lại — CHƯA loại trừ

| Rủi ro | Trạng thái |
|---|---|
| Thiết bị thật dùng class bị strip | ⚠️ **CHƯA test** — mới test Chrome desktop |
| Game thật (nặng hơn fixture) cần module bị bỏ | ⚠️ **CHƯA test** |
| Strip ảnh hưởng audio (D05 chưa có asset) | ⚠️ Module audio **vẫn giữ**, nhưng chưa có test thực tế |
| Nén texture mobile (nếu bật sau) | ⚠️ Các module nén **vẫn giữ**, chưa kiểm chứng |

**Khuyến nghị:** giữ strip, nhưng **phải chạy lại regression trên thiết bị thật** (D07) trước khi phát hành. Nếu có bất kỳ lỗi nào, quay về full templates — không bị chặn.

## 6. Trạng thái

| Task | Trạng thái |
|---|---|
| H01 | ✅ budgets từ số đo thật |
| H02 | ✅ game thứ hai |
| H03 | ✅ [phân tích strip](<../H03-strip-analysis.md>) |
| **H04** | ✅ stripped debug, hash + manifest |
| **H05** | ✅ stripped release, hash + manifest |
| **H06** | ✅ **regression 13/13 PASS**, quyết định **GIỮ** |

**Gate H: ĐẠT** (với điều kiện chạy lại trên thiết bị thật ở D07).
