@tool
extends RefCounted
## G04 (dock) — Static HTTP server cho Browser Preview.
##
## Chạy trên Thread RIÊNG: khi editor mất focus (đang Play, đang xem trình duyệt)
## editor chỉ tick ~100 ms/khung (unfocused_low_processor_mode_sleep_usec), nếu
## poll trong _process thì tải index.wasm vài MB sẽ rất chậm.
##
## An toàn: chỉ nghe 127.0.0.1, chỉ phục vụ file trong _root (chặn ".."),
## chỉ nhận Host 127.0.0.1/localhost (chống DNS rebinding), chỉ GET/HEAD.

const MIME := {
	"html": "text/html; charset=utf-8",
	"js": "text/javascript",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"svg": "image/svg+xml",
	"json": "application/json",
	"ico": "image/x-icon",
	"css": "text/css; charset=utf-8",
}
const COMMON_HEADERS := "Connection: close\r\nCache-Control: no-store, max-age=0\r\nCross-Origin-Opener-Policy: same-origin\r\nCross-Origin-Embedder-Policy: require-corp\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
const REQUEST_TIMEOUT_MS := 3000
const MAX_HEADER_BYTES := 16384
const CHUNK := 65536

var _root := ""
var _port := 0
var _server: TCPServer = null
var _thread: Thread = null
var _mutex := Mutex.new()
var _quit := false
var _served := 0

func get_root() -> String:
	return _root

func get_port() -> int:
	return _port

func is_running() -> bool:
	return _thread != null

func get_served_count() -> int:
	_mutex.lock()
	var n := _served
	_mutex.unlock()
	return n

## TCPServer.listen() bật SO_REUSEADDR (core/io/tcp_server.cpp:58). Trên Windows
## bind vẫn THÀNH CÔNG dù port đã có tiến trình khác nghe -> trình duyệt có thể
## nói chuyện với server lạ (bản export CŨ). Vì vậy phải dò bằng connect trước.
static func is_port_in_use(port: int) -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != OK:
		return false
	var deadline := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			return true
		if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
			return false
		OS.delay_msec(10)
	peer.disconnect_from_host()
	return false

func start(root: String, port: int) -> Error:
	stop()
	if is_port_in_use(port):
		return ERR_ALREADY_IN_USE
	_server = TCPServer.new()
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		_server = null
		return err
	_root = root
	_port = port
	_mutex.lock()
	_quit = false
	_served = 0
	_mutex.unlock()
	_thread = Thread.new()
	_thread.start(_run)
	return OK

func stop() -> void:
	if _thread != null:
		_mutex.lock()
		_quit = true
		_mutex.unlock()
		_thread.wait_to_finish()
		_thread = null
	if _server != null:
		_server.stop()
		_server = null
	_root = ""
	_port = 0

func _should_quit() -> bool:
	_mutex.lock()
	var q := _quit
	_mutex.unlock()
	return q

func _run() -> void:
	while not _should_quit():
		if _server.is_connection_available():
			var peer := _server.take_connection()
			if peer != null:
				_handle(peer)
				peer.disconnect_from_host()
		else:
			OS.delay_msec(2)

func _handle(peer: StreamPeerTCP) -> void:
	peer.set_no_delay(true)
	var buf := PackedByteArray()
	var deadline := Time.get_ticks_msec() + REQUEST_TIMEOUT_MS
	while true:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var n := peer.get_available_bytes()
		if n > 0:
			var res: Array = peer.get_partial_data(n)
			if res[0] != OK:
				return
			buf.append_array(res[1])
			if buf.get_string_from_ascii().find("\r\n\r\n") >= 0:
				break
			if buf.size() > MAX_HEADER_BYTES:
				_send_status(peer, "431 Request Header Fields Too Large")
				return
		elif Time.get_ticks_msec() > deadline or _should_quit():
			return
		else:
			OS.delay_msec(1)

	var lines := buf.get_string_from_ascii().split("\r\n")
	var parts := lines[0].split(" ", false)
	if parts.size() < 3 or (parts[0] != "GET" and parts[0] != "HEAD"):
		_send_status(peer, "405 Method Not Allowed")
		return
	if not _host_allowed(lines):
		_send_status(peer, "403 Forbidden")
		return

	var path := parts[1].get_slice("?", 0).uri_decode()
	if path == "/":
		path = "/index.html"
	var rel := path.trim_prefix("/")
	var ext := rel.get_extension().to_lower()
	if rel.is_empty() or rel.split("/").has("..") or rel.contains("\\") or rel.contains(":") or not MIME.has(ext):
		_send_status(peer, "404 Not Found")
		return
	var full := _root.path_join(rel)
	var f := FileAccess.open(full, FileAccess.READ)
	if f == null:
		_send_status(peer, "404 Not Found")
		return

	var head := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\n" % [MIME[ext], f.get_length()]
	if peer.put_data((head + COMMON_HEADERS).to_utf8_buffer()) != OK:
		return
	if parts[0] == "GET":
		while f.get_position() < f.get_length():
			if peer.put_data(f.get_buffer(CHUNK)) != OK or _should_quit():
				return
	_mutex.lock()
	_served += 1
	_mutex.unlock()

func _host_allowed(lines: PackedStringArray) -> bool:
	for l in lines:
		if l.to_lower().begins_with("host:"):
			var host := l.substr(5).strip_edges().to_lower()
			return host == "127.0.0.1:%d" % _port or host == "localhost:%d" % _port
	return false

func _send_status(peer: StreamPeerTCP, status: String) -> void:
	peer.put_data(("HTTP/1.1 %s\r\nContent-Length: 0\r\n" % status + COMMON_HEADERS).to_utf8_buffer())
