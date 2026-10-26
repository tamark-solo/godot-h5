extends Node2D
## H02 — Bàn puzzle: kéo các mảnh vào đúng ô.
## Khác fixture 1: không có timer/spawn liên tục; thắng khi TẤT CẢ mảnh đúng chỗ.

const RESULT_SCENE := "res://scenes/PuzzleResult.tscn"
const PIECE_COLORS := [
	Color(1.00, 0.70, 0.30),
	Color(0.45, 0.80, 1.00),
	Color(0.65, 0.95, 0.55),
	Color(1.00, 0.55, 0.75),
]

@onready var _slots: Node2D = $Slots
@onready var _pieces: Node2D = $Pieces
@onready var _moves_label: Label = %MovesLabel
@onready var _level_label: Label = %LevelLabel
@onready var _state_label: Label = %SaveStateLabel
@onready var _hint_label: Label = %HintLabel

var _moves: int = 0
var _correct: int = 0
var _total: int = 0
var _finished: bool = false

func _ready() -> void:
	# H02: ghi trang thai ra console de test tu dong doc duoc.
	# Canvas khong doc duoc text tu DOM, nen day la kenh xac minh chinh xac
	# (thay vi doan qua anh chup).
	PuzzleState.save_state_changed.connect(func(_s: int) -> void:
		_state_label.text = PuzzleState.state_text())
	_state_label.text = PuzzleState.state_text()
	_level_label.text = "Màn %d" % PuzzleState.current_level
	_setup_level(PuzzleState.current_level)
	_refresh()
	# In SAU khi setup xong, kem TOA DO THAT cua manh/o.
	# Ly do: voi stretch mode 'canvas_items' + aspect 'expand', viewport game
	# RONG HON 720 (canvas browser co the rong hon ty le thiet ke). Test tu dong
	# khong duoc doan toa do — phai doc tu game.
	var vp2 := get_viewport_rect().size
	_dbg("[PUZZLE] ready level=%d total=%d viewport=%dx%d" % [
		PuzzleState.current_level, _total, int(vp2.x), int(vp2.y)])
	for p in _pieces.get_children():
		if p is Area2D:
			_dbg("[PUZZLE] piece idx=%d at=%d,%d target=%d,%d" % [
				p.piece_index, int(p.global_position.x), int(p.global_position.y),
				int(p.target_position.x), int(p.target_position.y)])

func _setup_level(level: int) -> void:
	var count := clampi(level + 2, 3, 4)   # màn 1: 3 mảnh, màn 2+: 4 mảnh
	_total = count
	var vp := get_viewport_rect().size

	# Ô đích: hàng ngang phía trên
	var slot_y := vp.y * 0.30
	var spacing := vp.x / float(count + 1)
	for i in range(count):
		var slot := _make_box(52.0, Color(0.22, 0.20, 0.32), Color(0.45, 0.42, 0.60))
		slot.position = Vector2(spacing * (i + 1), slot_y)
		_slots.add_child(slot)

	# Mảnh: đặt lệch thứ tự ở dưới để phải kéo
	var order := []
	for i in range(count):
		order.append(i)
	order.reverse()
	var piece_y := vp.y * 0.72
	for i in range(count):
		var idx: int = order[i]
		var p := preload("res://scenes/Piece.tscn").instantiate() as Area2D
		p.piece_index = idx
		p.target_position = Vector2(spacing * (idx + 1), slot_y)
		p.color = PIECE_COLORS[idx % PIECE_COLORS.size()]
		p.position = Vector2(spacing * (i + 1), piece_y)
		p.placed.connect(_on_placed)
		_pieces.add_child(p)

func _make_box(r: float, fill: Color, border: Color) -> Node2D:
	var n := Node2D.new()
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var c := 8.0
	pts.append(Vector2(-r + c, -r)); pts.append(Vector2(r - c, -r))
	pts.append(Vector2(r, -r + c)); pts.append(Vector2(r, r - c))
	pts.append(Vector2(r - c, r)); pts.append(Vector2(-r + c, r))
	pts.append(Vector2(-r, r - c)); pts.append(Vector2(-r, -r + c))
	poly.polygon = pts
	poly.color = fill
	n.add_child(poly)
	var line := Line2D.new()
	var lp := PackedVector2Array(pts)
	lp.append(pts[0])
	line.points = lp
	line.width = 4.0
	line.default_color = border
	n.add_child(line)
	return n

func _on_placed(piece: Area2D, correct: bool) -> void:
	_moves += 1
	if correct:
		_correct += 1
		piece.modulate = Color(1, 1, 1, 0.85)
	_dbg("[PUZZLE] placed idx=%d correct=%s moves=%d correct_total=%d/%d" % [
		piece.piece_index, str(correct), _moves, _correct, _total])
	_refresh()
	if _correct >= _total and not _finished:
		_finish()

func _refresh() -> void:
	_moves_label.text = "Lần kéo: %d" % _moves
	_hint_label.text = "Đúng chỗ: %d/%d" % [_correct, _total]

func _finish() -> void:
	_finished = true
	_dbg("[PUZZLE] finished level=%d moves=%d" % [PuzzleState.current_level, _moves])
	PuzzleState.complete_level(PuzzleState.current_level, _moves)
	get_tree().change_scene_to_file(RESULT_SCENE)

## Log chẩn đoán chỉ chạy trong editor/bản debug; bản release không in gì.
func _dbg(msg: String) -> void:
	if OS.is_debug_build():
		print(msg)
