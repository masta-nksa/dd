class_name Enemy
extends Fighter
## Gegner mit KI als Zustandsautomat (Port von `gegner.py`).
## Die Figur (Körper) hat ihre eigene FSM aus `Fighter`; die KI entscheidet nur, was gerade vorgehabt wird.
##   LURK = kurz stehen, dann Ziel suchen     CHASE = zum Ziel laufen, in Position gehen
##   ATTACK = Angriff läuft                   RETREAT = nach dem Angriff Abstand nehmen
##   HURT = Körper wehrlos, KI denkt nicht    DEAD
##   FETCH = zu einem Baseballschläger am Boden laufen und ihn aufheben (danach Angriffe mit dem Schläger)

enum Ai { LURK, CHASE, ATTACK, RETREAT, HURT, DEAD, FETCH }

const TYPES := {
	&"thug": {"skin": Skins.THUG, "hp": 36, "scale": 1.0, "speed": Vector2(118, 78),
		"weight": 1.0, "points": 500, "attacks": [[&"g_schlag", 3], [&"g_tritt", 2]], "reach": 44.0,
		"pause": Vector2(0.55, 1.3), "combo": 0.35},
	&"dasher": {"skin": Skins.DASHER, "hp": 26, "scale": 0.95, "speed": Vector2(178, 112),
		"weight": 0.85, "points": 600, "attacks": [[&"g_flinktritt", 3], [&"g_schlag", 1]], "reach": 48.0,
		"pause": Vector2(0.3, 0.9), "combo": 0.2},
	&"brute": {"skin": Skins.BRUTE, "hp": 80, "scale": 1.28, "speed": Vector2(82, 56),
		"weight": 1.7, "points": 1500, "attacks": [[&"g_hammer", 2], [&"g_schlag", 2]], "reach": 58.0,
		"pause": Vector2(0.8, 1.6), "combo": 0.0},
	&"boss": {"skin": Skins.BOSS, "hp": 210, "scale": 1.18, "speed": Vector2(124, 82),
		"weight": 1.5, "points": 5000, "attacks": [[&"g_schlag", 3], [&"g_tritt", 2], [&"g_hammer", 1]], "reach": 52.0,
		"pause": Vector2(0.35, 0.95), "combo": 0.5, "ram": true},
}

const FETCH_RANGE := Vector2(300.0, 90.0)   # so weit sucht ein Gegner nach einem Schläger
const FETCH_GIVE_UP := 3.5                  # Sekunden, dann lässt er ihn liegen
const ARMED_REACH := 62.0                   # Abstand, aus dem er mit dem Schläger zuschlägt (Pixel bei Grösse 1)
const ARMED_ATTACKS := [[&"w_bat1", 3], [&"w_homerun", 1]]

var type_id: StringName = &"thug"
var data: Dictionary
var director: WaveDirector
var ai := Ai.LURK
var ai_time := 0.0
var target: Fighter = null
var points := 0
var may_attack := false   # vom Director gesetzt: darf ich zuschlagen?
var side := 1             # auf welcher Seite des Ziels stehe ich?
var reach_px := 44.0
var pause_factor := 1.0   # kleiner = kürzere Pausen zwischen den Angriffen (Schwierigkeit, vom Director gesetzt)

var _think_pause := randf_range(0.2, 0.6)
var _attack_pause := randf_range(0.6, 1.2)
var _ram_pause := 3.0
var _reaction := randf_range(0.3, 0.7)
var _wait_offset := randf_range(-50.0, 50.0)
var _retreat_dir := Vector2.ZERO
var _retreat_time := 0.5
var _fetch_target: WeaponPickup = null
var _fetch_check := randf_range(0.2, 1.0)

## look_index < 0 würfelt eine Variante aus `EnemyLooks`; Tests können eine feste wählen.
static func create(type: StringName, look_index := -1) -> Enemy:
	var e := Enemy.new()
	e.type_id = type
	e.data = TYPES[type]
	var look := EnemyLooks.pick(type, look_index)
	e.skin = EnemyLooks.skin_for(e.data["skin"], type, look)
	e.fighter_id = look["model"]
	e.palette = look["colors"]
	e.team = 1
	e.max_health = e.data["hp"]
	e.body_scale = e.data["scale"]
	e.weight = e.data["weight"]
	e.speed_x = e.data["speed"].x
	e.speed_z = e.data["speed"].y
	e.points = e.data["points"]
	e.reach_px = e.data["reach"] * e.body_scale
	e.lock_facing = true
	e.weapons_only = true
	return e

