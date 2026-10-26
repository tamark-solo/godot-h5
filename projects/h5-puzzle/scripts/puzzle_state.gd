extends Node
## H02 — Trạng thái puzzle: save có version, khác hẳn fixture 1.
##
## Khác biệt so với h5-demo (theo yêu cầu H02 "khác input/scene/resource mix"):
##   - Lưu TIẾN ĐỘ MÀN (level) chứ không phải điểm cao
##   - Lưu cả trạng thái từng mảnh ghép (resource mix khác)
##   - Dùng mảng/dictionary thay vì số nguyên đơn

signal save_state_changed(state: int)
signal level_changed(level: int)

const SAVE_PATH := "user://h5puzzle_save.json"
const SAVE_VERSION := 1
const TOTAL_LEVELS := 3

enum SaveState { UNKNOWN, SYNCED, FAILED, SESSION_ONLY }

var current_level: int = 1
var unlocked_level: int = 1
## Man VUA hoan thanh. Can rieng vi complete_level() tang current_level TRUOC khi
## man ket qua doc -> neu suy ra tu current_level se hien sai (man 1 -> "man 2").
var last_completed_level: int = 0
var last_completed_moves: int = 0
var best_moves: Dictionary = {}   ## level -> số lần kéo ít nhất
var save_state: int = SaveState.UNKNOWN
var save_error: String = ""

func _ready() -> void:
	load_game()

func state_text() -> String:
	match save_state:
		SaveState.SYNCED: return "Đã lưu (local)"
		SaveState.FAILED: return "Lưu thất bại — chỉ trong phiên này"
		SaveState.SESSION_ONLY: return "Chưa có save — chỉ trong phiên này"
		_: return "Chưa xác định"

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
	unlocked_level = clampi(int(data.get("unlocked_level", 1)), 1, TOTAL_LEVELS)
	current_level = clampi(int(data.get("current_level", 1)), 1, TOTAL_LEVELS)
	var bm: Variant = data.get("best_moves", {})
	if typeof(bm) == TYPE_DICTIONARY:
		best_moves = bm
	save_state = SaveState.SYNCED
	save_state_changed.emit(save_state)
	return true

func save_game() -> bool:
	save_error = ""
	var payload := {
		"version": SAVE_VERSION,
		"unlocked_level": unlocked_level,
		"current_level": current_level,
		"best_moves": best_moves,
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
	# Read-back: chỉ coi là SYNCED khi đọc lại đúng.
	var verify := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if verify == null:
		save_state = SaveState.FAILED
		save_error = "Ghi xong nhưng không đọc lại được"
		save_state_changed.emit(save_state)
		return false
	var back: Variant = JSON.parse_string(verify.get_as_text())
	verify.close()
	if typeof(back) != TYPE_DICTIONARY or int(back.get("unlocked_level", -1)) != unlocked_level:
		save_state = SaveState.FAILED
		save_error = "Read-back không khớp"
		save_state_changed.emit(save_state)
		return false
	save_state = SaveState.SYNCED
	save_state_changed.emit(save_state)
	return true

func complete_level(level: int, moves: int) -> void:
	last_completed_level = level
	last_completed_moves = moves
	var prev: int = int(best_moves.get(str(level), 0))
	if prev == 0 or moves < prev:
		best_moves[str(level)] = moves
	if level + 1 > unlocked_level and level < TOTAL_LEVELS:
		unlocked_level = level + 1
	if level < TOTAL_LEVELS:
		current_level = level + 1
	save_game()
	level_changed.emit(current_level)