class_name Effects
extends Node2D
## Effekte (Port von `effekte.py`): Trefferfunken, Splitter, Staub, schwebende Texte.
## Sie leben nur kurz, haben keinen Einfluss auf das Spiel und liegen in Weltkoordinaten (x, z = Tiefe, y = Höhe).

var _sparks: Array = []
var _bits: Array = []
var _dust: Array = []
var _texts: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 3000
	_rng.randomize()

## Sternförmiger Blitz an der Trefferstelle, dazu ein paar Funken.
func spark(x: float, z: float, y: float, big := false) -> void:
	_sparks.append({"x": x, "z": z, "y": y, "age": 0.0, "life": 0.22 if big else 0.16,
		"size": 26.0 if big else 17.0, "angle": _rng.randf_range(0.0, PI)})
	for i in (6 if big else 3):
		_add_bit(x, z, y, [Art.YELLOW, Color.WHITE, Art.ORANGE][_rng.randi_range(0, 2)], 260.0, 3.0, 900.0)

## Graue Wölkchen, die sich am Boden ausbreiten.
func dust(x: float, z: float, count := 4) -> void:
	for i in count:
		var life := _rng.randf_range(0.35, 0.55)
		_dust.append({"x": x, "z": z + _rng.randf_range(-3.0, 3.0), "y": 0.0, "age": 0.0, "life": life,
			"vx": (-1.0 if i % 2 == 1 else 1.0) * _rng.randf_range(30.0, 90.0), "size": _rng.randf_range(5.0, 9.0)})

func debris(x: float, z: float, y: float, colors: Array, count: int) -> void:
	for i in count:
		_add_bit(x, z, y, colors[_rng.randi_range(0, colors.size() - 1)], 300.0, float(_rng.randi_range(3, 6)), 1200.0)

func text(x: float, z: float, y: float, text_value: String, color := Art.YELLOW, size := 26.0) -> void:
	_texts.append({"x": x, "z": z, "y": y, "text": text_value, "color": color, "size": size, "age": 0.0, "life": 0.9})

func _add_bit(x: float, z: float, y: float, color: Color, speed: float, size: float, gravity: float) -> void:
	var angle := _rng.randf_range(0.0, TAU)
	_bits.append({"x": x, "z": z, "y": y, "color": color, "size": size, "gravity": gravity, "age": 0.0,
		"life": _rng.randf_range(0.35, 0.7),
		"vx": cos(angle) * speed * _rng.randf_range(0.4, 1.0), "vz": _rng.randf_range(-30.0, 30.0),
		"vy": absf(sin(angle)) * speed * _rng.randf_range(0.5, 1.2) + 60.0})

func _physics_process(delta: float) -> void:
	for s in _sparks:
		s["age"] += delta
	for b in _bits:
		b["age"] += delta
		b["vy"] -= b["gravity"] * delta
		b["x"] += b["vx"] * delta
		b["z"] += b["vz"] * delta
		b["y"] += b["vy"] * delta
		if b["y"] < 0.0:
			b["y"] = 0.0
			b["vy"] *= -0.4
			b["vx"] *= 0.6
	for d in _dust:
		d["age"] += delta
		d["x"] += d["vx"] * delta
		d["y"] += 18.0 * delta
	for t in _texts:
		t["age"] += delta
		t["y"] += 50.0 * delta
	_sparks = _sparks.filter(_alive)
	_bits = _bits.filter(_alive)
	_dust = _dust.filter(_alive)
	_texts = _texts.filter(_alive)
	queue_redraw()

func _alive(entry: Dictionary) -> bool:
	return entry["age"] < entry["life"]

func _draw() -> void:
	for d in _dust:
		var f: float = d["age"] / d["life"]
		var r: float = d["size"] * (0.6 + f)
		var light := int(200.0 - 60.0 * f)
		draw_circle(Vector2(d["x"], d["z"] - d["y"] - r * 0.5), r, Color8(light, light - 8, light - 20))
	for b in _bits:
		var g: float = b["size"] * (1.0 - 0.5 * b["age"] / b["life"])
		draw_rect(Rect2(b["x"] - g * 0.5, b["z"] - b["y"] - g * 0.5, g, g), b["color"])
	for s in _sparks:
		_draw_spark(s)
	for t in _texts:
		if t["age"] > t["life"] * 0.7 and int(t["age"] * 20.0) % 2 == 1:
			continue
		Art.text(self, t["text"], t["size"], Vector2(t["x"], t["z"] - t["y"]), t["color"])

func _draw_spark(s: Dictionary) -> void:
	var center := Vector2(s["x"], s["z"] - s["y"])
	var f: float = s["age"] / s["life"]
	var r: float = s["size"] * (0.6 + 0.8 * f)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 16:
		var radius := r if i % 2 == 0 else r * 0.38
		var angle: float = s["angle"] + i * PI / 8.0
		var q := Vector2(cos(angle), sin(angle)) * radius
		outer.append(center + q)
		inner.append(center + q * 0.6)
	draw_colored_polygon(outer, Art.ORANGE)
	draw_colored_polygon(inner, Color8(255, 250, 200) if f < 0.4 else Art.YELLOW)
