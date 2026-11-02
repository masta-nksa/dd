class_name CameraRig
extends Camera2D
## Hält alle Ziele im Bild: folgt dem Mittelpunkt und bleibt im Level.

var targets: Array[Fighter] = []
@export var follow_speed := 6.0

func _ready() -> void:
	limit_left = 0
	limit_right = int(Level.WIDTH)
	limit_top = 0
	limit_bottom = int(Level.HEIGHT)
	make_current()

func _process(delta: float) -> void:
	if targets.is_empty():
		return
	var sum := 0.0
	for t in targets:
		sum += t.pos_x
	var goal := sum / targets.size()
	position.x = lerpf(position.x, goal, clampf(follow_speed * delta, 0.0, 1.0))
	position.y = Level.HEIGHT * 0.5
