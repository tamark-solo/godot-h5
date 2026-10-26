extends Control
## H02 — Menu puzzle: chọn màn, hiển thị tiến độ, trạng thái save trung thực.

@onready var _level_buttons: HBoxContainer = %LevelButtons
@onready var _state_label: Label = %SaveStateLabel
@onready var _progress_label: Label = %ProgressLabel

func _ready() -> void:
	PuzzleState.save_state_changed.connect(_refresh)
	PuzzleState.level_changed.connect(func(_l: int) -> void: _refresh(PuzzleState.save_state))
	_build_level_buttons()
	_refresh(PuzzleState.save_state)

func _build_level_buttons() -> void:
	for i in _level_buttons.get_children():
		i.queue_free()
	for lv in range(1, PuzzleState.TOTAL_LEVELS + 1):
		var b := Button.new()
		var unlocked := lv <= PuzzleState.unlocked_level
		b.text = ("Màn %d" % lv) if unlocked else ("Màn %d 🔒" % lv)
		b.disabled = not unlocked
		b.custom_minimum_size = Vector2(190, 110)
		b.add_theme_font_size_override("font_size", 34)
		var best: int = int(PuzzleState.best_moves.get(str(lv), 0))
		if best > 0:
			b.tooltip_text = "Ít nhất %d lần kéo" % best
		b.pressed.connect(func() -> void: _play(lv))
		_level_buttons.add_child(b)

func _play(level: int) -> void:
	PuzzleState.current_level = level
	get_tree().change_scene_to_file("res://scenes/PuzzleBoard.tscn")

func _refresh(_state: int) -> void:
	_state_label.text = PuzzleState.state_text()
	if PuzzleState.save_state == PuzzleState.SaveState.FAILED:
		_state_label.modulate = Color(1.0, 0.55, 0.45)
	else:
		_state_label.modulate = Color(0.65, 0.75, 0.85)
	_progress_label.text = "Đã mở: %d/%d màn" % [PuzzleState.unlocked_level, PuzzleState.TOTAL_LEVELS]
	_build_level_buttons()
