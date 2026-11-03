class_name LevelPainter
extends Node2D
## Malt eine Hintergrund-Ebene (Port der `male_*`-Funktionen aus `level.py`): einmal in eine Textur, danach
## wird nur noch diese gezeigt. Der Zufall hat einen festen Startwert, darum sieht das Level immer gleich aus.
## Lange Ebenen entstehen in mehreren Stücken; `_x_from`/`_x_to` lassen alles aus, was nicht im Stück liegt.

enum Layer { SKY, FAR, NEAR }

const WIDTH := 5400
const SCREEN_W := 960
const SCREEN_H := 540
const PARALLAX := 0.35
const HOUSE_BOTTOM := 300    # hier beginnt der Gehsteig
const KERB := 352            # hier beginnt die Fahrbahn
const FAR_WIDTH := int(SCREEN_W + (WIDTH - SCREEN_W) * PARALLAX) + 4
const ZONES := [[0, 1900, &"old_town"], [1900, 3700, &"industry"], [3700, WIDTH, &"harbour"]]
const GRAFFITI := ["ZACK!", "BOOM", "KAI+RIA", "WUMMS", "NKSA", "PAFF", "2P"]
const SIGNS := ["PIZZA", "BAR", "ARCADE", "KEBAB", "KIOSK", "HOTEL", "DISCO"]
const NEON := [Color8(255, 80, 180), Color8(80, 230, 255), Color8(255, 220, 60), Color8(120, 255, 120)]

var layer := Layer.NEAR
var x_from := 0
var x_to := WIDTH

var _r := RandomNumberGenerator.new()

static func zone_at(x: float) -> StringName:
	for z in ZONES:
		if x >= z[0] and x < z[1]:
			return z[2]
	return ZONES[-1][2]

func _draw() -> void:
	_r.seed = 1987 + int(layer)
	_set_origin()
	match layer:
		Layer.SKY: _paint_sky()
		Layer.FAR: _paint_far()
		Layer.NEAR: _paint_near()

func _set_origin() -> void:
	draw_set_transform(Vector2(-x_from, 0.0))

# ------------------------------------------------------------ Hilfen

func _pick(values: Array) -> Variant:
	return values[_r.randi_range(0, values.size() - 1)]

func _visible(left: float, right: float) -> bool:
	return right >= x_from and left <= x_to

func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	if _visible(x, x + w):
		draw_rect(Rect2(x, y, w, h), c)

## Rahmen, der wie bei pygame nach innen wächst.
func _frame(x: float, y: float, w: float, h: float, c: Color, t: float) -> void:
	if not _visible(x, x + w):
		return
	draw_rect(Rect2(x, y, w, t), c)
	draw_rect(Rect2(x, y + h - t, w, t), c)
	draw_rect(Rect2(x, y, t, h), c)
	draw_rect(Rect2(x + w - t, y, t, h), c)

func _line(x0: float, y0: float, x1: float, y1: float, c: Color, w := 1.0) -> void:
	if _visible(minf(x0, x1) - w, maxf(x0, x1) + w):
		draw_line(Vector2(x0, y0), Vector2(x1, y1), c, w)

## Linie, die nicht über den x-Bereich hinausragt (Maschendraht).
func _line_clipped(x0: float, y0: float, x1: float, y1: float, left: float, right: float, c: Color) -> void:
	var t0 := 0.0
	var t1 := 1.0
	var dx := x1 - x0
	if absf(dx) < 0.001:
		if x0 < left or x0 > right:
			return
	else:
		var a := (left - x0) / dx
		var b := (right - x0) / dx
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 >= t1:
			return
	_line(x0 + dx * t0, lerpf(y0, y1, t0), x0 + dx * t1, lerpf(y0, y1, t1), c)

func _poly(points: Array, c: Color) -> void:
	var left := INF
	var right := -INF
	var pts := PackedVector2Array()
	for q in points:
		pts.append(q)
		left = minf(left, q.x)
		right = maxf(right, q.x)
	if _visible(left, right):
		draw_colored_polygon(pts, c)

func _circle(x: float, y: float, r: float, c: Color) -> void:
	if _visible(x - r, x + r):
		draw_circle(Vector2(x, y), r, c)

