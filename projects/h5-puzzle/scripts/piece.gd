extends Area2D
## H02 — Mảnh ghép kéo-thả.
##
## KHÁC fixture 1: đây là kéo-thả TỰ DO 2 CHIỀU (không chỉ theo trục ngang),
## có snap vào đúng ô, và phân biệt "đúng chỗ" / "sai chỗ".
## Xử lý: touch + mouse, cancel, mất focus — không kẹt trạng thái kéo.

signal placed(piece: Area2D, correct: bool)
signal picked(piece: Area2D)

@export var piece_index: int = 0
@export var target_position: Vector2 = Vector2.ZERO
@export var snap_radius: float = 60.0
@export var color: Color = Color.WHITE

var _dragging: bool = false
var _offset: Vector2 = Vector2.ZERO
var _settled: bool = false

@onready var _sprite: Polygon2D = $Shape

func _ready() -> void:
	add_to_group("pieces")
	_sprite.color = color
	# Vẽ hình vuông bo góc đơn giản — resource mix khác fixture 1 (không dùng SVG).
	var pts := PackedVector2Array()
	var r := 46.0
	var c := 8.0
	pts.append(Vector2(-r + c, -r)); pts.append(Vector2(r - c, -r))
	pts.append(Vector2(r, -r + c)); pts.append(Vector2(r, r - c))
	pts.append(Vector2(r - c, r)); pts.append(Vector2(-r + c, r))
	pts.append(Vector2(-r, r - c)); pts.append(Vector2(-r, -r + c))
	_sprite.polygon = pts

func _notification(what: int) -> void:
	## Mất focus / ẩn -> nhả kéo, tránh kẹt.
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_cancel_drag()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_cancel_drag()

func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		z_index = 0

## Danh dau su kien da duoc xu ly — AN TOAN khi node sap bi go.
##
## Loi da gap (shell bat duoc, piece.gd:68): _end_drag() phat tin hieu 'placed',
## man choi goi change_scene_to_file() -> node nay bi go khoi cay ngay lap tuc.
## Sau do get_viewport() tra ve null -> goi set_input_as_handled() tren null
## => "Attempt to call function on a null instance".
##
## Cach sua: lay viewport TRUOC khi lam bat cu viec gi co the doi scene,
## va kiem tra null truoc khi dung.
func _mark_handled(vp: Viewport) -> void:
	if vp != null:
		vp.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _settled:
		return

	# Lay viewport NGAY DAU, truoc moi thao tac co the doi scene.
	var vp := get_viewport()
	if vp == null:
		return

	# Touch TRƯỚC, mouse SAU; đánh dấu handled để không double-fire.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		# CHI danh dau handled khi THUC SU tieu thu su kien.
		#
		# Loi da gap (test H02 bat duoc): truoc day goi set_input_as_handled()
		# VO DIEU KIEN, ke ca khi bam truot. Vi cac manh la sibling, manh CUOI
		# trong cay nhan _unhandled_input TRUOC; no "nuot" moi cu bam ke ca khi
		# truot, nen cac manh khac KHONG BAO GIO nhan duoc su kien.
		# Hau qua: chi 1 trong 3 manh keo duoc -> game khong the thang.
		if st.pressed and _hit(st.position):
			_begin_drag(st.position)
			_mark_handled(vp)
		elif not st.pressed and _dragging:
			_end_drag()
			_mark_handled(vp)
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _dragging:
			global_position = sd.position - _offset
			_mark_handled(vp)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _hit(mb.position):
				_begin_drag(mb.position)
				_mark_handled(vp)
			elif not mb.pressed and _dragging:
				_end_drag()
				_mark_handled(vp)
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			global_position = mm.position - _offset
			_mark_handled(vp)

func _hit(p: Vector2) -> bool:
	var d := p.distance_to(global_position)
	var ok := d <= 52.0
	# Chi log khi GAN trung (tranh spam tu cac manh khac)
	if d <= 200.0:
		_dbg("[PUZZLE] hit_test idx=%d press=%d,%d piece=%d,%d dist=%d -> %s" % [
			piece_index, int(p.x), int(p.y), int(global_position.x), int(global_position.y), int(d), str(ok)])
	return ok

func _begin_drag(p: Vector2) -> void:
	_dbg("[PUZZLE] begin_drag idx=%d press=%d,%d piece_at=%d,%d" % [
		piece_index, int(p.x), int(p.y), int(global_position.x), int(global_position.y)])
	_dragging = true
	_offset = p - global_position
	z_index = 10
	picked.emit(self)

func _end_drag() -> void:
	_dragging = false
	z_index = 0
	var d := global_position.distance_to(target_position)
	_dbg("[PUZZLE] end_drag idx=%d at=%d,%d target=%d,%d dist=%d snap=%d" % [
		piece_index, int(global_position.x), int(global_position.y),
		int(target_position.x), int(target_position.y), int(d), int(snap_radius)])
	if d <= snap_radius:
		global_position = target_position
		_settled = true
		placed.emit(self, true)
	else:
		placed.emit(self, false)

## Log chẩn đoán chỉ chạy trong editor/bản debug; bản release không in gì.
func _dbg(msg: String) -> void:
	if OS.is_debug_build():
		print(msg)
