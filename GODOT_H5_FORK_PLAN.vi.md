# Kế hoạch chi tiết: fork Godot làm editor desktop xuất game H5

**Phương án đã chọn:** full source riêng, nhánh phát triển riêng, Windows editor EXE build từ fork và Web export templates debug/release từ cùng revision. Official Godot chỉ là đối chứng, không thay thế deliverable của fork.

**Trạng thái (cập nhật 2026-10-26):** đang triển khai. Tiến độ thực tế và bằng chứng nằm ở [docs/BACKLOG-STATUS.md](<docs/BACKLOG-STATUS.md>): 43/61 việc ✅, gate A/C/F đạt; E/H đạt trên desktop, chờ thiết bị. Các câu "chưa triển khai" bên dưới là bối cảnh lúc lập kế hoạch, không phải trạng thái hiện tại.

## 1. Phạm vi và cách đọc backlog

Giả định bản đầu: Windows x64, game 2D GDScript, Compatibility/WebGL2, web single-thread/no-GDExtension, portable ZIP. Target PC Chrome/Edge, Android Chrome và iPhone Safari thật qua HTTPS. Các giả định này thu hẹp effort, chưa phải cam kết hỗ trợ mọi thiết bị.

MVP gồm EXE fork, New H5 Project, addon/config/validator, Native Preview, Browser Preview, Release Export, cặp templates khớp revision và package chạy trên Windows sạch. Ngoài scope: 3D, browser-hosted editor, TypeScript runtime, SDK publisher thật, payment/cloud, PWA/service worker, installer/updater.

Mỗi dòng có **ID, công việc, phụ thuộc, effort, đầu ra và tiêu chí xong**. Các việc chưa được thực hiện; ID dùng để báo tiến độ/commit về sau. Một ngày công = 6 giờ tập trung. Task 0.5–2 ngày là base estimate cho người đã quen nền Godot; nếu vượt 2 ngày vì API/toolchain chưa rõ thì tách spike và cập nhật estimate sau quyết định.

Gate từng giai đoạn là Pass/Fail có chứng cứ. Không được lấy compile thành công làm bằng chứng game chạy trên iPhone, hoặc native pass thay Web pass.

## 2. Repository và lệnh dự kiến

