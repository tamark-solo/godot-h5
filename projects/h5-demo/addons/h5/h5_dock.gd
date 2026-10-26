@tool
extends VBoxContainer
## E07 — H5 dock: chỉnh H5 config (có UndoRedo) và chạy preflight validator.

const H5ConfigScript := preload("res://addons/h5/h5_config.gd")
const H5ValidatorScript := preload("res://addons/h5/h5_validator.gd")
const H5PreviewRunnerScript := preload("res://addons/h5/h5_preview_runner.gd")

const CONFIG_PATH := "res://h5_config.tres"

var _cfg: H5Config
var _undo: EditorUndoRedoManager

var _title_edit: LineEdit
var _icon_edit: LineEdit
var _res_x: SpinBox
var _res_y: SpinBox
var _orientation: OptionButton
var _stretch_mode: OptionButton
var _stretch_aspect: OptionButton
var _preset_edit: LineEdit
var _input_profile: LineEdit
var _tex_desktop: OptionButton
var _tex_mobile: OptionButton
var _block_on_error: CheckBox
var _results: RichTextLabel
var _status: Label

# --- Browser Preview (G04 trong dock) ---
var _runner: Node
var _pv_btn: Button
var _pv_stop_btn: Button
var _pv_copy_btn: Button
var _pv_open_btn: Button
var _pv_port: SpinBox
var _pv_status: Label
var _pv_log: RichTextLabel

const ORIENTATIONS := ["portrait", "landscape", "any"]
const STRETCH_MODES := ["canvas_items", "viewport", "disabled"]
const STRETCH_ASPECTS := ["expand", "keep", "keep_width", "keep_height"]
const TEX_POLICIES := ["vram_compressed", "lossless", "lossy"]

func _init() -> void:
	name = "H5"
	custom_minimum_size = Vector2(280, 0)

func _ready() -> void:
	_undo = EditorInterface.get_editor_undo_redo()
	_build_ui()
	_reload_config()
	_build_preview_ui()

