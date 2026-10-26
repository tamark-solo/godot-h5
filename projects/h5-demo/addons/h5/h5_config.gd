@tool
class_name H5Config
extends Resource
## Cấu hình H5 cho một project. Lưu tại res://h5_config.tres.
## Có version để migrate khi schema đổi (E05).

const CURRENT_VERSION := 1

@export_group("Version")
## Schema version. Tăng khi thêm/bớt trường theo cách không tương thích.
@export var config_version: int = CURRENT_VERSION

@export_group("Hiển thị")
@export var game_title: String = ""
@export var icon_path: String = "res://icon.svg"
@export var design_resolution: Vector2i = Vector2i(720, 1280)
@export_enum("portrait", "landscape", "any") var orientation: String = "portrait"
@export_enum("canvas_items", "viewport", "disabled") var stretch_mode: String = "canvas_items"
@export_enum("expand", "keep", "keep_width", "keep_height") var stretch_aspect: String = "expand"

@export_group("Export")
## Tên preset export trong export_presets.cfg mà H5 dùng.
@export var target_preset: String = "Web"
## Bật kiểm tra chặn export khi có lỗi severity=error.
@export var block_export_on_error: bool = true

@export_group("Input")
@export var input_profile: String = "touch+mouse"
@export var require_actions: PackedStringArray = PackedStringArray(["ui_accept", "ui_cancel"])

@export_group("Asset policy")
@export_enum("vram_compressed", "lossless", "lossy") var texture_policy_desktop: String = "vram_compressed"
@export_enum("vram_compressed", "lossless", "lossy") var texture_policy_mobile: String = "lossless"
## Cảnh báo nếu texture có cạnh dài vượt ngưỡng này (px).
@export var texture_max_dimension: int = 2048
## Cảnh báo nếu file audio vượt ngưỡng này (KB).
@export var audio_max_size_kb: int = 2048

func migrate() -> bool:
	## Trả về true nếu có thay đổi.
	var changed := false
	if config_version < CURRENT_VERSION:
		config_version = CURRENT_VERSION
		changed = true
	return changed

static func load_or_create(path: String) -> H5Config:
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is H5Config:
			return res
	var cfg := H5Config.new()
	return cfg
