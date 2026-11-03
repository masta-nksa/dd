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

static var _glow: GradientTexture2D = null
static var _glow_material: CanvasItemMaterial = null

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
		&"crate": p.color = Color8(165, 112, 58)
		&"barrel": p.color = [Color8(40, 90, 170), Color8(170, 50, 40), Color8(60, 120, 70)].pick_random()
		&"bin": p.color = Color8(140, 146, 152)
		_: p.color = Color8(52, 58, 72)
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

func _ready() -> void:
	if kind == &"lamp":
		_add_light(Vector2(42.0, -height + 10.0))   # Lichtkegel an der Lampe
		_add_light(Vector2(86.0, -10.0))            # und sein Schein auf dem Boden

func _add_light(at: Vector2) -> void:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		var core := Color8(46, 39, 23)
		gradient.colors = PackedColorArray([core, Art.darker(core, 0.54), Art.darker(core, 0.16), Color.BLACK])
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 160
		_glow.height = 160
		_glow_material = CanvasItemMaterial.new()
		_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var light := Sprite2D.new()
	light.texture = _glow
	light.material = _glow_material
	light.position = at
	add_child(light)

func _draw() -> void:
	if in_hands:
		return
	if kind == &"lamp":
		Art.shadow(self, 0.0, 1.0, 26.0)
	else:
		Art.shadow(self, 4.0, 2.0, width * 1.3)
	var wob := Vector2(sin(shake * 80.0) * 3.0, 0.0) if shake > 0.0 else Vector2.ZERO
	draw_art(self, kind, width, height, color, float(hp) / float(max_hp), wob)

## Zeichnet ein Requisit; `origin` ist der Fusspunkt (Mitte unten). Wird auch für Getragenes und Geworfenes genutzt.
static func draw_art(ci: CanvasItem, art_kind: StringName, w: float, h: float, col: Color, health: float, origin := Vector2.ZERO) -> void:
	var outline := Art.OUTLINE
	match art_kind:
		&"crate":
			var r := Rect2(origin.x - w * 0.5, origin.y - h + 8.0, w, h)
			var lid := PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w - 6, -12), r.position + Vector2(6, -12)])
			ci.draw_colored_polygon(lid, Color8(196, 146, 84))
			_outline(ci, lid, outline)
			ci.draw_rect(r, col)
			for i in range(1, 4):
				var y := r.position.y + i * h * 0.25
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color8(125, 82, 40), 2.0)
			ci.draw_line(r.position, r.end, Color8(120, 78, 38), 4.0)
			ci.draw_rect(r.grow(-2.5), Color8(130, 86, 42), false, 5.0)
			ci.draw_rect(r, outline, false, 2.0)
			if health < 1.0:
				ci.draw_line(Vector2(origin.x - 4, r.position.y + 6), Vector2(origin.x + 6, r.position.y + 20), outline, 2.0)
		&"barrel":
			var r := Rect2(origin.x - w * 0.5, origin.y - h + 6.0, w, h)
			ci.draw_rect(r, col)
			ci.draw_rect(Rect2(r.position.x + 5, r.position.y, 6, h), Art.lighter(col, 0.25))
			ci.draw_rect(Rect2(r.end.x - 8, r.position.y, 8, h), Art.darker(col))
			for f: float in [0.2, 0.75]:
				var y := r.position.y + h * f
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Art.darker(col, 0.55), 3.0)
			ci.draw_colored_polygon(Art.ellipse_points(Vector2(origin.x, r.end.y), w * 0.5, 6.0, 18), Art.darker(col, 0.6))
			ci.draw_rect(r, outline, false, 2.0)
			var lid := Art.ellipse_points(Vector2(origin.x, r.position.y), w * 0.5, 6.0, 18)
			ci.draw_colored_polygon(lid, Art.lighter(col, 0.15))
			_outline(ci, lid, outline)
			ci.draw_circle(Vector2(origin.x + 6, r.position.y), 3.0, Art.darker(col, 0.5))
		&"bin":
			var body := PackedVector2Array([origin + Vector2(-w * 0.5, -h + 10), origin + Vector2(w * 0.5, -h + 10),
				origin + Vector2(w * 0.5 - 4, 6), origin + Vector2(-w * 0.5 + 4, 6)])
			ci.draw_colored_polygon(body, col)
			for i in range(-2, 3):
				ci.draw_line(origin + Vector2(i * 6, -h + 14), origin + Vector2(i * 6, 3), Color8(110, 115, 122), 2.0)
			_outline(ci, body, outline)
			var lid := Art.ellipse_points(origin + Vector2(0, -h + 8), w * 0.5 + 3.0, 6.0, 18)
			ci.draw_colored_polygon(lid, Color8(165, 170, 176))
			_outline(ci, lid, outline)
			ci.draw_rect(Rect2(origin.x - 5, origin.y - h - 1, 10, 4), outline)
		_:
			var top := origin.y - h
			ci.draw_rect(Rect2(origin.x - 7, origin.y - 16, 14, 18), Color8(40, 44, 56))
			ci.draw_rect(Rect2(origin.x - 3, top, 7, h - 14), Color8(52, 58, 72))
			ci.draw_line(Vector2(origin.x - 1, top), Vector2(origin.x - 1, origin.y - 16), Color8(80, 88, 104), 2.0)
			ci.draw_polyline(PackedVector2Array([Vector2(origin.x, top + 4), Vector2(origin.x + 14, top - 8), Vector2(origin.x + 40, top - 8)]), Color8(52, 58, 72), 5.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(origin.x + 28, top - 12), Vector2(origin.x + 56, top - 12),
				Vector2(origin.x + 50, top - 2), Vector2(origin.x + 34, top - 2)]), Color8(40, 44, 56))
			ci.draw_colored_polygon(Art.ellipse_points(Vector2(origin.x + 42, top - 2), 8.0, 3.0, 14), Color8(255, 236, 160))

static func _outline(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, 2.0)
