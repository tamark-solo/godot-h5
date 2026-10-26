extends Control
## Màn kết quả: hiển thị điểm, điểm cao, trạng thái save TRUNG THỰC, chơi lại.

@onready var _score_label: Label = %ScoreLabel
@onready var _high_label: Label = %HighScoreLabel
@onready var _state_label: Label = %SaveStateLabel
@onready var _replay_button: Button = %ReplayButton
@onready var _menu_button: Button = %MenuButton

func _ready() -> void:
	_score_label.text = "Điểm: %d" % GameState.last_score
	_high_label.text = "Điểm cao: %d" % GameState.high_score
	_state_label.text = GameState.state_text()
	if GameState.save_state == GameState.SaveState.FAILED:
		_state_label.modulate = Color(1.0, 0.55, 0.45)
	else:
		_state_label.modulate = Color(0.65, 0.75, 0.85)
	_replay_button.pressed.connect(_on_replay)
	_menu_button.pressed.connect(_on_menu)
	_replay_button.grab_focus()

func _on_replay() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
