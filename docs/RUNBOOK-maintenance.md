# Runbook — Bảo trì và cập nhật Godot

> Cho người duy trì fork. Mục tiêu: cập nhật upstream **an toàn**, có rollback.

## 1. Trạng thái hiện tại

| Trường | Giá trị |
|---|---|
| Upstream | `https://github.com/godotengine/godot.git` (remote `upstream`) |
| Base commit | `ed1daf0bf001b61586d9930840f2f1394092c079` (4.7.2-stable) |
| Branch phát triển | `indie/h5-platform` |
| Commit fork | `e6a2176fb5` (E02/E03/E04) |
| Tổng patch | **6 file, +145 / −4 dòng** |

### Patch đang áp

| # | File | Mục đích |
|---|---|---|
| 1 | `version.py` | Tên hiển thị "Godot H5" |
| 2 | `core/version.h` | Macro `GODOT_H5_PRODUCT_DIR_NAME` |
| 3 | `core/os/os.cpp` | `get_godot_dir_name()` trả tên sản phẩm |
| 4 | `platform/windows/os_windows.cpp` | **Override Windows** (hàm thực sự chạy) |
| 5 | `editor/project_manager/project_dialog.h` | Khai báo checkbox + hàm template |
| 6 | `editor/project_manager/project_dialog.cpp` | UI + chép template H5 |

## 2. Quy trình cập nhật upstream

```powershell
# 1. Lay upstream moi (KHONG merge truc tiep vao branch chinh)
cd engine/godot-h5
git fetch upstream --tags

# 2. Tao branch thu nghiem tu base moi
git switch -c maint/upstream-<version> upstream/<tag-moi>

# 3. Ap lai patch cua fork
git cherry-pick e6a2176fb5
#    => Neu conflict: xu ly tay, ghi lai vao docs/patch-log.md

# 4. Build lai CA editor VA ca hai template (xem muc 3)

# 5. Chay regression tren CA HAI game (xem muc 4)

# 6. Chi merge khi tat ca pass
git switch indie/h5-platform
git merge maint/upstream-<version>
```

> **KHÔNG** sửa trực tiếp trên `upstream/*`. Luôn qua branch `maint/*`.

## 3. Build lại toàn bộ

Thứ tự **bắt buộc** (template dùng chung `bin/.web_zip`, không build song song):

```powershell
# Editor (native, giu nguyen full chuc nang)
.\tools\build\build-editor.ps1 -Label fork-e08

# Web debug (full)
.\tools\build\build-web.ps1 -Flavor debug -Label fork

# Web release (full)
.\tools\build\build-web.ps1 -Flavor release -Label fork

# Web stripped (neu giu toi uu) — xem docs/H03-strip-analysis.md
$strip = @("disable_3d=yes", "disable_navigation_2d=yes", "module_gltf_enabled=no",
           "module_visual_shader_enabled=no", "module_lightmapper_rd_enabled=no",
           "module_openxr_enabled=no", "module_mobile_vr_enabled=no", "module_webxr_enabled=no",
           "module_csg_enabled=no", "module_gridmap_enabled=no", "module_camera_enabled=no",
           "module_vhacd_enabled=no", "module_xatlas_unwrap_enabled=no", "module_webrtc_enabled=no",
           "module_websocket_enabled=no", "module_upnp_enabled=no", "module_jsonrpc_enabled=no",
           "module_theora_enabled=no", "module_interactive_music_enabled=no",
           "module_objectdb_profiler_enabled=no", "module_betsy_enabled=no")
.\tools\build\build-web.ps1 -Flavor debug   -Label stripped -ExtraArgs $strip
.\tools\build\build-web.ps1 -Flavor release -Label stripped -ExtraArgs $strip
```

## 4. Regression bắt buộc

```powershell
# Manifest + chan mismatch
.\tools\build\make-template-manifest.ps1 -Label stripped
.\tools\build\check-template-manifest.ps1 -Label stripped   # phai PASS

# Tro preset ca 2 game sang cap template moi
.\tools\build\set-preset-templates.ps1 -Project projects\h5-demo   -Label stripped
.\tools\build\set-preset-templates.ps1 -Project projects\h5-puzzle -Label stripped

# Export + boot test CA HAI game
# (xem docs/reports/H04-H06-strip-regression.md de biet harness)
```

**Điều kiện merge:** cả hai game PASS boot + tương tác. Nếu không, **không merge**.

## 5. Rollback

### Rollback template (nhanh, không cần rebuild)

```powershell
# Quay ve cap FULL da build san
.\tools\build\set-preset-templates.ps1 -Project projects\h5-demo -Label fork
```

### Rollback engine

```powershell
cd engine/godot-h5
git switch indie/h5-platform
git reset --hard <commit-truoc-do>   # vi du e6a2176fb5
# Rebuild editor + templates
```

### Rollback gói phát hành

Giữ **mọi** ZIP phát hành cũ. Gói mới là ZIP độc lập — giải nén đè hoặc để song song.

## 6. Ghi chép bắt buộc sau mỗi lần cập nhật

1. `docs/patch-log.md` — patch nào áp, conflict nào gặp, cách giải quyết
2. `docs/manifests/web-templates-<label>.json` — hash mới
3. `builds/portable/<product>-<ngày>/VERSION.json` — SHA, version, label
4. Kết quả regression — file report trong `docs/reports/`

## 7. Việc CHƯA làm (đánh dấu rõ)

- **Chưa diễn tập cập nhật upstream thật** — chưa có bản Godot mới hơn 4.7.2 để thử. Quy trình trên là **kế hoạch**, chưa chạy thực tế.
- **Chưa test trên thiết bị di động thật** — điều kiện tiên quyết trước khi phát hành.
- **Chưa test upgrade/rollback bundle trên host thật** (I04).