func _physics_process(delta: float) -> void:
	if _freeze_time <= 0.0:
		_think(delta)
	super._physics_process(delta)

func take_hit(a: AttackData, from: Fighter, from_x := NAN) -> bool:
	var knocked := super.take_hit(a, from, from_x)
	# Der Boss lässt sich von leichten Schlägen nicht so leicht aus dem Konzept bringen
	if knocked and type_id == &"boss" and state == State.HIT:
		_hit_time *= 0.6
	return knocked

func time_dead() -> float:
	return _state_time if state == State.DEAD else 0.0

func _set_ai(new_ai: Ai) -> void:
	ai = new_ai
	ai_time = 0.0

# ---------------------------------------------------------------- KI

func _think(delta: float) -> void:
	ai_time += delta
	_think_pause -= delta
	_attack_pause -= delta
	_ram_pause -= delta
	_fetch_check -= delta

	if current_health <= 0 or state == State.DEAD:
		ai = Ai.DEAD
		move_input = Vector2.ZERO
		return
	if state == State.HIT or state == State.KNOCKDOWN or state == State.GETUP:
		if ai != Ai.HURT:
			_set_ai(Ai.HURT)
		move_input = Vector2.ZERO
		return
	if state == State.ATTACK:
		move_input = Vector2.ZERO
		return
	match ai:
		Ai.LURK: _ai_lurk()
		Ai.CHASE: _ai_chase()
		Ai.ATTACK: _ai_attack_done()
		Ai.RETREAT: _ai_retreat()
		Ai.HURT: _ai_recovered()
		Ai.FETCH: _ai_fetch()

func _ai_lurk() -> void:
	move_input = Vector2.ZERO
	if ai_time < _reaction:
		return
	if _look_for_weapon():
		return
	target = _choose_target()
	if target != null:
		_set_ai(Ai.CHASE)

func _ai_recovered() -> void:
	_reaction = randf_range(0.15, 0.45)
	if randf() < 0.4:
		_start_retreat()
	else:
		_set_ai(Ai.LURK)

func _ai_chase() -> void:
	if _think_pause <= 0.0 or target == null or target.current_health <= 0:
		target = _choose_target()
		_think_pause = randf_range(0.8, 1.5)
	if target == null:
		_set_ai(Ai.LURK)
		return
	if _look_for_weapon():
		return
	var dx := target.pos_x - pos_x
	var dz := target.pos_z - pos_z
	var goal_x: float
	var goal_z: float
	if may_attack:
		goal_x = target.pos_x + side * _reach() * 0.85
		goal_z = target.pos_z
	else:
		# warten: mit Abstand daneben stehen und langsam kreisen
		var dist := 150.0 + 30.0 * sin(_anim_time * 0.7 + _wait_offset)
		goal_x = target.pos_x + side * dist
		goal_z = target.pos_z + _wait_offset + 25.0 * sin(_anim_time * 0.9)
		goal_x = clampf(goal_x, director.screen_left() + 40.0, director.screen_right() - 40.0)
	goal_z = _detour(goal_x, goal_z)
	_walk_to(goal_x, goal_z, not may_attack)
	if dx != 0.0:
		facing = 1 if dx > 0.0 else -1

	if not may_attack or target.is_invulnerable():
		return
	# Boss: Anlauf aus der Distanz
	if data.get("ram", false) and _ram_pause <= 0.0 and absf(dz) < 16.0 and absf(dx) > 170.0 and absf(dx) < 420.0:
		_ram_pause = randf_range(4.0, 7.0)
		_begin_attack(&"g_rammen")
		return
	var reach := _reach()
	var in_range := absf(dx) > reach * 0.45 and absf(dx) < reach * 1.2 and absf(dz) < 12.0
	if in_range and _attack_pause <= 0.0:
		_begin_attack(_pick_attack())
		if randf() < data["combo"]:
			request_attack(&"punch")   # versucht die Kette, falls der erste Schlag sitzt

## Mit Schläger in der Hand schlägt der Gegner aus grösserer Entfernung zu.
func _armed() -> bool:
	return carried != null and not carried.heavy

func _reach() -> float:
	return maxf(reach_px, ARMED_REACH * body_scale) if _armed() else reach_px

## Liegt ein Schläger in der Nähe und kein Spieler ist näher dran, holt ihn der Gegner (ohne Waffe, ab und zu geprüft).
func _look_for_weapon() -> bool:
	if _armed() or _fetch_check > 0.0 or director.items == null:
		return false
	_fetch_check = randf_range(0.6, 1.2)
	var w := director.items.find_weapon_for_enemy(self, FETCH_RANGE)
	if w == null or w.pos_x < director.screen_left() + 20.0 or w.pos_x > director.screen_right() - 20.0:
		return false
	_fetch_target = w
	_set_ai(Ai.FETCH)
	return true

