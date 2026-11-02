class_name Level
extends Node2D
## Einfacher Hintergrund: Himmel, Skyline, Strasse mit Spurlinien.

const WIDTH := 5400.0
const HEIGHT := 540.0
const STREET_TOP := 290.0

func _ready() -> void:
	z_index = -4000

## (Art, x, z) – z ist der Fusspunkt (Port von `REQUISITEN_PLAN`)
const PROP_PLAN := [
	[&"lamp", 300, 330], [&"crate", 760, 360], [&"bin", 1000, 340],
	[&"lamp", 1120, 330], [&"barrel", 1560, 470], [&"crate", 1700, 345],
	[&"lamp", 1950, 330], [&"barrel", 2500, 350], [&"barrel", 2540, 372], [&"crate", 2900, 480],
	[&"lamp", 2780, 330], [&"bin", 3100, 342], [&"crate", 3500, 355], [&"lamp", 3620, 330],
	[&"barrel", 3950, 470], [&"crate", 4200, 350], [&"crate", 4246, 350], [&"lamp", 4480, 330],
	[&"barrel", 5000, 360], [&"lamp", 5300, 330],
]

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
