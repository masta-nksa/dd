class_name Fighter
extends Node2D
## Kämpfer im 2.5D-Raum. X = horizontal, Z = Tiefe/Spur, Y = Höhe (Sprung).
## Die Figur kennt keine Eingabe: ein Controller (Spieler, KI, Netzwerk) setzt `move_input`
## und ruft `request_jump()`, `request_attack()` auf.

signal died

enum State { IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD, GRAB }

static var debug_boxes := false

@export var body_color := Color(0.2, 0.45, 0.9)
@export var team := 0
@export var max_health := 100
@export var speed_x := 175.0
@export var speed_z := 115.0
@export var jump_speed := 620.0
@export var gravity := 1800.0
@export var body_scale := 1.0
@export var weight := 1.0     # Rückstoss wird durch das Gewicht geteilt

const FRICTION := 700.0
const REQUEST_WINDOW := 0.25
const HITSTOP := 0.07
const LIE_TIME := 0.7
const GETUP_TIME := 0.4

var current_health := 100
var pos_x := 0.0
var pos_z := 0.0
var pos_y := 0.0
var velocity_y := 0.0
var vel_x := 0.0
var facing := 1
var state := State.IDLE
var move_input := Vector2.ZERO
var bounds := Rect2(0, 300, 3000, 200)

var hurt_box: HurtBox
var hit_box: HitBox
var attack: AttackData = null
var attack_time := 0.0
var score := 0
var last_attacker: Fighter = null
var lock_facing := false   # Blickrichtung setzt der Controller selbst (Gegner)
var carried: Carry = null
var items: WorldItems = null
var _grab_requested := false
var _grab_target: Node2D = null
var _thrown := false

var _jump_requested := false
var _request: StringName = &""
var _request_timer := 0.0
var _air_attack := false
var _hit_time := 0.3
var _state_time := 0.0
var _landed := false
var _freeze_time := 0.0
var _flash_time := 0.0
var _anim_time := 0.0

func _init() -> void:
	hurt_box = HurtBox.new()
	hit_box = HitBox.new()
	add_child(hurt_box)
	add_child(hit_box)

func _ready() -> void:
	current_health = max_health

func setup(start_x: float, start_z: float, new_bounds: Rect2) -> void:
	pos_x = start_x
	pos_z = start_z
	bounds = new_bounds
	_apply_position()

func request_jump() -> void:
	_jump_requested = true

## kind: &"punch", &"kick" oder &"special"
func request_attack(kind: StringName) -> void:
	_request = kind
	_request_timer = REQUEST_WINDOW

func request_grab() -> void:
	_grab_requested = true

func is_carrying_heavy() -> bool:
	return carried != null and carried.heavy

func is_invulnerable() -> bool:
	return state == State.KNOCKDOWN or state == State.GETUP or state == State.DEAD

func is_dead() -> bool:
	return state == State.DEAD

func revive() -> void:
	current_health = max_health
	state = State.IDLE
	pos_y = 0.0
	velocity_y = 0.0
	vel_x = 0.0

# ---------------------------------------------------------------- Aktualisierung

func _physics_process(delta: float) -> void:
	if _freeze_time > 0.0:      # Trefferpause: kurz einfrieren
		_freeze_time -= delta
		return
	_anim_time += delta
	_state_time += delta
	_flash_time = maxf(_flash_time - delta, 0.0)
	_request_timer -= delta
	if _request_timer <= 0.0:
		_request = &""

	match state:
		State.IDLE, State.WALK: _tick_ground(delta)
		State.JUMP: _tick_jump(delta)
		State.ATTACK: _tick_attack(delta)
		State.HIT: _tick_hit(delta)
		State.KNOCKDOWN: _tick_knockdown(delta)
		State.GETUP: _tick_getup()
		State.DEAD: _slide(delta)
		State.GRAB: _tick_grab(delta)

	_jump_requested = false
	_grab_requested = false
	_push_out_of_props()
	_apply_position()
	queue_redraw()

func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0

func _move(delta: float, scale := 1.0) -> void:
	pos_x += move_input.x * speed_x * scale * delta
	pos_z += move_input.y * speed_z * scale * delta
	pos_x = clampf(pos_x, bounds.position.x, bounds.end.x)
	pos_z = clampf(pos_z, bounds.position.y, bounds.end.y)
	if not lock_facing and absf(move_input.x) > 0.1:
		facing = 1 if move_input.x > 0.0 else -1

func _slide(delta: float) -> void:
	pos_x = clampf(pos_x + vel_x * delta, bounds.position.x, bounds.end.x)
	vel_x = move_toward(vel_x, 0.0, FRICTION * delta)

