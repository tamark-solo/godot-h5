@tool
extends Node
## G04 (dock) — Browser Preview: lưu -> preflight -> export debug MỚI -> kiểm
## artifact + build ID -> serve 127.0.0.1 -> xác minh nội dung -> mở trình duyệt.
##
## Quy tắc G05 thực thi ở đây:
##   - preflight có ERROR       -> dừng, không export
##   - export thiếu/hỏng file    -> dừng, không mở output
##   - port bận (tiến trình khác) -> báo rõ, KHÔNG tự đổi port
##   - server phục vụ khác bản vừa export (SHA256 index.html) -> dừng server, không mở
##   - file trong res:// bị sửa trong lúc export -> báo "bản preview đã cũ"
##   - tắt plugin / đóng editor -> dừng server, kill export đang chạy
##
## Export chạy bằng chính editor EXE (--headless --export-debug) qua
## OS.execute_with_pipe (không chặn editor). Cùng đường CLI đã chứng minh
## byte-identical với GUI ở F07.

signal state_changed
signal log_message(text: String, level: String)
signal finished(ok: bool, message: String)

const ServerScript := preload("res://addons/h5/h5_preview_server.gd")
const H5ConfigScript := preload("res://addons/h5/h5_config.gd")
const H5ValidatorScript := preload("res://addons/h5/h5_validator.gd")

const CONFIG_PATH := "res://h5_config.tres"
## Không dùng 8060: trùng "Run in Browser" có sẵn của Godot (export/web/http_port).
const DEFAULT_PORT := 8070
const OUTPUT_DIR := "res://.godot/h5_preview"
const EXPORT_TIMEOUT_MS := 300000
const REQUIRED_FILES := ["index.html", "index.js", "index.wasm", "index.pck"]
const MIN_WASM_BYTES := 1048576
const SCAN_IDLE_FRAMES := 3

enum State { IDLE, WAIT_SCAN, EXPORTING }

var port := DEFAULT_PORT
var server = ServerScript.new()
var state := State.IDLE
var last_url := ""
var last_build_id := ""
## true nếu có file trong res:// bị sửa SAU khi export bắt đầu.
var stale := false
var stale_files := PackedStringArray()

var _open_browser := true
var _idle_frames := 0
var _pid := -1
var _pipes: Array = []
var _export_log := ""
var _export_started_ms := 0
var _export_started_unix := 0
var _out_dir := ""

func _init() -> void:
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		shutdown()

func is_busy() -> bool:
	return state != State.IDLE

func get_url() -> String:
	return "http://127.0.0.1:%d/index.html" % port

## Bắt đầu một lượt preview. Trả false nếu đang bận.
func start(open_browser: bool = true) -> bool:
	if state != State.IDLE:
		_log("Đang có một lượt preview chạy — đợi xong rồi bấm lại.", "warning")
		return false
	_open_browser = open_browser
	last_build_id = ""
	stale = false
	stale_files = PackedStringArray()
	_log("[1/6] Lưu scene đang mở…")
	EditorInterface.save_all_scenes()
	_idle_frames = 0
	_set_state(State.WAIT_SCAN)
	return true

## Dừng mọi thứ tool này sở hữu: export đang chạy + server.
func shutdown() -> void:
	_kill_export()
	if server != null:
		server.stop()
	if state != State.IDLE:
		state = State.IDLE
		set_process(false)

func stop_server() -> void:
	if server.is_running():
		server.stop()
		_log("Đã dừng server port %d." % port)
	state_changed.emit()

## GET một đường dẫn từ server preview (dùng để xác minh nội dung + selftest).
## Trả {status:int, headers:String, body:PackedByteArray, ms:int}.
func fetch(path: String, timeout_ms: int = 10000) -> Dictionary:
	var out := {"status": 0, "headers": "", "body": PackedByteArray(), "ms": 0}
	var t0 := Time.get_ticks_msec()
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != OK:
		return out
	var data := PackedByteArray()
	var sent := false
	while Time.get_ticks_msec() - t0 < timeout_ms:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				peer.put_data(("GET %s HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nConnection: close\r\n\r\n" % [path, port]).to_utf8_buffer())
				sent = true
			var n := peer.get_available_bytes()
			if n > 0:
				var r: Array = peer.get_partial_data(n)
				data.append_array(r[1])
				continue
		elif st != StreamPeerTCP.STATUS_CONNECTING:
			break
		OS.delay_msec(1)
	out.ms = Time.get_ticks_msec() - t0
	var sep := _find_header_end(data)
	if sep < 0:
		return out
	var head := data.slice(0, sep).get_string_from_ascii()
	out.headers = head
	var first := head.get_slice("\r\n", 0).split(" ", false)
	if first.size() >= 2:
		out.status = int(first[1])
	out.body = data.slice(sep + 4)
	return out

