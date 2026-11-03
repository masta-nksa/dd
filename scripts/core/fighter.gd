class_name Fighter
extends Node2D
## Kämpfer im 2.5D-Raum. X = horizontal, Z = Tiefe/Spur, Y = Höhe (Sprung).
## Die Figur kennt keine Eingabe: ein Controller (Spieler, KI, Netzwerk) setzt `move_input`
## und ruft `request_jump()`, `request_attack()` auf.

signal died

enum State { IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD, GRAB }

static var debug_boxes := false

@export var body_color := Art.PLAYER_COLORS[0]   # Farbe von Ring, Anzeige und Hinweisen
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
const RESPAWN_DELAY := 1.6
const RESPAWN_HEIGHT := 330.0
const RESPAWN_SAFE_TIME := 2.5
const COMBO_TIME := 1.2

var skin: Dictionary = Skins.KAI
var fighter_id: StringName = &""   # gewählter Kämpfer (`FighterData`); leer = nur 2D-Figur
var damage_factor := 1.0           # Werte des Kämpfers, siehe `FighterData`
var attack_speed := 1.0
var reach_factor := 1.0
var model: ModelFigure = null      # 3D-Modell, solange die Datei vorhanden ist
var player_number := 0     # 0 = Gegner; 1 oder 2 zeichnet Ring und Kennzeichen
var lives := 0             # Extraleben
var camera: CameraRig = null   # hier taucht man nach einem verlorenen Leben wieder auf
var cheer := false         # jubelt nach dem Sieg
var combo := 0
var best_combo := 0
var _combo_time := 0.0
var _invulnerable_time := 0.0

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
var _scaled_attacks := {}

func _init() -> void:
	hurt_box = HurtBox.new()
	hit_box = HitBox.new()
	add_child(hurt_box)
	add_child(hit_box)

func _ready() -> void:
	current_health = max_health
	if fighter_id != &"":
		model = ModelFigure.create(fighter_id)
		if model != null:
			add_child(model)

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
	return _invulnerable_time > 0.0 or state == State.KNOCKDOWN or state == State.GETUP or state == State.DEAD

func is_dead() -> bool:
	return state == State.DEAD

## Endgültig ausgeschieden: keine Lebenspunkte und keine Extraleben mehr.
func is_out() -> bool:
	return current_health <= 0 and lives <= 0

func revive() -> void:
	current_health = max_health
	state = State.IDLE
	pos_y = 0.0
	velocity_y = 0.0
	vel_x = 0.0

# ---------------------------------------------------------------- Aktualisierung

func _physics_process(delta: float) -> void:
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	if _combo_time > 0.0:
		_combo_time -= delta
		if _combo_time <= 0.0:
			combo = 0
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
		State.DEAD: _tick_dead(delta)
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
	if cheer:
		state = State.IDLE
		return
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
		_dust(3)
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
	attack = _attack_for(id)
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

## Der Angriff mit den Faktoren dieses Kämpfers; ohne Abweichung die gemeinsame Vorlage.
func _attack_for(id: StringName) -> AttackData:
	var base := Attacks.get_attack(id)
	if damage_factor == 1.0 and attack_speed == 1.0 and reach_factor == 1.0:
		return base
	if not _scaled_attacks.has(id):
		_scaled_attacks[id] = Attacks.scaled(base, damage_factor, attack_speed, reach_factor)
	return _scaled_attacks[id]

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
			_dust(6)
			if items != null and items.camera != null:
				items.camera.shake(4.0 * weight)
			_state_time = 0.0
			vel_x *= 0.5
	elif _state_time >= LIE_TIME:
		_set_state(State.DEAD if current_health <= 0 else State.GETUP)

func _tick_dead(delta: float) -> void:
	_slide(delta)
	if lives > 0 and _state_time >= RESPAWN_DELAY:
		lives -= 1
		_respawn()

## Fällt von oben ins Bild, kurz unverwundbar (Port von `einsteigen`).
func _respawn() -> void:
	if camera != null:
		pos_x = camera.position.x - CameraRig.HALF_WIDTH + 960.0 * (0.3 if player_number == 1 else 0.6)
	pos_z = bounds.get_center().y + (player_number - 1.5) * 40.0
	pos_y = RESPAWN_HEIGHT
	velocity_y = 0.0
	vel_x = 0.0
	current_health = max_health
	_invulnerable_time = RESPAWN_SAFE_TIME
	facing = 1
	_set_state(State.JUMP)

func _dust(count: int) -> void:
	if items != null:
		items.effects.dust(pos_x, pos_z, count)

