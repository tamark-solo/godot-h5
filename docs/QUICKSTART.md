# Quickstart — Godot H5

> Cho người dùng mới. Mục tiêu: **giải nén → tạo project → chỉnh sửa → preview → export**.
> Bản: `GodotH5-20261026` · Engine `e6a2176fb`

## 1. Cài đặt

1. Giải nén `GodotH5-20261026.zip` vào thư mục bạn muốn (đường dẫn có dấu/khoảng trắng **vẫn chạy**, đã kiểm chứng).
2. Chạy `godot.windows.editor.x86_64.exe`.
3. **Không cần** cài Godot, Python, compiler hay template global. Mọi thứ đã nằm trong gói.

> Editor này dùng thư mục riêng `%APPDATA%\GodotH5` — **không đụng** vào cài đặt Godot chính thức nếu bạn có.

## 2. Tạo project H5

1. Trong Project Manager, bấm **Create** (hoặc **Create New Project**).
2. Đặt tên và đường dẫn.
3. Chọn renderer **Compatibility** (bắt buộc cho Web).
4. Giữ tick ☑ **"Create H5 Project (Web export ready)"**.
5. Bấm **Create**.

Project mới đã có sẵn:
- addon H5 (dock + validator + export hook) **đã bật**
- `h5_config.tres` — cấu hình H5
- `export_presets.cfg` — preset **Web** với `threads=off`, `extensions=off`, `PWA=off`
- `h5_shell.html` — HTML shell có loading/error/retry
- game mẫu (menu → chơi → kết quả)

> Muốn project Godot **thường** (không có H5)? Bỏ tick ở bước 4.

## 3. Chỉnh sửa

- Mở scene trong `scenes/`, sửa như Godot bình thường.
- Dock **H5** (bên phải) để chỉnh: tiêu đề, độ phân giải thiết kế, orientation, preset, texture policy.
- Bấm **Kiểm tra** trong dock để chạy preflight validator.

### Validator bắt gì

| Mức | Ví dụ |
|---|---|
| **Lỗi** | Renderer không phải Compatibility · thiếu main scene · preset bật threads/extensions · debug và release trỏ cùng file |
| **Cảnh báo** | Texture quá lớn · audio quá nặng · action chưa khai báo · dùng API không có trên web |
| **Thông tin** | Preset chưa dùng custom HTML shell |

## 4. Native Preview

Bấm ▶ (Play) trong editor — chạy game trên Windows như bình thường.

> Native pass **không** có nghĩa là web pass. Phải test web riêng.

## 5. Kiểm tra H5 trước khi export

Trong terminal, từ thư mục gói:

```powershell
# Chạy preflight validator (exit 0 = pass, 1 = có lỗi)
.\godot.windows.editor.x86_64.console.exe --headless --path <duong-dan-project> `
  --script res://addons/h5/h5_validate_cli.gd
```

## 6. Browser Preview

```powershell
.\tools\preview\browser-preview.ps1 -Project <duong-dan-project> -Port 8070
```

Script này làm 5 bước và **dừng nếu có lỗi**:

1. Chạy preflight validator — có lỗi thì **dừng**, không export
2. Export debug **mới** (dọn output cũ trước)
3. Ghi build ID, kiểm tra artifact đủ bộ
4. Start/reuse server — **xác minh nội dung** khớp bản vừa export
5. Mở URL

> Nếu port đang có server **cũ**, script **từ chối** mở browser (tránh xem bản cũ). Dùng `-Port` khác hoặc `stop-preview-server.ps1`.

Dừng server:

```powershell
.\tools\preview\stop-preview-server.ps1 -Port 8070
```

## 7. Release Export

```powershell
.\tools\build\export-web.ps1 -Project <duong-dan-project> -Flavor release
```

Hoặc trong editor: **Project → Export…** → chọn preset **Web** → **Export Project…**

Cả hai đường cho ra artifact **giống hệt nhau** (đã kiểm chứng byte-identical).

## 8. Đưa lên hosting

### Bắt buộc

| Yêu cầu | Lý do |
|---|---|
| **HTTPS** | Engine cần secure context (kể cả `threads=no`) |
| **MIME `application/wasm`** cho `.wasm` | `WebAssembly.instantiateStreaming` từ chối MIME sai |
| **Nén gzip hoặc brotli** | `.wasm` ~27 MB không nén → **~7 MB** có nén (**−74%**) |

### Test cục bộ

```powershell
.\tools\serve\serve-web.ps1 -Dir builds\web\<project>-release -Port 8070
```

### Test trên điện thoại

`http://IP-LAN-PC` **KHÔNG** tương đương localhost — điện thoại sẽ báo lỗi secure context. Cần tunnel HTTPS:

```bash
cloudflared tunnel --url http://localhost:8070
# hoặc
ngrok http 8070
```

## 9. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| "Cần kết nối HTTPS" | Đang mở qua `http://` (không phải localhost) | Dùng HTTPS hoặc tunnel |
| "Thiếu WebGL2" | Tắt tăng tốc phần cứng | Bật lại trong trình duyệt |
| "Không tải được index.js" | Thiếu file hoặc sai MIME | Kiểm tra đã deploy đủ `.js/.wasm/.pck` |
| "Tải engine quá lâu — có thể thiếu file" | Thiếu `.wasm`/`.pck`, hoặc mạng chậm | Kiểm tra file trên host |
| "Khởi động thất bại" | `.wasm`/`.pck` thiếu hoặc MIME sai | Xem chi tiết trong hộp lỗi |
| Game chạy nhưng không có tiếng | Chưa có gesture | Chạm vào màn hình một lần |
| Nút bị "kẹt" sau khi chuyển app | Mất focus giữa lúc kéo | Đã xử lý trong fixture; kiểm tra code của bạn |
| Save báo "Lưu thất bại" | IndexedDB bị chặn / hết quota | Chế độ riêng tư hoặc storage đầy — game vẫn chơi được |

### Bật log chi tiết

Mở DevTools (F12) → Console. Engine in:
```text
Godot H5 v4.7.2.stable.custom_build.e6a2176fb
OpenGL ES 3.0 (WebGL 2.0) - Compatibility
Build configuration: Emscripten 4.0.23, single-threaded, no GDExtension support.
```

## 10. Giới hạn đã biết

- **Chưa nghiệm thu trên thiết bị di động thật** (Android/iPhone) — cần làm trước khi phát hành.
- **Chưa test audio thực tế** (fixture chưa có asset âm thanh).
- **Chưa test nhập văn bản / bàn phím ảo.**
- **Không hỗ trợ** 3D, GDExtension web, threads, PWA/service worker.
- **Không có** installer/updater/signing — chỉ portable ZIP.
- Mất WebGL context giữa chừng: hiện chỉ báo lỗi và hướng reload, **không** tự khôi phục.
- Save cục bộ **không** chống được browser xoá site data.
