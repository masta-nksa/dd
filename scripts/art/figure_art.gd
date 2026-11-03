class_name FigureArt
extends RefCounted
## Zeichnet eine Figur aus einfachen Formen (Port von `zeichne_figur` aus `grafik.py`).
## Eine Figur ist ein Skelett aus Gelenken; die Pose (siehe `Poses`) legt die Winkel fest.
## Gezeichnet wird von hinten nach vorne: hinteres Bein, hinterer Arm, Rumpf, vorderes Bein, Kopf, vorderer Arm.
## Gerechnet wird lokal: Ursprung am Fusspunkt, +x in Blickrichtung, y nach unten. Erst `_p` spiegelt und kippt.

const THIGH := 21.0
const SHIN := 21.0
const TORSO := 30.0
const NECK := 3.0
const HEAD_RADIUS := 10.0
const UPPER_ARM := 15.0
const FOREARM := 15.0
const FOOT := 9.0
const HEIGHT := THIGH + SHIN + TORSO + NECK + 2.0 * HEAD_RADIUS

static var _art := FigureArt.new()

var _ci: CanvasItem
var _origin := Vector2.ZERO
var _dir := 1.0
var _shift := 0.0
var _cos := 1.0
var _sin := 0.0
var _offset := 0.0
var _lift := 0.0
var _s := 1.0
var _d := 1.0
var _white := false
var _outline := Art.OUTLINE
var _skin: Dictionary
var _head_pos := Vector2.ZERO
var _head_angle := 0.0
var _head_r := 10.0

## holder: wird zuletzt gerufen und bekommt (vordere Hand, vorderer Ellbogen, hintere Hand, hinterer Ellbogen, Skala).
static func draw(ci: CanvasItem, skin: Dictionary, pose: Dictionary, x: float, y: float, facing: int, scale := 1.0,
		white := false, time := 0.0, holder := Callable()) -> void:
	_art._draw_figure(ci, skin, pose, x, y, facing, scale, white, time, holder)

## Kopf der Figur vergrössert für ein Porträt: Fusspunkt so, dass der Kopf bei `center` liegt.
static func portrait_foot(center: Vector2, scale: float) -> Vector2:
	return Vector2(center.x - 2.0 * scale, center.y + (HEIGHT - HEAD_RADIUS - 3.0) * scale)

func _p(q: Vector2) -> Vector2:
	var ly := q.y + _shift
	return _origin + Vector2(_dir * (q.x * _cos - ly * _sin + _offset), q.x * _sin + ly * _cos - _lift)

func _c(color: Color) -> Color:
	return Color.WHITE if _white else color

func _limb(start: Vector2, a1: float, l1: float, a2: float, l2: float) -> Array:
	var r1 := deg_to_rad(a1)
	var r2 := deg_to_rad(a2)
	var mid := start + Vector2(sin(r1), cos(r1)) * l1 * _s
	return [mid, mid + Vector2(sin(r2), cos(r2)) * l2 * _s]

func _draw_figure(ci: CanvasItem, skin: Dictionary, p: Dictionary, x: float, y: float, facing: int, scale: float,
		white: bool, time: float, holder: Callable) -> void:
	_ci = ci
	_skin = skin
	_origin = Vector2(x, y)
	_dir = -float(facing) if p["flip"] > 0.5 else float(facing)
	_s = scale
	_d = float(skin["build"]) * scale
	_white = white
	_outline = Color8(210, 210, 225) if white else Art.OUTLINE

	var hip := Vector2(0.0, -(THIGH + SHIN) * _s + p["low"] * _s)
	var lean: float = deg_to_rad(p["lean"])
	var neck := hip + Vector2(sin(lean), -cos(lean)) * TORSO * _s
	var shoulder := hip.lerp(neck, 0.86)
	_head_angle = lean + deg_to_rad(p["head"])
	_head_pos = neck + Vector2(sin(_head_angle), -cos(_head_angle)) * (NECK + HEAD_RADIUS) * _s

	var hip_back := hip - Vector2(2.0 * _s, 0.0)
	var shoulder_back := shoulder - Vector2(3.0 * _s, 0.0)
	var front_leg := _limb(hip, p["fh"], THIGH, p["fh"] - p["fk"], SHIN)
	var back_leg := _limb(hip_back, p["bh"], THIGH, p["bh"] - p["bk"], SHIN)
	var front_arm := _limb(shoulder, p["fs"], UPPER_ARM, p["fs"] + p["fe"], FOREARM)
	var back_arm := _limb(shoulder_back, p["bs"], UPPER_ARM, p["bs"] + p["be"], FOREARM)

	# Steht die Figur, kommt der tiefste Fuss genau auf den Boden
	var turn: float = deg_to_rad(p["turn"])
	_shift = 0.0
	if absf(p["turn"]) < 1.0:
		_shift = -maxf(front_leg[1].y, back_leg[1].y) - 3.0 * _d
	_cos = cos(turn)
	_sin = sin(turn)
	_offset = -_sin * 40.0 * _s
	_lift = absf(_sin) * 7.0 * _s

	_draw_leg(hip_back, back_leg[0], back_leg[1], p["bh"] - p["bk"], true)
	_draw_arm(shoulder_back, back_arm[0], back_arm[1], true)
	_draw_torso(hip, shoulder, neck)
	_draw_leg(hip, front_leg[0], front_leg[1], p["fh"] - p["fk"], false)
	_draw_head(neck, time)
	_draw_arm(shoulder, front_arm[0], front_arm[1], false)
	if holder.is_valid():
		holder.call(_p(front_arm[1]), _p(front_arm[0]), _p(back_arm[1]), _p(back_arm[0]), _s)