func _ellipse(x: float, y: float, w: float, h: float, c: Color) -> void:
	if _visible(x, x + w):
		draw_colored_polygon(Art.ellipse_points(Vector2(x + w * 0.5, y + h * 0.5), w * 0.5, h * 0.5), c)

func _ellipse_ring(x: float, y: float, w: float, h: float, c: Color, t := 2.0) -> void:
	if not _visible(x, x + w):
		return
	var pts := Art.ellipse_points(Vector2(x + w * 0.5, y + h * 0.5), w * 0.5, h * 0.5)
	pts.append(pts[0])
	draw_polyline(pts, c, t)

func _text(value: String, size: float, pos: Vector2, c: Color, anchor := Art.Anchor.CENTER, outlined := true) -> void:
	var half := Art.text_size(value, size).x * 0.5 + 4.0
	if _visible(pos.x - half, pos.x + half):
		Art.text(self, value, size, pos, c, anchor, outlined, Art.painted_font())

# ------------------------------------------------------------ Himmel

func _paint_sky() -> void:
	var top := Color8(16, 12, 38)
	var bottom := Color8(150, 62, 82)
	for y in SCREEN_H:
		draw_rect(Rect2(0, y, SCREEN_W, 1), top.lerp(bottom, pow(minf(1.0, y / 300.0), 1.6)))
	for i in 90:
		var x := _r.randi_range(0, SCREEN_W - 1)
		var y := _r.randi_range(0, 199)
		var light := _r.randi_range(120, 255)
		draw_rect(Rect2(x, y, 1, 1), Color8(light, light, light))
	draw_circle(Vector2(780, 70), 30.0, Color8(250, 240, 210))
	draw_circle(Vector2(770, 62), 6.0, Color8(232, 220, 190))
	draw_circle(Vector2(790, 82), 4.0, Color8(232, 220, 190))

# ------------------------------------------------------------ Skyline

func _paint_far() -> void:
	# zwei Reihen: hinten dunkler und höher
	var rows := [[Color8(44, 30, 70), 120, 230, Color8(90, 80, 120)], [Color8(30, 22, 52), 70, 160, Color8(200, 170, 90)]]
	for row in 2:
		var color: Color = rows[row][0]
		var window: Color = rows[row][3]
		var x := -20
		while x < FAR_WIDTH:
			var b := _r.randi_range(50, 120)
			var h := _r.randi_range(rows[row][1], rows[row][2])
			var zone := zone_at(x / PARALLAX)
			var top := HOUSE_BOTTOM - h
			if zone == &"industry" and row == 1 and _r.randf() < 0.4:
				# Fabrik mit Schornstein
				_rect(x, HOUSE_BOTTOM - 60, b, 60, color)
				_rect(x + b / 3, top, 14, h, color)
				_rect(x + b / 3, top + 6, 14, 5, Color8(180, 40, 40))
			elif zone == &"harbour" and row == 0 and _r.randf() < 0.35:
				# Hafenkran
				_rect(x + 20, top, 10, h, color)
				_line(x - 30, top + 8, x + 110, top + 8, color, 6.0)
				_line(x + 25, top - 20, x + 100, top + 8, color, 2.0)
				_line(x + 25, top - 20, x - 30, top + 8, color, 2.0)
				_line(x + 90, top + 8, x + 90, top + 60, color)
			else:
				_rect(x, top, b, h, color)
				if _r.randf() < 0.3:
					_rect(x + b / 2 - 2, top - 25, 3, 25, color)
				for fy in range(top + 8, HOUSE_BOTTOM - 8, 12):
					for fx in range(x + 6, x + b - 6, 10):
						if _r.randf() < 0.28:
							_rect(fx, fy, 4, 5, window)
			x += b + _r.randi_range(-10, 15)

# ------------------------------------------------------------ Häuser

func _paint_graffiti(x: float, y: float) -> void:
	var word: String = _pick(GRAFFITI)
	var color: Color = _pick([Color8(255, 90, 160), Color8(90, 220, 255), Color8(255, 210, 60), Color8(140, 255, 120), Color8(200, 120, 255)])
	var size := _r.randi_range(34, 48)
	var angle := deg_to_rad(_r.randf_range(-10.0, 10.0))
	if not _visible(x - 90.0, x + 90.0):
		return
	draw_set_transform(Vector2(x - x_from, y), angle)
	Art.text(self, word, size, Vector2.ZERO, color, Art.Anchor.CENTER, true, Art.painted_font())
	_set_origin()