## Tắt plugin / đóng editor: dừng server + export đang chạy (G05: không sót process).
func _exit_tree() -> void:
	if _runner != null:
		_runner.shutdown()

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	var title := Label.new()
	title.text = "H5 Platform"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)

	_title_edit = _add_line(grid, "Tiêu đề game")
	_icon_edit = _add_line(grid, "Icon (res://)")
	_res_x = _add_spin(grid, "Rộng thiết kế", 1, 8192)
	_res_y = _add_spin(grid, "Cao thiết kế", 1, 8192)
	_orientation = _add_option(grid, "Orientation", ORIENTATIONS)
	_stretch_mode = _add_option(grid, "Stretch mode", STRETCH_MODES)
	_stretch_aspect = _add_option(grid, "Stretch aspect", STRETCH_ASPECTS)
	_preset_edit = _add_line(grid, "Preset export")
	_input_profile = _add_line(grid, "Input profile")
	_tex_desktop = _add_option(grid, "Texture desktop", TEX_POLICIES)
	_tex_mobile = _add_option(grid, "Texture mobile", TEX_POLICIES)

	_block_on_error = CheckBox.new()
	_block_on_error.text = "Chặn export khi có lỗi"
	_block_on_error.toggled.connect(func(v: bool) -> void: _commit("block_export_on_error", v))
	add_child(_block_on_error)

	add_child(HSeparator.new())

	var row := HBoxContainer.new()
	add_child(row)

	var save_btn := Button.new()
	save_btn.text = "Lưu config"
	save_btn.pressed.connect(_save_config)
	row.add_child(save_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Kiểm tra"
	validate_btn.pressed.connect(_validate)
	row.add_child(validate_btn)

	var create_btn := Button.new()
	create_btn.text = "Tạo config"
	create_btn.pressed.connect(_create_config)
	row.add_child(create_btn)

	_results = RichTextLabel.new()
	_results.bbcode_enabled = true
	_results.custom_minimum_size = Vector2(0, 220)
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.scroll_active = true
	add_child(_results)

	# Kết nối commit khi rời ô / xác nhận.
	_title_edit.text_submitted.connect(func(_t: String) -> void: _commit("game_title", _title_edit.text))
	_title_edit.focus_exited.connect(func() -> void: _commit("game_title", _title_edit.text))
	_icon_edit.text_submitted.connect(func(_t: String) -> void: _commit("icon_path", _icon_edit.text))
	_icon_edit.focus_exited.connect(func() -> void: _commit("icon_path", _icon_edit.text))
	_preset_edit.text_submitted.connect(func(_t: String) -> void: _commit("target_preset", _preset_edit.text))
	_preset_edit.focus_exited.connect(func() -> void: _commit("target_preset", _preset_edit.text))
	_input_profile.text_submitted.connect(func(_t: String) -> void: _commit("input_profile", _input_profile.text))
	_input_profile.focus_exited.connect(func() -> void: _commit("input_profile", _input_profile.text))

	_orientation.item_selected.connect(func(i: int) -> void: _commit("orientation", ORIENTATIONS[i]))
	_stretch_mode.item_selected.connect(func(i: int) -> void: _commit("stretch_mode", STRETCH_MODES[i]))
	_stretch_aspect.item_selected.connect(func(i: int) -> void: _commit("stretch_aspect", STRETCH_ASPECTS[i]))
	_tex_desktop.item_selected.connect(func(i: int) -> void: _commit("texture_policy_desktop", TEX_POLICIES[i]))
	_tex_mobile.item_selected.connect(func(i: int) -> void: _commit("texture_policy_mobile", TEX_POLICIES[i]))
	_res_x.value_changed.connect(func(_v: float) -> void: _commit("design_resolution", Vector2i(int(_res_x.value), int(_res_y.value))))
	_res_y.value_changed.connect(func(_v: float) -> void: _commit("design_resolution", Vector2i(int(_res_x.value), int(_res_y.value))))

func _add_line(grid: GridContainer, label: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	grid.add_child(l)
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(e)
	return e

func _add_spin(grid: GridContainer, label: String, lo: int, hi: int) -> SpinBox:
	var l := Label.new()
	l.text = label
	grid.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(s)
	return s

func _add_option(grid: GridContainer, label: String, items: Array) -> OptionButton:
	var l := Label.new()
	l.text = label
	grid.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(o)
	return o

# -------------------------------------------------------------- config
func _reload_config() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		var res := ResourceLoader.load(CONFIG_PATH)
		if res is H5Config:
			_cfg = res
	if _cfg == null:
		_cfg = H5Config.new()
		_status.text = "Chưa có h5_config.tres — bấm 'Tạo config'."
	else:
		_status.text = "Config: %s (schema v%d)" % [CONFIG_PATH, _cfg.config_version]
	_refresh_fields()

func _refresh_fields() -> void:
	if _cfg == null:
		return
	_title_edit.text = _cfg.game_title
	_icon_edit.text = _cfg.icon_path
	# set_value_no_signal: gán .value sẽ phát value_changed -> _commit() với ô kia
	# còn giá trị cũ (min=1) -> từng lưu design_resolution = (720, 1).
	_res_x.set_value_no_signal(_cfg.design_resolution.x)
	_res_y.set_value_no_signal(_cfg.design_resolution.y)
	_orientation.selected = maxi(0, ORIENTATIONS.find(_cfg.orientation))
	_stretch_mode.selected = maxi(0, STRETCH_MODES.find(_cfg.stretch_mode))
	_stretch_aspect.selected = maxi(0, STRETCH_ASPECTS.find(_cfg.stretch_aspect))
	_preset_edit.text = _cfg.target_preset
	_input_profile.text = _cfg.input_profile
	_tex_desktop.selected = maxi(0, TEX_POLICIES.find(_cfg.texture_policy_desktop))
	_tex_mobile.selected = maxi(0, TEX_POLICIES.find(_cfg.texture_policy_mobile))
	_block_on_error.set_pressed_no_signal(_cfg.block_export_on_error)

func _create_config() -> void:
	if _cfg == null:
		_cfg = H5Config.new()
	_save_config()
	_reload_config()

func _save_config() -> void:
	if _cfg == null:
		return
	var err := ResourceSaver.save(_cfg, CONFIG_PATH)
	if err != OK:
		_status.text = "Lỗi lưu config: %s" % error_string(err)
		push_error("H5: không lưu được %s (%s)" % [CONFIG_PATH, error_string(err)])
		return
	_status.text = "Đã lưu %s (schema v%d)" % [CONFIG_PATH, _cfg.config_version]
	EditorInterface.get_resource_filesystem().scan()

## Ghi thuộc tính config qua UndoRedo để Ctrl+Z hoạt động trong editor.
func _commit(prop: String, value: Variant) -> void:
	if _cfg == null:
		return
	if _cfg.get(prop) == value:
		return
	_undo.create_action("H5: đổi %s" % prop)
	_undo.add_do_property(_cfg, prop, value)
	_undo.add_undo_property(_cfg, prop, _cfg.get(prop))
	_undo.add_do_method(self, "_after_commit")
	_undo.add_undo_method(self, "_after_commit")
	_undo.commit_action()

func _after_commit() -> void:
	_save_config()
	_refresh_fields()

# ------------------------------------------------------------ validate
func _validate() -> void:
	if _cfg == null:
		_reload_config()
	var v := H5ValidatorScript.new()
	var issues := v.run(_cfg, EditorInterface)
	_render_issues(issues)

func _render_issues(issues: Array[Dictionary]) -> void:
	_results.clear()
	if issues.is_empty():
		_results.append_text("[color=#7ddc7d]Không có vấn đề nào.[/color]\n")
		return
	var errs := 0
	var warns := 0
	var infos := 0
	for i in issues:
		match i.severity:
			"error": errs += 1
			"warning": warns += 1
			_: infos += 1
	_results.append_text("[b]%d lỗi · %d cảnh báo · %d thông tin[/b]\n\n" % [errs, warns, infos])
	for i in issues:
		var color := "#ff8a7a"
		var tag := "LỖI"
		if i.severity == "warning":
			color = "#ffd479"
			tag = "CẢNH BÁO"
		elif i.severity == "info":
			color = "#8fb8ff"
			tag = "INFO"
		_results.append_text("[color=%s][b]%s[/b][/color] [i]%s[/i]\n%s\n" % [color, tag, i.code, i.message])
		if not str(i.get("hint", "")).is_empty():
			_results.append_text("   [color=#9aa7b8]→ %s[/color]\n" % i.hint)
		_results.append_text("\n")

# ------------------------------------------------------- browser preview
func _build_preview_ui() -> void:
	_runner = H5PreviewRunnerScript.new()
	_runner.name = "PreviewRunner"
	add_child(_runner)
	var es := EditorInterface.get_editor_settings()
	_runner.port = int(es.get_project_metadata("h5", "preview_port", H5PreviewRunnerScript.DEFAULT_PORT))

	add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Browser Preview"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	var row1 := HBoxContainer.new()
	add_child(row1)
	_pv_btn = Button.new()
	_pv_btn.text = "Preview trên trình duyệt"
	_pv_btn.tooltip_text = "Lưu scene → preflight → export debug MỚI → serve 127.0.0.1 → xác minh → mở trình duyệt."
	_pv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pv_btn.pressed.connect(func() -> void: _runner.start(true))
	row1.add_child(_pv_btn)
	var port_lbl := Label.new()
	port_lbl.text = "Port"
	row1.add_child(port_lbl)
	_pv_port = SpinBox.new()
	_pv_port.min_value = 1024
	_pv_port.max_value = 65535
	_pv_port.step = 1
	_pv_port.set_value_no_signal(_runner.port)
	_pv_port.value_changed.connect(_on_port_changed)
	row1.add_child(_pv_port)

	var row2 := HBoxContainer.new()
	add_child(row2)
	_pv_open_btn = Button.new()
	_pv_open_btn.text = "Mở lại"
	_pv_open_btn.pressed.connect(func() -> void: OS.shell_open(_runner.last_url))
	row2.add_child(_pv_open_btn)
	_pv_copy_btn = Button.new()
	_pv_copy_btn.text = "Copy URL"
	_pv_copy_btn.pressed.connect(func() -> void: DisplayServer.clipboard_set(_runner.last_url))
	row2.add_child(_pv_copy_btn)
	_pv_stop_btn = Button.new()
	_pv_stop_btn.text = "Dừng server"
	_pv_stop_btn.pressed.connect(func() -> void: _runner.stop_server())
	row2.add_child(_pv_stop_btn)

	_pv_status = Label.new()
	_pv_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_pv_status)

	_pv_log = RichTextLabel.new()
	_pv_log.bbcode_enabled = true
	_pv_log.scroll_following = true
	_pv_log.custom_minimum_size = Vector2(0, 140)
	_pv_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_pv_log)

	_runner.state_changed.connect(_refresh_preview_ui)
	_runner.log_message.connect(_on_preview_log)
	_runner.finished.connect(func(_ok: bool, _m: String) -> void: _refresh_preview_ui())
	_refresh_preview_ui()

