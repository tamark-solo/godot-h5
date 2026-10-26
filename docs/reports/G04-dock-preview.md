# G04 (dock) — Browser Preview trong dock H5

> Ngày: 2026-10-26 · Addon v0.2.0 · Editor fork e08 `4.7.2.stable.custom_build.e6a2176fb`
> **Kết luận: PASS trên desktop (Windows + Chrome).** Thay thế luồng PowerShell + Python của [G04-G05-preview.md](<G04-G05-preview.md>) cho người dùng cuối; script cũ giữ lại cho CI.

## 1. Thành phần

| File | Vai trò |
|---|---|
| `addons/h5/h5_preview_server.gd` | Server HTTP trên Thread riêng; chỉ `127.0.0.1`, GET/HEAD, kiểm Host (chống DNS rebinding), chặn `..`, MIME `application/wasm`, COOP/COEP, `no-store` |
| `addons/h5/h5_preview_runner.gd` | Lưu scene → chờ scan/import → preflight → export debug mới (`--headless --export-debug`, nền) → kiểm artifact/magic/build ID → serve → so SHA256 → mở URL |
| `addons/h5/h5_dock.gd` | Mục "Browser Preview": Preview/Re-export, Port (mặc định 8070), Mở lại, Copy URL, Dừng server, trạng thái + log |

Quyết định thiết kế: server GDScript thay `EditorHTTPServer` (không bind cho script) để chạy được không cần Python/PowerShell và không thêm patch C++. Port 8070 để không trùng "Run in Browser" của Godot (8060).

## 2. Kết quả (editor fork thật, bản sao h5-demo)

| Ca | Kết quả |
|---|---|
| Luồng bình thường | ✅ SHA256 index.html khớp; wasm 28 MB tải 116–158 ms |
| Boot trong Chrome từ server của dock | ✅ `RESULT: PASS` — 0 exception, 0 request lỗi, 0 MIME sai, H5Bridge v1.2.0 |
| Bấm Play khi server đang phục vụ | ✅ game native chạy, server vẫn phục vụ (8 request), trình duyệt boot PASS |
| Bấm Preview lần 2 khi đang chạy | ✅ bị từ chối |
| Sửa file trong lúc export | ✅ báo "bản preview ĐÃ CŨ" + tên file |
| Preflight lỗi (`forward_plus`) | ✅ dừng trước export |
| Preset không tồn tại | ✅ preflight chặn |
| Port bị tiến trình khác chiếm | ✅ báo rõ, không tự đổi port |
| `/../project.godot`, đuôi lạ | ✅ 404 |
| Bật/tắt plugin 4 lần | ✅ luôn đúng 1 dock khi bật, 0 khi tắt; port nhả mỗi lần tắt |
| Đóng editor | ✅ port nhả, 0 tiến trình sót |

## 3. Lỗi sửa trong bước này

- **#19** build ID chứa dấu cách (`…-20261026 123839`): `get_datetime_string_from_system(false, true)` dùng space thay `T`. Sửa tham số thứ hai thành `false` → `…-20261026-124219`.

## 4. Giới hạn — CHƯA nghiệm thu

- Chưa đo riêng tốc độ tải khi editor **mất focus** (server chạy thread riêng nên về thiết kế không phụ thuộc tick editor).
- Chưa nhìn bố cục dock bằng mắt trên GUI.
- Bản web không nối debugger editor; log xem trong DevTools.
- Chỉ Chrome desktop; mobile vẫn chờ G06/G07 (tunnel + thiết bị).
- macOS chưa test (cần editor macOS — giai đoạn J).
