class_name Level
extends Node2D
## Einfacher Hintergrund: Himmel, Skyline, Strasse mit Spurlinien.

const WIDTH := 5400.0
const HEIGHT := 540.0
const STREET_TOP := 290.0

func _ready() -> void:
	z_index = -4000

func lane_bounds() -> Rect2:
	return Rect2(40.0, 322.0, WIDTH - 80.0, 200.0)

func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, STREET_TOP), Color(0.55, 0.7, 0.9))
	# Skyline in zwei Ebenen
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for layer in 2:
		var x := 0.0
		var col := Color(0.35, 0.4, 0.55).lerp(Color(0.5, 0.55, 0.7), layer)
		while x < WIDTH:
			var w := rng.randf_range(70.0, 140.0)
			var h := rng.randf_range(80.0, 190.0) - layer * 30.0
			draw_rect(Rect2(x, STREET_TOP - h, w, h), col)
			x += w + 4.0
	draw_rect(Rect2(0, STREET_TOP, WIDTH, HEIGHT - STREET_TOP), Color(0.32, 0.32, 0.35))
	draw_rect(Rect2(0, STREET_TOP, WIDTH, 14), Color(0.55, 0.55, 0.58))
	var y := 340.0
	while y < HEIGHT:
		draw_line(Vector2(0, y), Vector2(WIDTH, y), Color(1, 1, 1, 0.08), 2.0)
		y += 50.0