## Schwerkraft; gibt true zurück, sobald der Boden erreicht ist.
func _fall(delta: float) -> bool:
	velocity_y -= gravity * delta
	pos_y += velocity_y * delta
	if pos_y <= 0.0:
		pos_y = 0.0
		velocity_y = 0.0
		return true
	return false

func _tick_ground(delta: float) -> void:
	if _grab_requested and _try_grab():
		return
	if _jump_requested and not is_carrying_heavy():
		velocity_y = jump_speed
		SoundBank.play(&"jump")
		_set_state(State.JUMP)
		return
	if _request != &"" and _start_requested_attack():
		return
	_move(delta, carried.data["tempo"] if is_carrying_heavy() else 1.0)
	state = State.WALK if move_input.length() > 0.1 else State.IDLE

func _tick_jump(delta: float) -> void:
	_move(delta)
	if _request != &"" and _request != &"special":
		_air_attack = true
		start_attack(&"jump_kick")
		return
	if _fall(delta):
		_set_state(State.IDLE)

func _start_requested_attack() -> bool:
	if is_carrying_heavy():   # mit Kiste, Fass oder Tonne in den Händen wirft jede Angriffstaste
		start_attack(&"throw")
		return true
	var armed := carried != null
	match _request:
		&"punch":
			start_attack(&"w_bat1" if armed else &"punch1")
		&"kick":
			start_attack(&"kick")
		&"special":
			if armed:
				start_attack(&"w_homerun")
				return true
			if current_health <= Attacks.get_attack(&"spin").health_cost:
				_request = &""
				return false
			start_attack(&"spin")
		_:
			return false
	return true

func start_attack(id: StringName) -> void:
	if String(id).begins_with("w_") and (carried == null or carried.heavy):
		id = &"punch1"   # die Waffe ist inzwischen weg (zerbrochen): mit blossen Fäusten weiter
	attack = Attacks.get_attack(id)
	_thrown = false
	hit_box.hit_props.clear()
	attack_time = 0.0
	_air_attack = pos_y > 0.0
	_request = &""
	_request_timer = 0.0
	hit_box.attack = attack
	hit_box.hit_targets.clear()
	hit_box.active = false
	SoundBank.play(&"throw" if attack.throws else &"whoosh")
	vel_x = facing * attack.lunge
	if attack.health_cost > 0:
		current_health = maxi(current_health - attack.health_cost, 1)
	_set_state(State.ATTACK)

func _tick_attack(delta: float) -> void:
	var a := attack
	attack_time += delta
	hit_box.active = a.damage > 0 and attack_time >= a.startup and attack_time < a.startup + a.active
	if a.throws and not _thrown and attack_time >= a.startup:
		_thrown = true
		_do_throw()
	if _air_attack:
		_move(delta, 0.6)
		if _fall(delta):
			_end_attack(State.IDLE)
			return
	else:
		_slide(delta)
	# Combo: Anfrage während der Erholung startet den nächsten Schlag der Kette
	if a.drive > 0.0 and hit_box.active:
		vel_x = facing * a.drive
	if attack_time >= a.startup + a.active and _request == &"punch" and a.chain_to != &"" \
			and (not a.chain_needs_hit or not hit_box.hit_targets.is_empty()):
		start_attack(a.chain_to)
		return
	if attack_time >= a.total_time():
		_end_attack(State.JUMP if _air_attack else State.IDLE)

func _end_attack(next_state: State) -> void:
	hit_box.active = false
	attack = null
	_air_attack = false
	_set_state(next_state)

func _tick_hit(delta: float) -> void:
	_slide(delta)
	if _state_time >= _hit_time:
		_set_state(State.IDLE)

func _tick_knockdown(delta: float) -> void:
	_slide(delta)
	if not _landed:
		if _fall(delta):
			_landed = true
			SoundBank.play(&"thud")
			_state_time = 0.0
			vel_x *= 0.5
	elif _state_time >= LIE_TIME:
		_set_state(State.DEAD if current_health <= 0 else State.GETUP)

func _tick_getup() -> void:
	if _state_time >= GETUP_TIME:
		_set_state(State.IDLE)

# ---------------------------------------------------------------- Greifen und Werfen

func _try_grab() -> bool:
	_grab_requested = false
	if items == null:
		return false
	var target := items.find_grabbable(self)
	if target == null:
		if carried != null:
			start_attack(&"throw")   # nichts zum Aufheben in der Nähe: das Getragene werfen
			return true
		return false
	_grab_target = target
	move_input = Vector2.ZERO
	_set_state(State.GRAB)
	return true

func _tick_grab(_delta: float) -> void:
	if _grab_target != null and _state_time >= 0.09:
		var t := _grab_target
		_grab_target = null
		items.take(self, t)
	if _state_time >= 0.18:
		_set_state(State.IDLE)

func lay_down(died: bool) -> void:
	if items != null:
		items.put_down(self, died)
	else:
		carried = null

