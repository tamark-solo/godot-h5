extends Node2D
## Gameplay: hứng sao, đếm điểm, thua khi bỏ lỡ quá số lần cho phép.
## D05 — âm thanh bật sau gesture; D06 — commit checkpoint khi kết thúc.

const STAR_SCENE := preload("res://scenes/Star.tscn")
const RESULT_SCENE := "res://scenes/Result.tscn"

const MAX_MISSES := 3
const ROUND_SECONDS := 45.0

@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _round_timer: Timer = $RoundTimer
@onready var _stars_root: Node2D = $Stars
@onready var _score_label: Label = %ScoreLabel
@onready var _miss_label: Label = %MissLabel
@onready var _time_label: Label = %TimeLabel
@onready var _state_label: Label = %SaveStateLabel
@onready var _pause_button: Button = %PauseButton
@onready var _overlay: Control = $Overlay
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_resume: Button = %OverlayResume
@onready var _overlay_quit: Button = %OverlayQuit

var _score: int = 0
var _stars_caught: int = 0
var _misses: int = 0
var _time_left: float = ROUND_SECONDS
var _finished: bool = false

func _ready() -> void:
	_spawn_timer.timeout.connect(_spawn_star)
	_round_timer.timeout.connect(_on_round_tick)
	_pause_button.pressed.connect(_pause)
	_overlay_resume.pressed.connect(_resume)
	_overlay_quit.pressed.connect(_quit_to_menu)
	GameState.save_state_changed.connect(_on_save_state_changed)

	_overlay.visible = false
	_refresh_hud()
	_on_save_state_changed(GameState.save_state)
	_spawn_timer.start(0.8)
	_round_timer.start(0.25)

func _notification(what: int) -> void:
	## D05/G07 — khi app bị đẩy xuống nền: tạm dừng, không để simulation nhảy.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if not _finished and not get_tree().paused:
				_pause()
		NOTIFICATION_APPLICATION_PAUSED:
			if not _finished:
				_pause()

func _spawn_star() -> void:
	if _finished or get_tree().paused:
		return
	var star := STAR_SCENE.instantiate() as Area2D
	var vp := get_viewport_rect().size
	star.position = Vector2(randf_range(60.0, vp.x - 60.0), -40.0)
	star.fall_speed = randf_range(220.0, 380.0) + minf(_stars_caught * 6.0, 160.0)
	star.horizontal_drift = randf_range(-60.0, 60.0)
	star.caught.connect(_on_star_caught)
	star.missed.connect(_on_star_missed)
	_stars_root.add_child(star)

func _on_star_caught(_star: Area2D) -> void:
	_score += 10
	_stars_caught += 1
	_refresh_hud()

func _on_star_missed(_star: Area2D) -> void:
	_misses += 1
	_refresh_hud()
	if _misses >= MAX_MISSES:
		_finish()

func _on_round_tick() -> void:
	if _finished or get_tree().paused:
		return
	_time_left = maxf(0.0, _time_left - 0.25)
	_refresh_hud()
	if _time_left <= 0.0:
		_finish()

func _refresh_hud() -> void:
	_score_label.text = "Điểm: %d" % _score
	_miss_label.text = "Bỏ lỡ: %d/%d" % [_misses, MAX_MISSES]
	_time_label.text = "Thời gian: %d" % int(ceil(_time_left))

func _on_save_state_changed(_state: int) -> void:
	_state_label.text = GameState.state_text()

func _pause() -> void:
	get_tree().paused = true
	_overlay_title.text = "TẠM DỪNG"
	_overlay_resume.text = "Tiếp tục"
	_overlay.visible = true

func _resume() -> void:
	_overlay.visible = false
	get_tree().paused = false

func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_spawn_timer.stop()
	_round_timer.stop()
	GameState.commit_score(_score, _stars_caught)
	get_tree().change_scene_to_file(RESULT_SCENE)
