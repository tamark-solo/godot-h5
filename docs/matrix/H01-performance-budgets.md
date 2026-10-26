# H01 — Performance budgets (từ số đo THẬT)

> Ngày: 2026-10-26 · Harness: [measure-perf.mjs](<../../tools/test/measure-perf.mjs>)
> Nguồn số: [perf-h5-demo-debug.json](<perf-h5-demo-debug.json>), [perf-h5-demo-debug-gzip.json](<perf-h5-demo-debug-gzip.json>)

## 1. Số đo

| Chỉ số | Không nén | **Có gzip** | Ghi chú |
|---|---:|---:|---|
| **Cold boot** (tới khi overlay ẩn) | 5 366 ms | **2 652 ms** | Nhanh hơn **2.0×** |
| **Warm boot** | 1 236 ms | 2 616 ms | Xem mục 4 |
| **Tổng bytes truyền** | 37 169 654 | **9 815 941** | **26.4%** kích thước gốc |
| — `.wasm` | 36 767 826 | 9 674 077 | Nén tốt nhất |
| — `.js` | 315 339 | 78 943 | |
| — `.pck` | 64 872 | 50 831 | |
| — `.html` | 15 777 | 6 250 | |
| — `.png` | 5 840 | 5 840 | PNG đã nén sẵn |

### Frame time (299 mẫu, ~5 giây)

| | Không nén | Có gzip |
|---|---:|---:|
| p50 | 16.66 ms | 16.70 ms |
| p95 | 16.67 ms | 16.70 ms |
| p99 | 16.67 ms | 16.80 ms |
| avg | 16.67 ms | 16.67 ms |

→ **60 FPS ổn định**, độ lệch cực nhỏ (p50≈p99). Đây là headless Chrome desktop với game fixture rất nhẹ — **không** đại diện cho game thật hay thiết bị di động.

### Memory (soak 60 giây)

| | Không nén | Có gzip |
|---|---:|---:|
| JS heap sau boot | 9.0 MB | 9.2 MB |
| JS heap sau soak | 9.3 MB | 9.1 MB |
| Đỉnh | 10.2 MB | 10.8 MB |
| **Tăng trưởng** | **+0.4 MB** | **−0.1 MB** |

→ Trong 60 giây **không có dấu hiệu rò rỉ bộ nhớ**. Cần soak dài hơn (10 phút, 20 lần đổi scene) để kết luận chắc.

## 2. Phát hiện quan trọng: NÉN LÀ BẮT BUỘC

**`.wasm` chiếm 98.9% tổng bytes truyền** (36.8 MB / 37.2 MB). Không nén, mỗi người chơi phải tải **37 MB** — trên 4G thực tế (~10 Mbps) mất khoảng **30 giây**, không chấp nhận được cho game mobile.

Với gzip: **9.8 MB** (~8 giây trên 4G). Tỷ lệ nén **26.3%**.

> **Đây là yêu cầu bắt buộc cho I03 (release hosting):** host **phải** gửi `Content-Encoding: gzip` (hoặc brotli) cho `.wasm`. Brotli thường tốt hơn gzip 15–20% nữa.

## 3. Ngân sách đề xuất (bản đầu)

Dựa trên số đo, **chưa** phải cam kết cho mọi game:

| Hạng mục | Ngân sách | Cơ sở |
|---|---:|---|
| Tổng bytes truyền (nén) — **tầng engine** | **≤ 10 MB** | wasm nén 9.67 MB + loader |
| Tổng bytes truyền (nén) — **cả game** | **≤ 15 MB** | chừa ~5 MB cho asset game |
| Cold boot trên WiFi | ≤ 5 s | đo được 2.65 s |
| Warm boot | ≤ 2 s | đo được 1.24 s (không nén) |
| Frame time p95 | ≤ 33 ms (≥30 FPS) | đo được 16.7 ms |
| Memory tăng sau 10 phút | ≤ 20 MB | đo được +0.4 MB/60 s |

**Điều kiện áp dụng:** Chrome desktop, fixture h5-demo, mạng cục bộ. **Phải đo lại** trên thiết bị thật (D07) trước khi công bố.

## 4. Bất thường cần điều tra: warm boot có gzip CHẬM hơn

| | Không nén | Có gzip |
|---|---:|---:|
| Warm boot | **1 236 ms** | 2 616 ms |

**Giả thuyết:** server gzip của ta **nén lại mỗi request** (`gzip.compress` trong `do_GET`) và gửi `Cache-Control: no-store`. Với `no-store`, warm load gần như cold load — 2 616 ms là hợp lý. Còn 1 236 ms ở lần đo không nén có thể do cache đĩa của Chrome cho file **không** bị `no-store` chặn ở một số đường.

**Kết luận:** số warm boot ở đây **không đáng tin** vì server test cố tình gửi `no-store`. Cần đo lại trên host thật có cache header đúng (I03).

## 5. Hạn chế của phép đo

| Hạn chế | Ảnh hưởng |
|---|---|
| **Headless Chrome desktop**, `--disable-gpu` | Không đại diện GPU mobile; frame time có thể đẹp giả |
| Game fixture **rất nhẹ** (2D, 5 scene, 3 SVG) | Không đại diện game thật |
| Server **cục bộ** (`127.0.0.1`) | Không có độ trễ mạng thật |
| Server test gửi `no-store` | Warm boot không đáng tin |
| Soak **60 giây**, không đổi scene | Chưa phát hiện rò rỉ chậm |
| **Chưa đo draw calls / texture count** | Harness chưa lấy được từ engine |

## 6. Việc tiếp theo

| # | Việc | Chặn bởi |
|---|---|---|
| 1 | Đo lại trên **thiết bị thật** (Android/iPhone) | Cần thiết bị + tunnel |
| 2 | Soak **10 phút + 20 lần đổi scene** | Cần harness mở rộng |
| 3 | Đo **draw calls / texture count** | Cần đọc từ engine |
| 4 | Thử **brotli** | Cần host hỗ trợ |
| 5 | Đo lại **warm boot** trên host có cache header đúng | I03 |

## 7. Trạng thái

| Task | Trạng thái |
|---|---|
| **H01** | ✅ **budgets đặt từ số đo thật** (không hứa FPS/dung lượng chung) |
| H02 | ⏳ game mẫu thứ hai |
| H03–H06 | ⏳ phân tích strip + build + regression |
