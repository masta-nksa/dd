class_name GroundItem
extends Node2D
## Etwas, das auf dem Boden liegt (Waffe, Heilung, Geld): hüpft beim Herausfallen und verschwindet nach einer Weile.

var pos_x := 0.0
var pos_z := 0.0
var pos_y := 40.0
var velocity_y := 260.0
var age := 0.0
var lifetime := 14.0
var blinking := false      # blinkt die ganze Zeit (Waffe eines gestorbenen Spielers)
var items: WorldItems

func place(x: float, z: float) -> void:
	pos_x = x
	pos_z = z
	_apply()

func _apply() -> void:
	position = Vector2(pos_x, pos_z - pos_y)
	z_index = int(pos_z)

func _physics_process(delta: float) -> void:
	age += delta
	if pos_y > 0.0 or velocity_y > 0.0:
		velocity_y -= 1800.0 * delta
		pos_y = maxf(pos_y + velocity_y * delta, 0.0)
		if pos_y == 0.0:
			velocity_y = 0.0
	_apply()
	if age > lifetime:
		remove()
	queue_redraw()

func remove() -> void:
	items.forget(self)
	queue_free()

func is_visible_now() -> bool:
	if blinking:
		return fmod(age * 6.0, 1.0) <= 0.6
	return not (age > lifetime - 3.0 and int(age * 10.0) % 2 == 1)

func _draw() -> void:
	Art.shadow(self, 0.0, pos_y + 2.0, shadow_width())
	if is_visible_now():
		draw_item()

func shadow_width() -> float:
	return 26.0 / (1.0 + pos_y / 120.0)

func draw_item() -> void:
	pass
