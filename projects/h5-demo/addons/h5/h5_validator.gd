@tool
class_name H5Validator
extends RefCounted
## Preflight validator cho H5 export (E07).
## Trả về danh sách issue: { severity, code, message, hint }
## severity: "error" | "warning" | "info"

const SEV_ERROR := "error"
const SEV_WARNING := "warning"
const SEV_INFO := "info"

## Action dựng sẵn của Godot (không nằm trong [input] của project.godot).
## Thiếu sót này đã bị bắt khi chạy thử CLI lần đầu -> bổ sung để tránh false positive.
const BUILTIN_ACTIONS := [
	"ui_accept", "ui_select", "ui_cancel", "ui_focus_next", "ui_focus_prev",
	"ui_left", "ui_right", "ui_up", "ui_down", "ui_page_up", "ui_page_down",
	"ui_home", "ui_end", "ui_cut", "ui_copy", "ui_paste", "ui_undo", "ui_redo",
	"ui_text_completion_query", "ui_text_completion_accept", "ui_text_completion_replace",
	"ui_text_newline", "ui_text_newline_blank", "ui_text_newline_above",
	"ui_text_indent", "ui_text_dedent", "ui_text_backspace", "ui_text_backspace_word",
	"ui_text_backspace_all_to_left", "ui_text_backspace_word.macos",
	"ui_text_backspace_all_to_left.macos", "ui_text_delete", "ui_text_delete_word",
	"ui_text_delete_all_to_right", "ui_text_delete_word.macos",
	"ui_text_delete_all_to_right.macos", "ui_text_caret_left", "ui_text_caret_word_left",
	"ui_text_caret_right", "ui_text_caret_word_right", "ui_text_caret_up",
	"ui_text_caret_down", "ui_text_caret_line_start", "ui_text_caret_line_end",
	"ui_text_caret_page_up", "ui_text_caret_page_down", "ui_text_caret_document_start",
	"ui_text_caret_document_end", "ui_text_caret_start", "ui_text_caret_end",
	"ui_text_scroll_up", "ui_text_scroll_down", "ui_text_select_all",
	"ui_text_select_word_under_caret", "ui_text_add_selection_for_next_occurrence",
	"ui_text_clear_carets_and_selection", "ui_text_toggle_insert_mode",
	"ui_text_submit", "ui_graph_duplicate", "ui_graph_delete", "ui_filedialog_up_one_level",
	"ui_filedialog_refresh", "ui_filedialog_show_hidden", "ui_swap_input_direction",
	"ui_menu", "ui_accept.macos",
]

## API native không có trên web (danh sách ĐÃ XÁC ĐỊNH — không hứa phân tích mọi API).
const WEB_UNSUPPORTED_APIS := [
	"OS.shell_open",
	"OS.execute",
	"OS.create_process",
	"OS.kill",
	"OS.get_processor_name",
	"OS.set_restart_on_exit",
	"Engine.get_singleton",       # chỉ đúng khi có GDExtension; MVP tắt extensions
	"ProjectSettings.load_resource_pack",  # chỉ dùng được nếu có file pack ngoài
]

var _issues: Array[Dictionary] = []

func issues() -> Array[Dictionary]:
	return _issues

func has_errors() -> bool:
	for i in _issues:
		if i.severity == SEV_ERROR:
			return true
	return false

func _add(severity: String, code: String, message: String, hint: String = "") -> void:
	_issues.append({ "severity": severity, "code": code, "message": message, "hint": hint })

## edit: EditorInterface hoac null (khi chay tu CLI headless).
## KHONG duoc khai bao kieu EditorInterface: GDScript bao
## 'argument 2 should be EditorInterface but is null' khi truyen null.
func run(cfg: H5Config, edit = null) -> Array[Dictionary]:
	_issues.clear()
	_check_renderer()
	_check_main_scene()
	_check_preset(cfg)
	_check_templates(cfg, edit)
	_check_assets(cfg)
	_check_input(cfg)
	_check_unsupported_apis()
	_check_resolution(cfg)
	return _issues

