# A06 — Workspace map

> Cấu trúc thư mục của dự án AppGame. Ngày tạo: 2026-10-25.

```text
AppGame/
├─ reference/godot/          # Nguồn tham chiếu (shallow+sparse+blob:none). CHỈ ĐỌC. Không sửa/build.
├─ engine/godot-h5/          # Full checkout Godot 4.7.2 + branch phát triển indie/h5-platform
├─ projects/
│   ├─ h5-demo/              # Fixture game 1 (menu → play → result → replay)
│   └─ h5-puzzle/            # Fixture game 2 (puzzle drag-drop, H02)
├─ tools/
│   ├─ env/                  # Script kiểm tra/khóa môi trường (B07)
│   ├─ build/                # Script build editor + web templates (C, F, H)
│   └─ package/              # Script đóng gói portable ZIP (I01)
├─ builds/                   # Artifact: control / candidate / release (không commit binary)
├─ third_party/
│   └─ emsdk/                # Emscripten SDK (không commit)
└─ docs/
    ├─ scope-v0.1.md         # A01 — phạm vi bản đầu
    ├─ source-fingerprint.md # A02 — fingerprint nguồn đối chiếu
    ├─ workspace-map.md      # A06 — file này
    ├─ patch-log.md          # A06 — nhật ký patch engine
    ├─ manifests/            # Manifest JSON: version, hash, profile
    ├─ matrix/               # Device/browser matrix, baseline report
    ├─ reports/              # Smoke test, regression, acceptance report
    └─ logs/                 # Build log, env log
```

## Ranh giới Git

| Khu vực | Repo | Ghi chú |
|---|---|---|
| `%USERPROFILE%\Documents\godot-h5` | Repo **riêng** (fork) — **checkout chính**, theo `tools/engine-dir.txt` | `upstream` = official Godot; `origin` = `github.com/tamark-solo/godot-h5` |
| `engine/godot-h5/` | Bản trùng cùng HEAD | **Không commit ở đây**; mọi build dùng checkout chính |
| `reference/godot/` | Repo riêng (official, partial) | Không sửa |
| Phần còn lại của AppGame | Chưa khởi tạo repo | Nếu khởi tạo: dùng `.gitignore` ở root |

## Quy tắc

1. **Không** commit binary/build output vào repo engine (`bin/`, `builds/`, `*.exe`, `*.wasm`, `*.zip`).
2. Project game **độc lập** với source engine — không copy file C++ vào project.
3. Engine repo là **checkout độc lập**, không submodule phụ thuộc object store của reference.
4. `tools/h5_template` là **nguồn duy nhất** của addon/shell/template. Không sửa tay bản sao; dùng `tools/package/sync-template.ps1` (kiểm tra: `-Check`).