func _on_port_changed(v: float) -> void:
	if _runner.server.is_running():
		_runner.stop_server()
	_runner.port = int(v)
	EditorInterface.get_editor_settings().set_project_metadata("h5", "preview_port", int(v))
	_refresh_preview_ui()

func _on_preview_log(text: String, level: String) -> void:
	var color := "#c8d0dc"
	if level == "error":
		color = "#ff8a7a"
	elif level == "warning":
		color = "#ffd479"
	_pv_log.append_text("[color=%s]%s[/color]\n" % [color, text.replace("[", "[lb]")])

func _refresh_preview_ui() -> void:
	if _runner == null or _pv_btn == null:
		return
	var busy: bool = _runner.is_busy()
	var serving: bool = _runner.server.is_running()
	var has_url: bool = serving and not _runner.last_url.is_empty()
	_pv_btn.disabled = busy
	_pv_btn.text = "Đang chạy…" if busy else ("Re-export + mở lại" if serving else "Preview trên trình duyệt")
	_pv_port.editable = not busy
	_pv_stop_btn.disabled = busy or not serving
	_pv_open_btn.disabled = busy or not has_url
	_pv_copy_btn.disabled = busy or not has_url
	if busy:
		_pv_status.text = "Đang export…"
	elif has_url:
		var s := "Đang phục vụ %s" % _runner.last_url
		if not _runner.last_build_id.is_empty():
			s += "\nbuild: %s" % _runner.last_build_id
		if _runner.stale:
			s += "\n⚠ Bản preview đã cũ (có file sửa trong lúc export) — bấm Re-export."
		_pv_status.text = s
	else:
		_pv_status.text = "Server đang tắt (port %d)." % _runner.port
