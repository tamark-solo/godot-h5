# B01 — Device / host matrix

> **Trạng thái: ĐANG CHỜ THÔNG TIN NGƯỜI DÙNG.**
> Các ô `<...>` phải được điền bằng thiết bị **thật**. Emulator **không** thay thế nghiệm thu mobile.
> Theo kế hoạch: nếu chưa truy cập được Android/iPhone thật hoặc trusted HTTPS thì D07 và gate mobile được đánh dấu **ĐANG CHỜ**, không được claim H5 mobile đã pass.

## 1. Host build (máy phát triển)

| Trường | Giá trị | Ghi chú |
|---|---|---|
| Máy | `<hostname>` | |
| OS | Windows 10.0.26100 | Đã xác minh |
| CPU | `<model>` | |
| RAM | `<GB>` | |
| Disk trống (C:) | 262.8 GB | Đã xác minh 2026-10-25 |
| Visual Studio | 18.10.3 Community | Đã xác minh |
| MSVC toolset | 14.51.36231 | Đã xác minh |
| Windows SDK | 10.0.26100.0 | Đã xác minh |
| Python | 3.13.9 (`%LOCALAPPDATA%\Programs\Python\Python313`) | Đã xác minh |
| SCons | 4.11.1 | Đã cài 2026-10-25 |
| Emscripten | 4.0.23 (pin) | Đang cài |
| Git | 2.56.0.windows.1 | Đã xác minh |

## 2. Thiết bị test

### Android

| Trường | Giá trị |
|---|---|
| Model | `<ví dụ: Samsung Galaxy A54>` |
| OS version | `<Android 14>` |
| Chrome version | `<...>` |
| Người giữ thiết bị | `<tên>` |
| Cách truy cập HTTPS staging | `<LAN + cert / tunnel / DNS>` |

### iPhone

| Trường | Giá trị |
|---|---|
| Model | `<ví dụ: iPhone 13>` |
| iOS version | `<iOS 18.x>` |
| Safari version | `<đi kèm iOS>` |
| Người giữ thiết bị | `<tên>` |
| Cách truy cập HTTPS staging | `<...>` |

### iPad (tuỳ chọn)

| Trường | Giá trị |
|---|---|
| Model | `<...>` |
| iPadOS version | `<...>` |

## 3. PC browser

| Trình duyệt | Version | Ghi chú |
|---|---|---|
| Chrome | `<...>` | Gate chính |
| Edge | `<...>` | Gate chính |
| Firefox | `<...>` | Kiểm tra sau, không phải gate |

## 4. HTTPS staging

| Trường | Giá trị |
|---|---|
| Hostname | `<staging.example.com>` |
| Cách cấp cert | `<Let's Encrypt / cert nội bộ / tunnel>` |
| Cert được thiết bị tin cậy? | `<có/không>` |
| `window.isSecureContext` | `<true/false>` |
| MIME `application/wasm` | `<đã cấu hình?>` |
| Compression | `<gzip / brotli / none>` |

**Lưu ý:** `http://IP-LAN-PC` **không** tương đương localhost. Godot kiểm tra secure context **ngay cả khi** `threads=no`.

## 5. Người liên hệ / người giữ thiết bị

| Thiết bị | Người giữ | Liên hệ |
|---|---|---|
| Android | `<...>` | `<...>` |
| iPhone | `<...>` | `<...>` |
