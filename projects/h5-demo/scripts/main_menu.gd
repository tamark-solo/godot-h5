extends Control
## Menu chính: chơi mới, xem điểm cao, hiển thị trạng thái save trung thực.

@onready var _high_label: Label = %HighScoreLabel
@onready var _state_label: Label = %SaveStateLabel
@onready var _play_button: Button = %PlayButton

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	GameState.save_state_changed.connect(_refresh)
	_refresh(GameState.save_state)
	_play_button.grab_focus()

func _refresh(_state: int) -> void:
	_high_label.text = "Điểm cao: %d" % GameState.high_score
	_state_label.text = GameState.state_text()
	if GameState.save_state == GameState.SaveState.FAILED:
		_state_label.modulate = Color(1.0, 0.55, 0.45)
	else:
		_state_label.modulate = Color(0.65, 0.75, 0.85)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