func _shade(color: Color, dark: bool) -> Color:
	return _c(Art.darker(color) if dark else color)

func _draw_leg(hip: Vector2, knee: Vector2, foot: Vector2, shin_angle: float, dark: bool) -> void:
	var pants: Color = _skin["pants"]
	Art.capsule(_ci, _p(hip), _p(knee), 5.2 * _d, _shade(pants, dark), _outline, 4.6 * _d)
	Art.capsule(_ci, _p(knee), _p(foot), 4.6 * _d, _shade(pants, dark), _outline, 4.0 * _d)
	var a := deg_to_rad(shin_angle)
	var along := Vector2(cos(a), -sin(a))   # der Fuss zeigt nach vorne
	Art.capsule(_ci, _p(foot - along * 2.0 * _s), _p(foot + along * FOOT * _s), 3.4 * _d, _shade(_skin["shoes"], dark), _outline)

func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, dark: bool) -> void:
	var skin: Color = _skin["skin"]
	var upper: Color = _skin["top"] if _skin["sleeves"] and _skin["top"] != null else skin
	Art.capsule(_ci, _p(shoulder), _p(elbow), 4.2 * _d, _shade(upper, dark), _outline, 3.8 * _d)
	Art.capsule(_ci, _p(elbow), _p(hand), 3.7 * _d, _shade(skin, dark), _outline, 3.4 * _d)
	if &"gloves" in _skin["extras"]:
		Art.capsule(_ci, _p(hand), _p(hand), 5.0 * _d, _shade(_skin["gloves"], dark), _outline)
	else:
		Art.capsule(_ci, _p(hand), _p(hand), 4.4 * _d, _shade(skin, dark), _outline)

func _draw_torso(hip: Vector2, shoulder: Vector2, neck: Vector2) -> void:
	var t := neck - hip
	var length := maxf(t.length(), 1.0)
	var n := Vector2(-t.y, t.x) / length      # zeigt nach vorne (Brust)
	var color: Color = _skin["top"] if _skin["top"] != null else _skin.get("vest", _skin["skin"])
	Art.capsule(_ci, _p(hip), _p(shoulder), 7.4 * _d, _c(color), _outline, 9.6 * _d)
	if _skin["top"] == null:
		# offene Weste: vorne sieht man die Brust
		var skin := _c(_skin["skin"])
		Art.capsule(_ci, _p(hip + n * 4.0 * _d), _p(shoulder + n * 4.5 * _d), 3.6 * _d, skin, skin, 5.2 * _d)
	elif not _white:
		# Lichtkante vorne am Oberteil
		_ci.draw_line(_p(hip + n * 4.5 * _d - Vector2(0.0, 2.0 * _s)), _p(shoulder + n * 5.5 * _d), Art.lighter(color, 0.3), maxf(1.0, 2.5 * _s))
	# Gürtel
	var up := t / length * 2.0
	_ci.draw_line(_p(hip + n * 7.6 * _d - up), _p(hip - n * 7.6 * _d - up), _c(_skin["belt"]), maxf(2.0, 3.5 * _s))
	if &"chain" in _skin["extras"] and not _white:
		for i in 5:
			var f := 0.2 + i * 0.16
			var link := neck + n * (2.0 + i * 1.6) * _d - (neck - shoulder) * f * 3.0
			_ci.draw_circle(_p(link), maxf(1.5, 1.8 * _s), Color8(240, 200, 70))

## Punkt am Kopf: theta in Grad ab «oben», positiv = nach vorne; factor = Anteil vom Radius.
func _hp(theta: float, factor: float) -> Vector2:
	var a := _head_angle + deg_to_rad(theta)
	return _head_pos + Vector2(sin(a), -cos(a)) * _head_r * factor

