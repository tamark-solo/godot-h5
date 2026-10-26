# Kế hoạch phát triển bộ công cụ Godot H5

> **Đã thay thế cho lựa chọn cách 2:** dùng [kế hoạch fork Godot chi tiết](<C:/Users/Mark-TA/Desktop/AppGame/GODOT_H5_FORK_PLAN.vi.md>) làm backlog hiện hành. Nội dung bên dưới giữ lại để tham khảo phương án dùng editor chính thức và addon; không phải lộ trình hiện tại của dự án.

## 0. Mục tiêu đã chốt và giả định lập kế hoạch

Mục tiêu là một **ứng dụng editor desktop giống Godot**, dùng để tạo game và xuất game H5 chạy trên:

- trình duyệt máy tính: Chrome/Edge trước, Firefox kiểm tra sau;
- Android Chrome;
- iPhone Safari; iPad bổ sung khi có thiết bị và nhu cầu kiểm thử;
- web top-level qua HTTPS, không lấy file HTML bằng file:// làm tiêu chí chạy thật.

Các lựa chọn sau là **giả định đề xuất cho bản đầu**, chưa phải yêu cầu bạn đã xác nhận riêng từng mục:

- Windows x64 editor;
- game 2D;
- GDScript;
- renderer Compatibility/WebGL2;
- web runtime single-thread, không GDExtension web trong MVP;
- native Preview và Browser Preview riêng biệt;
- lưu cục bộ qua cơ chế web của Godot, chưa làm cloud save;
- bản phân phối đầu là portable ZIP, chưa làm installer/updater.

Một ngày công trong kế hoạch = khoảng 6 giờ tập trung. Khoảng thời gian là ước lượng cho người đã có nền Godot/GDScript và có thể đọc C++/JavaScript; không phải cam kết deadline. Nếu vừa học plugin, build C++, Emscripten và kiểm thử thiết bị, nên dự trù 4–6 tháng hoặc hơn.

