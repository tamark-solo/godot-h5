# Baseline metrics — mẫu ghi số đo

> Điền cho **mỗi** tổ hợp (build × thiết bị × network profile).
> Mọi số đo **phải** gắn với build ID. Không công bố FPS/dung lượng chung cho mọi game.

## Nhận dạng build

| Trường | Giá trị |
|---|---|
| Ngày đo | |
| Người đo | |
| Source SHA (engine) | |
| Fork revision / patch | |
| Editor build ID | |
| Template flavor | debug / release |
| Template SHA256 | |
| Shell version | |
| Game | h5-demo / h5-puzzle |
| Build ID (export) | |
| URL | |

## Thiết bị / môi trường

| Trường | Giá trị |
|---|---|
| Thiết bị | |
| OS version | |
| Browser + version | |
| `window.isSecureContext` | |
| Màn hình / DPR | |
| Network profile | ví dụ: 4G ~10 Mbps, RTT 80 ms / WiFi / Fast 3G |

## 1. Tải trang (cold / warm)

| Chỉ số | Cold | Warm | Ghi chú |
|---|---:|---:|---|
| Tổng bytes truyền (compressed) | | | DevTools → Network, "Transferred" |
| Trong đó `.wasm` | | | |
| Trong đó `.pck` | | | |
| Trong đó JS loader | | | |
| Thời gian tới WASM init xong | | | |
| Thời gian tới PCK/assets decode xong | | | |
| **Thời gian tới tương tác đầu tiên** | | | Từ navigation start tới frame đầu phản hồi input |
| Số request | | | |

## 2. Frame time

| Chỉ số | Giá trị | Ghi chú |
|---|---:|---|
| Frame time p50 | | ms |
| Frame time p95 | | ms |
| Frame time p99 | | ms |
| Draw calls | | |
| Texture count | | |
| FPS trung bình | | Chỉ ghi kèm bối cảnh, không hứa chung |

## 3. Bền vững (soak)

| Chỉ số | Sau 1 phút | Sau 10 phút | Sau 20 lần đổi scene |
|---|---:|---:|---:|
| Memory (JS heap + WASM) | | | |
| Số node trong cây scene | | | |
| Cảnh báo/lỗi console | | | |

## 4. Kết luận

| Trường | Giá trị |
|---|---|
| Pass / Fail | |
| Boot blocker? | |
| Repro (nếu fail) | |
| Log / ảnh | |