func _do_throw() -> void:
	var c := carried
	if c == null or items == null:
		return
	carried = null
	c.rest -= c.data["throw_cost"]
	items.spawn_projectile(self, c)

func on_hit_landed(a: AttackData) -> void:
	if carried != null and not carried.heavy and a.durability > 0:
		carried.rest -= a.durability
		if carried.rest <= 0:
			break_weapon()

func break_weapon() -> void:
	SoundBank.play(&"crack")
	if items != null:
		items.effects.debris(pos_x + facing * 40.0, pos_z, 60.0,
			[Color(0.70, 0.49, 0.27), Color(0.47, 0.34, 0.19), Color(0.88, 0.72, 0.47)], 16)
		items.effects.text(pos_x, pos_z, 110.0, "KAPUTT!", Color(1.0, 0.3, 0.3))
	carried = null
	_request = &""

## Schiebt den Körper aus Requisiten heraus (am Boden; wer hoch genug springt, fliegt drüber).
func _push_out_of_props() -> void:
	if items == null:
		return
	for p in items.props:
		if not p.is_blocking() or pos_y >= p.height - 4.0:
			continue
		var ox := p.width * 0.5 + 12.0 - absf(pos_x - p.pos_x)
		var oz := p.depth + 5.0 - absf(pos_z - p.pos_z)
		if ox <= 0.0 or oz <= 0.0:
			continue
		if ox < oz * 2.5:
			pos_x += ox * (1.0 if pos_x >= p.pos_x else -1.0)
		else:
			pos_z += oz * (1.0 if pos_z >= p.pos_z else -1.0)
	pos_x = clampf(pos_x, bounds.position.x, bounds.end.x)
	pos_z = clampf(pos_z, bounds.position.y, bounds.end.y)

# ---------------------------------------------------------------- Treffer

## Gibt true zurück, wenn der Treffer zählt.
func take_hit(a: AttackData, from: Fighter, from_x := NAN) -> bool:
	if is_invulnerable():
		return false
	current_health = maxi(current_health - a.damage, 0)
	var dir := signi(int(pos_x - (from.pos_x if is_nan(from_x) else from_x)))
	if dir == 0:
		dir = from.facing
	facing = -dir
	hit_box.active = false
	attack = null
	_air_attack = false
	_freeze_time = HITSTOP
	if is_nan(from_x):
		from._freeze_time = HITSTOP
	_flash_time = 0.12
	last_attacker = from
	if carried != null and (carried.heavy or current_health <= 0):
		lay_down(current_health <= 0)   # Schweres lässt man bei jedem Treffer fallen; Gestorbene lassen die Waffe liegen
	_grab_target = null
	vel_x = dir * a.knockback / weight
	if current_health <= 0 or a.knockdown or pos_y > 0.0:
		_landed = false
		velocity_y = maxf(velocity_y, 320.0)
		pos_y = maxf(pos_y, 0.01)
		vel_x = dir * maxf(a.knockback, 180.0) / weight
		_set_state(State.KNOCKDOWN)
		if current_health <= 0:
			died.emit()
	else:
		_hit_time = a.hitstun
		_set_state(State.HIT)
	return true

# ---------------------------------------------------------------- Darstellung

func _apply_position() -> void:
	position = Vector2(pos_x, pos_z - pos_y)
	z_index = int(pos_z)

func _draw() -> void:
	var k := body_scale
	var s := clampf(1.0 - pos_y / 400.0, 0.4, 1.0) * k
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(Vector2(cos(ang) * 26.0 * s, pos_y + sin(ang) * 8.0 * s))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))

	self_modulate = Color(2.2, 2.2, 2.2) if _flash_time > 0.0 else Color.WHITE
	if state == State.DEAD and int(_anim_time * 10.0) % 2 == 0 and _state_time > 0.8:
		self_modulate = Color(1, 1, 1, 0.4)

	var f := float(facing)
	var offset := Vector2.ZERO
	var angle := 0.0
	if state == State.KNOCKDOWN or state == State.DEAD or state == State.GETUP:
		angle = -f * PI * 0.5
		offset = Vector2(0, -6 * k)
		if state == State.KNOCKDOWN and not _landed:
			angle = -f * PI * 0.3
		elif state == State.GETUP:
			angle = -f * PI * 0.5 * (1.0 - _state_time / GETUP_TIME)
	elif state == State.HIT:
		angle = -f * 0.18
	elif state == State.GRAB:
		angle = f * 0.45
	draw_set_transform(offset, angle, Vector2(k, k))
	_draw_figure(f)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_health_bar()
	if debug_boxes:
		_draw_debug()

