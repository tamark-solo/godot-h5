# H02 — Game mẫu thứ hai (puzzle kéo-thả)

> Ngày: 2026-10-26 · Project: [projects/h5-puzzle](<C:/Users/Mark-TA/Desktop/AppGame/projects/h5-puzzle>)
> **Kết luận: PASS** — game thứ hai chạy trên web, hoàn thành màn, save hoạt động. **4 lỗi thật** được phát hiện và sửa.

## 1. Vì sao cần game thứ hai

Kế hoạch yêu cầu game 2 **khác input/scene/resource mix** để phát hiện lỗi mà một fixture không lộ ra. Bảng so sánh:

| Khía cạnh | h5-demo (fixture 1) | **h5-puzzle (fixture 2)** |
|---|---|---|
| Thể loại | Hứng sao (action) | **Xếp hình (puzzle)** |
| Input | Kéo **1 chiều ngang** | **Kéo-thả tự do 2 chiều** + snap |
| Vòng chơi | Timer 45 s + spawn liên tục | **Không timer**, thắng khi đủ mảnh |
| Số scene | 5 | 4 |
| Đồ hoạ | **SVG** (star, basket) | **Polygon2D vẽ bằng code** (không asset ngoài) |
| Save | Điểm cao (số nguyên) | **Tiến độ màn + kỷ lục theo màn** (Dictionary) |
| Điều kiện thắng | Hết giờ / bỏ lỡ 3 | **Tất cả mảnh đúng chỗ** |
| HUD | Điểm, bỏ lỡ, thời gian | Màn, lần kéo, đúng chỗ |

## 2. Kiểm thử: 7/7 PASS

Harness: [browser-puzzle-complete.mjs](<C:/Users/Mark-TA/Desktop/AppGame/tools/test/browser-puzzle-complete.mjs>)

| # | Kiểm tra | Kết quả |
|---|---|---|
| 1 | Overlay audio ẩn sau gesture | ✅ |
| 2 | Vào được màn chơi | ✅ `ready level=1 total=3 viewport=720x1280` |
| 3 | Game báo đủ số mảnh | ✅ 3 mảnh |
| 4 | Kéo được cả 3 mảnh | ✅ 3/3 |
| 5 | Mảnh đặt **đúng chỗ** | ✅ 3/3 |
| 6 | **Màn 1 hoàn thành** | ✅ `finished level=1 moves=3` |
| 7 | Không exception | ✅ |

### Ảnh bằng chứng

| Ảnh | Nội dung |
|---|---|
| [h02c-1-menu.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/h02c-1-menu.png>) | Menu: XẾP HÌNH, Màn 1 mở / Màn 2,3 khoá |
| [h02c-2-board.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/h02c-2-board.png>) | Bàn chơi: 3 ô đích trên, 3 mảnh màu dưới |
| [h02c-5-result.png](<C:/Users/Mark-TA/Desktop/AppGame/docs/reports/img/h02c-5-result.png>) | Kết quả: "Hoàn thành màn 1 (3 lần kéo)", "Kỷ lục: 3 lần kéo", **"Đã lưu (local)"**, nút MÀN TIẾP |

## 3. BỐN LỖI THẬT đã phát hiện và sửa

### Lỗi 1 — Chỉ MỘT mảnh kéo được (nghiêm trọng, chặn thắng game)

**Triệu chứng:** kéo mảnh nào cũng không được, trừ mảnh cuối cùng trong cây scene.

**Chẩn đoán:** thêm log vào `_hit()` và `_begin_drag()`, thấy rõ:
```text
[PUZZLE] hit_test idx=0 press=360,921 piece=540,921 dist=180 -> false
[PUZZLE] hit_test idx=0 press=360,921 piece=540,921 dist=180 -> false
```
Chỉ `idx=0` (mảnh cuối) nhận được sự kiện.

**Nguyên nhân:** `set_input_as_handled()` được gọi **vô điều kiện**, kể cả khi bấm trượt. Các mảnh là **sibling**; mảnh **cuối** trong cây nhận `_unhandled_input` **trước**. Nó "nuốt" mọi cú bấm kể cả khi trượt → các mảnh khác **không bao giờ** nhận được sự kiện.

**Sửa:** chỉ đánh dấu handled khi **thực sự** tiêu thụ sự kiện.

### Lỗi 2 — `get_viewport()` trả về null sau khi đổi scene

**Triệu chứng:** shell hiện `[0] _unhandled_input (res://scripts/piece.gd:68)`.

**Nguyên nhân:** `_end_drag()` phát tín hiệu `placed` → màn chơi gọi `change_scene_to_file()` → **node bị gỡ khỏi cây ngay lập tức**. Dòng tiếp theo gọi `get_viewport().set_input_as_handled()` trên **null**.

**Sửa:** lấy `viewport` **trước** mọi thao tác có thể đổi scene, kiểm tra null, và dùng hàm trợ giúp `_mark_handled(vp)`.

> **Đáng chú ý:** lỗi này **chỉ lộ ra trên web**, không lộ khi chạy headless. Và **shell đã bắt được nó** — hiển thị đúng thông báo lỗi kèm vị trí file. Đây là bằng chứng G02 hoạt động đúng thiết kế.

### Lỗi 3 — Màn kết quả hiện SAI màn

**Triệu chứng:** hoàn thành **màn 1** nhưng hiện "Hoàn thành màn **2**" và "Kỷ lục: —".

**Nguyên nhân:** `complete_level()` **tăng `current_level` trước** khi màn kết quả đọc. Suy ra màn vừa chơi từ `current_level` là sai. Kỷ lục cũng tra sai khoá nên luôn hiện "—".

**Sửa:** thêm `last_completed_level` và `last_completed_moves` vào `PuzzleState`, ghi **trước** khi tăng `current_level`; màn kết quả dùng giá trị đó.

### Lỗi 4 — Test đoán toạ độ (lỗi phương pháp)

**Triệu chứng:** test báo "không đăng ký" dù toạ độ tính tay "đúng".

**Nguyên nhân:** với stretch mode `canvas_items` + aspect `expand`, **viewport game rộng hơn 720** khi canvas browser rộng hơn tỷ lệ thiết kế. Đoán toạ độ theo thiết kế là **sai phương pháp**.

**Sửa:** game **in toạ độ thật** ra console (`piece idx=I at=X,Y target=TX,TY`), test **đọc** rồi kéo theo giá trị thật. Không đoán.

## 4. Trạng thái

| Task | Trạng thái |
|---|---|
| **H02** | ✅ **PASS** — game 2 chạy web, hoàn thành màn, save OK |
| H03 | ⏳ phân tích module có thể bỏ |
| H04–H05 | ⏳ build stripped templates |
| H06 | ⏳ regression 2 game |

## 5. Giới hạn — CHƯA nghiệm thu

- **Chrome desktop headless**. Chưa test thiết bị thật.
- Chưa test **touch thật** (dùng mouse event).
- Chưa test màn 2, 3 (chỉ màn 1).
- Chưa test **save qua reload** cho puzzle (fixture 1 đã test).
- Mới chạy **1 lượt**; chưa soak.