# ---------------------------------------------------------------- renderer
func _check_renderer() -> void:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var mobile := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	if method != "gl_compatibility":
		_add(SEV_ERROR, "renderer.desktop",
			"Renderer desktop là '%s', không phải 'gl_compatibility'." % method,
			"Web export dùng Compatibility/WebGL2. Đổi trong Project Settings > Rendering > Renderer.")
	if mobile != "gl_compatibility":
		_add(SEV_ERROR, "renderer.mobile",
			"Renderer mobile là '%s', không phải 'gl_compatibility'." % mobile,
			"Đặt rendering_method.mobile = gl_compatibility.")

# ------------------------------------------------------------- main scene
func _check_main_scene() -> void:
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.is_empty():
		_add(SEV_ERROR, "main_scene.missing",
			"Chưa đặt main scene (application/run/main_scene).",
			"Đặt main scene trong Project Settings > Application > Run.")
	elif not ResourceLoader.exists(main):
		_add(SEV_ERROR, "main_scene.not_found",
			"Main scene '%s' không tồn tại." % main,
			"Kiểm tra lại đường dẫn main scene.")

# ----------------------------------------------------------------- preset
func _check_preset(cfg: H5Config) -> void:
	var presets := _read_export_presets()
	if presets.is_empty():
		_add(SEV_ERROR, "preset.missing",
			"Không tìm thấy export_presets.cfg hoặc không có preset nào.",
			"Tạo preset Web trong Project > Export.")
		return

	var found := false
	for p in presets:
		if p.get("name", "") != cfg.target_preset:
			continue
		found = true
		if p.get("platform", "") != "Web":
			_add(SEV_ERROR, "preset.platform",
				"Preset '%s' không phải platform Web (là '%s')." % [cfg.target_preset, p.get("platform", "")],
				"Chọn đúng preset Web.")
		if bool(p.get("variant/thread_support", false)):
			_add(SEV_ERROR, "preset.threads",
				"Preset '%s' đang BẬT thread support." % cfg.target_preset,
				"MVP dùng web single-thread. Tắt 'Thread Support' trong preset.")
		if bool(p.get("variant/extensions_support", false)):
			_add(SEV_ERROR, "preset.extensions",
				"Preset '%s' đang BẬT extensions support." % cfg.target_preset,
				"MVP không dùng GDExtension web. Tắt 'Extensions Support'.")
		if bool(p.get("progressive_web_app/enabled", false)):
			_add(SEV_WARNING, "preset.pwa",
				"Preset '%s' đang bật PWA/service worker." % cfg.target_preset,
				"PWA nằm ngoài MVP. Tắt để tránh thêm lớp cache khó gỡ.")
		if str(p.get("html/custom_html_shell", "")).is_empty():
			_add(SEV_INFO, "preset.shell",
				"Preset '%s' chưa dùng custom HTML shell." % cfg.target_preset,
				"Trỏ html/custom_html_shell vào tools/shell/h5-shell.html để có loading/error/retry UI.")

	if not found:
		_add(SEV_ERROR, "preset.not_found",
			"Không có preset tên '%s'." % cfg.target_preset,
			"Tạo preset Web tên đúng hoặc sửa trường target_preset trong H5 config.")

# -------------------------------------------------------------- templates
## F05/F06: debug và release phải là MỘT cặp (cùng nhãn, cùng revision với editor)
## và preset không được phụ thuộc đường dẫn máy developer.
## Khuyến nghị: để TRỐNG custom_template và cài cặp template vào thư mục
## export_templates của editor (tools/build/install-templates.ps1, hoặc gói portable),
## kèm h5_manifest.json để đối chiếu SHA256 trước mỗi lần export.
func _check_templates(cfg: H5Config, edit = null) -> void:
	var presets := _read_export_presets()
	for p in presets:
		if p.get("name", "") != cfg.target_preset:
			continue
		var dbg := str(p.get("custom_template/debug", ""))
		var rel := str(p.get("custom_template/release", ""))
		if dbg.is_empty() != rel.is_empty():
			_add(SEV_ERROR, "template.mixed",
				"Preset '%s' chỉ đặt custom template cho MỘT flavor; flavor còn lại sẽ lấy template đã cài, có thể khác nhãn/revision." % cfg.target_preset,
				"Để trống CẢ HAI custom_template (dùng cặp đã cài) hoặc trỏ cả hai về cùng một cặp.")
			return
		if dbg.is_empty():
			_check_installed_templates(edit)
		else:
			_check_custom_templates(dbg, rel)
		return

