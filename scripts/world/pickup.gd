class_name Pickup
extends GroundItem
## Heilung (Huhn, Apfel) oder Geld; wird beim Berühren eingesammelt.

const KINDS := {
	&"chicken": {"heal": 40, "score": 0},
	&"apple": {"heal": 15, "score": 0},
	&"money": {"heal": 0, "score": 1000},
}

var kind: StringName = &"apple"

func collect(f: Fighter) -> void:
	var d: Dictionary = KINDS[kind]
	SoundBank.play(&"collect")
	if d["heal"] > 0:
		f.current_health = mini(f.max_health, f.current_health + d["heal"])
		items.effects.text(pos_x, pos_z, 70.0, "+%d HP" % d["heal"], Color(0.4, 1.0, 0.4))
	if d["score"] > 0:
		f.score += d["score"]
		items.effects.text(pos_x, pos_z, 70.0, "+%d" % d["score"], Color(1.0, 0.9, 0.3))
	remove()

func draw_item() -> void:
	var outline := Color(0.12, 0.1, 0.14)
	match kind:
		&"chicken":
			draw_circle(Vector2(0, -12), 11.0, outline)
			draw_circle(Vector2(0, -12), 9.0, Color(0.78, 0.45, 0.18))
			draw_line(Vector2(6, -6), Vector2(16, 2), Color(0.95, 0.92, 0.85), 4.0)
			draw_circle(Vector2(17, 3), 3.0, Color(0.95, 0.92, 0.85))
		&"apple":
			draw_circle(Vector2(0, -9), 9.0, outline)
			draw_circle(Vector2(0, -9), 7.5, Color(0.85, 0.15, 0.15))
			draw_line(Vector2(0, -17), Vector2(2, -22), Color(0.4, 0.25, 0.1), 2.0)
			draw_rect(Rect2(2, -22, 6, 3), Color(0.3, 0.7, 0.25))
		_:
			draw_circle(Vector2(0, -11), 11.0, outline)
			draw_circle(Vector2(0, -11), 9.0, Color(1.0, 0.82, 0.2))
			draw_string(ThemeDB.fallback_font, Vector2(-5, -6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.35, 0.05))
