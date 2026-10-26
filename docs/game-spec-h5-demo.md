# D01 — Đặc tả fixture game 1: "Hứng Sao"

> Fixture dùng xuyên suốt dự án cho D02–D07, G07–G08, H01, I04.
> Mục tiêu: **nhỏ nhưng đủ** để phơi ra mọi rủi ro H5 (input, audio, save, lifecycle, resize).

## 1. Vòng chơi

```text
MainMenu  →  [CHƠI]  →  Game (45 giây)  →  Result  →  [CHƠI LẠI] → Game
                                          └→ [VỀ MENU] → MainMenu
```

- **MainMenu:** tiêu đề, điểm cao, **trạng thái save trung thực**, nút CHƠI.
- **Game:** người chơi kéo ngang để hứng sao rơi. Mỗi sao = 10 điểm. Bỏ lỡ 3 sao **hoặc** hết 45 giây → kết thúc. Có nút tạm dừng.
- **Result:** điểm vừa đạt, điểm cao, trạng thái save, CHƠI LẠI / VỀ MENU.

## 2. Scene (5)

| Scene | Loại | Vai trò |
|---|---|---|
| `scenes/MainMenu.tscn` | Control | Menu, điểm cao, trạng thái save |
| `scenes/Game.tscn` | Node2D | Gameplay + HUD + overlay tạm dừng |
| `scenes/Result.tscn` | Control | Kết quả + chơi lại |
| `scenes/Star.tscn` | Area2D | Sao rơi (physics đơn giản) |
| `scenes/Player.tscn` | Area2D | Giỏ hứng (chuột + touch) |

## 3. Script (7)

| Script | Vai trò | Task liên quan |
|---|---|---|
| `scripts/game_state.gd` | Autoload: điểm cao, save có version, trạng thái save | D06, G08 |
| `scripts/main_menu.gd` | Menu | D02 |
| `scripts/game.gd` | Vòng chơi, spawn, HUD, pause/resume | D02, D05 |
| `scripts/player.gd` | Input chuột + touch, chống double-fire, nhả khi mất focus | D04, G07 |
| `scripts/star.gd` | Rơi, nảy cạnh, bắt/miss | D02 |
| `scripts/result.gd` | Màn kết quả | D02 |

## 4. Asset

| Asset | Định dạng | Lý do |
|---|---|---|
| `assets/star.svg` | SVG | Vector → không cần atlas, không phụ thuộc nén texture; kiểm tra import SVG trên web |
| `assets/basket.svg` | SVG | Như trên |
| `icon.svg` | SVG | Icon project |

**Chưa có ở bước này:** sprite atlas raster và font tiếng Việt nhúng. Xem mục 6.

## 5. Cấu hình project

| Thuộc tính | Giá trị | Lý do |
|---|---|---|
| Viewport | 720 × 1280 (portrait) | Tỷ lệ điện thoại phổ biến |
| Stretch mode | `canvas_items` | UI co giãn theo độ phân giải |
| Stretch aspect | `expand` | Không letterbox; kiểm tra safe-area ở G07 |
| Renderer | `gl_compatibility` (+ mobile) | WebGL2 |
| `emulate_touch_from_mouse` | `true` | Test touch trên desktop |
| `emulate_mouse_from_touch` | `true` | Tương thích ngược; **phải** chống double-fire trong `player.gd` |
| Autoload | `GameState` | Save dùng chung giữa các scene |
| Orientation | `1` (portrait) | Không hứa lock cứng — browser có thể từ chối |

## 6. Việc còn lại của D03 (asset/import policy)

1. **Font tiếng Việt:** Godot dùng font mặc định; phải **kiểm tra thực tế** dấu tiếng Việt hiển thị đúng trên web (Android/iOS) — nếu thiếu glyph thì nhúng font có Vietnamese subset.
2. **Sprite atlas raster:** thêm một atlas PNG để kiểm tra đường nén texture desktop/mobile.
3. **Texture policy:** preset web mặc định bật VRAM compression desktop và tắt mobile compression → phải chốt policy rõ ràng, không lấy mặc định.

## 7. Tiêu chí xong (D02)

- [ ] Chơi hết vòng menu → game → kết quả → chơi lại **không** nhân object, **không** giữ sai trạng thái.
- [ ] Restart nhiều lần liên tiếp: số node trong `Stars` trở về 0 sau mỗi lần kết thúc.
- [ ] Bỏ lỡ 3 sao kết thúc đúng; hết 45 giây kết thúc đúng.
- [ ] Tạm dừng/tiếp tục không làm sao rơi "nhảy" vị trí.