func _check_custom_templates(dbg: String, rel: String) -> void:
	if not FileAccess.file_exists(dbg):
		_add(SEV_ERROR, "template.debug_missing",
			"custom_template/debug không tồn tại: %s" % dbg, "Kiểm tra lại đường dẫn template debug.")
	if not FileAccess.file_exists(rel):
		_add(SEV_ERROR, "template.release_missing",
			"custom_template/release không tồn tại: %s" % rel, "Kiểm tra lại đường dẫn template release.")
	if dbg == rel:
		_add(SEV_ERROR, "template.same_file",
			"custom_template/debug và release trỏ CÙNG một file.",
			"Debug và release phải là hai ZIP khác nhau.")
		return
	if dbg.is_absolute_path() or rel.is_absolute_path():
		_add(SEV_WARNING, "template.absolute_path",
			"custom_template dùng đường dẫn tuyệt đối — project sẽ hỏng export khi chuyển sang máy khác.",
			"Để trống custom_template và cài cặp template bằng tools/build/install-templates.ps1.")
	# build-web.ps1 ghi manifest.json cạnh mỗi ZIP: dùng để bắt cặp lệch nhãn/revision.
	var md := _read_json(dbg.get_base_dir().path_join("manifest.json"))
	var mr := _read_json(rel.get_base_dir().path_join("manifest.json"))
	if md.is_empty() or mr.is_empty():
		_add(SEV_WARNING, "template.unverified",
			"Không có manifest.json cạnh template — không xác minh được debug/release là một cặp.",
			"Dùng template build bằng tools/build/build-web.ps1 hoặc cặp đã cài.")
		return
	var sd := str(md.get("sourceSha", ""))
	var sr := str(mr.get("sourceSha", ""))
	var ld := str(md.get("label", ""))
	var lr := str(mr.get("label", ""))
	if sd != sr or ld != lr:
		_add(SEV_ERROR, "template.pair_mismatch",
			"debug ('%s' @ %s) và release ('%s' @ %s) KHÔNG cùng một cặp." % [ld, sd.left(10), lr, sr.left(10)],
			"Trỏ cả hai flavor về cùng một nhãn build.")
	_check_engine_revision(sd)

func _check_installed_templates(edit) -> void:
	var before := _issues.size()
	var dir := _templates_dir(edit)
	var d := dir.path_join("web_nothreads_debug.zip")
	var r := dir.path_join("web_nothreads_release.zip")
	if not FileAccess.file_exists(d) or not FileAccess.file_exists(r):
		_add(SEV_ERROR, "template.not_installed",
			"Chưa cài đủ cặp Web template tại %s" % dir,
			"Chạy tools/build/install-templates.ps1, hoặc dùng gói portable có sẵn template.")
		return
	var mf := _read_json(dir.path_join("h5_manifest.json"))
	if mf.is_empty():
		_add(SEV_WARNING, "template.no_manifest",
			"Thư mục template không có h5_manifest.json hợp lệ — không xác minh được debug/release cùng revision.",
			"Cài lại bằng tools/build/install-templates.ps1.")
		return
	var tpl: Dictionary = mf.get("templates", {})
	var want_d := str(tpl.get("debug", {}).get("sha256", "")).to_lower()
	var want_r := str(tpl.get("release", {}).get("sha256", "")).to_lower()
	var got_d := FileAccess.get_sha256(d).to_lower()
	var got_r := FileAccess.get_sha256(r).to_lower()
	if got_d != want_d:
		_add(SEV_ERROR, "template.hash_mismatch",
			"web_nothreads_debug.zip KHÔNG khớp manifest (file bị đổi/thay thế).",
			"Cài lại cặp template bằng install-templates.ps1.")
	if got_r != want_r:
		_add(SEV_ERROR, "template.hash_mismatch",
			"web_nothreads_release.zip KHÔNG khớp manifest (file bị đổi/thay thế).",
			"Cài lại cặp template bằng install-templates.ps1.")
	if got_d == got_r:
		_add(SEV_ERROR, "template.same_file",
			"Template debug và release giống hệt nhau — không phải hai flavor.",
			"Cài lại cặp template bằng install-templates.ps1.")
	var src: Dictionary = mf.get("source", {})
	_check_engine_revision(str(src.get("upstreamSha", "")))
	if _issues.size() == before:
		_add(SEV_INFO, "template.ok",
			"Cặp template '%s' @ %s, SHA256 khớp manifest." % [str(mf.get("label", "?")), str(src.get("upstreamSha", "")).left(10)])

