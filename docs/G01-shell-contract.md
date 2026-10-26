# G01 — HTML loader boot contract (ĐÃ ĐỐI CHIẾU SOURCE THẬT)

> Ngày: 2026-10-25 · Nguồn đối chiếu: template thật `bin/.web_zip/godot.html` (sinh từ build control)
> + `platform/web/js/engine/{engine,config}.js` + `platform/web/export/export_plugin.cpp`.
> **Kết luận: shell v1.0.0 có 1 lỗi nghiêm trọng; đã sửa thành v1.1.0.**

## 1. Danh sách placeholder (từ `export_plugin.cpp`)

Bảng thay thế tại [export_plugin.cpp:169-194](<../engine/godot-h5/platform/web/export/export_plugin.cpp#L169-L194>):

| Placeholder | Nguồn giá trị |
|---|---|
| `$GODOT_URL` | `<tên>.js` |
| `$GODOT_PROJECT_NAME` | `application/config/name` |
| `$GODOT_HEAD_INCLUDE` | icon/manifest link + `html/head_include` của preset |
| `$GODOT_CONFIG` | JSON cấu hình export (executable, mainPack, canvasResizePolicy, …) |
| `$GODOT_SPLASH_COLOR` | `application/boot_splash/bg_color` |
| `$GODOT_SPLASH_CLASSES` | `show-image--*`, `fullsize--*`, `use-filter--*` |
| `$GODOT_SPLASH` | `<tên>.png` |
| `$GODOT_THREADS_ENABLED` | `variant/thread_support` → `"true"`/`"false"` |

> Ghi chú: `___GODOT_*` (3 gạch dưới) là placeholder **của service worker PWA**, không phải của shell. PWA ngoài scope.

## 2. Thứ tự nạp script — LỖI NGHIÊM TRỌNG của shell v1.0.0

Template thật ([bin/.web_zip/godot.html:110-114](<../engine/godot-h5/bin/.web_zip/godot.html#L110-L114>)):

```html
<script src="$GODOT_URL"></script>   <!-- 1. loader engine TRUOC -->
<script>
const GODOT_CONFIG = $GODOT_CONFIG;
const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;
const engine = new Engine(GODOT_CONFIG);   <!-- 2. dung Engine SAU -->
</script>
```

Shell v1.0.0 đặt `<script src="$GODOT_URL">` ở **cuối `<body>`, SAU** script inline đã gọi `new Engine(...)`.
→ `Engine` chưa tồn tại tại thời điểm gọi ⇒ **ReferenceError, game không bao giờ boot**, dù mọi thứ khác đúng.

**Đã sửa ở v1.1.0:** loader engine nạp **trước** script inline.

## 3. Năng lực engine — dùng API chính thức, không tự đoán

Template thật kiểm tra bằng `Engine.getMissingFeatures({threads: GODOT_THREADS_ENABLED})`
([godot.html:163-197](<../engine/godot-h5/bin/.web_zip/godot.html#L163-L197>)), export tại `engine.js:280`.

Shell v1.1.0 dùng **cùng API** làm nguồn sự thật, rồi **bổ sung** thông báo tiếng Việt có hướng dẫn cho:
- `isSecureContext === false` → giải thích HTTPS (engine không nói rõ nguyên nhân này);
- thiếu WebGL2;
- thiếu thread support (thiếu COOP/COEP).

## 4. `startGame(override)` — các khóa là CONFIG KEY

`startGame` ([engine.js:196-210](<../engine/godot-h5/platform/web/js/engine/engine.js#L196-L210>)) gọi `this.config.update(override)` rồi `init` + `preloadFile(pack)` + `start`.

Các khóa shell dùng đều **hợp lệ**, đã xác minh trong `config.js`:

| Khóa | Dòng | Ghi chú |
|---|---|---|
| `canvas` | [config.js:38,260,334-346](<../engine/godot-h5/platform/web/js/engine/config.js#L38>) | nhận `HTMLCanvasElement` |
| `canvasResizePolicy` | [config.js:80,264](<../engine/godot-h5/platform/web/js/engine/config.js#L80>) | `2` = Adaptive |
| `onProgress` | [config.js:194,257](<../engine/godot-h5/platform/web/js/engine/config.js#L194>) | `(current, total)` |
| `onPrintError` | [config.js:222,255](<../engine/godot-h5/platform/web/js/engine/config.js#L222>) | nhận nhiều tham số |

## 5. LỖI THỨ HAI của v1.0.0 — shell đánh nhau với engine về canvas size

`canvasResizePolicy = 2` nghĩa là **engine tự** điều chỉnh canvas cho khớp cửa sổ
([config.js:67-80](<../engine/godot-h5/platform/web/js/engine/config.js#L67-L80>)).

Shell v1.0.0 tự set `canvas.width/height` theo DPR trong `syncCanvasSize()` → **hai bên cùng ghi** vào backing size ⇒ nguy cơ méo/nhảy kích thước, đúng loại lỗi mà G02 phải tránh.

**Đã sửa ở v1.1.0:** shell **chỉ** lo CSS (`width/height: 100%`, `touch-action: none`), **không** đụng `canvas.width/height`; để engine làm theo policy `2`.

## 6. Ghi chú khác

- `html/canvas_resize_policy` trong preset là **enum** `None,Project,Adaptive` ([export_plugin.cpp:382](<../engine/godot-h5/platform/web/export/export_plugin.cpp#L382>)) và được ghi vào `config["canvasResizePolicy"]` ([dòng 147](<../engine/godot-h5/platform/web/export/export_plugin.cpp#L147>)). Preset của fixture đặt `2` (Adaptive) — **khớp** với shell.
- Template thật **tự remove** overlay `#status` khi thành công (`statusOverlay.remove()`, [godot.html:129-131](<../engine/godot-h5/bin/.web_zip/godot.html#L129-L131>)). Shell v1.1.0 dùng `.hidden` để có thể hiện lại khi retry.

## 7. Trạng thái

| Task | Trạng thái |
|---|---|
| G01 — spike loader contract | ✅ **xong** (có bằng chứng source + template thật) |
| G02 — loading/error/retry UI | 🔄 shell v1.1.0 đã viết; **chờ export thật để kiểm chứng** |
| G03 — bridge/mock adapter | 🔄 `window.H5Bridge` đã có; chờ kiểm chứng trên bản export |

> **Chưa được nghiệm thu:** shell v1.1.0 mới chỉ **đối chiếu tĩnh** với source. Phải chạy trên artifact export thật (C07) mới chứng minh boot được.