# ------------------------------------------------------------------ loop
func _process(_delta: float) -> void:
	match state:
		State.WAIT_SCAN:
			# save_all_scenes có thể kích hoạt scan/import muộn vài khung: đợi
			# vài khung LIÊN TIẾP không scan, để tiến trình export không import
			# chồng lên editor (hai tiến trình cùng ghi .godot/imported).
			if EditorInterface.get_resource_filesystem().is_scanning():
				_idle_frames = 0
			else:
				_idle_frames += 1
				if _idle_frames >= SCAN_IDLE_FRAMES:
					_preflight_and_export()
		State.EXPORTING:
			_poll_export()

func _set_state(s: State) -> void:
	state = s
	set_process(s != State.IDLE)
	state_changed.emit()

func _log(text: String, level: String = "info") -> void:
	log_message.emit(text, level)

func _fail(msg: String) -> void:
	_log(msg, "error")
	_set_state(State.IDLE)
	finished.emit(false, msg)

# ------------------------------------------------------- preflight + export
func _preflight_and_export() -> void:
	_log("[2/6] Preflight H5…")
	var cfg = H5ConfigScript.load_or_create(CONFIG_PATH)
	var issues: Array = H5ValidatorScript.new().run(cfg, EditorInterface)
	var errors: Array = issues.filter(func(i): return i.severity == "error")
	if not errors.is_empty():
		for i in errors.slice(0, 5):
			_log("   %s — %s" % [i.code, i.message], "error")
		_fail("PREFLIGHT có %d lỗi — dừng, không export, không mở trình duyệt." % errors.size())
		return

	_out_dir = ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_fail("Không tạo được thư mục preview: %s" % _out_dir)
		return
	# Dọn output cũ: nếu export fail thì không còn file cũ nào để lỡ phục vụ.
	for f in DirAccess.get_files_at(_out_dir):
		if DirAccess.remove_absolute(_out_dir.path_join(f)) != OK:
			_fail("Không xoá được file preview cũ (đang bị khoá?): %s" % f)
			return

	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var args := PackedStringArray(["--headless", "--path", project_dir, "--export-debug", str(cfg.target_preset), _out_dir.path_join("index.html")])
	_log("[3/6] Export debug mới (preset '%s')…" % cfg.target_preset)
	var info := OS.execute_with_pipe(OS.get_executable_path(), args, false)
	if info.is_empty():
		_fail("Không khởi động được tiến trình export: %s" % OS.get_executable_path())
		return
	_pid = int(info["pid"])
	_pipes = [info["stdio"], info["stderr"]]
	_export_log = ""
	_export_started_ms = Time.get_ticks_msec()
	_export_started_unix = int(Time.get_unix_time_from_system())
	_set_state(State.EXPORTING)

func _drain_pipes() -> void:
	for p in _pipes:
		if p == null:
			continue
		while true:
			var b: PackedByteArray = p.get_buffer(8192)
			if b.is_empty():
				break
			_export_log += b.get_string_from_utf8()
	if _export_log.length() > 20000:
		_export_log = _export_log.right(20000)

func _poll_export() -> void:
	_drain_pipes()
	if OS.is_process_running(_pid):
		if Time.get_ticks_msec() - _export_started_ms > EXPORT_TIMEOUT_MS:
			_kill_export()
			_fail("Export quá %d giây — đã dừng tiến trình export." % (EXPORT_TIMEOUT_MS / 1000))
		return
	_drain_pipes()
	var code := OS.get_process_exit_code(_pid)
	_close_pipes()
	_pid = -1
	_after_export(code)

func _kill_export() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_close_pipes()

func _close_pipes() -> void:
	for p in _pipes:
		if p != null:
			p.close()
	_pipes = []

