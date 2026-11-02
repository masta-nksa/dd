class_name CameraRig
extends Camera2D
## Hält alle Ziele im Bild: folgt dem Mittelpunkt, bleibt im Level und steht still, solange eine Welle läuft.

var targets: Array[Fighter] = []
var lock_x := -1.0                   # Mittelpunkt, an dem die Kamera stehen bleibt (−1 = frei)
var keep_players_on_screen := true   # Spieler können den Bildrand nicht verlassen
@export var follow_speed := 6.0

const HALF_WIDTH := 480.0
const MARGIN := 24.0

func _ready() -> void:
	limit_left = 0
	limit_right = int(Level.WIDTH)
	limit_top = 0
	limit_bottom = int(Level.HEIGHT)
	make_current()

func _process(delta: float) -> void:
	if targets.is_empty():
		return
	var sum := 0.0
	var n := 0
	for t in targets:
		if t.current_health > 0:
			sum += t.pos_x
			n += 1
	if n == 0:
		n = targets.size()
		for t in targets:
			sum += t.pos_x
	var goal := sum / n
	if lock_x >= 0.0:
		goal = minf(goal, lock_x)
	position.x = clampf(lerpf(position.x, goal, clampf(follow_speed * delta, 0.0, 1.0)), HALF_WIDTH, Level.WIDTH - HALF_WIDTH)
	if lock_x >= 0.0:
		position.x = minf(position.x, lock_x)
	position.y = Level.HEIGHT * 0.5
	if keep_players_on_screen:
		var left := maxf(position.x - HALF_WIDTH + MARGIN, 40.0)
		var right := minf(position.x + HALF_WIDTH - MARGIN, Level.WIDTH - 40.0)
		for t in targets:
			t.bounds = Rect2(left, t.bounds.position.y, right - left, t.bounds.size.y)
