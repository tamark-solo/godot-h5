extends Control
## H02 — Màn kết quả puzzle: số lần kéo, kỷ lục, trạng thái save, điều hướng.

@onready var _moves_label: Label = %MovesLabel
@onready var _best_label: Label = %BestLabel
@onready var _state_label: Label = %SaveStateLabel
@onready var _next_button: Button = %NextButton
@onready var _menu_button: Button = %MenuButton

func _ready() -> void:
	# Dung last_completed_level, KHONG suy ra tu current_level.
	# Ly do (loi da gap): complete_level() tang current_level truoc khi man ket qua
	# doc -> suy ra se hien "Hoan thanh man 2" khi vua xong man 1, va tra cuu
	# ky luc sai khoa nen luon hien "—".
	var played: int = PuzzleState.last_completed_level
	if played <= 0:
		played = clampi(PuzzleState.current_level - 1, 1, PuzzleState.TOTAL_LEVELS)
	_moves_label.text = "Hoàn thành màn %d (%d lần kéo)" % [played, PuzzleState.last_completed_moves]
	var best: int = int(PuzzleState.best_moves.get(str(played), 0))
	_best_label.text = ("Kỷ lục: %d lần kéo" % best) if best > 0 else "Kỷ lục: —"
	_state_label.text = PuzzleState.state_text()
	if PuzzleState.save_state == PuzzleState.SaveState.FAILED:
		_state_label.modulate = Color(1.0, 0.55, 0.45)
	else:
		_state_label.modulate = Color(0.65, 0.75, 0.85)

	_next_button.visible = PuzzleState.unlocked_level > played
	_next_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/PuzzleBoard.tscn"))
	_menu_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/PuzzleMenu.tscn"))
	_next_button.grab_focus()