Mã nguồn tham chiếu là Godot 4.7.2-stable, commit ed1daf0bf001b61586d9930840f2f1394092c079; phiên bản được ghi trong [version.py](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/version.py#L1-L9>). Checkout hiện tại là sparse và chưa có sẵn Godot, SCons hoặc Emscripten trong PATH. Vì vậy không được coi việc build custom editor/template là đã hoàn thành.

## 1. Kết quả sản phẩm theo từng tầng

| Tầng | Kết quả | Có thể dùng được chưa? |
| --- | --- | --- |
| M0 — Baseline | Một project Godot nguyên bản chạy native và H5 trên PC/Android/iOS | Có, để xác nhận nền tảng trước khi sửa engine |
| M1 — Công cụ nội bộ | Official Godot editor + H5 addon + project template + validator + Browser Preview | Có, dùng để làm game H5 nội bộ |
| M2 — Alpha sản phẩm | Editor Windows đóng gói riêng + custom HTML shell + export template khớp phiên bản | Có, có thể đưa cho người khác thử |
| M3 — Release candidate | Hai game mẫu, device matrix, build reproducible, cache/hosting/rollback được kiểm tra | Có, đủ cơ sở phát hành bản đầu |

**MVP thực dụng là M1.** Không nên chờ custom C++ editor hoàn tất mới kiểm chứng việc game có chạy tốt trên mobile hay không. M2/M3 chỉ bắt đầu sau khi M1 đã xuất được một game thật.

## 2. Mười đầu việc chính

### H5-01 — Chốt phạm vi hỗ trợ và đặc tả game kiểm thử

**Mục tiêu:** chốt phạm vi hỗ trợ và chuẩn bị đặc tả, asset, ca kiểm thử cho một game mẫu dùng xuyên suốt dự án. Việc dựng project bằng editor và chạy game nằm ở H5-02.

**Phụ thuộc:** không có.

**Đầu ra:**

- tài liệu support contract ghi rõ Windows editor, browser, Android/iOS, phiên bản OS/browser và model thiết bị mục tiêu;
- đặc tả game mẫu nhỏ có menu → gameplay → kết quả → chơi lại;
- danh mục scene và asset: sprite/atlas, font tiếng Việt, audio; yêu cầu mouse/touch, physics đơn giản, save/load;
- mẫu bảng baseline để H5-02 điền: kích thước file, bytes truyền sau gzip/Brotli, thời gian tới tương tác đầu tiên, frame time p95, memory sau 10 phút và sau nhiều lần đổi scene;
- danh sách thiết bị thật: ít nhất một Android và một iPhone, emulator chỉ là kiểm tra phụ.

**Việc chi tiết:**

1. Chọn loại game 2D và thiết kế màn chơi đủ nhỏ để hoàn thành trong một tuần.
2. Ghi exact model, OS, browser version và ngày kiểm tra.
3. Chốt cấu hình mục tiêu: Compatibility, GDScript, web threads/extensions tắt, PWA tắt.
4. Chuẩn bị asset và ca kiểm thử input: nhấn, giữ, kéo, thả ngoài canvas và mất focus.
5. Định nghĩa checkpoint save và cách kiểm tra sau reload/reopen, không chỉ dựa vào callback ghi file.
6. Lập ma trận debug/release trên desktop browser và thiết bị thật; chọn nơi thử HTTPS.
7. Chuẩn bị mẫu báo lỗi riêng cho Native Preview, Browser Preview và Release Web Export.

**Nghiệm thu:** có phạm vi thiết bị/browser, đặc tả game nhỏ, asset sẵn dùng, các ca kiểm thử và phương án HTTPS. Xác nhận khả năng tiếp cận Android/iPhone thật; nếu chưa có thì đánh dấu nghiệm thu mobile đang chờ, không thay bằng emulation. H5-02 mới nghiệm thu game chạy thực tế.

**Ước lượng:** 3–5 ngày.

### H5-02 — Thiết lập Godot chính thức và baseline Web

**Mục tiêu:** chứng minh Godot nguyên bản đã đáp ứng phần lõi trước khi viết addon hoặc fork.

**Phụ thuộc:** H5-01.

**Đầu ra:**

- editor Godot và web export templates cùng một phiên bản;
- project mẫu mở được bằng editor sạch;
- preset web debug và release;
- biên bản baseline cho PC, Android và iOS;
- manifest ghi phiên bản editor, template, project, preset và build flavor.

**Việc chi tiết:**

1. Dùng bản editor chính thức 4.7.2 tương ứng với source reference, hoặc khóa một phiên bản khác và ghi lại rõ.
2. Dựng game theo đặc tả H5-01: menu, gameplay, kết quả, chơi lại; sprite/font, touch/mouse, audio, save và hai scene tối thiểu. Import, save/reopen và chạy native Preview.
3. Export web với Compatibility/WebGL2, tắt Thread Support và Extensions Support trong preset. Cờ build `threads=no` chỉ dùng ở bước tự biên dịch runtime H5-07.
4. Chạy bằng URL HTTP(S), không dùng file://.
5. Kiểm tra boot, input, audio, save, đổi scene và reload.
6. Đo cold load và warm load trên mạng cố định.
7. Kiểm tra texture import: preset web hiện để VRAM desktop compression bật và mobile compression tắt tại [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L374-L377>), nên phải quyết định policy texture riêng thay vì mặc định mù.

**Nghiệm thu:** baseline chạy được trên bốn nhóm môi trường: Chrome/Edge desktop, Android Chrome, iOS Safari và native editor. Không còn lỗi boot blocker chưa phân loại. Mọi số đo đều gắn với build ID và thiết bị cụ thể.

**Ước lượng:** 3–5 ngày.

### H5-03 — H5 addon, project template và preflight validator

**Mục tiêu:** biến Godot nguyên bản thành workflow làm H5 có hướng dẫn và kiểm tra trước khi export.

**Phụ thuộc:** H5-02.

**Đầu ra:** một project addon có thể bật/tắt, một template project, H5 dock và validator.

**Việc chi tiết:**

1. Tạo EditorPlugin có lifecycle sạch: register, unregister, reload; không nhân đôi dock/action sau nhiều lần bật tắt.
2. Tạo H5 configuration Resource có version, design resolution, orientation, stretch policy, title/icon, input profile và target preset.
3. Tạo project template với input actions, root Control responsive, safe-area helper và hướng dẫn portrait/landscape.
4. Thêm H5 dock chỉnh các thuộc tính và dùng UndoRedo cho thay đổi editor.
5. Thêm validator severity error/warning/info cho:
   - renderer không phải Compatibility;
   - thiếu main scene;
   - preset còn threads/extensions;
   - template debug/release không khớp;
   - asset thiếu hoặc đường dẫn sai;
   - texture quá lớn, font/audio không phù hợp mobile;
   - dùng API native không có trong web;
   - input/action hoặc orientation chưa khai báo.
6. Dùng EditorExportPlugin để validate/customize export; không viết lại toàn bộ exporter.
7. Khi còn là addon project-scoped, dùng template project để bootstrap. Không hứa addon tự thêm New H5 Project vào Project Manager của editor nguyên bản.

Các hook export hiện có trong [editor_export_plugin.h](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/editor/export/editor_export_plugin.h#L98-L120>), còn web preset đã có custom template, custom HTML shell, resize policy và các tùy chọn threads/extensions tại [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L370-L395>).

**Nghiệm thu:** copy template vào thư mục mới, bật addon, cấu hình project, tạo scene, save/reopen, chạy native, validator và export web mà không phải sửa tay file cấu hình. Tắt addon vẫn mở được project hợp lệ. Một project thứ hai cũng cài addon được.

**Ước lượng:** 5–8 ngày.

### H5-04 — Browser Preview và pipeline export không mở build cũ

**Mục tiêu:** có ba nút/luồng rõ ràng: Native Preview, Browser Preview và Release Web Export.

**Phụ thuộc:** H5-02; H5-03 ở mức validator cơ bản.

**Đầu ra:** Browser Preview dùng lại cơ chế Godot có sẵn, log rõ ràng, export mới trước khi mở browser.

**Việc chi tiết:**

1. Kiểm tra API public/CLI để gọi export; nếu hook nội bộ không phù hợp, dùng CLI export được hỗ trợ thay vì viết server thứ hai.
2. Browser Preview phải save pending edits, validate, export debug mới, ghi build ID, start/reuse server và mở URL thật.
3. Nếu export thất bại, không được mở output cũ như thể export thành công.
4. Xử lý port bận, template thiếu, đường dẫn có dấu/khoảng trắng, output stale, server chết và editor đóng bất thường.
5. Start/stop/re-export nhiều lần không để lại process thuộc editor.
6. Tách Release Web Export: output folder sạch, debug/release đúng preset, không dùng kết quả debug để kết luận release.
7. Dùng lại Run in Browser, Start HTTP Server, Stop HTTP Server và re-export đã có trong [export_plugin.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export_plugin.cpp#L779-L883>).

**Lưu ý HTTPS:** preview mặc định dùng localhost, port 8060 và TLS tắt tại [export.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/export.cpp#L45-L52>). Điện thoại truy cập http://IP-LAN-PC không tương đương localhost và không chứng minh H5 mobile hoạt động. Godot kiểm tra secure context ngay cả khi threads=no tại [features.js](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/js/engine/features.js#L90-L101>). Cần trusted HTTPS staging hoặc chứng chỉ local được thiết bị tin cậy và hostname/SAN đúng.

Preview server hiện gửi COOP/COEP và no-store tại [editor_http_server.cpp](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/export/editor_http_server.cpp#L108-L115>); do đó preview pass không tự động chứng minh hosting production, iframe hoặc SDK publisher sẽ pass.

**Nghiệm thu:** chỉnh sprite hoặc scene, bấm Browser Preview, browser hiển thị bản mới; khi cố tình làm export lỗi, browser không chạy bản trước. Stop/Start lặp lại sạch. Release artifact chạy ở một HTTPS host gần production, có đúng MIME application/wasm, path subdirectory và compression.

**Ước lượng:** 4–7 ngày.

### H5-05 — Custom HTML shell và browser bridge

**Mục tiêu:** kiểm soát lớp web bên ngoài WASM mà không sửa engine C++ sớm.

**Phụ thuộc:** H5-04.

**Đầu ra:** custom HTML shell, JavaScript bridge nhỏ, mock host API và tài liệu callback.

**Việc chi tiết:**

1. Giữ đúng placeholder/boot contract của Godot.
2. Hiển thị loading progress, initializing, ready, unsupported và failed; có retry, không spinner vô hạn.
3. Kiểm tra secure context, WebGL2, fetch/WASM và hiển thị lỗi có hướng dẫn.
4. Đồng bộ canvas backing size, CSS size, DPR, resize và orientation.
5. Unlock/resume audio sau thao tác người dùng.
6. Tạo bridge trung lập cho ready, pause, resume, show ad mock, analytics mock và save event; không gắn cứng một publisher.
7. Tách platform adapter khỏi gameplay; không đưa DOM/SDK object vào scene resource.
8. Không làm PWA/service worker ở giai đoạn này để tránh thêm lớp cache khó gỡ.

**Nghiệm thu:** shell tự báo lỗi WebGL2/secure-context/thiếu file; game boot được khi host API không tồn tại; mock callback pause/resume hoạt động; canvas không bị méo sau resize/DPR; audio bắt đầu sau gesture; shell debug và release dùng đúng template.

**Ước lượng:** 4–7 ngày.

### H5-06 — Mobile input, viewport, audio, save và resume

**Mục tiêu:** làm game thật sự chơi được trên điện thoại, không chỉ boot được.

**Phụ thuộc:** H5-04 và H5-05; H5-01 cung cấp fixture.

**Việc chi tiết:**

1. Test portrait/landscape, rotate, browser chrome co giãn, notch/safe area và DPR.
2. Xử lý pointer/touch cancel, multitouch nếu game cần, drag ra ngoài canvas, focus loss và touch-to-mouse không tạo double action.
3. Ngăn canvas kéo scroll trang khi gameplay cần gesture; không hứa fullscreen/orientation lock vì browser có thể từ chối.
4. Start gesture cho audio, mute/volume, home/lock/tab background 30 giây rồi quay lại.
5. Visibility resume phải clamp/reset thời gian hợp lý, không làm simulation nhảy quá lớn.
6. Save checkpoint trước khi background; reload/reopen cùng origin phải giữ save nếu IndexedDB hoạt động.
7. Nếu quota/private mode/storage bị chặn, game vẫn chơi được và UI không nói sai là đã lưu.
8. Context loss chỉ cần hiển thị lỗi và hướng reload/restore checkpoint trong MVP; không tuyên bố tự khôi phục GPU hoàn toàn.
9. Nếu game cần nhập văn bản, tạo task IME/virtual keyboard riêng; không xem tính năng experimental là đã hoàn thành.

**Nghiệm thu:** game fixture chơi được bằng touch trên Android Chrome và iOS Safari; không kẹt nút sau cancel/focus loss; audio resume đúng; save failure có trạng thái rõ; sau background/resume không crash hoặc nhảy simulation bất thường. Có URL/build ID/device cho từng kết quả.

**Ước lượng:** 8–12 ngày.

### H5-07 — Toolchain reproducible và custom Web export templates

**Mục tiêu:** chỉ sau khi baseline ổn định mới build template WASM riêng, tránh tối ưu mù.

**Phụ thuộc:** H5-02, H5-06 và source đầy đủ.

**Đầu ra:** build recipe, web template debug/release, manifest tương thích và test mismatch.

**Việc chi tiết:**

1. Mở rộng sparse checkout thành full source trước khi compile; checkout hiện tại thiếu các vùng editor/Windows/thirdparty/misc cần cho build hoàn chỉnh.
2. Tạo branch/worktree phát triển từ commit khóa; không sửa trực tiếp detached reference.
3. Cài và pin Python tối thiểu 3.9, SCons tối thiểu 4.4 theo [SConstruct](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/SConstruct#L1-L5>), MSVC/Windows SDK và Emscripten tối thiểu 4.0.0 theo [detect.py](<C:/Users/Mark-TA/Desktop/AppGame/reference/godot/platform/web/detect.py#L112-L119>).
4. Build editor Windows nguyên bản làm control trước khi áp patch. Chuẩn bị thêm một scene kiểm thử resource/input khác game chính để bắt lỗi khi strip template; game thứ hai hoàn chỉnh hơn được dựng ở H5-10.
5. Build full-feature web debug/release cùng commit, wasm32, Compatibility, threads=no, extensions=no, dlink=no.
6. Không trộn JS loader, WASM, PCK và HTML shell khác revision.
7. Tạo manifest gồm upstream commit, patch revision, editor build ID, template flavor, feature profile, shell version và hash từng template.
8. Kiểm tra mismatch/missing template trước khi export; validation file tồn tại của Godot không đủ làm manifest compatibility.
9. Chỉ sau khi full template pass mới strip module 3D/XR/navigation/physics không dùng; kiểm tra game chính và scene kiểm thử bổ sung. Kiểm thử lại bằng hai game ở H5-10 trước khi phát hành.
10. Texture policy phải explicit cho desktop/mobile; không áp threads=no lên native editor Windows.

**Nghiệm thu:** người khác có thể chạy build recipe trên máy sạch đã cài toolchain; editor/template debug/release tạo output boot được; export từ GUI và CLI chọn cùng manifest; template sai bị từ chối; mọi tối ưu có số đo trước/sau về transfer, startup và regression.

**Ước lượng:** 10–18 ngày. Đây là vùng có rủi ro cao nhất; nếu chưa từng build Godot/Emscripten, dùng đầu trên của dải hoặc cao hơn.

### H5-08 — Đóng gói editor Windows riêng và New H5 Project

**Mục tiêu:** từ công cụ nội bộ thành ứng dụng desktop có nhận diện và onboarding riêng.

**Phụ thuộc:** H5-03, H5-07; nên có H5-04 đến H5-06 để workflow đã được chứng minh.

**Đầu ra:** portable ZIP gồm editor, addon, templates, HTML shell, samples, docs và manifest.

**Việc chi tiết:**

1. Giữ patch C++ nhỏ; chỉ sửa product identity, H5 toolbar/entry và bootstrap nếu plugin không thể làm.
2. Thêm New H5 Project: chép template đúng revision, enable addon và tạo preset hợp lệ.
3. Đặt plugin/template/shell/sample trong thư mục của sản phẩm; không dựa vào Godot/plugin/template global của máy developer.
4. Tách user data, cache và project data; giữ đường dẫn tương đối ổn định.
5. Đóng gói portable ZIP trước; installer, updater, signing để sau.
6. Kiểm tra Explorer launch, project mới/mở, save/reopen, import, native play, Browser Preview và Release Export.
7. Test đường dẫn có dấu, khoảng trắng, ổ đĩa khác, quyền ghi hạn chế và clean Windows user/machine.
8. Ghi version manifest để app không dùng nhầm template của Godot khác.

**Nghiệm thu:** trên máy Windows sạch không có Godot/Python/compiler global, người dùng mở EXE, tạo H5 project, chỉnh scene, chạy native, Browser Preview và xuất artifact release theo tài liệu ngắn. Plugin disable/re-enable/reopen không nhân dock/action.

**Ước lượng:** 8–15 ngày. Nếu chỉ phân phối official editor + addon, đây là bản trung gian, không gọi là custom editor hoàn chỉnh.

### H5-09 — Performance, release hosting và cache/version policy

**Mục tiêu:** đảm bảo artifact ngoài editor chạy ổn trên hosting gần production.

**Phụ thuộc:** H5-06 và H5-07; có thể làm đo sớm từ H5-01.

**Việc chi tiết:**

1. Đo cold/warm load trên mạng cố định: compressed transferred bytes, WASM init, PCK/assets decode, first interaction.
2. Đo frame p50/p95/p99, draw calls, texture count và memory trend.
3. Cho game chạy 10 phút; đổi scene 20 lần; phát hiện crash hoặc memory tăng không giới hạn.
4. Tạo output folder sạch, MIME application/wasm, gzip/Brotli đúng Content-Encoding, HTTPS và subdirectory path.
5. Dùng versioned/atomic bundle để JS/WASM/PCK không trộn khi deploy.
6. Kiểm cache v1 → v2, reload cứng, warm cache và rollback v1.
7. Kiểm release-like host tách khỏi preview server có COOP/COEP/no-store mặc định.
8. Giữ PWA/service worker ngoài MVP; chỉ thêm sau khi cache policy không còn lỗi.
9. Đặt device floor và ngân sách dựa trên số đo, không công bố FPS/dung lượng chung cho mọi game.

**Nghiệm thu:** release artifact được serve ở host HTTPS gần production, browser PC và thiết bị mobile boot đúng; không trộn bundle sau deploy; số đo có build ID và network profile; lỗi vượt ngân sách dẫn tới tối ưu hoặc thu hẹp support contract.

**Ước lượng:** 5–8 ngày.

### H5-10 — Release candidate, game thứ hai và maintenance baseline

**Mục tiêu:** kiểm tra engine/tool không chỉ phù hợp một game mẫu và có thể duy trì sau khi phát hành.

**Phụ thuộc:** H5-07, H5-08, H5-09.

**Đầu ra:** fixture thứ hai, smoke test, device matrix, release ZIP, quickstart/troubleshooting và patch manifest.

**Việc chi tiết:**

1. Làm game thứ hai khác layout/input/resource mix, ví dụ puzzle kéo-thả thay vì game action.
2. Tự động hóa project import, validator, debug export, release export, manifest check và artifact file check.
3. Giữ physical-device manual test cho touch, audio, background/resume, save và context loss.
4. Test malformed preset, missing template, corrupt save, storage failure, stale cache và export failure.
5. Test upgrade thủ công, giữ user data, rollback bundle và export offline khi template đã cài.
6. Ghi upstream commit, patch list, toolchain version và cách tái tạo build.
7. Viết quy trình cập nhật Godot trên branch riêng, chạy lại hai game trước khi merge. Thử một bản cập nhật nếu đã có bản phù hợp; nếu chưa, diễn tập build và regression trên một thay đổi nhỏ có kiểm soát.
8. Viết quickstart cho người dùng mới: tạo project → edit → Native Preview → Browser Preview → Release Export.

**Nghiệm thu:** một developer khác có thể giải nén, tạo project H5, chỉnh scene, preview và export mà không cần máy developer. Hai game đều pass browser/device matrix; có rollback và build recipe; danh sách known limitations rõ ràng.

**Ước lượng:** 8–12 ngày.

## 3. Tổng thời gian và đường găng

| Phạm vi | Đầu việc | Dải ước lượng |
| --- | --- | ---: |
| M0 baseline | H5-01 → H5-02 | 6–10 ngày |
| M1 công cụ nội bộ | H5-03 → H5-06 | 21–34 ngày |
| M2 app riêng/template | H5-07 → H5-08 | 18–33 ngày |
| M3 release candidate | H5-09 → H5-10 | 13–20 ngày |
| **Tổng toàn bộ** | **H5-01 → H5-10** | **58–97 ngày công** |

Với một người làm full-time và đã quen Godot, dải thực tế nên công bố là khoảng **12–20 tuần**, không phải deadline chắc chắn. Nếu vừa học Godot plugin, C++, MSVC, SCons và Emscripten thì có thể thành **4–6 tháng hoặc hơn**.

Đường găng nên là:

~~~text
H5-01 phạm vi / đặc tả fixture
  → H5-02 baseline web/mobile
    → H5-03 addon/validator
      → H5-04 Browser Preview
        → H5-05 shell/bridge
          → H5-06 mobile hardening
            → H5-07 custom templates
              → H5-08 custom editor
                → H5-09 release hosting/performance
                  → H5-10 RC
~~~

Đây là thứ tự ưu tiên cho một người làm, không phải mọi bước đều bắt buộc chờ hoàn tất bước liền trước. Có thể chuẩn bị toolchain của H5-07 sau H5-03; chỉ nghiệm thu template sau H5-06. Các phép đo H5-09 bắt đầu từ H5-02, còn nghiệm thu release hosting thực hiện sau khi có artifact ổn định. Không để custom build ngăn việc kiểm chứng game với official editor/template.

## 4. Mốc có thể dừng để đánh giá

### Sau 10 ngày — quyết định nền tảng

Nếu game fixture không boot/chơi được trên một trong các browser mục tiêu, dừng sửa editor và xử lý platform issue trước. Không bước sang custom C++.

### Sau khoảng 27–44 ngày công — MVP dùng nội bộ

Phải có official editor + addon + template + validator + Browser Preview + mobile hardening cơ bản. Nếu đạt, bạn đã có công cụ làm game H5; custom editor chưa cần thiết để tiếp tục làm game.

### Sau khoảng 45–77 ngày công — alpha sản phẩm riêng

Có custom template, manifest, portable editor và custom shell. Chỉ phát hành cho nhóm thử nhỏ, chưa quảng bá hỗ trợ mọi thiết bị.

### Sau khoảng 58–97 ngày công — release candidate hẹp

Hai game mẫu, browser/device matrix, clean-machine test, cache/hosting/release test và build recipe đều đạt. Những tính năng chưa có phải ghi rõ, không âm thầm nhận support.

## 5. Những việc cố ý để ngoài MVP

Các việc sau nằm ngoài cả MVP nội bộ và bản phát hành hẹp trong 10 đầu việc trên; cần ước lượng riêng khi nền tảng ổn định. Các dải dưới chỉ là sơ bộ và phụ thuộc API, backend, yêu cầu publisher:

- publisher/ad SDK thật theo từng nền tảng: khoảng 5–10 ngày cho mỗi SDK, chưa tính review/policy;
- payment và backend transaction verification: khoảng 10–20 ngày;
- account/cloud save/sync/conflict/offline: khoảng 15–30 ngày;
- PWA/offline service worker và cache invalidation nâng cao;
- GDExtension web và threads;
- TypeScript gameplay runtime;
- 3D/renderer mới/physics mới;
- visual no-code editor thay thế sâu editor Godot;
- installer, signing, updater, crash reporting và telemetry production;
- browser-hosted editor.

Không nên gộp các mục này thành một task chung “SDK/payment/cloud”, vì mỗi mục có dependency và rủi ro khác nhau.

## 6. Việc nên làm trong tuần đầu

1. Chốt model Android/iPhone, OS/browser và support contract.
2. Cài official Godot editor + đúng export template; ghi version/hash.
3. Tạo game fixture menu → play → result → replay có font tiếng Việt, touch, audio và save.
4. Export debug/release cho desktop browser.
5. Dùng trusted HTTPS staging để chạy Android Chrome và iOS Safari; kiểm tra window.isSecureContext.
6. Ghi boot blocker, input/audio/save/resume issue và baseline metrics.
7. Tạo skeleton H5 addon và bốn validator đầu tiên: renderer, main scene, preset variant, template matching.
8. Chỉ sau khi các bước trên pass mới quyết định có cần mở rộng source và build custom editor/template hay không.

Theo yêu cầu, kế hoạch tập trung vào sản phẩm và kỹ thuật, không phân tích thêm giấy phép. Trọng tâm là chứng minh workflow editor desktop → game H5 trên thiết bị thật trước, sau đó đầu tư vào fork và đóng gói sản phẩm riêng. Đây là kế hoạch đề xuất; chưa có addon, custom build hoặc benchmark nào được hoàn thành.