func _paint_old_town(x: int, width: int) -> void:
	var height := _r.randi_range(170, 290)
	var top := HOUSE_BOTTOM - height
	var wall: Color = _pick([Color8(120, 62, 52), Color8(96, 70, 60), Color8(78, 76, 98), Color8(112, 92, 64), Color8(70, 84, 80)])
	_rect(x, top, width, height, wall)
	# Backsteine andeuten
	var brick := Art.darker(wall, 0.85)
	for y in range(top + 4, HOUSE_BOTTOM, 8):
		var shift := 0 if (y / 8) % 2 == 1 else 9
		for bx in range(x + shift, x + width, 18):
			_line(bx, y, bx, y + 7, brick)
		_line(x, y, x + width, y, brick)
	_rect(x - 4, top - 8, width + 8, 10, Art.darker(wall, 0.6))
	# Fenster
	var sash := Color8(40, 30, 30)
	for fy in range(top + 22, HOUSE_BOTTOM - 110, 52):
		for fx in range(x + 18, x + width - 40, 54):
			var glass := Color8(255, 214, 120) if _r.randf() < 0.45 else Color8(36, 40, 66)
			_rect(fx - 3, fy - 3, 34, 42, sash)
			_rect(fx, fy, 28, 36, glass)
			_line(fx + 14, fy, fx + 14, fy + 36, sash, 2.0)
			_line(fx, fy + 18, fx + 28, fy + 18, sash, 2.0)
			_rect(fx - 5, fy + 38, 38, 4, Art.darker(wall, 0.7))
	# Erdgeschoss: Laden oder Tür
	if _r.randf() < 0.6:
		var left := x + 14
		var right := x + width - 14
		var shop_top := HOUSE_BOTTOM - 88
		_rect(left, shop_top, right - left, 88, Color8(30, 34, 50))
		_rect(left + 6, shop_top + 23, right - left - 12, 58, Color8(70, 110, 130))
		var awning: Color = _pick([Color8(200, 50, 50), Color8(40, 120, 200), Color8(60, 150, 80), Color8(220, 160, 40)])
		var i := 0
		for sx in range(left - 6, right + 6, 16):
			_poly([Vector2(sx, shop_top - 20), Vector2(sx + 16, shop_top - 20), Vector2(sx + 20, shop_top), Vector2(sx + 4, shop_top)],
				awning if i % 2 == 0 else Color8(235, 230, 220))
			i += 1
		var neon: Color = _pick(NEON)
		_text(_pick(SIGNS), 30, Vector2((left + right) * 0.5, shop_top - 24), neon, Art.Anchor.MID_BOTTOM)
	else:
		var door_x := x + width / 2 - 20
		var door_y := HOUSE_BOTTOM - 70
		_rect(door_x, door_y, 40, 70, Color8(60, 40, 30))
		_frame(door_x, door_y, 40, 70, Color8(30, 20, 16), 3.0)
		_circle(door_x + 31, door_y + 35, 3.0, Color8(220, 190, 80))
		_rect(door_x - 6, HOUSE_BOTTOM - 6, 52, 6, Color8(90, 90, 100))
		if _r.randf() < 0.7:
			_paint_graffiti(x + _r.randi_range(30, width - 30), HOUSE_BOTTOM - _r.randi_range(25, 45))
	_line(x, top, x, HOUSE_BOTTOM, Art.darker(wall, 0.5), 2.0)

func _paint_fence(x: int, width: int) -> void:
	# Maschendrahtzaun: dahinter sieht man die Skyline
	var base := HOUSE_BOTTOM - 162
	var top := base + 12
	var wire := Color8(120, 126, 132)
	for d in range(-150, width + 150, 14):
		_line_clipped(x + d, top, x + d + 150, base + 162, x, x + width, wire)
		_line_clipped(x + d + 150, top, x + d, base + 162, x, x + width, wire)
	for px in range(0, width, 60):
		_rect(x + px, top - 6, 6, 156, Color8(70, 74, 80))
	_line(x, top, x + width, top, Color8(90, 94, 100), 3.0)
	for px in range(0, width, 10):   # Stacheldraht
		_line(x + px, top - 10, x + px + 6, top - 4, Color8(150, 150, 160))