func _draw_figure(f: float) -> void:
	var bob := 0.0
	var step := 0.0
	if state == State.WALK:
		step = sin(_anim_time * 12.0)
		bob = absf(step) * 2.0
	var skin := Color(0.95, 0.8, 0.65)
	var dark := body_color.darkened(0.45)
	var pose: StringName = attack.pose if attack != null else &""
	var phase := 0.0   # 0 = Anlauf, 1 = aktiv, 2 = Erholung
	if attack != null:
		phase = 0.0 if attack_time < attack.startup else (1.0 if attack_time < attack.startup + attack.active else 2.0)

	# Beine
	var kick_leg := pose == &"kick" and phase == 1.0
	draw_rect(Rect2(-9 + step * 4.0, -34, 8, 34), dark)
	if kick_leg:
		draw_rect(Rect2(f * 6 - (0 if f > 0 else 44), -34, 44, 9), dark)
	else:
		draw_rect(Rect2(1 - step * 4.0, -34, 8, 34 if state != State.JUMP else 24), dark)
	# Oberkörper
	draw_rect(Rect2(-13, -72 + bob, 26, 40), body_color)
	draw_rect(Rect2(-13, -38 + bob, 26, 4), body_color.darkened(0.6))
	# Arme
	var winding_up := pose == &"punch" and phase == 0.0 and attack.startup >= 0.15
	var punch_arm := (pose == &"punch" and phase == 1.0) or (pose == &"throw" and phase >= 1.0)
	if winding_up:
		draw_rect(Rect2(f * 10 - 4, -96, 8, 30), skin)
	elif punch_arm:
		var length := 44.0
		draw_rect(Rect2(f * 10 - (0 if f > 0 else length), -68, length, 9), skin)
	else:
		draw_rect(Rect2(f * 12 - 4, -70 + bob, 8, 28), skin)
	if pose == &"spin" and phase == 1.0:
		draw_arc(Vector2(0, -50), 58.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 4.0)
	else:
		draw_rect(Rect2(-f * 12 - 4, -70 + bob, 8, 28), skin.darkened(0.15))
	_draw_carried(f, phase, pose, bob)
	# Kopf
	draw_circle(Vector2(0, -86 + bob), 12.0, skin)
	draw_arc(Vector2(0, -88 + bob), 12.5, PI, TAU, 16, Color(0.15, 0.1, 0.1), 5.0)
	draw_circle(Vector2(f * 5, -86 + bob), 1.8, Color.BLACK)

func _draw_carried(f: float, phase: float, pose: StringName, bob: float) -> void:
	if carried == null:
		return
	if carried.heavy:
		var rect_origin := Vector2(0, -88 + bob)
		Prop.draw_art(self, carried.kind, carried.prop.width, carried.prop.height, carried.prop.color, 1.0, rect_origin)
		return
	var hand := Vector2(f * 14.0, -52.0 + bob)
	var dir := Vector2(f * 0.35, -1.0)            # in Ruhe schräg nach oben
	if pose == &"swing":
		if phase == 0.0:
			dir = Vector2(-f * 0.6, -1.0)         # ausholen
		elif phase == 1.0:
			dir = Vector2(f, 0.1)                 # Schwung nach vorn
		else:
			dir = Vector2(f * 0.6, 0.8)           # ausschwingen
	var grip := hand - dir.normalized() * 8.0
	var tip := hand + dir.normalized() * 52.0
	WeaponPickup.draw_bat(self, grip, tip, carried.ratio())

func _draw_health_bar() -> void:
	if state == State.DEAD:
		return
	var w := 44.0
	var ratio := float(current_health) / float(max_health)
	var top := -112.0 * body_scale
	draw_rect(Rect2(-w * 0.5, top, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w * 0.5, top, w * ratio, 5), Color(0.3, 0.9, 0.3).lerp(Color(0.95, 0.2, 0.2), 1.0 - ratio))

func _draw_debug() -> void:
	var origin := Vector2(pos_x, pos_z - pos_y)
	_draw_box_outline(hurt_box.world_box(), origin, Color(0.2, 1.0, 0.2))
	if hit_box.active and hit_box.attack != null:
		_draw_box_outline(hit_box.world_box(), origin, Color(1.0, 0.2, 0.2))

func _draw_box_outline(box: AABB, origin: Vector2, col: Color) -> void:
	var zc := box.position.z + box.size.z * 0.5
	var top := zc - (box.position.y + box.size.y)
	draw_rect(Rect2(Vector2(box.position.x, top) - origin, Vector2(box.size.x, box.size.y)), col, false, 2.0)
	# Tiefenausdehnung als kurzer Strich am Boden der Box
	var foot := zc - box.position.y
	draw_line(Vector2(box.position.x + box.size.x * 0.5, foot - box.size.z * 0.5) - origin,
		Vector2(box.position.x + box.size.x * 0.5, foot + box.size.z * 0.5) - origin, col, 2.0)
