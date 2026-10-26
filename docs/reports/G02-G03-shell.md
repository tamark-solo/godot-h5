# G02/G03 — Shell loading/error/retry và browser bridge

> Ngày: 2026-10-26 · Shell **v1.2.0** · Harness: [browser-error-test.mjs](<C:/Users/Mark-TA/Desktop/AppGame/tools/test/browser-error-test.mjs>)
> **Kết luận: PASS** — 7/7 ca, sau khi sửa **2 lỗi thật** do chính test này phát hiện.

## 1. Yêu cầu G02 và cách kiểm chứng

Kế hoạch yêu cầu: *"Có progress/initializing/ready/fail; WebGL2/secure context/WASM-PCK-fetch errors có message/retry, **không spinner vô hạn**; giữ boot placeholders."*

Cách kiểm chứng: phục vụ artifact **thật**, rồi **phá hoại có chủ đích** từng nhánh hỏng.

| Fixture | Cách tạo |
|---|---|
| `missing-wasm` | Export thật, rồi **xóa `index.wasm`** |
| `missing-js` | Export thật, rồi **xóa `index.js`** |
| `ok` + chặn WebGL | Export nguyên vẹn + chèn script chặn `getContext('webgl*')` trả `null` |
| `ok` | Đối chứng |

## 2. Kết quả: 7/7 PASS

| # | Ca | Mong đợi | Thực tế |
|---|---|---|---|
| 1 | Thiếu `index.wasm` | Hiện lỗi, **không spinner vô hạn** | ✅ `Tải engine quá lâu — có thể thiếu file` |
| 2 | Thiếu `index.wasm` | Có nút Thử lại | ✅ `retry visible: true` |
| 3 | Thiếu `index.js` | Hiện lỗi rõ ràng | ✅ `Không tải được index.js` + hộp chi tiết |
| 4 | Thiếu `index.js` | Nhắc tới loader | ✅ có nhắc `.js/.wasm/.pck` |
| 5 | WebGL2 không khả dụng | Hiện lỗi | ✅ `Thiết bị/trình duyệt thiếu tính năng bắt buộc` |
| 6 | WebGL2 không khả dụng | Có hướng dẫn WebGL2 | ✅ `Thiếu WebGL2: bật tăng tốc phần cứng…` |
| 7 | Bản bình thường (đối chứng) | Boot được | ✅ overlay ẩn, `Engine` có mặt |

## 3. HAI LỖI THẬT do test này phát hiện

### Lỗi 1 — Spinner vô hạn khi thiếu `.wasm` (VI PHẠM yêu cầu G02)

**Triệu chứng:** xóa `index.wasm` → shell quay **mãi mãi** ở "Đang tải engine…", không bao giờ báo lỗi.

**Nguyên nhân:** loader của engine **không** báo lỗi khi file `.wasm` thiếu trong trường hợp này — promise không resolve cũng không reject. Shell chỉ biết chờ.

**Đây chính xác là điều kế hoạch cấm:** *"không spinner vô hạn"*.

**Sửa:** thêm **watchdog** hai ngưỡng:

| Ngưỡng | Mặc định | Ý nghĩa |
|---|---:|---|
| `STALL_TIMEOUT_MS` | 60 000 ms | Không có **tiến triển** (`onProgress` không gọi) trong bao lâu thì coi như treo |
| `HARD_TIMEOUT_MS` | 180 000 ms | Trần tuyệt đối cho toàn bộ quá trình boot |

Watchdog được **reset mỗi lần `onProgress` chạy** (nên tải chậm mà vẫn tiến triển thì không bị cắt), và được **dừng** khi thành công hoặc khi có lỗi khác.

Có thể ghi đè để test/tinh chỉnh: `?stallMs=8000` trên URL, hoặc `window.H5ShellConfig`.

### Lỗi 2 — Hộp chi tiết lỗi không hiện khi `raw` là `null`

**Triệu chứng:** nhánh thiếu `index.js` gọi `showError(title, detail, null)` → chỉ hiện tiêu đề, **không** hiện chi tiết.

**Nguyên nhân:**
```js
if (raw) { elError.style.display = "block"; elError.textContent = String(raw); }
```
Điều kiện `if (raw)` khiến hộp lỗi **không bao giờ hiện** khi `raw` falsy.

**Sửa:** **luôn** hiện hộp lỗi; nếu không có `raw` thì dùng `title + detail` làm nội dung.

## 4. G03 — Browser bridge

`window.H5Bridge` v1.2.0 (đã kiểm chứng chạy thật):

| API | Mục đích |
|---|---|
| `on(evt, fn)` / `emit(evt, payload)` | Đăng ký và phát sự kiện |
| `host` | Chỗ gắn SDK publisher thật; **vắng mặt vẫn boot bình thường** |
| `ready()` | Phát khi engine khởi động xong |
| `pause()` / `resume()` | Nối từ `visibilitychange`, `blur`/`focus` |
| `showAdMock(placement)` | Mock quảng cáo — **no-op**, trả `{shown:false, reason:"mock"}` |
| `analyticsMock(name, params)` | Mock analytics — chỉ log |
| `saveEvent(state, detail)` | Phát sự kiện save |
| `emit("error", …)` | Phát khi shell báo lỗi |

Đã kiểm chứng: `H5Bridge` tồn tại (v1.2.0), `ready` phát khi boot xong, overlay audio unlock hoạt động, không exception.

## 5. Trạng thái

| Task | Trạng thái |
|---|---|
| G01 | ✅ |
| **G02** | ✅ **7/7 PASS** — 2 lỗi thật đã sửa |
| **G03** | ✅ bridge chạy thật |
| G04/G05 | ✅ [G04-G05-preview.md](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/G04-G05-preview.md>) |
| G06–G08 | ⏳ chờ thiết bị thật + tunnel |

## 6. Giới hạn — CHƯA nghiệm thu

- Toàn bộ trên **Chrome desktop headless**.
- Nhánh **secure context** (`isSecureContext === false`) **chưa** test được: `127.0.0.1` luôn là secure context. Cần host qua `http://IP-LAN` mới tái hiện được.
- Chưa test **context loss** (mất WebGL context giữa chừng).
- Chưa test **touch thật**.