## Ein eigener Treffer zählt für Combo und Punkte (Port von `zaehle_treffer`).
func count_hit(a: AttackData) -> void:
	combo += 1
	_combo_time = COMBO_TIME
	best_combo = maxi(best_combo, combo)
	score += a.damage * 10 + (combo - 1) * 5

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
			[WeaponPickup.WOOD, Art.darker(WeaponPickup.WOOD), Art.lighter(WeaponPickup.WOOD)], 16)
		items.effects.text(pos_x, pos_z, 110.0, "KAPUTT!", Art.RED)
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

## Passende Pose zum Zustand (Port von `aktuelle_pose`).
func current_pose() -> Dictionary:
	match state:
		State.ATTACK:
			if attack == null:
				return Poses.stand(_anim_time)
			var total := attack.total_time()
			var t := attack_time / total
			if t >= 1.0 and pos_y > 0.0:
				return Poses.jump()
			return Poses.attack(attack.pose, minf(t, 1.0), attack.startup / total, (attack.startup + attack.active) / total)
		State.WALK:
			return Poses.carry(Poses.walk(_anim_time)) if is_carrying_heavy() else Poses.walk(_anim_time)
		State.JUMP:
			return Poses.jump()
		State.HIT:
			return Poses.hit(_state_time)
		State.KNOCKDOWN:
			return Poses.lying() if _landed else Poses.fall(minf(_state_time / 0.45, 1.0))
		State.DEAD:
			return Poses.lying()
		State.GETUP:
			return Poses.get_up(_state_time / GETUP_TIME)
		State.GRAB:
			return Poses.bend()
	if cheer:
		return Poses.cheer(_anim_time)
	return Poses.carry(Poses.stand(_anim_time)) if is_carrying_heavy() else Poses.stand(_anim_time)

func _is_blinked_out() -> bool:
	if state == State.DEAD:
		return (is_out() and _state_time >= RESPAWN_DELAY) or int(_state_time * 14.0) % 2 == 1
	return _invulnerable_time > 0.5 and int(_anim_time * 16.0) % 2 == 1

func _draw() -> void:
	# Der Schatten bleibt am Boden, auch wenn die Figur springt; so sieht man die Tiefe.
	var lying_down := state == State.DEAD or (state == State.KNOCKDOWN and _landed)
	if not (is_out() and state == State.DEAD and _state_time >= RESPAWN_DELAY):
		Art.shadow(self, 0.0, pos_y, 46.0 * body_scale / (1.0 + pos_y / 160.0) * (2.1 if lying_down else 1.0))
	if player_number > 0 and state != State.KNOCKDOWN and state != State.DEAD:
		Art.player_ring(self, 0.0, pos_y, 50.0, body_color, facing)
	if not _is_blinked_out():
		var jitter := 0.0
		if _flash_time > 0.0:   # zittert beim Treffer
			jitter = 2.0 if int(_flash_time * 120.0) % 2 == 0 else -2.0
		if model != null:
			var pose := current_pose()
			model.set_pose(pose, facing, _flash_time > 0.06)
			model.draw(self, jitter, 0.0, body_scale)
			if carried != null:
				var h := model.hands(body_scale)
				_hold_carried(h[0], h[1], h[2], h[3], body_scale)
		else:
			FigureArt.draw(self, skin, current_pose(), jitter, 0.0, facing, body_scale, _flash_time > 0.06, _anim_time,
				_hold_carried if carried != null else Callable())
		if player_number > 0 and not lying_down:
			Art.text(self, "%dP" % player_number, 20.0, Vector2(0.0, -FigureArt.HEIGHT * body_scale - 14.0), body_color)
	if debug_boxes:
		_draw_debug()

## Zeichnet das Getragene in die Hände (Port von `zeichne_in_hand`).
func _hold_carried(hand: Vector2, elbow: Vector2, other_hand: Vector2, _other_elbow: Vector2, s: float) -> void:
	if carried.heavy:
		var prop := carried.prop
		Prop.draw_art(self, carried.kind, prop.width, prop.height, prop.color, 1.0, ((hand + other_hand) * 0.5 - Vector2(0.0, 2.0)).round())
		return
	var along := (hand - elbow).normalized()
	var tip := hand + along * 52.0 * s
	if carried.ratio() < 0.25:   # wackelt, wenn er fast kaputt ist
		tip += Vector2(sin(_anim_time * 53.0), cos(_anim_time * 41.0))
	WeaponPickup.draw_bat(self, hand - along * 8.0 * s, tip, carried.ratio(), s)

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