func _ai_fetch() -> void:
	var w := _fetch_target
	if _armed() or w == null or not is_instance_valid(w) or not director.items.weapons.has(w) or ai_time > FETCH_GIVE_UP:
		_fetch_target = null
		_set_ai(Ai.CHASE)
		return
	var dx := w.pos_x - pos_x
	var dz := w.pos_z - pos_z
	if absf(dx) < WorldItems.GRAB_REACH.x * 0.8 and absf(dz) < WorldItems.GRAB_REACH.y * 0.8:
		move_input = Vector2.ZERO
		request_grab()
		_fetch_target = null
		_set_ai(Ai.LURK)
		return
	_walk_to(w.pos_x, _detour(w.pos_x, w.pos_z), false)
	if dx != 0.0:
		facing = 1 if dx > 0.0 else -1

func _begin_attack(id: StringName) -> void:
	move_input = Vector2.ZERO
	_set_ai(Ai.ATTACK)
	start_attack(id)

func _ai_attack_done() -> void:
	var pause: Vector2 = data["pause"]
	_attack_pause = randf_range(pause.x, pause.y) * pause_factor
	if randf() < 0.35:
		_start_retreat()
	else:
		_set_ai(Ai.CHASE)

func _ai_retreat() -> void:
	move_input = _retreat_dir * 0.8
	if target != null:
		facing = 1 if target.pos_x > pos_x else -1
	if ai_time > _retreat_time:
		_set_ai(Ai.CHASE)

func _start_retreat() -> void:
	_retreat_dir = Vector2(-facing, [-1, 0, 1].pick_random())
	_retreat_time = randf_range(0.35, 0.8)
	_set_ai(Ai.RETREAT)

## Steht ein Requisit zwischen mir und dem Ziel, gehe ich oben oder unten herum.
func _detour(goal_x: float, goal_z: float) -> float:
	if director.items == null:
		return goal_z
	var dir := 1 if goal_x > pos_x else -1
	for p in director.items.props:
		if not p.is_blocking():
			continue
		var ahead := (p.pos_x - pos_x) * dir
		var in_front := ahead > 0.0 and ahead < 70.0 + p.width * 0.5
		var target_behind := (goal_x - p.pos_x) * dir > 0.0
		var same_lane := p.pos_z - p.depth - 8.0 < pos_z and pos_z < p.pos_z + p.depth + 8.0
		if in_front and target_behind and same_lane:
			var top := p.pos_z - p.depth - 16.0
			var bottom := p.pos_z + p.depth + 16.0
			var lane := director.level.lane_bounds()
			if top < lane.position.y:
				return bottom
			if bottom > lane.end.y:
				return top
			return top if absf(goal_z - top) < absf(goal_z - bottom) else bottom
	return goal_z

func _walk_to(gx: float, gz: float, slow: bool) -> void:
	var dx := gx - pos_x
	var dz := gz - pos_z
	var k := 0.6 if slow else 1.0
	var mx := 0.0 if absf(dx) < 6.0 else signf(dx) * k
	var mz := 0.0 if absf(dz) < 4.0 else signf(dz) * k
	if absf(dx) < 20.0:
		mx *= absf(dx) / 20.0
	if absf(dz) < 10.0:
		mz *= absf(dz) / 10.0
	move_input = Vector2(mx, mz)

## Nimmt den Spieler, der am nächsten ist, und verteilt sich auf beide Spieler.
func _choose_target() -> Fighter:
	var best: Fighter = null
	var best_cost := INF
	for p in director.players:
		if p.current_health <= 0:
			continue
		var cost := absf(p.pos_x - pos_x) + 1.5 * absf(p.pos_z - pos_z)
		for g in director.enemies:
			if g != self and g.target == p and g.current_health > 0:
				cost += 160.0
		if p == target:
			cost -= 80.0
		cost += randf_range(0.0, 40.0)
		if cost < best_cost:
			best_cost = cost
			best = p
	return best

func _pick_attack() -> StringName:
	var table: Array = ARMED_ATTACKS if _armed() else data["attacks"]
	var total := 0
	for entry in table:
		total += entry[1]
	var r := randi_range(1, total)
	for entry in table:
		r -= entry[1]
		if r <= 0:
			return entry[0]
	return table[0][0]
