class_name Art
extends RefCounted
## Gemeinsame Zeichenhilfen (Port der Hilfsfunktionen aus `grafik.py`): Farben, Kapseln, Schatten, Text.

enum Anchor { CENTER, TOP_LEFT, TOP_RIGHT, MID_LEFT, MID_BOTTOM }

const OUTLINE := Color8(22, 18, 30)
const TEXT := Color8(240, 238, 245)
const YELLOW := Color8(255, 210, 60)
const ORANGE := Color8(255, 140, 40)
const RED := Color8(230, 50, 50)
const GREEN := Color8(90, 210, 100)
const GRAY := Color8(140, 140, 155)
const TITLE_SHADOW := Color8(120, 30, 40)
const PLAYER_COLORS: Array[Color] = [Color8(70, 150, 255), Color8(255, 80, 80)]

static var _font: FontVariation = null

static func darker(c: Color, factor := 0.74) -> Color:
	return Color(c.r * factor, c.g * factor, c.b * factor, c.a)

static func lighter(c: Color, amount := 0.35) -> Color:
	return Color(lerpf(c.r, 1.0, amount), lerpf(c.g, 1.0, amount), lerpf(c.b, 1.0, amount), c.a)

## Abgerundeter Balken von a nach b (Radius r1 bei a, r2 bei b) mit Umriss. r2 < 0 heisst: wie r1.
static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, r1: float, color: Color, outline := OUTLINE, r2 := -1.0) -> void:
	if r2 < 0.0:
		r2 = r1
	_capsule_layer(ci, a, b, r1 + 1.6, r2 + 1.6, outline)
	_capsule_layer(ci, a, b, r1, r2, color)

static func _capsule_layer(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, color: Color) -> void:
	var d := b - a
	var length := d.length()
	if length > 0.5:
		var n := Vector2(-d.y, d.x) / length
		ci.draw_colored_polygon(PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), color)
	ci.draw_circle(a, ra, color)
	if length > 0.5:
		ci.draw_circle(b, rb, color)

static func ellipse_points(center: Vector2, rx: float, ry: float, count := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(count)
	for i in count:
		var angle := TAU * i / count
		pts[i] = center + Vector2(cos(angle) * rx, sin(angle) * ry)
	return pts

## Schatten am Boden: Ellipse mit Mittelpunkt (x, y).
static func shadow(ci: CanvasItem, x: float, y: float, width: float) -> void:
	var w := maxf(6.0, width)
	var h := maxf(4.0, w / 3.0)
	ci.draw_colored_polygon(ellipse_points(Vector2(x, y), w * 0.5, h * 0.5, 20), Color(0, 0, 0, 100.0 / 255.0))

## Farbiger Ring am Boden mit Pfeil in Blickrichtung.
static func player_ring(ci: CanvasItem, x: float, y: float, width: float, color: Color, facing: int) -> void:
	var pts := ellipse_points(Vector2(x, y), width * 0.5, width / 6.0, 28)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, 2.0)
	var tip_x := x + facing * (width * 0.5 + 9.0)
	var base_x := x + facing * (width * 0.5 + 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(tip_x, y), Vector2(base_x, y - 5.0), Vector2(base_x, y + 5.0)]), color)

## Schrift des Spiels: die eingebaute, etwas fetter, weil das Original eine fette Schrift nutzt.
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.6
	return _font

## Pygame-Schriftgrössen sind höher als Godot-Grössen; so bleiben die Zahlen aus dem Original gültig.
static func font_size(size: float) -> int:
	return maxi(8, roundi(size * 0.72))

static func text_size(text_value: String, size: float) -> Vector2:
	return font().get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(size))

## Text mit Umriss. size ist die Grösse wie im Original.
static func text(ci: CanvasItem, text_value: String, size: float, pos: Vector2, color := TEXT, anchor := Anchor.CENTER, outlined := true) -> void:
	var f := font()
	var fs := font_size(size)
	var dim := f.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var top_left := pos
	match anchor:
		Anchor.CENTER: top_left = pos - dim * 0.5
		Anchor.TOP_RIGHT: top_left = pos - Vector2(dim.x, 0.0)
		Anchor.MID_LEFT: top_left = pos - Vector2(0.0, dim.y * 0.5)
		Anchor.MID_BOTTOM: top_left = pos - Vector2(dim.x * 0.5, dim.y)
	var baseline := top_left + Vector2(0.0, f.get_ascent(fs))
	if outlined:
		ci.draw_string_outline(f, baseline, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(size) / 8), OUTLINE)
	ci.draw_string(f, baseline, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## Grosser Titel mit Schatten wie im Original.
static func title(ci: CanvasItem, text_value: String, size: float, pos: Vector2, color := YELLOW) -> void:
	text(ci, text_value, size, pos + Vector2(4.0, 5.0), TITLE_SHADOW)
	text(ci, text_value, size, pos, color)