func _paint_industry(x: int, width: int) -> void:
	if _r.randf() < 0.4:
		_paint_fence(x, width)
		return
	var height := _r.randi_range(190, 240)
	var top := HOUSE_BOTTOM - height
	var wall: Color = _pick([Color8(84, 98, 92), Color8(110, 104, 84), Color8(76, 86, 104)])
	_rect(x, top, width, height, wall)
	for wx in range(x, x + width, 10):
		_line(wx, top, wx, HOUSE_BOTTOM, Art.lighter(wall, 0.12), 2.0)
		_line(wx + 5, top, wx + 5, HOUSE_BOTTOM, Art.darker(wall, 0.8))
	_rect(x, top, width, 8, Art.darker(wall, 0.6))
	# Rohre
	_rect(x, top + 40, width, 10, Color8(130, 70, 40))
	_rect(x, top + 48, width, 3, Color8(90, 50, 30))
	# Warnstreifen und Tor
	var gate_x := x + width / 2 - 50
	var gate_y := HOUSE_BOTTOM - 110
	_rect(gate_x, gate_y, 100, 110, Color8(60, 64, 70))
	for y in range(gate_y + 6, HOUSE_BOTTOM, 9):
		_line(gate_x, y, gate_x + 100, y, Color8(44, 46, 52), 2.0)
	for i in range(0, 100, 20):
		_poly([Vector2(gate_x + i, gate_y - 10), Vector2(gate_x + i + 20, gate_y - 10), Vector2(gate_x + i + 10, gate_y), Vector2(gate_x + i - 10, gate_y)],
			Color8(230, 190, 40) if (i / 20) % 2 == 0 else Color8(30, 30, 30))
	_poly([Vector2(x + 30, HOUSE_BOTTOM - 120), Vector2(x + 52, HOUSE_BOTTOM - 82), Vector2(x + 8, HOUSE_BOTTOM - 82)], Color8(240, 200, 40))
	_text("!", 30, Vector2(x + 30, HOUSE_BOTTOM - 94), Color8(20, 20, 20), Art.Anchor.CENTER, false)
	if _r.randf() < 0.6:
		_paint_graffiti(x + width - 70, HOUSE_BOTTOM - 50)

func _paint_harbour(x: int, width: int, last: bool) -> void:
	if last:
		# Am Ende: das grosse Lagerhaus des Bosses
		var top := HOUSE_BOTTOM - 280
		_rect(x, top, width, 280, Color8(70, 40, 36))
		for y in range(top, HOUSE_BOTTOM, 10):
			_line(x, y, x + width, y, Color8(58, 32, 30))
		var gate_y := HOUSE_BOTTOM - 170
		_rect(x + 60, gate_y, width - 120, 170, Color8(90, 96, 104))
		for y in range(gate_y, HOUSE_BOTTOM, 8):
			_line(x + 60, y, x + width - 60, y, Color8(64, 68, 76), 2.0)
		_frame(x + 60, gate_y, width - 120, 170, Color8(30, 30, 34), 6.0)
		_text("LAGER 7", 46, Vector2(x + width * 0.5, top + 80), Color8(255, 220, 80))
		return
	if _r.randf() < 0.55:
		# Container-Stapel
		var bottom := HOUSE_BOTTOM
		for floor_index in _r.randi_range(1, 3):
			var color: Color = _pick([Color8(170, 60, 40), Color8(40, 100, 160), Color8(60, 130, 70), Color8(190, 140, 40), Color8(110, 110, 120)])
			var left := x + _r.randi_range(0, 20)
			var w := width - 30
			_rect(left, bottom - 70, w, 70, color)
			for cx in range(left + 6, left + w - 4, 9):
				_line(cx, bottom - 66, cx, bottom - 4, Art.darker(color, 0.75), 2.0)
			_frame(left, bottom - 70, w, 70, Art.darker(color, 0.55), 3.0)
			bottom -= 70
		return
	var top2 := HOUSE_BOTTOM - 210
	_rect(x, top2, width, 210, Color8(60, 70, 90))
	for wx in range(x, x + width, 12):
		_line(wx, top2, wx, HOUSE_BOTTOM, Color8(50, 58, 76), 2.0)
	var door_y := HOUSE_BOTTOM - 130
	_rect(x + 20, door_y, width - 40, 130, Color8(100, 104, 110))
	for y in range(door_y, HOUSE_BOTTOM, 8):
		_line(x + 20, y, x + width - 20, y, Color8(74, 78, 86), 2.0)
	_text(str(_r.randi_range(1, 6)), 40, Vector2(x + width * 0.5, top2 + 36), Color8(240, 240, 240))

