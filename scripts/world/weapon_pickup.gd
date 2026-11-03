class_name WeaponPickup
extends GroundItem
## Eine Waffe am Boden. Wird nie automatisch eingesammelt, nur mit der Greifen-Taste.

const WOOD := Color8(178, 126, 68)

var kind: StringName = &"bat"
var rest := 10

func draw_item() -> void:
	WeaponPickup.draw_bat(self, Vector2(-24, -5), Vector2(26, -11), float(rest) / 10.0)

func shadow_width() -> float:
	return 44.0 / (1.0 + pos_y / 120.0)

## Baseballschläger von grip nach tip (Port von `zeichne_schlaeger`). Unter 30 % Haltbarkeit hat er Risse.
static func draw_bat(ci: CanvasItem, grip: Vector2, tip: Vector2, ratio := 1.0, s := 1.0) -> void:
	var length := maxf(grip.distance_to(tip), 1.0)
	var dir := (tip - grip) / length
	Art.capsule(ci, grip, tip, 2.0 * s, WOOD, Art.OUTLINE, 4.6 * s)
	# helle Kante auf der dicken Seite und dunkles Griffband
	ci.draw_line(grip + dir * length * 0.55, grip + dir * length * 0.9, Art.lighter(WOOD), maxf(1.0, 2.0 * s))
	ci.draw_line(grip + dir * length * 0.04, grip + dir * length * 0.28, Color8(50, 40, 44), maxf(2.0, 3.4 * s))
	ci.draw_circle(grip, maxf(2.0, 3.2 * s), Art.darker(WOOD, 0.7))
	if ratio < 0.3:
		var n := Vector2(-dir.y, dir.x)
		for f: float in [0.62, 0.78]:
			var m := grip + dir * length * f
			ci.draw_line(m + n * 4.0 * s, m - n * 2.0 * s, Art.OUTLINE, 2.0)

## Kleines Bild der Waffe fürs HUD.
static func draw_symbol(ci: CanvasItem, kind_id: StringName, rect: Rect2) -> void:
	var data := WeaponData.get_data(kind_id)
	if data["heavy"]:
		var box := rect.grow_individual(-4.0, 0.0, -4.0, 0.0)
		ci.draw_rect(box, data["color"])
		ci.draw_rect(box, Art.OUTLINE, false, 2.0)
	else:
		draw_bat(ci, Vector2(rect.position.x + 3.0, rect.end.y - 3.0), Vector2(rect.end.x - 3.0, rect.position.y + 3.0), 1.0, 0.6)
