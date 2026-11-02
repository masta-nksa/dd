class_name WeaponPickup
extends GroundItem
## Eine Waffe am Boden. Wird nie automatisch eingesammelt, nur mit der Greifen-Taste.

var kind: StringName = &"bat"
var rest := 10

func draw_item() -> void:
	WeaponPickup.draw_bat(self, Vector2(-24, -5), Vector2(26, -11), float(rest) / 10.0)

static func draw_bat(ci: CanvasItem, grip: Vector2, tip: Vector2, ratio := 1.0, width := 6.0) -> void:
	var wood := Color(0.70, 0.49, 0.27)
	var dir := (tip - grip).normalized()
	var len := grip.distance_to(tip)
	ci.draw_line(grip, tip, Color(0.12, 0.1, 0.14), width + 2.5)
	ci.draw_line(grip, tip, wood, width)
	ci.draw_line(grip + dir * len * 0.55, grip + dir * len * 0.9, wood.lightened(0.35), width * 0.35)
	ci.draw_line(grip + dir * len * 0.04, grip + dir * len * 0.28, Color(0.2, 0.16, 0.17), width * 0.6)
	if ratio < 0.3:
		var n := Vector2(-dir.y, dir.x)
		for f: float in [0.62, 0.78]:
			var m := grip + dir * len * f
			ci.draw_line(m - n * 4.0, m + n * 2.0, Color(0.12, 0.1, 0.14), 2.0)