# ------------------------------------------------------------ Strasse

func _zone_bands(y: float, h: float, colors: Dictionary) -> void:
	for z in ZONES:
		_rect(z[0], y, z[1] - z[0], h, colors[z[2]])

func _paint_near() -> void:
	# Häuserzeile
	var x := 0
	while x < WIDTH:
		var zone := zone_at(x)
		if zone == &"harbour" and x >= WIDTH - 700:
			_paint_harbour(x, WIDTH - x, true)
			break
		var width := _r.randi_range(190, 320)
		match zone:
			&"old_town": _paint_old_town(x, width)
			&"industry": _paint_industry(x, width)
			_: _paint_harbour(x, width, false)
		x += width

	# Gehsteig
	_zone_bands(HOUSE_BOTTOM, KERB - HOUSE_BOTTOM,
		{&"old_town": Color8(120, 116, 124), &"industry": Color8(110, 108, 100), &"harbour": Color8(104, 108, 116)})
	for px in range(0, WIDTH, 48):
		_line(px, HOUSE_BOTTOM, px - 18, KERB, Color8(88, 86, 94), 2.0)
	_line(0, HOUSE_BOTTOM + 26, WIDTH, HOUSE_BOTTOM + 26, Color8(80, 78, 86))
	_rect(0, HOUSE_BOTTOM, WIDTH, 4, Color8(60, 58, 66))
	# Bordstein
	_rect(0, KERB, WIDTH, 6, Color8(150, 148, 156))
	_rect(0, KERB + 6, WIDTH, 4, Color8(70, 68, 76))

	# Fahrbahn
	var top := KERB + 10
	_zone_bands(top, SCREEN_H - top,
		{&"old_town": Color8(52, 50, 62), &"industry": Color8(60, 56, 54), &"harbour": Color8(64, 66, 72)})
	for i in 4000:
		var px := _r.randi_range(0, WIDTH - 1)
		var py := _r.randi_range(top, SCREEN_H - 1)
		var light := _r.randi_range(40, 90)
		_rect(px, py, 1, 1, Color8(light, light, light + 6))
	# Mittelstreifen und Details
	for px in range(0, WIDTH, 120):
		var stripe := Color8(230, 190, 50) if zone_at(px) == &"harbour" else Color8(230, 220, 200)
		_poly([Vector2(px, 446), Vector2(px + 64, 446), Vector2(px + 60, 452), Vector2(px - 4, 452)], stripe)
	for px in range(0, WIDTH, 1400):
		# Fussgängerstreifen
		for i in 6:
			var sx := px + 600 + i * 34
			_poly([Vector2(sx, top + 6), Vector2(sx + 18, top + 6), Vector2(sx + 4, SCREEN_H), Vector2(sx - 14, SCREEN_H)], Color8(210, 210, 205))
	for i in 14:
		# Pfützen und Gullydeckel
		var px := _r.randi_range(200, WIDTH - 201)
		var py := _r.randi_range(top + 30, SCREEN_H - 21)
		if _r.randf() < 0.5:
			_ellipse(px, py, _r.randi_range(40, 90), _r.randi_range(10, 18), Color8(74, 84, 110))
		else:
			_ellipse(px, py, 44, 16, Color8(40, 40, 46))
			_ellipse_ring(px, py, 44, 16, Color8(70, 70, 78))
			for j in range(1, 4):
				_line(px + j * 11, py + 3, px + j * 11, py + 13, Color8(70, 70, 78))
