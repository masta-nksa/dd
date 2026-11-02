class_name Effects
extends Node2D
## Splitter und schwebende Texte (Weltkoordinaten: x, z = Tiefe, y = Höhe).

var _debris: Array = []
var _texts: Array = []

func _ready() -> void:
	z_index = 3000

func debris(x: float, z: float, y: float, colors: Array, count: int) -> void:
	for i in count:
		_debris.append({"x": x, "z": z, "y": y, "vx": randf_range(-160, 160), "vy": randf_range(120, 380),
			"vz": randf_range(-30, 30), "size": randf_range(3, 7), "color": colors.pick_random(), "life": randf_range(0.7, 1.2)})

func text(x: float, z: float, y: float, text_value: String, color := Color.WHITE) -> void:
	_texts.append({"x": x, "z": z, "y": y, "text": text_value, "color": color, "life": 1.1})

func _physics_process(delta: float) -> void:
	for d in _debris:
		d["vy"] -= 1500.0 * delta
		d["x"] += d["vx"] * delta
		d["z"] += d["vz"] * delta
		d["y"] += d["vy"] * delta
		if d["y"] <= 0.0:
			d["y"] = 0.0
			d["vy"] = absf(d["vy"]) * 0.3
			d["vx"] *= 0.5
		d["life"] -= delta
	_debris = _debris.filter(func(d): return d["life"] > 0.0)
	for t in _texts:
		t["y"] += 40.0 * delta
		t["life"] -= delta
	_texts = _texts.filter(func(t): return t["life"] > 0.0)
	queue_redraw()

func _draw() -> void:
	for d in _debris:
		var c: Color = d["color"]
		c.a = clampf(d["life"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2(d["x"] - d["size"] * 0.5, d["z"] - d["y"] - d["size"] * 0.5, d["size"], d["size"]), c)
	var font := ThemeDB.fallback_font
	for t in _texts:
		var c: Color = t["color"]
		c.a = clampf(t["life"] * 2.0, 0.0, 1.0)
		draw_string(font, Vector2(t["x"] - 30.0, t["z"] - t["y"]), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, c)
