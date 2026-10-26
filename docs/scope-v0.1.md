# A01 — Phạm vi bản đầu (Scope v0.1)

> Trạng thái: **ĐÃ CHỐT** cho giai đoạn A–I của `GODOT_H5_FORK_PLAN.vi.md`.
> Ngày chốt: 2026-10-25. Mọi mục thêm ngoài danh sách này phải có estimate riêng, không tự động nhận support.

## 1. Sản phẩm

Ứng dụng editor desktop **fork từ Godot** (không phải official editor + addon) có khả năng tạo project và xuất game **H5 chạy trên trình duyệt**.

Deliverable cuối (Gate I): **portable ZIP** chạy trên Windows sạch, gồm editor EXE build từ fork, New H5 Project, addon/config/validator, Native Preview, Browser Preview, Release Export, cặp Web export templates debug/release cùng revision và game mẫu.

## 2. Nền tảng được hỗ trợ (bản đầu)

| Hạng mục | Chốt |
|---|---|
| Editor host | Windows x64 (Windows 10/11) |
| Engine nguồn | Godot 4.7.2-stable, SHA `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Loại game | 2D |
| Ngôn ngữ gameplay | GDScript |
| Renderer | Compatibility (WebGL2) |
| Web runtime | single-thread (`threads=no`), không GDExtension (`dlink_enabled=no`) |
| Lưu trữ | Local save qua cơ chế web của Godot (IndexedDB); **không** cloud save |
| Phân phối | Portable ZIP; **không** installer/updater/signing |
| PWA / service worker | **Ngoài scope** |

## 3. Ma trận trình duyệt/thiết bị mục tiêu

| Nhóm | Mục tiêu | Ghi chú |
|---|---|---|
| PC | Chrome, Edge (bản stable mới nhất tại thời điểm test) | Firefox: kiểm tra sau, không phải gate |
| Android | Chrome trên **thiết bị thật** | Emulator chỉ là kiểm tra phụ, không thay nghiệm thu |
| iOS | Safari trên **iPhone thật** | iPad: bổ sung khi có thiết bị |
| Native | Editor Windows (control baseline) | Không dùng native pass để suy ra web pass |

**Điều kiện bắt buộc cho mobile:** trusted HTTPS (hostname + SAN đúng, cert được thiết bị tin cậy) và `window.isSecureContext === true`.
`http://IP-LAN-PC` **không** tương đương localhost và **không** được dùng làm bằng chứng H5 mobile.

## 4. Ngoài scope bản đầu

3D · browser-hosted editor · TypeScript gameplay runtime · GDExtension web · threads · publisher/ad SDK thật · payment/backend · account/cloud save/sync · PWA/offline service worker · installer/signing/updater · crash reporting/telemetry production · visual no-code editor thay thế editor Godot.

Mỗi mục trên cần estimate và gate riêng khi nền tảng đã ổn định.

## 5. Ràng buộc kỹ thuật đã biết (từ source reference)

- `threads=no` **chỉ** áp cho Web runtime. Editor Windows giữ thread mặc định.
- Một số strip flag (ví dụ `disable_3d`) **bị cấm** cho target editor.
- Hai Web flavor dùng chung `bin/.web_zip` → **không build debug/release song song** trong cùng source tree.
- Custom-template validation của Godot chủ yếu kiểm **file tồn tại** → fork phải tự làm manifest + hash + flavor check.
- Preview server mặc định gửi COOP/COEP + `no-store` → **không** đại diện hosting production.

## 6. Định nghĩa "xong" cho mỗi task

Mỗi ID trong backlog phải có: **đầu ra** nêu trong bảng + **bằng chứng** (log/hash/report) lưu trong `docs/`, gắn với source SHA, toolchain version và build ID. Compile thành công **không** được dùng làm bằng chứng game chạy trên thiết bị.

## 7. Việc cần người dùng xác nhận (đang mở)

- **B01:** model Android/iPhone thật, OS/browser version, người giữ thiết bị.
- **HTTPS staging:** tên miền/subdomain và cách cấp cert cho thiết bị thật.
- **A05:** URL repository riêng cho `origin` (nếu muốn push fork lên remote riêng).
