class_name Fighter
extends Node2D
## Kämpfer im 2.5D-Raum. X = horizontal, Z = Tiefe/Spur, Y = Höhe (Sprung).
## Die Figur kennt keine Eingabe: ein Controller (Spieler, KI, Netzwerk) setzt `move_input` und `request_jump()`.

enum State { IDLE, WALK, JUMP }

@export var body_color := Color(0.2, 0.45, 0.9)
@export var speed_x := 175.0
@export var speed_z := 115.0
@export var jump_speed := 620.0
@export var gravity := 1800.0

var pos_x := 0.0
var pos_z := 0.0
var pos_y := 0.0          # Höhe über dem Boden, 0 = am Boden
var velocity_y := 0.0
var facing := 1           # 1 = rechts, -1 = links
var state := State.IDLE
var move_input := Vector2.ZERO   # x = links/rechts, y = Tiefe (negativ = nach hinten)
var bounds := Rect2(0, 300, 3000, 200)   # x/z-Grenzen (Fusspunkt)

var _jump_requested := false
var _anim_time := 0.0

func request_jump() -> void:
	_jump_requested = true

func setup(start_x: float, start_z: float, new_bounds: Rect2) -> void:
	pos_x = start_x
	pos_z = start_z
	bounds = new_bounds
	_apply_position()

func _physics_process(delta: float) -> void:
	_update_state(delta)
	_apply_position()
	queue_redraw()

func _update_state(delta: float) -> void:
	var on_ground := pos_y <= 0.0 and velocity_y <= 0.0
	if on_ground:
		if _jump_requested:
			velocity_y = jump_speed
			state = State.JUMP
		else:
			state = State.WALK if move_input.length() > 0.1 else State.IDLE
	_jump_requested = false

	# Bewegung: in der Luft bleibt die Steuerung erhalten (Beat-'em-up-typisch)
	pos_x += move_input.x * speed_x * delta
	pos_z += move_input.y * speed_z * delta
	pos_x = clampf(pos_x, bounds.position.x, bounds.end.x)
	pos_z = clampf(pos_z, bounds.position.y, bounds.end.y)
	if absf(move_input.x) > 0.1:
		facing = 1 if move_input.x > 0.0 else -1

	if state == State.JUMP:
		velocity_y -= gravity * delta
		pos_y += velocity_y * delta
		if pos_y <= 0.0:
			pos_y = 0.0
			velocity_y = 0.0
			state = State.IDLE
	_anim_time += delta

func _apply_position() -> void:
	# Bildschirm: x bleibt, y = Tiefe minus Höhe. z_index sortiert nach Tiefe (hinten zuerst).
	position = Vector2(pos_x, pos_z - pos_y)
	z_index = int(pos_z)

func _draw() -> void:
	# Schatten am Boden (relativ zum Fusspunkt: Boden liegt pos_y weiter unten)
	var s := clampf(1.0 - pos_y / 400.0, 0.4, 1.0)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 26.0 * s, pos_y + sin(a) * 8.0 * s))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))

	var bob := 0.0
	var step := 0.0
	if state == State.WALK:
		step = sin(_anim_time * 12.0)
		bob = absf(step) * 2.0
	var f := float(facing)
	var skin := Color(0.95, 0.8, 0.65)
	var dark := body_color.darkened(0.45)
	# Beine
	var spread := 7.0 if state != State.JUMP else 10.0
	draw_rect(Rect2(-9 + step * 4.0, -34, 8, 34), dark)
	draw_rect(Rect2(1 - step * 4.0, -34, 8, 34), dark)
	if state == State.JUMP:
		draw_rect(Rect2(-spread - 2, -30, 6, 24), dark)
	# Oberkörper
	draw_rect(Rect2(-13, -72 + bob, 26, 40), body_color)
	draw_rect(Rect2(-13, -38 + bob, 26, 4), body_color.darkened(0.6))
	# Arme
	draw_rect(Rect2(f * 12 - 4, -70 + bob, 8, 28), skin)
	draw_rect(Rect2(-f * 12 - 4, -70 + bob, 8, 28), skin.darkened(0.15))
	# Kopf, Haare, Auge
	draw_circle(Vector2(0, -86 + bob), 12.0, skin)
	draw_arc(Vector2(0, -88 + bob), 12.5, PI, TAU, 16, Color(0.15, 0.1, 0.1), 5.0)
	draw_circle(Vector2(f * 5, -86 + bob), 1.8, Color.BLACK)