func _check_engine_revision(sha: String) -> void:
	var eng := str(Engine.get_version_info().get("hash", ""))
	if sha.is_empty() or eng.is_empty():
		return
	if sha != eng:
		_add(SEV_ERROR, "template.engine_mismatch",
			"Template build từ revision %s nhưng editor là %s." % [sha.left(10), eng.left(10)],
			"Dùng cặp template build từ cùng revision với editor.")

## Cùng quy tắc với EditorPaths: self-contained (._sc_/_sc_ cạnh EXE) -> editor_data/;
## ngược lại -> <data dir>/GodotH5/. Thêm thư mục version như GODOT_VERSION_FULL_CONFIG.
func _templates_dir(edit) -> String:
	var base := ""
	# EditorPaths.get_export_templates_dir() KHONG duoc bind cho script; chi co get_data_dir().
	# Cung quy tac C++: export_templates_dir = data_dir/export_templates (editor_paths.cpp:75).
	if edit != null and edit.has_method("get_editor_paths"):
		base = edit.get_editor_paths().get_data_dir().path_join("export_templates")
	if base.is_empty():
		var exe_dir := OS.get_executable_path().get_base_dir()
		if FileAccess.file_exists(exe_dir.path_join("._sc_")) or FileAccess.file_exists(exe_dir.path_join("_sc_")):
			base = exe_dir.path_join("editor_data/export_templates")
		else:
			base = OS.get_data_dir().path_join("GodotH5/export_templates")
	var vi := Engine.get_version_info()
	var ver := "%d.%d" % [int(vi["major"]), int(vi["minor"])]
	if int(vi["patch"]) != 0:
		ver += ".%d" % int(vi["patch"])
	ver += "." + str(vi["status"])
	return base.path_join(ver)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

# ----------------------------------------------------------------- assets
func _check_assets(cfg: H5Config) -> void:
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if not main.is_empty() and not ResourceLoader.exists(main):
		pass # đã báo ở _check_main_scene
	if not cfg.icon_path.is_empty() and not FileAccess.file_exists(cfg.icon_path):
		_add(SEV_WARNING, "asset.icon_missing",
			"Icon không tồn tại: %s" % cfg.icon_path, "Sửa icon_path hoặc thêm file.")

	var textures := _scan_files("res://", ["png", "jpg", "jpeg", "webp", "svg"], 400)
	for t in textures:
		var img := _texture_size(t)
		if img.x > cfg.texture_max_dimension or img.y > cfg.texture_max_dimension:
			_add(SEV_WARNING, "asset.texture_large",
				"Texture %s có kích thước %dx%d, vượt ngưỡng %d." % [t, img.x, img.y, cfg.texture_max_dimension],
				"Giảm kích thước hoặc nâng ngưỡng nếu có chủ đích (mobile VRAM hạn chế).")

	var audios := _scan_files("res://", ["wav", "ogg", "mp3"], 400)
	for a in audios:
		var kb := _file_size_kb(a)
		if kb > cfg.audio_max_size_kb:
			_add(SEV_WARNING, "asset.audio_large",
				"Audio %s nặng %d KB, vượt ngưỡng %d KB." % [a, kb, cfg.audio_max_size_kb],
				"Nén lại hoặc nâng ngưỡng nếu có chủ đích.")