# ----------------------------------------------------------- verify + serve
func _after_export(code: int) -> void:
	_log("[4/6] Kiểm tra artifact…")
	var missing := PackedStringArray()
	for f in REQUIRED_FILES:
		if not FileAccess.file_exists(_out_dir.path_join(f)):
			missing.append(f)
	if not missing.is_empty():
		for l in _export_log.strip_edges().split("\n").slice(-8):
			_log("   " + l.strip_edges(), "error")
		_fail("EXPORT THẤT BẠI (exit %d), thiếu: %s — không mở trình duyệt." % [code, ", ".join(missing)])
		return
	var wasm := FileAccess.open(_out_dir.path_join("index.wasm"), FileAccess.READ)
	var magic := wasm.get_buffer(4) if wasm != null else PackedByteArray()
	var wasm_len := wasm.get_length() if wasm != null else 0
	if magic != PackedByteArray([0x00, 0x61, 0x73, 0x6D]) or wasm_len < MIN_WASM_BYTES:
		_fail("index.wasm hỏng (sai magic bytes hoặc < 1 MB) — không mở trình duyệt.")
		return
	if code != 0:
		# Đã biết (G04 §4.1): editor headless đôi khi crash LÚC THOÁT sau khi export xong.
		_log("Export exit %d nhưng artifact đầy đủ, hợp lệ — tiếp tục (ghi nhận cảnh báo)." % code, "warning")

	var bid_path := _out_dir.path_join("h5_build_id.json")
	if FileAccess.file_exists(bid_path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(bid_path))
		if j is Dictionary:
			last_build_id = str(j.get("build_id", ""))
	if last_build_id.is_empty():
		_log("Không có h5_build_id.json (export plugin H5 chưa chạy?).", "warning")
	else:
		_log("   build_id: %s" % last_build_id)

	stale_files = _changed_since(_export_started_unix)
	stale = not stale_files.is_empty()

	_log("[5/6] Server 127.0.0.1:%d…" % port)
	if server.is_running() and server.get_root() == _out_dir and server.get_port() == port:
		_log("   dùng lại server đang chạy (cùng thư mục, cùng port)")
	else:
		var err: Error = server.start(_out_dir, port)
		if err == ERR_ALREADY_IN_USE:
			_fail("Port %d đang bị tiến trình KHÁC dùng — không tự đổi port. Đổi port trong dock hoặc dừng tiến trình đó." % port)
			return
		if err != OK:
			_fail("Không mở được server port %d: %s" % [port, error_string(err)])
			return

	var local_hash := FileAccess.get_sha256(_out_dir.path_join("index.html"))
	var r := fetch("/index.html")
	var served_hash := _sha256(r.body) if r.status == 200 else ""
	if served_hash != local_hash:
		server.stop()
		_fail("Server KHÔNG phục vụ đúng bản vừa export (HTTP %d) — đã dừng server, không mở trình duyệt." % r.status)
		return
	_log("   đã xác minh: server phục vụ ĐÚNG bản vừa export (SHA256 index.html khớp)")

	last_url = get_url()
	if stale:
		_log("Bản preview ĐÃ CŨ: %d file bị sửa trong lúc export (vd %s). Bấm Preview lại." % [stale_files.size(), stale_files[0]], "warning")
	if _open_browser:
		_log("[6/6] Mở %s" % last_url)
		OS.shell_open(last_url)
	else:
		_log("[6/6] %s (không mở trình duyệt)" % last_url)
	_set_state(State.IDLE)
	finished.emit(true, last_url)

func _changed_since(t: int) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[String] = ["res://"]
	var seen := 0
	while not stack.is_empty() and seen < 5000:
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if not sub.begins_with("."):
				stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			seen += 1
			if f.ends_with(".import") or f.ends_with(".uid") or f.ends_with(".tmp"):
				continue
			var p := d.path_join(f)
			if FileAccess.get_modified_time(p) > t:
				out.append(p)
	return out

static func _sha256(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not b.is_empty():
		h.update(b)
	return h.finish().hex_encode()

static func _find_header_end(data: PackedByteArray) -> int:
	for i in range(0, data.size() - 3):
		if data[i] == 13 and data[i + 1] == 10 and data[i + 2] == 13 and data[i + 3] == 10:
			return i
	return -1
