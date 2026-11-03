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
		items.effects.text(pos_x, pos_z, 70.0, "+%d HP" % d["heal"], Art.GREEN)
	if d["score"] > 0:
		f.score += d["score"]
		items.effects.text(pos_x, pos_z, 70.0, "+%d" % d["score"], Art.YELLOW)
	remove()

func draw_item() -> void:
	var o := Vector2(0.0, -6.0 - 3.0 * absf(sin(age * 4.0)))
	var outline := Art.OUTLINE
	match kind:
		&"chicken":
			_oval(o + Vector2(-18, -4), Vector2(36, 12), Color8(235, 235, 240), outline)
			_oval(o + Vector2(-13, -14), Vector2(22, 16), Color8(190, 110, 45), outline)
			draw_line(o + Vector2(6, -6), o + Vector2(15, -11), Color8(250, 245, 230), 4.0)
			draw_circle(o + Vector2(16, -12), 3.0, Color8(250, 245, 230))
			_oval(o + Vector2(-9, -12), Vector2(9, 5), Color8(225, 150, 80))
		&"apple":
			draw_circle(o + Vector2(0, -6), 10.0, outline)
			draw_circle(o + Vector2(0, -6), 8.5, Color8(215, 35, 40))
			draw_circle(o + Vector2(-3, -9), 2.0, Color8(255, 140, 140))
			draw_line(o + Vector2(0, -14), o + Vector2(1, -19), Color8(90, 60, 30), 2.0)
			_oval(o + Vector2(2, -20), Vector2(9, 5), Color8(70, 180, 70))
		_:
			for d: Vector2 in [Vector2(-8, 0), Vector2(6, 0), Vector2(-1, -5), Vector2(0, -10)]:
				var at := o + d + Vector2(-9, -5)
				_oval(at + Vector2(0, 2), Vector2(18, 8), Color8(200, 160, 40))
				_oval(at, Vector2(18, 8), Color8(255, 215, 70), outline, 1.0)
			draw_circle(o + Vector2(3, -14), 2.0, Color(1.0, 1.0, absf(sin(age * 3.0))))

func _oval(at: Vector2, dim: Vector2, color: Color, outline := Color(0, 0, 0, 0), width := 2.0) -> void:
	var pts := Art.ellipse_points(at + dim * 0.5, dim.x * 0.5, dim.y * 0.5, 18)
	draw_colored_polygon(pts, color)
	if outline.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, outline, width)
