@tool
extends EditorPlugin
## TẠM — selftest cho Browser Preview (không ship, chỉ nằm trong tools/test).
## Mode (env H5_SELFTEST_MODE):
##   normal | touch | busyport : như trước (headless)
##   serve  : preview -> giữ server, bấm Play (play_main_scene), chờ file H5_SELFTEST_DONE rồi thoát
##   toggle : preview -> tắt/bật plugin 4 lần, kiểm tra port nhả + không nhân dock

const ServerScript := preload("res://addons/h5/h5_preview_server.gd")

var _runner: Node
var _results := {}
var _phase := 0
var _t := 0
var _mode := ""
var _wait := 0
var _cycle := 0
var _cycles: Array = []

func _enter_tree() -> void:
	_mode = OS.get_environment("H5_SELFTEST_MODE")
	set_process(true)

func _find_runner(n: Node) -> Node:
	if n.name == "PreviewRunner" and n.has_method("start") and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var r := _find_runner(c)
		if r != null:
			return r
	return null

func _count_docks(n: Node) -> int:
	var c := 0
	if n.name == "PreviewRunner" and not n.is_queued_for_deletion():
		c += 1
	for ch in n.get_children():
		c += _count_docks(ch)
	return c

func _write(res: Dictionary) -> void:
	var f := FileAccess.open(OS.get_environment("H5_SELFTEST_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()

func _process(_d: float) -> void:
	_t += 1
	match _phase:
		0:
			if _t < 30:
				return
			_runner = _find_runner(EditorInterface.get_base_control())
			if _runner == null:
				_done({"error": "no runner"})
				return
			if _mode == "busyport":
				_runner.port = int(OS.get_environment("H5_SELFTEST_PORT"))
			_runner.log_message.connect(func(t, l): print("[runner/%s] %s" % [l, t]))
			_runner.finished.connect(_on_finished)
			_results["start_ok"] = _runner.start(false)
			_results["second_start_rejected"] = not _runner.start(false)
			_phase = 1
		1:
			if _mode == "touch" and _runner.state == 2 and not _results.has("touched"):
				OS.delay_msec(1500)
				var f := FileAccess.open("res://scripts/game_state.gd", FileAccess.READ_WRITE)
				f.seek_end(); f.store_string("\n"); f.close()
				_results["touched"] = true
		10: # serve: chờ Play lên
			_wait += 1
			if _wait == 120:
				_results["playing_after_play"] = EditorInterface.is_playing_scene()
				_results["server_running_while_playing"] = _runner.server.is_running()
				_write(_results)
				print("[selftest] READY " + _runner.last_url)
				_phase = 11
		11: # serve: đợi tín hiệu từ bên ngoài
			var done := OS.get_environment("H5_SELFTEST_DONE")
			if FileAccess.file_exists(done):
				_results["served_total"] = _runner.server.get_served_count()
				_results["still_playing_at_end"] = EditorInterface.is_playing_scene()
				if EditorInterface.is_playing_scene():
					EditorInterface.stop_playing_scene()
				_done(_results)
		20: # toggle: tắt plugin
			EditorInterface.set_plugin_enabled("h5", false)
			_wait = 0
			_phase = 21
		21:
			_wait += 1
			if _wait < 10:
				return
			var rec := {
				"cycle": _cycle,
				"docks_when_off": _count_docks(EditorInterface.get_base_control()),
				"port_free_when_off": not ServerScript.is_port_in_use(_results.get("port", 8070)),
			}
			_cycles.append(rec)
			EditorInterface.set_plugin_enabled("h5", true)
			_wait = 0
			_phase = 22
		22:
			_wait += 1
			if _wait < 10:
				return
			_cycles[-1]["docks_when_on"] = _count_docks(EditorInterface.get_base_control())
			_cycle += 1
			if _cycle < 4:
				_phase = 20
			else:
				_results["cycles"] = _cycles
				_done(_results)

func _on_finished(ok: bool, msg: String) -> void:
	_results["ok"] = ok
	_results["msg"] = msg
	_results["stale"] = _runner.stale
	_results["stale_files"] = Array(_runner.stale_files)
	_results["build_id"] = _runner.last_build_id
	_results["port"] = _runner.port
	if ok and _mode != "serve":
		var r: Dictionary = _runner.fetch("/index.wasm", 30000)
		_results["wasm_status"] = r.status
		_results["wasm_bytes"] = r.body.size()
		_results["wasm_ms"] = r.ms
		_results["wasm_ctype"] = "application/wasm" in r.headers
		_results["coop"] = "same-origin" in r.headers
		_results["traversal"] = _runner.fetch("/../project.godot").status
		_results["outside_ext"] = _runner.fetch("/h5_build_id.txt").status
		_results["served"] = _runner.server.get_served_count()
	if not ok:
		_done(_results)
		return
	if _mode == "serve":
		_results["url"] = _runner.last_url
		EditorInterface.play_main_scene()
		_wait = 0
		_phase = 10
	elif _mode == "toggle":
		_results["port_busy_before_toggle"] = ServerScript.is_port_in_use(_runner.port)
		_phase = 20
	else:
		_done(_results)

func _done(res: Dictionary) -> void:
	_write(res)
	set_process(false)
	get_tree().quit()
