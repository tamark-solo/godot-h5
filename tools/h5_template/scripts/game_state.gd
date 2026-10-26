extends Node
## D06 — Trạng thái game + save checkpoint có version.
##
## Quy tắc (theo kế hoạch):
##  - Save ghi vào user:// (trên web Godot map sang IndexedDB).
##  - Trạng thái save phải TRUNG THỰC: không hiển thị "đã lưu" khi ghi thất bại.
##  - Save cũ/hỏng/version mới hơn -> fallback, không crash.
##  - Không dựa vào unload để hoàn tất save bất đồng bộ.

signal save_state_changed(state: int)

const SAVE_PATH := "user://h5demo_save.json"
const SAVE_VERSION := 1

enum SaveState {
	UNKNOWN,       ## chưa thử đọc/ghi
	SYNCED,        ## đã ghi và đọc lại được
	FAILED,        ## ghi/đọc lỗi (quota, bị chặn, hỏng)
	SESSION_ONLY,  ## chưa có file save; chỉ sống trong phiên này
}

var high_score: int = 0
var last_score: int = 0
var last_stars: int = 0
var save_state: int = SaveState.UNKNOWN
var save_error: String = ""

func _ready() -> void:
	load_game()

func state_text() -> String:
	match save_state:
		SaveState.SYNCED:
			return "Đã lưu (local)"
		SaveState.FAILED:
			return "Lưu thất bại — chỉ trong phiên này"
		SaveState.SESSION_ONLY:
			return "Chưa có save — chỉ trong phiên này"
		_:
			return "Chưa xác định"

func storage_available() -> bool:
	## Kiểm tra thô: thử mở một file tạm để ghi.
	var probe := FileAccess.open("user://.probe", FileAccess.WRITE)
	if probe == null:
		return false
	probe.store_string("ok")
	probe.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://.probe"))
	return true

func load_game() -> bool:
	save_error = ""
	if not FileAccess.file_exists(SAVE_PATH):
		save_state = SaveState.SESSION_ONLY
		save_state_changed.emit(save_state)
		return false

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		save_state = SaveState.FAILED
		save_error = "Không mở được save: %s" % error_string(FileAccess.get_open_error())
		save_state_changed.emit(save_state)
		return false

	var text := f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		save_state = SaveState.FAILED
		save_error = "Save hỏng (không phải JSON object)"
		save_state_changed.emit(save_state)
		return false

	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		save_state = SaveState.FAILED
		save_error = "Save thuộc phiên bản mới hơn (%d > %d)" % [version, SAVE_VERSION]
		save_state_changed.emit(save_state)
		return false

	high_score = int(data.get("high_score", 0))
	save_state = SaveState.SYNCED
	save_state_changed.emit(save_state)
	return true

func save_game() -> bool:
	save_error = ""
	var payload := {
		"version": SAVE_VERSION,
		"high_score": high_score,
		"last_score": last_score,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		save_state = SaveState.FAILED
		save_error = "Không ghi được save: %s" % error_string(FileAccess.get_open_error())
		save_state_changed.emit(save_state)
		return false

	f.store_string(JSON.stringify(payload))
	f.close()

	## Read-back: chỉ coi là SYNCED khi đọc lại đúng.
	var verify := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if verify == null:
		save_state = SaveState.FAILED
		save_error = "Ghi xong nhưng không đọc lại được"
		save_state_changed.emit(save_state)
		return false
	var back: Variant = JSON.parse_string(verify.get_as_text())
	verify.close()
	if typeof(back) != TYPE_DICTIONARY or int(back.get("high_score", -1)) != high_score:
		save_state = SaveState.FAILED
		save_error = "Read-back không khớp"
		save_state_changed.emit(save_state)
		return false

	save_state = SaveState.SYNCED
	save_state_changed.emit(save_state)
	return true

func commit_score(score: int, stars: int) -> void:
	last_score = score
	last_stars = stars
	if score > high_score:
		high_score = score
	save_game()