Nguồn khóa: Godot 4.7.2-stable, SHA `ed1daf0bf001b61586d9930840f2f1394092c079`, đối chiếu [version.py](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/version.py#L1>). Giữ [bản source tham chiếu](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/>) nguyên trạng, tạo development checkout độc lập.

Cấu trúc **đề xuất**, các đường dẫn mới chưa được tạo:

```text
AppGame/
├─ reference/godot/          # Nguồn tham chiếu hiện có, không sửa/build
├─ engine/godot-h5/          # Full checkout và branch phát triển
├─ projects/h5-demo/         # Game kiểm thử 1
├─ projects/h5-puzzle/       # Game kiểm thử 2
├─ tools/                   # Build/environment/package scripts
├─ builds/                  # Control/candidate/release artifacts
└─ docs/                    # Manifest, matrix, logs và runbooks
```

Các lệnh dưới **chỉ là ví dụ để triển khai sau**, chưa được chạy. Không dùng `--depth`, `--filter`, `--shared`; không copy source C++ vào game project.

```powershell
git clone https://github.com/godotengine/godot.git engine/godot-h5
git -C engine/godot-h5 checkout --detach ed1daf0bf001b61586d9930840f2f1394092c079
git -C engine/godot-h5 switch -c indie/h5-platform
git -C engine/godot-h5 remote rename origin upstream
# Thay placeholder bằng URL repository riêng đã tạo
git -C engine/godot-h5 remote add origin '<PRIVATE_FORK_URL>'
```

Trong native compiler shell, từ root development checkout:

```powershell
scons platform=windows target=editor arch=x86_64
```

Trong shell đã activate emsdk đúng version, build **tuần tự**:

```powershell
scons platform=web target=template_debug arch=wasm32 threads=no dlink_enabled=no
scons platform=web target=template_release arch=wasm32 threads=no dlink_enabled=no
```

Tool minima: Python >=3.9, SCons >=4.4 theo [SConstruct](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/SConstruct#L4>); Emscripten >=4.0.0 theo [Web detector](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/detect.py#L116>). Chọn exact versions sau kiểm tra full source. Compiler/SDK Windows cụ thể chưa được xác minh từ detector Windows vì sparse checkout chưa có file đó.

Hai Web flavors dùng chung `bin/.web_zip` theo [emscripten_helpers.py](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/emscripten_helpers.py#L122>), nên không build song song trong một source tree. `threads=no` chỉ áp Web runtime; Windows editor giữ thread mặc định. Một số strip flags như `disable_3d` bị cấm cho editor theo [SConstruct](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/SConstruct#L1056>).

## 3. Backlog công việc

### A — Khóa phạm vi và tạo source fork

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| A01 | Chốt phạm vi bản đầu | Không | 1–1.5 | Scope v0.1 | Windows x64 editor; game 2D GDScript, Compatibility/WebGL2; Chrome/Edge PC, Android Chrome, iPhone Safari; web threads/extensions off. Các mục thêm phải có estimate riêng. |
| A02 | Ghi nguồn Godot đối chiếu | A01 | 0.5–1 | Source fingerprint | Ghi origin, Godot 4.7.2-stable, SHA ed1daf0bf001b61586d9930840f2f1394092c079; reference sparse đang sạch. Không sửa/build ở đó. |
| A03 | Clone full source độc lập | A02 | 1–2 | engine/godot-h5 | Clone chính thức không depth/filter/shared, checkout đúng SHA, tạo branch indie/h5-platform. Không phụ thuộc object store của reference. |
| A04 | Kiểm tra checkout đầy đủ | A03 | 0.5–1 | Source verification log | Shallow=false, sparse off, không alternates; có editor, platform/windows, thirdparty, misc; git status sạch trước patch. |
| A05 | Thiết lập branch và remote phát triển | A03 | 0.5–1 | Repo/remote policy | Giữ official làm upstream, remote riêng làm origin; nếu dùng private thì xác nhận visibility thực tế. Push/fetch thử nhánh, không lưu token trong repo. |
| A06 | Tổ chức workspace và patch log | A04,A05 | 1–1 | Workspace map, patch log | Engine repo độc lập hoặc submodule được khai báo rõ; source, project game, build output, tools và docs tách riêng; không vô tình commit binaries/cache vào source. |

**Gate A — 4.5–7.5 ngày công base:** Full checkout độc lập, đúng commit; reference nguyên vẹn; nhánh/remote và ranh giới Git rõ ràng.

### B — Khóa toolchain Windows và Web

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| B01 | Ghi host và ma trận thiết bị | A01 | 1–1.5 | Device/host matrix | Ghi Windows/CPU/RAM/disk, Android/iPhone thật, OS/browser version, người giữ thiết bị và cách truy cập HTTPS staging. |
| B02 | Cài native compiler/Windows SDK | A04 | 1–1.5 | MSVC/SDK version lock | Đọc platform/windows/detect.py sau full checkout, đối chiếu tài liệu rồi cài đúng C++ tools/SDK cần; native toolchain chưa được xác nhận từ sparse source hiện tại. |
| B03 | Khóa Python | A04 | 0.5–1 | Python environment | Chọn exact version >=3.9, ghi interpreter path; PowerShell/Developer shell gọi đúng interpreter. |
| B04 | Khóa SCons | B03 | 1–1.5 | SCons environment | Chọn exact version >=4.4; chạy scons --version hoặc python -m SCons --version trong môi trường đã khóa. |
| B05 | Cài/activate Emscripten SDK | A04 | 1–1.5 | emsdk version lock | Chọn exact version >=4.0.0 tương thích, ghi emcc/SDK version và activation recipe; không chỉ ghi latest. |
| B06 | Quyết định WASM SIMD/device floor | B01,B05 | 0.5–1 | SIMD decision | Source mặc định wasm_simd=yes; ghi policy và browser/device hỗ trợ, giữ đồng nhất giữa flavors. Nếu cần tắt phải thành profile rõ ràng. |
| B07 | Viết script môi trường/build | B02,B04,B05 | 0.5–1 | env-report/build scripts | Script kiểm version, lưu command/log; phân biệt native threads mặc định với threads=no cho Web; không để custom.py/SCONSFLAGS ngầm đổi profile. |

**Gate B — 5.5–9 ngày công base:** Terminal sạch kích hoạt được native/Web environments, version manifest và scripts build rõ ràng; không dùng config ngầm.

### C — Build đối chứng từ source chưa sửa

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| C01 | Tạo control build profile | B07 | 1–1.5 | Baseline profile | Source SHA đúng, không branding/custom module/strip; ghi tất cả SCons args và cấu hình kế thừa. |
| C02 | Build Windows editor control | C01 | 1–2 | Control EXE + log/hash | Build platform=windows target=editor arch=x86_64; EXE có source fingerprint, không chỉ file tải sẵn đổi tên. |
| C03 | Smoke-test editor control | C02 | 1–2 | Native smoke report | Launch Project Manager, import, sửa scene, save/reopen, chạy native; blocker có repro và log. |
| C04 | Khóa full Web control profile | B06,B07 | 1–1.5 | Web profile | wasm32, threads=no, dlink_enabled=no, chưa strip; Compatibility/WebGL2 và SIMD policy được ghi. |
| C05 | Build Web debug control | C04 | 1–2 | Debug ZIP + hash/log | Build target=template_debug, kiểm args, giữ artifact với source/toolchain fingerprint. |
| C06 | Build Web release control | C05 | 1–2 | Release ZIP + hash/log | Build target=template_release sau debug hoàn tất; không song song trong cùng checkout vì chung bin/.web_zip. |
| C07 | Export thử bằng cặp control | C03,C06 | 2–2 | Debug/release smoke exports | Preset trỏ rõ cả hai custom ZIP; xuất một scene đơn giản qua GUI/CLI và boot cả hai trong browser; ghi build IDs. |

**Gate C — 8–13 ngày công base:** Windows control editor hoạt động, cặp control templates tồn tại và boot fixture; lưu logs, hashes và baseline trước patch.

### D — Game mẫu và baseline PC/điện thoại

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| D01 | Tạo fixture game 2D | C03 | 1–1.5 | Project mẫu đầu tiên | Project game độc lập với engine source, scene/script/assets có version control; import từ clone sạch được. |
| D02 | Làm vòng chơi hoàn chỉnh | D01 | 1–1.5 | Menu/play/result/replay | Có ít nhất hai scene, physics đơn giản, restart không nhân object hoặc giữ sai trạng thái. |
| D03 | Thêm hình/font/UI responsive | D01 | 1–1.5 | Asset/import policy | Sprite/atlas, font tiếng Việt, nhiều tỷ lệ; chọn texture desktop/mobile compression rõ ràng, không chỉ lấy preset mặc định. |
| D04 | Thêm input mouse/touch | D02 | 1–1.5 | Input cases | Tap/hold/drag, thả ngoài canvas, cancel/focus loss không kẹt action; touch-to-mouse không double fire; multitouch theo yêu cầu game. |
| D05 | Thêm âm thanh/lifecycle | D02 | 1–1.5 | BGM/SFX/start gesture | Audio unlock sau gesture, mute/volume, tab/home/background-resume không phát nhạc chồng hoặc nhảy simulation. |
| D06 | Thêm save checkpoint có version | D01 | 1–1.5 | Local-save fixture | Write/read cùng origin, reload/reopen giữ checkpoint khi storage hỗ trợ; corrupt data fallback. Save cục bộ không bảo đảm chống browser eviction/xóa site data. |
| D07 | Chạy matrix và đo baseline | C07,D02,D03,D04,D05,D06,B01 | 1–2 | Baseline device report | Trusted HTTPS phải sẵn ở bước này: test native, PC Chrome/Edge, Android Chrome, iPhone Safari thật; ghi URL/build ID/secure context, cold-warm bytes, first-play, frame p95, memory. |

**Gate D — 7–11 ngày công base:** Game hoàn thành vòng chơi trên native và trusted HTTPS PC/Android/iPhone; có số đo và issue list theo build/device.

### E — Editor EXE riêng và New H5 Project

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| E01 | Spike entry points của editor | C03 | 1–2 | Bản đồ source + quyết định | Trong 1–2 ngày xác định Project Manager/New Project, branding/about/build ID, paths và bootstrap; ghi file/hook thật cùng phương án patch nhỏ. |
| E02 | Thêm product/build identity | E01 | 1–1.5 | Identity patch | Tên hiển thị, About/diagnostics và build ID có upstream SHA+fork revision; không tự ý đổi định dạng scene/project Godot. |
| E03 | Tách user config/cache/data | E01 | 1–1.5 | Path policy + patch | Không đè thiết lập của official Godot; phân biệt install dir, AppData/cache và project; dữ liệu người dùng giữ qua nâng cấp. |
| E04 | Thêm New H5 Project entry | E01,E02 | 1–2 | Project Manager bootstrap | Chọn tên/path, validate và tạo từ template; test spaces/Unicode/ổ khác/path đã tồn tại, lỗi copy được báo rõ. |
| E05 | Sinh project H5 hợp lệ | E04 | 1–1.5 | Versioned project template | Tạo project.godot, main scene, H5 config Resource có version, action map, resolution/stretch/orientation và Web preset; không cần sửa tay. |
| E06 | Nạp addon lần mở đầu | E05 | 1–1.5 | Bundled EditorPlugin | Template bật plugin trước mở project; lifecycle register/unregister sạch, enable-disable-reopen không nhân dock/action; không dựa plugin global. |
| E07 | Làm H5 dock/config/validator | E06 | 1–2 | H5 authoring tools | UndoRedo khi chỉnh config; severity error/warning cho renderer/main scene/preset/templates/assets/input và danh sách APIs web đã xác định. Không hứa phân tích mọi API native. |
| E08 | Build và test fork editor | E02,E03,E04,E07,D07 | 1–1 | Fork EXE + smoke report | Build identity/version đúng; New H5 Project→edit→save/reopen→Native Preview chạy; lưu patch diff/log/hash. E01–E07 có thể chuẩn bị song song baseline D, nghiệm thu E08 chờ D07. |

**Gate E — 8–13 ngày công base:** Editor build từ fork có identity thật; từ profile sạch tạo H5 project với addon/config/preset active ngay lần mở đầu.

### F — Cặp Web templates cùng fork revision

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| F01 | Khóa Web product profile | D07,E08 | 1–1.5 | Versioned profile | wasm32, Compatibility/WebGL2, threads/extensions/dlink off, SIMD policy; profile/script commit cùng source. |
| F02 | Build fork debug template | F01 | 1–1.5 | Fork debug ZIP | Xác minh source SHA/profile trước compile; artifact có hash/log và không lẫn control template. |
| F03 | Build fork release template | F02 | 1–1.5 | Fork release ZIP | Tuần tự cùng exact revision/toolchain; archive độc lập đúng flavor, không lấy staging của debug. |
| F04 | Sinh compatibility manifest | F02,F03 | 1–1.5 | Manifest JSON | Ghi upstream/fork revision, toolchain, arch/target/flags, SIMD, shell version, debug/release ZIP SHA256. |
| F05 | Nối preset tới cặp đóng gói | F04 | 1–1.5 | Template resolver | custom_template/debug và custom_template/release trỏ vào package đúng version; không dùng nhầm template global hoặc đường dẫn developer cố định. |
| F06 | Chặn mismatch/missing template | F05 | 1–1.5 | Preflight + negative cases | So manifest, flavor, source/profile và hashes. Đổi ZIP/manifest có chủ ý phải bị từ chối; file tồn tại/version string giống nhau chưa đủ. |
| F07 | Test GUI và CLI exports | F06 | 1–2 | Debug/release parity report | Cùng game xuất bằng GUI/CLI chọn cùng manifest; mỗi flavor boot được, build ID đúng; tạo output directories trước export. |

**Gate F — 7–11 ngày công base:** Editor và cả hai ZIP từ exact revision/profile có manifest/hash; GUI/CLI export đúng, mismatch fail và không fallback global.

### G — Shell, Browser Preview và mobile hardening

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| G01 | Spike HTML loader contract | F07 | 1–1.5 | Shell hello-game | Xác định placeholder/loader boot contract từ output generated; shell tối thiểu chạy với cả debug/release trước khi tùy biến sâu. |
| G02 | Làm loading/error/retry UI | G01 | 1–1.5 | Custom HTML shell | Có progress/initializing/ready/fail; WebGL2/secure context/WASM-PCK-fetch errors có message/retry, không spinner vô hạn; giữ boot placeholders. |
| G03 | Thêm browser bridge/mock adapter | G01 | 1–1.5 | Bridge contract + mock | ready/pause/resume/save/analytics/ad mock; không có host SDK vẫn boot. SDK publisher thật cần task/estimate riêng. |
| G04 | Nối Native/Browser/Release flow | F06 | 1–2 | Ba luồng riêng | Browser: save pending edits→validate→export debug mới→build ID→serve/open URL. Native pass không đánh dấu web pass; release output sạch riêng. |
| G05 | Test lỗi preview và cleanup | G04 | 1–2 | Failure/repeat report | Export fail/template thiếu/port bận/server crash/repeat run/editor exit/path Unicode-space: không mở stale output, không sót server/process tool sở hữu. |
| G06 | Hoàn thiện HTTPS/release-like host | G02,G04,D07 | 1–1.5 | Hosting/HTTPS recipe | Tận dụng staging đã có từ D07; trusted cert/hostname trên từng máy, isSecureContext=true, application/wasm, compression/subdirectory. Preview COOP/COEP/no-store không đại diện production headers. |
| G07 | Fix input/viewport/audio/resume | G06,D04,D05 | 1–1.5 | Mobile regression report | Safe area/DPR/rotate/browser chrome, cancel/multitouch, audio gesture/home/tab 30s resume; không phụ thuộc fullscreen/orientation-lock. Context loss báo reload/checkpoint trong MVP. |
| G08 | Hoàn thiện save state và failure | G03,G06,D06 | 1–2 | Save state/report | Pending/đã đồng bộ cục bộ/failed/session-only trung thực; sync + reload/reopen read-back; test quota/blocked IndexedDB/private mode thực tế/abrupt close. Không dựa unload để hoàn tất async save. |

**Gate G — 8–13.5 ngày công base:** Browser Preview luôn export mới, trusted HTTPS/device cases pass; save state trung thực; lỗi không mở bản cũ hoặc để server rác.

### H — Tối ưu templates theo số đo

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| H01 | Đặt performance budgets | D07,G07 | 1–1.5 | Budgets theo device floor | Chốt cold/warm compressed bytes, first-play, frame p95, memory sau 10 phút/20 scene swaps theo game/network/device; chưa có số đo thì không hứa FPS/dung lượng. |
| H02 | Tạo game mẫu thứ hai | E08,F07 | 1–2 | Fixture thứ hai | Game khác input/scene/resource mix, ví dụ puzzle drag-drop/save đối chiếu action/tick/audio; tạo từ app product, không chỉ copy fixture đầu, để có trước khi strip regression. |
| H03 | Phân tích module có thể bỏ | H01 | 1–1.5 | Strip dependency plan | Không bỏ GDScript/UI/font/audio/physics 2D còn dùng; cân nhắc 3D/XR/navigation dựa resource thực tế, chọn một thay đổi mỗi lần. |
| H04 | Build stripped debug template | H03 | 1–1.5 | Candidate debug ZIP | Pass strip flags chỉ vào template; source cấm disable_3d và một số disable flags cho editor. Giữ editor đầy đủ chức năng. |
| H05 | Build stripped release template | H04 | 1–1.5 | Candidate release ZIP/manifest | Build tuần tự đúng profile/revision, cập nhật hashes; không chỉ test debug rồi suy ra release. |
| H06 | Regression và giữ/rollback tối ưu | H05,H02 | 1–2 | Before/after decision | Chạy hai game trên devices, đo load/frame/memory; chỉ giữ thay đổi khi có lợi mà không mất tính năng. Không đạt thì ship full templates, không bị chặn bởi tối ưu tùy chọn. |

**Gate H — 6–10 ngày công base:** Strip chỉ ở Web templates, từng thay đổi có trước-sau và rollback; hai game và hai flavors pass trên devices.

### I — Đóng gói, release candidate và bảo trì

| ID | Công việc | Phụ thuộc | Ngày công | Đầu ra | Tiêu chí xong |
|---|---|---|---:|---|---|
| I01 | Đóng gói portable candidate | E08,F07 | 1–2 | Portable ZIP + manifest | EXE/dependencies, bootstrap, addon/template, cặp Web ZIP, shell và samples đi theo một version. Refresh package sau G/H; không dùng đường dẫn template trên máy developer. |
| I02 | Test Windows sạch | I01,G05 | 1–2 | Clean-machine report | Không cài Godot/Python/compiler/global templates: unpack→launch→new project→edit→native→browser→release. Test user mới, non-writable install dir, ổ khác, Unicode/space; fix và rerun khi package đổi. |
| I03 | Test release hosting thực | G06,I01 | 1–2 | Deployment recipe/report | Output sạch, HTTPS, MIME application/wasm, gzip/Brotli Content-Encoding đúng, subdirectory/cache headers; giữ PWA/service worker ngoài scope. |
| I04 | Kiểm version/cache/two-game matrix | I02,I03,H02,H06,G07,G08 | 1–2 | RC acceptance report | Rebuild/refresh EXE+Web pair+shell/addon manifest cuối; v1 warm-cache→v2→reload/fresh profile→rollback không lẫn JS/WASM/PCK; cả hai games pass desktop/Android/iPhone và debug/release flavors. |
| I05 | Diễn tập maintenance và bàn giao | I04 | 0.5–1.5 | Runbook + rehearsal | Trên branch riêng áp upstream candidate hoặc controlled patch, rebuild EXE+cả templates và rerun hai games; ghi conflict/rollback. Có quickstart create/edit/native/browser/export và capacity cho update sau release. |

**Gate I — 4.5–9.5 ngày công base:** Portable app chạy trên Windows sạch; hai games pass debug/release-device matrix; update/cache/rollback không trộn bundle; có rehearsal upstream.

## 4. Effort và dự phòng

| Giai đoạn | Số việc | Base ngày công |
|---|---:|---:|
| A — Khóa phạm vi và tạo source fork | 6 | 4.5–7.5 |
| B — Khóa toolchain Windows và Web | 7 | 5.5–9 |
| C — Build đối chứng từ source chưa sửa | 7 | 8–13 |
| D — Game mẫu và baseline PC/điện thoại | 7 | 7–11 |
| E — Editor EXE riêng và New H5 Project | 8 | 8–13 |
| F — Cặp Web templates cùng fork revision | 7 | 7–11 |
| G — Shell, Browser Preview và mobile hardening | 8 | 8–13.5 |
| H — Tối ưu templates theo số đo | 6 | 6–10 |
| I — Đóng gói, release candidate và bảo trì | 5 | 4.5–9.5 |
| **Tổng base** | **61** | **58.5–97.5** |

Dự phòng integration/rebuild/regression **25–40%** trên tổng base cho khoảng **74–137 ngày công**, tương đương khoảng **15–28 tuần** ở 5 ngày/tuần, 6 giờ tập trung/ngày. Đây là band lập kế hoạch, không phải deadline. Đây là phần dự phòng duy nhất; không cộng thêm estimate review/gates vì chúng đã nằm trong task base.

Thời gian học mới Godot/C++/MSVC/Emscripten, đợi thiết bị, network hoặc certificate/DNS nằm ngoài base và có thể kéo dài lịch. Đánh giá lại sau C07 và D07. Bản kế hoạch cũ plugin-first có band khác; band ở đây thay thế nó cho lựa chọn fork.

Mốc nghiệm thu:

- **A–C:** full source, toolchain và control editor/templates khả thi; nếu fail thì xử lý trước branding.
- **D:** fixture chơi được qua HTTPS trên PC và điện thoại thật, có baseline.
- **E–G:** internal alpha có own EXE, New H5 Project, cặp Web templates, preview/export/mobile flow.
- **H–I:** release candidate sau package sạch, hai games và cache/update/rollback/maintenance. Strip là tối ưu tùy chọn; nếu không có lợi thì dùng full templates đã kiểm.

## 5. Dependency và nhánh có thể làm song song

Một người đi A→B→C→D trước để triệt tiêu rủi ro build/browser. Sau C03 có thể làm E01–E07 song song với phần D; chỉ nghiệm thu E08 sau D07. Trong B có thể cài native compiler, Python và emsdk độc lập. Không chạy debug/release Web build đồng thời trong một checkout.

Sau E08/F07 có thể chuẩn bị I01–I03 và H02 sớm; game thứ hai H02 phải có trước H06 để regression trên hai game. I04 chờ H06/G07/G08 và refresh/rebuild package cuối trước khi chốt RC. E/G code thay đổi sau F01 cần build lại EXE/cả templates theo revision cuối rồi cập nhật manifest; kết quả đầu giai đoạn không tự áp dụng cho code mới. Các dependency đã được kiểm tra không có vòng.

Nếu chưa truy cập được iPhone/Android hoặc trusted HTTPS, đánh dấu D07 và gate mobile đang chờ; vẫn có thể làm native/editor riêng độc lập, nhưng không claim H5 mobile đã pass.

## 6. Ma trận nghiệm thu tối thiểu

| Ca kiểm thử | Native Windows | PC Chrome/Edge | Android Chrome thật | iPhone Safari thật |
|---|---|---|---|---|
| New H5 Project, edit/save/reopen, plugin enable/disable | Bắt buộc | Không áp dụng | Không áp dụng | Không áp dụng |
| Chơi menu→game→result→replay, đổi scene | Bắt buộc | Debug + release | Debug + release smoke | Debug + release smoke |
| WebGL2/secure context, boot/error/retry | Không áp dụng | Trusted HTTPS + local preview | Trusted HTTPS | Trusted HTTPS |
| Tap/drag/cancel, resize/DPR/safe area, rotate | Mouse/focus | Mouse/resize | Touch và browser chrome | Touch, notch và browser chrome |
| Audio gesture, mute, tab/home 30s rồi resume | Native behavior | Bắt buộc | Bắt buộc | Bắt buộc |
| Local save reload/reopen và storage errors | File/native case | Same release origin | Same release origin | Same release origin |
| Cold/warm load, p95 frame, 10m/20 scene swaps | Control baseline | Đo | Đo | Đo |
| Warm-cache v1→v2→rollback không trộn bundle | App/package case | Bắt buộc | Bắt buộc | Bắt buộc |

Mỗi record có source/fork SHA, editor/template/shell build ID và hashes, flavor, URL, ngày kiểm, model/OS/browser, network profile, pass/fail/repro/log. Hai game phải khác input/resource mix. Không lấy Chrome/Edge desktop cùng Chromium để thay Safari trên máy thật.

Tiêu chí save: sync thành công + read-back sau reload/reopen chứng minh đường lưu cục bộ được thử, không bảo đảm sống sót khi browser eviction hoặc người dùng clear site data. Private mode không mặc định đồng nghĩa IndexedDB bị chặn; test browser thực tế rồi hiển thị trạng thái đúng. Nếu stock bridge chưa cho receipt cần thiết, G08 phải có spike/sửa bridge tối thiểu và estimate lại, không hiển thị thành công giả.

## 7. Thứ tự triển khai trong những tuần đầu

Lịch dưới là thứ tự ưu tiên, không dồn 10–16 ngày công của A+B vào một tuần:

- **Ngày 1:** A01 — scope bản đầu, thiết bị tối thiểu và tính năng ngoài scope.
- **Ngày 2:** hoàn tất A01 nếu cần; A02 — fingerprint nguồn và quyết định repo boundaries của A06.
- **Ngày 3:** A03 — bắt đầu clone development source độc lập và checkout commit khóa.
- **Ngày 4:** hoàn tất A03, A04 — xác minh full source và trạng thái Git.
- **Ngày 5:** A05 và bắt đầu A06 nếu các bước trước đã pass; việc chưa xong chuyển sang tuần sau.
- **Tuần 2 trở đi:** hoàn tất A, làm B01–B07. A+B có base 10–16.5 ngày công, chưa kể chờ download hoặc xử lý môi trường.
- **Khi gate B pass:** C01→C02→C03; sau đó cặp Web templates C04→C05→C06→C07. Có thể chuẩn bị Web profile trước khi native build xong, nhưng không gọi gate C hoàn thành khi mới có EXE.

Không hứa có cả editor và Web templates trong tuần đầu. Mục tiêu tuần đầu là source/repo đúng và kế hoạch môi trường rõ; bắt đầu branding chỉ sau khi build đối chứng và baseline đủ bằng chứng.

## 8. Những điểm source có ảnh hưởng tới thiết kế

- Web exporter có sẵn custom template/shell và variant switches: [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L370>). Desktop VRAM compression mặc định khác mobile, cần import policy riêng.
- Godot có Run in Browser/re-export/start-stop server tại [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L779>); tận dụng trước khi viết server mới. H5 commands có thể dùng public API/CLI sau spike, không giả định gọi được internal API từ GDScript.
- Secure context vẫn cần khi threads=no: [features.js](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/js/engine/features.js#L90>). `http://IP-LAN-PC` trên điện thoại không tương đương localhost của PC.
- Preview mặc định localhost/TLS off ở [export.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export.cpp#L45>); preview server gửi COOP/COEP/no-store ở [editor_http_server.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/editor_http_server.cpp#L108>). Host production cần nghiệm thu riêng.
- Custom-template validation chủ yếu kiểm file tồn tại tại [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L437>); manifest+hash/flavor check là công việc bắt buộc của fork.

Tài liệu build đối chiếu: [Windows](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_windows.html), [Web](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_web.html), [SCons buildsystem](https://docs.godotengine.org/en/stable/engine_details/development/compiling/introduction_to_the_buildsystem.html). Docs stable có thể thay đổi; full source commit đã khóa là căn cứ cuối cho flags/toolchain.

Kế hoạch này thay thế lộ trình plugin-first trong [kế hoạch trước](<C:/Users/Mark-TA/Desktop/AppGame/GODOT_H5_PLAN.vi.md>). Giữ [bản nghiên cứu](<C:/Users/Mark-TA/Desktop/AppGame/GODOT_H5_STUDY.vi.md>) làm tài liệu kiến trúc. Trạng thái từng việc: xem [docs/BACKLOG-STATUS.md](<docs/BACKLOG-STATUS.md>). Quyết định lệch kế hoạch (server GDScript cho Browser Preview, macOS là giai đoạn J) được ghi ở cuối file đó.
