# H03 — Phân tích module có thể bỏ (strip plan)

> Ngày: 2026-10-26 · Nguồn: `engine/godot-h5` @ `e6a2176fb`
> **Nguyên tắc (từ SConstruct):** strip flag **CHỈ** dùng cho export template, **KHÔNG** cho editor.

## 1. Ràng buộc đã xác minh từ source

[SConstruct:1056-1074](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/SConstruct#L1056-L1074>) — nếu là editor build mà đặt các flag sau thì **thoát 255**:

```text
disable_3d, disable_advanced_gui, disable_physics_2d,
disable_physics_3d, disable_navigation_2d, disable_navigation_3d
```

[SConstruct:1076-1092](<C:/Users/Mark-TA/Desktop/AppGame/engine/godot-h5/SConstruct#L1076-L1092>) — `disable_3d` **kéo theo** `disable_navigation_3d`, `disable_physics_3d`, `disable_xr`.

→ **Editor giữ nguyên full chức năng.** Chỉ template bị strip.

## 2. Cái gì game CỦA CHÚNG TA thực sự dùng

| Tính năng | h5-demo | h5-puzzle | Kết luận |
|---|---|---|---|
| 2D physics (`Area2D`) | ✅ | ✅ | **GIỮ** `physics_2d` |
| Control/UI | ✅ | ✅ | **GIỮ** `advanced_gui` (dock dùng RichTextLabel, GridContainer…) |
| GDScript | ✅ | ✅ | **GIỮ** |
| Font/text | ✅ | ✅ | **GIỮ** cả `text_server_adv` + `text_server_fb` |
| SVG | ✅ | ❌ | **GIỮ** |
| Audio | ⏳ | ⏳ | **GIỮ** (kế hoạch D05 sẽ thêm) |
| **3D** | ❌ | ❌ | **BỎ ĐƯỢC** |
| Navigation | ❌ | ❌ | **BỎ ĐƯỢC** |
| XR / VR | ❌ | ❌ | **BỎ ĐƯỢC** |
| Mạng (WebRTC/WebSocket/UPnP) | ❌ | ❌ | **BỎ ĐƯỢC** |
| Video (Theora) | ❌ | ❌ | **BỎ ĐƯỢC** |
| 3D import (glTF/FBX) | ❌ | ❌ | **BỎ ĐƯỢC** |
| Visual shader | ❌ | ❌ | **BỎ ĐƯỢC** |

## 3. Profile strip đề xuất

```text
# Cấp engine (SConstruct)
disable_3d=yes                 # keo theo navigation_3d + physics_3d + xr
disable_navigation_2d=yes

# Cấp module
module_gltf_enabled=no         # import 3D (1018 KB source)
module_visual_shader_enabled=no  # 1373 KB
module_lightmapper_rd_enabled=no # 276 KB
module_openxr_enabled=no       # 1799 KB
module_mobile_vr_enabled=no
module_webxr_enabled=no
module_csg_enabled=no          # 178 KB
module_gridmap_enabled=no      # 199 KB
module_camera_enabled=no
module_vhacd_enabled=no
module_xatlas_unwrap_enabled=no
module_webrtc_enabled=no
module_websocket_enabled=no
module_upnp_enabled=no
module_jsonrpc_enabled=no
module_theora_enabled=no
module_interactive_music_enabled=no
module_objectdb_profiler_enabled=no
module_betsy_enabled=no
```

### CỐ Ý GIỮ (không strip)

| Module | Lý do |
|---|---|
| `astcenc`, `etcpack`, `basis_universal`, `cvtt` | Nếu sau này bật nén texture mobile thì cần; rủi ro cao nếu bỏ |
| `noise`, `regex`, `zip`, `mbedtls` | Nhỏ, dùng phổ biến |
| `text_server_adv` + `text_server_fb` | Tiếng Việt + dự phòng |
| `godot_physics_2d`, `jolt_physics` | `jolt` là 3D — **có thể bỏ**, nhưng để lại an toàn |
| `svg`, `jpg`, `png`, `webp`, `ogg`, `vorbis`, `mp3` | Asset runtime |

## 4. Nguyên tắc thực hiện (theo kế hoạch H03)

1. **Một thay đổi mỗi lần** — không gộp nhiều nhóm flag rồi đoán.
2. **Đo trước/sau** — bytes truyền, thời gian boot, frame time.
3. **Chạy CẢ HAI game** trước khi giữ.
4. **Không đạt thì ship full template** — strip là **tùy chọn**, không chặn phát hành.

## 5. Rủi ro đã biết

| Rủi ro | Giảm thiểu |
|---|---|
| `disable_3d` làm hỏng scene có node 3D | Cả 2 game đều 2D thuần; regression sẽ bắt |
| Bỏ module làm thiếu class khi load | Chạy cả 2 game + validator |
| `disable_advanced_gui` phá UI | **KHÔNG** đặt flag này |
| Bỏ `astcenc`/etcpack phá nén texture | **KHÔNG** bỏ các module này |
| Template strip lệch revision với editor | Dùng **cùng** source SHA; manifest F04 cập nhật hash mới |

## 6. Trạng thái

| Task | Trạng thái |
|---|---|
| **H03** | ✅ **xong** — danh sách module + profile + rủi ro |
| H04 | 🔄 build stripped debug |
| H05 | ⏳ build stripped release |
| H06 | ⏳ regression 2 game, quyết định giữ/rollback |