func _hp_arc(from: int, to: int, step: int, factor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for t in range(from, to, step):
		pts.append(_p(_hp(t, factor)))
	return pts

func _draw_head(neck: Vector2, time: float) -> void:
	var skin: Color = _skin["skin"]
	var hair: Color = _skin["hair"]
	var style: StringName = _skin["hairstyle"]
	_head_r = HEAD_RADIUS * _s * (1.0 + (float(_skin["build"]) - 1.0) * 0.3)
	var wave := sin(time * 9.0)
	if style == &"ponytail":
		var root := _hp(-105.0, 0.9)
		var mid := root + Vector2(-7.0, 5.0 + wave * 1.5) * _s
		var end := root + Vector2(-12.0, 13.0 + wave * 3.0) * _s
		Art.capsule(_ci, _p(root), _p(mid), 3.6 * _s, _c(hair), _outline, 3.2 * _s)
		Art.capsule(_ci, _p(mid), _p(end), 3.2 * _s, _c(hair), _outline, 2.0 * _s)
	# Hals und Kopf
	Art.capsule(_ci, _p(neck), _p(neck), 3.6 * _d, _c(Art.darker(skin, 0.9)), _outline)
	Art.capsule(_ci, _p(_head_pos), _p(_head_pos), _head_r, _c(skin), _outline)

	match style:
		&"short", &"ponytail":
			var pts := _hp_arc(45, -136, -15, 1.1)
			pts.append_array(_hp_arc(-110, 31, 20, 0.6))
			_ci.draw_colored_polygon(pts, _c(hair))
		&"spikes":
			var outer := PackedVector2Array()
			var i := 0
			for t in range(40, -141, -12):
				outer.append(_p(_hp(t, 1.15 if i % 2 == 1 else 1.5)))
				i += 1
			var pts := outer.duplicate()
			pts.append_array(_hp_arc(-120, 31, 30, 0.65))
			_ci.draw_colored_polygon(pts, _c(hair))
			_ci.draw_polyline(outer, _outline, 1.0)
		&"mohawk":
			for t in range(25, -96, -24):
				var tri := PackedVector2Array([_p(_hp(t + 9, 0.95)), _p(_hp(t - 6, 1.75)), _p(_hp(t - 9, 0.95))])
				_ci.draw_colored_polygon(tri, _c(hair))
				tri.append(tri[0])
				_ci.draw_polyline(tri, _outline, 1.0)
		&"bald":
			if not _white:
				_ci.draw_circle(_p(_hp(-15.0, 0.55)), maxf(1.5, _head_r * 0.22), Art.lighter(skin, 0.45))
	if _white:
		return

	# Gesicht: alles auf der Vorderseite, so sieht man sofort, wohin die Figur schaut
	_ci.draw_circle(_p(_hp(-80.0, 0.15)), maxf(1.5, _head_r * 0.22), Art.darker(skin, 0.8))   # Ohr
	if &"glasses" in _skin["extras"]:
		var dark := Color8(10, 10, 12)
		_ci.draw_line(_p(_hp(-70.0, 0.98)), _p(_hp(60.0, 0.62)), dark, maxf(2.0, 2.0 * _s))
		_ci.draw_line(_p(_hp(48.0, 0.62)), _p(_hp(88.0, 1.02)), dark, maxf(3.0, 4.4 * _s))
		_ci.draw_circle(_p(_hp(66.0, 0.78)), maxf(1.0, 1.1 * _s), Color8(120, 200, 255))
	else:
		_ci.draw_circle(_p(_hp(66.0, 0.62)), maxf(1.5, 2.1 * _s), Color.WHITE)
		_ci.draw_circle(_p(_hp(70.0, 0.68)), maxf(1.0, 1.3 * _s), Color8(20, 20, 30))
		_ci.draw_line(_p(_hp(50.0, 0.72)), _p(_hp(80.0, 0.84)), Art.darker(hair, 0.8), maxf(1.0, 2.0 * _s))
	_ci.draw_circle(_p(_hp(96.0, 1.0)), maxf(1.5, 1.9 * _s), Art.darker(skin, 0.88))         # Nase
	_ci.draw_line(_p(_hp(122.0, 0.72)), _p(_hp(135.0, 0.62)), Color8(120, 50, 50), maxf(1.0, 1.5 * _s))   # Mund
	if &"beard" in _skin["extras"]:
		var beard := _hp_arc(100, 211, 22, 1.08)
		beard.append(_p(_hp(150.0, 0.45)))
		_ci.draw_colored_polygon(beard, hair)

	if _skin["band"] != null:
		var band: Color = _skin["band"]
		var back := _hp(-88.0, 1.0)
		_ci.draw_line(_p(_hp(32.0, 1.0)), _p(back), band, maxf(2.0, 3.5 * _s))
		# die Bänder flattern nach hinten: zweiter Richtungsanzeiger
		_ci.draw_line(_p(back), _p(back + Vector2(-11.0, 2.0 + wave * 2.5) * _s), band, maxf(2.0, 3.0 * _s))
		_ci.draw_line(_p(back), _p(back + Vector2(-9.0, 7.0 - wave * 2.0) * _s), Art.darker(band), maxf(2.0, 3.0 * _s))
