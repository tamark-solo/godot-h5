@tool
extends EditorExportPlugin
## E07 — Hook export cho H5.
##
## GIỚI HẠN ĐÃ XÁC MINH TỪ SOURCE (editor/export/editor_export_plugin.h):
##   - `_export_begin` trả về void -> EditorExportPlugin KHÔNG có API hủy export.
##   - Vì vậy "chặn export" ở đường GUI chỉ ở mức CẢNH BÁO qua
##     `_get_export_option_warning` (hiện trong hộp thoại Export).
##   - Đường CHẶN THẬT do luồng Browser Preview / Release Export tự kiểm soát
##     (xem G04): validate trước, export sau, fail thì không mở output.
## Không hứa phân tích mọi API native.

const H5ConfigScript := preload("res://addons/h5/h5_config.gd")
const H5ValidatorScript := preload("res://addons/h5/h5_validator.gd")

const CONFIG_PATH := "res://h5_config.tres"

var _last_issues: Array[Dictionary] = []
var _build_id: String = ""
var _export_path: String = ""
var _is_debug: bool = false

func _get_name() -> String:
	return "H5Preflight"

func _is_web(platform: EditorExportPlatform) -> bool:
	return platform != null and platform.get_name() == "Web"

func _load_config() -> H5Config:
	if ResourceLoader.exists(CONFIG_PATH):
		var res := ResourceLoader.load(CONFIG_PATH)
		if res is H5Config:
			return res
	return H5Config.new()

func _run_validation() -> Array[Dictionary]:
	var cfg := _load_config()
	var v := H5ValidatorScript.new()
	_last_issues = v.run(cfg, EditorInterface)
	return _last_issues

func _error_count() -> int:
	var n := 0
	for i in _last_issues:
		if i.severity == "error":
			n += 1
	return n

# --- Cảnh báo hiện trong hộp thoại Export (đường GUI) ---
func _get_export_option_warning(platform: EditorExportPlatform, option: String) -> String:
	if not _is_web(platform):
		return ""
	var issues := _run_validation()
	var errors: Array[String] = []
	for i in issues:
		if i.severity == "error":
			errors.append(i.message)
	if errors.is_empty():
		return ""
	return "H5 preflight: %d lỗi — %s (xem dock H5 để biết chi tiết)" % [errors.size(), errors[0]]

# --- Bắt đầu export: chạy preflight, sinh build ID ---
func _export_begin(features: PackedStringArray, is_debug: bool, path: String, _flags: int) -> void:
	if not features.has("web"):
		return

	_is_debug = is_debug
	_export_path = path

	var vi := Engine.get_version_info()
	var engine_hash := str(vi.get("hash", "unknown"))
	if engine_hash.length() > 12:
		engine_hash = engine_hash.substr(0, 12)
	var flavor := "debug" if is_debug else "release"
	_build_id = "%s-%s-%s" % [engine_hash, flavor, Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "-")]

	var issues := _run_validation()
	var errs := _error_count()
	var warns := 0
	for i in issues:
		if i.severity == "warning":
			warns += 1

	print_rich("[b]H5 export[/b] build_id=%s flavor=%s" % [_build_id, flavor])
	print("H5 export: %d error, %d warning" % [errs, warns])
	for i in issues:
		var line := "  [%s] %s — %s" % [str(i.severity).to_upper(), i.code, i.message]
		if i.severity == "error":
			push_error(line)
		elif i.severity == "warning":
			push_warning(line)
		else:
			print(line)

	var cfg := _load_config()
	if errs > 0 and cfg.block_export_on_error:
		push_error("H5 preflight có %d lỗi. Export GUI vẫn tiếp tục vì EditorExportPlugin không có API hủy; " % errs
			+ "hãy dùng Browser Preview / Release Export (đã chặn thật) hoặc sửa lỗi rồi export lại.")

# --- Kết thúc export: ghi build ID cạnh artifact ---
func _export_end() -> void:
	if _build_id.is_empty() or _export_path.is_empty():
		return
	var dir := _export_path.get_base_dir()
	if dir.is_empty():
		return
	var out := {
		"build_id": _build_id,
		"flavor": "debug" if _is_debug else "release",
		"engine_version": Engine.get_version_info().get("string", ""),
		"engine_hash": Engine.get_version_info().get("hash", ""),
		"exported_at": Time.get_datetime_string_from_system(true, true),
		"errors": _error_count(),
		"issues": _last_issues,
	}
	var f := FileAccess.open(dir.path_join("h5_build_id.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("H5 export: build ID ghi vào %s" % dir.path_join("h5_build_id.json"))
