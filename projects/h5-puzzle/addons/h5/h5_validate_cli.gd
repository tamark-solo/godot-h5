extends SceneTree
## E07 / G04 — Chạy H5 preflight validator từ CLI (headless).
##
## Dùng:
##   godot --headless --path <project> --script res://addons/h5/h5_validate_cli.gd
##
## Exit code:
##   0 = không có lỗi (có thể còn warning/info)
##   1 = có ít nhất một lỗi severity=error
##
## Đây là "chặn thật" cho luồng Browser Preview / Release Export:
## EditorExportPlugin không có API hủy export, nên preflight phải chạy TRƯỚC export.

const CONFIG_PATH := "res://h5_config.tres"

func _initialize() -> void:
	var cfg: H5Config = null
	if ResourceLoader.exists(CONFIG_PATH):
		var res := ResourceLoader.load(CONFIG_PATH)
		if res is H5Config:
			cfg = res
	if cfg == null:
		print("H5 preflight: chưa có %s — dùng cấu hình mặc định." % CONFIG_PATH)
		cfg = H5Config.new()

	var v := H5Validator.new()
	var issues := v.run(cfg, null)

	var errs := 0
	var warns := 0
	var infos := 0
	for i in issues:
		match i.severity:
			"error": errs += 1
			"warning": warns += 1
			_: infos += 1

	print("")
	print("=== H5 PREFLIGHT ===")
	print("project     : %s" % ProjectSettings.globalize_path("res://"))
	print("config      : %s (schema v%d)" % [CONFIG_PATH, cfg.config_version])
	print("kết quả     : %d lỗi · %d cảnh báo · %d thông tin" % [errs, warns, infos])
	print("")

	for i in issues:
		var tag := str(i.severity).to_upper()
		print("[%s] %s" % [tag, i.code])
		print("    %s" % i.message)
		if not str(i.get("hint", "")).is_empty():
			print("    → %s" % i.hint)
		print("")

	if errs == 0:
		print("PREFLIGHT: PASS")
		quit(0)
	else:
		print("PREFLIGHT: FAIL (%d lỗi)" % errs)
		quit(1)
