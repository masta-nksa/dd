class_name Prop
extends Node2D
## Requisit auf der Strasse: Kiste, Fass, Mülltonne (zerstörbar, tragbar, werfbar) und Laterne.
## Alle blockieren die Bewegung am Boden; wer hoch genug springt, fliegt drüber.

const DATA := {
	&"crate": {"w": 46.0, "d": 12.0, "h": 44.0, "hp": 3, "breakable": true, "grab": true},
	&"barrel": {"w": 32.0, "d": 10.0, "h": 50.0, "hp": 3, "breakable": true, "grab": true},
	&"bin": {"w": 34.0, "d": 10.0, "h": 46.0, "hp": 2, "breakable": true, "grab": true},
	&"lamp": {"w": 12.0, "d": 5.0, "h": 230.0, "hp": 1, "breakable": false, "grab": false},
}

var kind: StringName
var width: float
var depth: float
var height: float
var hp: int
var max_hp: int
var breakable: bool
var grabbable: bool
var color := Color.WHITE
var pos_x := 0.0
var pos_z := 0.0
var in_hands := false
var shake := 0.0

static func create(new_kind: StringName, x: float, z: float) -> Prop:
	var p := Prop.new()
	var d: Dictionary = DATA[new_kind]
	p.kind = new_kind
	p.width = d["w"]
	p.depth = d["d"]
	p.height = d["h"]
	p.hp = d["hp"]
	p.max_hp = d["hp"]
	p.breakable = d["breakable"]
	p.grabbable = d["grab"]
	match new_kind:
		&"crate": p.color = Color(0.67, 0.45, 0.24)
		&"barrel": p.color = [Color(0.16, 0.35, 0.67), Color(0.67, 0.2, 0.16), Color(0.24, 0.47, 0.27)].pick_random()
		&"bin": p.color = Color(0.59, 0.61, 0.63)
		_: p.color = Color(0.2, 0.22, 0.28)
	p.pos_x = x
	p.pos_z = z
	p.place()
	return p

func place() -> void:
	position = Vector2(pos_x, pos_z)
	z_index = int(pos_z)

func is_blocking() -> bool:
	return not in_hands

func hit_aabb() -> AABB:
	return AABB(Vector3(pos_x - width * 0.5, 0.0, pos_z - depth - 6.0), Vector3(width, height, 2.0 * (depth + 6.0)))

func debris_colors() -> Array:
	return [color, color.darkened(0.3), color.lightened(0.25)]

## Ein Treffer: wackelt, nach genug Treffern zerbricht es.
func hit(items: WorldItems) -> void:
	if not breakable:
		return
	hp -= 1
	shake = 0.15
	items.effects.debris(pos_x, pos_z, height * 0.6, debris_colors(), 5)
	if hp <= 0:
		items.break_prop(self, true)
	else:
		SoundBank.play(&"punch")

func _physics_process(delta: float) -> void:
	shake = maxf(shake - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if in_hands:
		return
	var s := width * 1.3
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(4 + cos(a) * s * 0.5, 2 + sin(a) * 6.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
	var wob := Vector2(sin(shake * 80.0) * 2.5, 0.0) if shake > 0.0 else Vector2.ZERO
	draw_art(self, kind, width, height, color, float(hp) / float(max_hp), wob)

## Zeichnet ein Requisit; `origin` ist der Fusspunkt (Mitte unten). Wird auch für Getragenes und Geworfenes genutzt.
static func draw_art(ci: CanvasItem, art_kind: StringName, w: float, h: float, col: Color, health: float, origin := Vector2.ZERO) -> void:
	var outline := Color(0.12, 0.1, 0.14)
	match art_kind:
		&"crate":
			var r := Rect2(origin.x - w * 0.5, origin.y - h, w, h)
			ci.draw_rect(r, col)
			ci.draw_rect(r, outline, false, 2.0)
			ci.draw_line(r.position + Vector2(3, 3), r.end - Vector2(3, 3), col.darkened(0.35), 3.0)
			ci.draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.position.y + 3), col.darkened(0.35), 3.0)
			ci.draw_rect(r.grow(-3), col.darkened(0.3), false, 2.0)
			if health < 0.7:
				ci.draw_line(origin + Vector2(-6, -h + 4), origin + Vector2(2, -h * 0.5), outline, 2.0)
		&"barrel":
			var r2 := Rect2(origin.x - w * 0.5, origin.y - h, w, h)
			ci.draw_rect(r2, col)
			ci.draw_rect(r2, outline, false, 2.0)
			for f in [0.2, 0.75]:
				ci.draw_rect(Rect2(r2.position.x, r2.position.y + h * f, w, 5), col.darkened(0.4))
			ci.draw_rect(Rect2(r2.position.x + 3, r2.position.y + 2, 5, h - 4), col.lightened(0.25))
			if health < 0.7:
				ci.draw_line(origin + Vector2(-4, -h + 6), origin + Vector2(4, -h * 0.4), outline, 2.0)
		&"bin":
			var pts := PackedVector2Array([origin + Vector2(-w * 0.5, -h + 6), origin + Vector2(w * 0.5, -h + 6),
				origin + Vector2(w * 0.4, 0), origin + Vector2(-w * 0.4, 0)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), outline, 2.0)
			ci.draw_rect(Rect2(origin.x - w * 0.55, origin.y - h, w * 1.1, 8), col.darkened(0.25))
			for i in range(-1, 2):
				ci.draw_line(origin + Vector2(i * 8, -h + 14), origin + Vector2(i * 7, -6), col.darkened(0.35), 2.0)
		_:
			ci.draw_rect(Rect2(origin.x - 3, origin.y - h + 14, 7, h - 14), Color(0.2, 0.23, 0.29))
			ci.draw_rect(Rect2(origin.x - 12, origin.y - h + 6, 24, 10), Color(0.16, 0.18, 0.24))
			ci.draw_circle(origin + Vector2(0, -h + 12), 9.0, Color(1.0, 0.9, 0.5, 0.45))
			ci.draw_rect(Rect2(origin.x - 6, origin.y - h + 8, 12, 6), Color(1.0, 0.92, 0.6))