# ------------------------------------------------------------------ input
func _check_input(cfg: H5Config) -> void:
	var actions := _input_actions()
	for a in cfg.require_actions:
		if BUILTIN_ACTIONS.has(a):
			continue  # action dựng sẵn của Godot, không cần khai báo
		if not actions.has(a):
			_add(SEV_WARNING, "input.action_missing",
				"Action '%s' chưa được khai báo trong Input Map." % a,
				"Thêm action trong Project Settings > Input Map.")

	if cfg.orientation == "any":
		_add(SEV_INFO, "input.orientation_any",
			"Orientation = 'any' — game phải tự xử lý cả portrait và landscape.",
			"Kiểm tra safe-area và resize ở cả hai hướng.")

# -------------------------------------------------------------- web APIs
func _check_unsupported_apis() -> void:
	var hits := _grep_scripts(WEB_UNSUPPORTED_APIS)
	for h in hits:
		_add(SEV_WARNING, "api.web_unsupported",
			"%s dùng '%s' — API này không có (hoặc không đáng tin) trên web." % [h.file, h.api],
			"Bọc trong kiểm tra nền tảng hoặc thay bằng API tương đương web.")

# ------------------------------------------------------------- resolution
func _check_resolution(cfg: H5Config) -> void:
	if cfg.design_resolution.x <= 0 or cfg.design_resolution.y <= 0:
		_add(SEV_ERROR, "display.resolution",
			"design_resolution không hợp lệ: %s" % str(cfg.design_resolution),
			"Đặt độ phân giải thiết kế dương, ví dụ 720x1280.")

# ------------------------------------------------------------- helpers
func _read_export_presets() -> Array[Dictionary]:
	## export_presets.cfg có HAI tầng:
	##   [preset.0]          -> name, platform, runnable, export_path, ...
	##   [preset.0.options]  -> custom_template/*, variant/*, html/*, progressive_web_app/*, ...
	## Phải GỘP hai tầng, nếu không mọi kiểm tra option sẽ âm thầm PASS.
	## (Lỗi này bị bắt khi chạy thử: preset.shell vẫn báo thiếu dù đã set.)
	var out: Array[Dictionary] = []
	var path := "res://export_presets.cfg"
	if not FileAccess.file_exists(path):
		return out
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return out

	var sections := cf.get_sections()
	for section in sections:
		# Chỉ lấy tầng gốc "preset.<N>", bỏ qua "preset.<N>.options" và các hậu tố khác.
		if not section.begins_with("preset."):
			continue
		var rest := section.substr("preset.".length())
		if rest.is_empty() or not rest.is_valid_int():
			continue

		var d := {}
		for key in cf.get_section_keys(section):
			d[key] = cf.get_value(section, key)

		# Gộp tầng options.
		var opt_section := section + ".options"
		if sections.has(opt_section):
			for key in cf.get_section_keys(opt_section):
				d[key] = cf.get_value(opt_section, key)

		out.append(d)
	return out

func _input_actions() -> PackedStringArray:
	var out := PackedStringArray()
	var cf := ConfigFile.new()
	if cf.load("res://project.godot") != OK:
		return out
	if not cf.has_section("input"):
		return out
	for key in cf.get_section_keys("input"):
		out.append(key)
	return out

func _scan_files(root: String, exts: Array, limit: int) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[String] = [root]
	while not stack.is_empty() and out.size() < limit:
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("."):
				name = dir.get_next()
				continue
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				if name != "addons":
					stack.append(full)
			else:
				var ext := name.get_extension().to_lower()
				if exts.has(ext):
					out.append(full)
			name = dir.get_next()
		dir.list_dir_end()
	return out

func _texture_size(path: String) -> Vector2i:
	var img := Image.new()
	var err := ERR_UNAVAILABLE
	if path.get_extension().to_lower() == "svg":
		return Vector2i(0, 0) # SVG là vector, không tính theo px
	err = img.load(path)
	if err != OK:
		return Vector2i(0, 0)
	return img.get_size()

func _file_size_kb(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return int(n / 1024)

func _grep_scripts(apis: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var files := _scan_files("res://", ["gd"], 500)
	for f in files:
		var fh := FileAccess.open(f, FileAccess.READ)
		if fh == null:
			continue
		var text := fh.get_as_text()
		fh.close()
		for api in apis:
			if text.contains(api):
				hits.append({ "file": f, "api": api })
	return hits
