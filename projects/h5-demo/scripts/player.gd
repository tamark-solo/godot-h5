extends Area2D
## D04 — Người chơi: điều khiển bằng chuột VÀ touch, không double-fire.
##
## - Theo con trỏ/finger ngang.
## - Khi thả ngoài canvas hoặc mất focus: dừng, KHÔNG kẹt trạng thái.
## - Chỉ dùng sự kiện input (không polling) để tránh lệch giữa mouse và touch.

@export var follow_smoothing: float = 18.0
@export var horizontal_margin: float = 40.0

var _target_x: float = 0.0
var _dragging: bool = false

func _ready() -> void:
	_target_x = global_position.x
	add_to_group("player")

func _notification(what: int) -> void:
	## Mất focus (chuyển tab, home, alt-tab) -> nhả kéo, tránh kẹt.
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_dragging = false
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	# Lay viewport NGAY DAU va kiem tra null.
	# Bai hoc tu fixture 2 (H02): khi scene doi, node bi go khoi cay ngay lap tuc;
	# get_viewport() sau do tra ve null -> "call on a null instance".
	# Fixture nay chi co MOT doi tuong nhan input nen hau qua nhe hon, nhung
	# van phai phong ngua: game ket thuc se doi scene.
	var vp := get_viewport()
	if vp == null:
		return

	## Touch trước, mouse sau. Godot có thể emulate mouse từ touch —
	## nếu đã xử lý touch thì đánh dấu handled để không double-fire.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
		if st.pressed:
			_target_x = st.position.x
		vp.set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_dragging = true
		_target_x = sd.position.x
		vp.set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_target_x = mb.position.x
			vp.set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_target_x = mm.position.x

func _physics_process(delta: float) -> void:
	var vp := get_viewport_rect().size
	var clamped := clampf(_target_x, horizontal_margin, vp.x - horizontal_margin)
	global_position.x = lerpf(global_position.x, clamped, clampf(follow_smoothing * delta, 0.0, 1.0))
