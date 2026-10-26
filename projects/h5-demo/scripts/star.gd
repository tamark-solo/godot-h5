extends Area2D
## Ngôi sao rơi: physics đơn giản (vận tốc + trọng lực nhẹ), không dùng RigidBody.

signal caught(star: Area2D)
signal missed(star: Area2D)

@export var fall_speed: float = 260.0
## KHONG dat ten la 'gravity': Area2D da co property native 'gravity'
## (scene/2d/physics/area_2d.cpp:661) -> se bao "Member gravity redefined".
@export var fall_gravity: float = 180.0
@export var horizontal_drift: float = 0.0

var _velocity := Vector2.ZERO
var _resolved := false

func _ready() -> void:
	add_to_group("stars")
	_velocity = Vector2(horizontal_drift, fall_speed)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _resolved:
		return
	_velocity.y += fall_gravity * delta
	position += _velocity * delta

	var vp := get_viewport_rect().size
	if position.x < 18.0 or position.x > vp.x - 18.0:
		_velocity.x = -_velocity.x
		position.x = clampf(position.x, 18.0, vp.x - 18.0)

	if position.y > vp.y + 60.0:
		_resolved = true
		missed.emit(self)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _resolved:
		return
	if area.is_in_group("player"):
		_resolved = true
		caught.emit(self)
		queue_free()