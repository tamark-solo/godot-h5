# G04/G05 — Browser Preview và xử lý lỗi

> Ngày: 2026-10-26 · Script: [browser-preview.ps1](<../../tools/preview/browser-preview.ps1>) + [stop-preview-server.ps1](<../../tools/preview/stop-preview-server.ps1>)
> **Kết luận: PASS** — 7/7 ca kiểm thử, gồm 4 ca lỗi.

## 1. Luồng 5 bước

```text
[1/5] Preflight validator   -> có ERROR thì DỪNG (không export, không mở browser)
[2/5] Export debug MỚI      -> output được dọn trước; fail thì DỪNG
[3/5] Build ID + artifact   -> kiểm tra đủ file + magic bytes WASM
[4/5] Static server         -> start/reuse CÓ XÁC MINH NỘI DUNG
[5/5] Mở URL thật
```

## 2. Điểm cốt lõi: xác minh nội dung, không chỉ "HTTP 200"

**Vấn đề:** kiểm tra "port có server trả 200" là **không đủ**. Một server cũ còn sót lại sẽ trả 200 cho **bản export trước đó** — đúng loại lỗi mà G04 cấm ("không được mở output cũ như thể export thành công").

**Cách làm:** so sánh **SHA256 của `index.html` mà server trả về** với **file vừa export**. Khác nhau ⇒ từ chối, không mở browser.

```powershell
function Test-ServedMatches([int]$p, [string]$localIndex) {
    $bytes = (New-Object System.Net.WebClient).DownloadData("http://127.0.0.1:$p/index.html")
    $servedHash = Get-Sha256OfBytes $bytes
    $localHash  = (Get-FileHash $localIndex -Algorithm SHA256).Hash
    ...
}
```

Server mới khởi động cũng phải **vượt qua** phép kiểm tra này (thử tối đa 10 lần) trước khi được coi là hợp lệ.

## 3. Kết quả kiểm thử (7/7 PASS)

| # | Ca | Mong đợi | Thực tế | Exit |
|---|---|---|---|---|
| A | Preset không tồn tại | Fail, không mở browser | ✅ `EXPORT THAT BAI` | **2** |
| B | Port bị tiến trình khác chiếm | Phát hiện | ✅ nhận diện + xác minh nội dung | — |
| C | Preflight có ERROR (renderer `forward_plus`) | Dừng **trước** export | ✅ `PREFLIGHT THAT BAI`, không export | **1** |
| D | **Server cũ (stale) trên port** | **Từ chối** | ✅ `noi dung KHAC ban vua export` + in cả 2 hash | **4** |
| E | Luồng bình thường, port trống | Thành công | ✅ server mới + xác minh OK | **0** |
| F | Chạy lại ngay cùng port | Reuse (nội dung khớp) | ✅ `phuc vu DUNG ban vua export -> REUSE` | **0** |
| G | Stop server | Port trả về trống | ✅ `da dung server PID 5424`, port trống | — |

### Bằng chứng ca D (quan trọng nhất)

```text
port 8075 co server nhung noi dung KHAC ban vua export (server cu/stale?)
  server tra ve : 40C71E2DC76C36C6...
  ban vua export: 1FBE331B31D8C2F9...
=> TU CHOI mo browser (tranh phuc vu ban CU).
```

Server cũ được dựng có chủ ý với `index.html` chứa chuỗi `"BAN CU - KHONG DUOC PHEP PHUC VU"` để chứng minh phép so sánh thật sự hoạt động, không phải trùng hợp.

## 4. Sự cố đã gặp và xử lý

### 4.1 Editor crash lúc THOÁT sau khi export xong

| Trường | Giá trị |
|---|---|
| Triệu chứng | `exit -1073741819` (0xC0000005 access violation), `ERROR: Parameter "singleton" is null` tại [EditorNode::is_cmdline_mode](<../../engine/godot-h5/editor/editor_node.cpp#L6617-L6620>) |
| Thời điểm | **Sau** khi `savepack` xong, build ID đã ghi, plugin đã tắt sạch |
| Tính chất | **Không ổn định** — 6 lần chạy trực tiếp liên tiếp đều exit **0** |
| Có phải do patch fork? | **Không.** Cả control editor và fork editor đều exit 0 khi chạy trực tiếp |

**Xử lý (quan trọng):** `export-web.ps1` **không** còn phán xử chỉ bằng exit code. Thay vào đó xác minh **artifact thật**:

- đủ 4 file bắt buộc (`index.html`, `index.js`, `index.wasm`, `index.pck`);
- kích thước tối thiểu (wasm ≥ 1 MB — bắt trường hợp bị cắt ngắn);
- **magic bytes** của WASM: `00 61 73 6D`.

Nếu artifact **đầy đủ và hợp lệ** mà exit code khác 0 ⇒ coi là **thành công**, nhưng **ghi rõ cảnh báo** vào log (không che giấu). Nếu artifact thiếu/hỏng ⇒ thất bại thật, có `EXPORT_FAILED.txt`.

> Lý do thiết kế: nhìn exit code đơn thuần sẽ báo **thất bại giả**, khiến Browser Preview không mở bản vừa export — sai chức năng. Ngược lại, bỏ qua exit code hoàn toàn sẽ che mất export hỏng thật. Xác minh artifact là tiêu chí đúng.

### 4.2 PowerShell 5.1 đọc .ps1 không BOM theo ANSI

Script có ký tự tiếng Việt bị **lỗi cú pháp** khi chạy (`Unexpected token`). Nguyên nhân: PowerShell 5.1 mặc định đọc file `.ps1` không BOM theo **ANSI**, làm hỏng ký tự đa byte.

**Đã sửa:** thêm **BOM UTF-8** cho **12** script trong `tools/`. Đây là yêu cầu bắt buộc cho mọi script có tiếng Việt.

## 5. Trạng thái

| Task | Trạng thái |
|---|---|
| G04 — 3 luồng preview | ✅ **PASS** (Native/Browser/Release tách biệt; Browser luôn export mới) |
| G05 — Test lỗi + cleanup | ✅ **PASS** 7/7 ca |
| G02 | 🔄 shell boot thật OK; **còn thiếu** test nhánh lỗi WebGL2/thiếu file |
| G03 | 🔄 bridge chạy thật; mock ad/analytics chưa gọi thử |
| G06 | ⏳ chờ tunnel HTTPS + thiết bị thật |
| G07/G08 | ⏳ chờ thiết bị thật |

## 6. Giới hạn — CHƯA nghiệm thu

- Toàn bộ test trên **Chrome desktop headless**. **Chưa** chứng minh gì cho mobile.
- Chưa test qua **tunnel HTTPS** — `127.0.0.1` được coi là secure context.
- Chưa test **touch thật** (`InputEventScreenTouch`).
- Chưa đo **frame time / memory** (H01).
