class_name WaveDirector
extends Node
## Startet die Wellen der Reihe nach (Port von `Wellensteuerung`), verteilt die Angreifer
## und räumt tote Gegner weg. Muss im Szenenbaum NACH den Fightern stehen.

signal banner(text: String)
signal go_hint
signal all_waves_done

const MAX_ATTACKERS := 2    # so viele Gegner dürfen gleichzeitig auf denselben Spieler losgehen
const CORPSE_TIME := 1.6

# kamera_x = linker Bildrand, an dem die Kamera stehen bleibt
const WAVES := [
	{"camera_x": 420.0, "enemies": [&"thug", &"thug", &"thug"], "extra": [&"thug"], "at_once": 3},
	{"camera_x": 1350.0, "enemies": [&"thug", &"dasher", &"thug", &"dasher"], "extra": [&"thug", &"dasher"], "at_once": 3},
	{"camera_x": 2350.0, "enemies": [&"brute", &"thug", &"dasher", &"thug"], "extra": [&"dasher", &"thug"], "at_once": 3},
	{"camera_x": 3300.0, "enemies": [&"dasher", &"thug", &"brute", &"dasher", &"thug"], "extra": [&"brute", &"dasher"], "at_once": 4},
	{"camera_x": 4440.0, "enemies": [&"boss", &"thug", &"dasher", &"thug"], "extra": [&"brute", &"dasher"], "at_once": 3,
		"title": "BOSS: GRANIT"},
]

var players: Array[Fighter] = []
var enemies: Array[Enemy] = []
var camera: CameraRig
var combat: CombatSystem
var level: Level
var items: WorldItems
var two_players := true
var finished := false
var index := 0
var waves_total := 0

var _active := {}
var _queue: Array = []
var _next_in := 0.0
var _side := 1

func screen_left() -> float:
	return camera.position.x - 480.0

func screen_right() -> float:
	return camera.position.x + 480.0

func _physics_process(delta: float) -> void:
	_assign_attackers()
	_remove_corpses()
	if finished:
		return
	if _active.is_empty():
		if index >= WAVES.size():
			_finish()
			return
		var wave: Dictionary = WAVES[index]
		if screen_left() >= wave["camera_x"] - 4.0:
			_start(wave)
		return

	_next_in -= delta
	var alive := _alive_count()
	if not _queue.is_empty() and alive < _active["at_once"] and _next_in <= 0.0:
		_spawn(_queue.pop_front())
		_next_in = randf_range(0.6, 1.4)
	if _queue.is_empty() and alive == 0:
		camera.lock_x = -1.0
		_active = {}
		index += 1
		if index >= WAVES.size():
			_finish()
		else:
			go_hint.emit()

func _finish() -> void:
	finished = true
	all_waves_done.emit()

func _alive_count() -> int:
	var n := 0
	for g in enemies:
		if g.current_health > 0:
			n += 1
	return n

func _start(wave: Dictionary) -> void:
	_active = wave
	camera.lock_x = wave["camera_x"] + 480.0
	_queue = wave["enemies"].duplicate()
	if two_players:
		var extra: Array = wave["extra"]
		for i in extra.size():
			_queue.insert(mini(_queue.size(), 2 + i * 2), extra[i])
	_next_in = 0.5
	banner.emit(wave.get("title", "WELLE %d" % (index + 1)))

func _spawn(type: StringName) -> void:
	var seite := 1
	if type != &"boss":
		seite = _side if randf() < 0.7 else -_side
		_side = -_side
	var enemy := Enemy.create(type)
	enemy.director = director_ref()
	enemy.items = items
	var lane := level.lane_bounds()
	enemy.setup(screen_left() - 60.0 if seite < 0 else screen_right() + 60.0,
		randf_range(lane.position.y + 15.0, lane.end.y - 15.0), lane)
	enemy.facing = -seite
	enemy.died.connect(_on_enemy_died.bind(enemy))
	get_parent().add_child(enemy)
	enemies.append(enemy)
	combat.fighters.append(enemy)

func director_ref() -> WaveDirector:
	return self

func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.last_attacker != null:
		enemy.last_attacker.score += enemy.points
	if items != null:
		items.roll_weapon(enemy.type_id, enemy.pos_x, enemy.pos_z)

func _remove_corpses() -> void:
	for g in enemies.duplicate():
		if g.time_dead() > CORPSE_TIME:
			enemies.erase(g)
			combat.fighters.erase(g)
			g.queue_free()

## Pro Spieler dürfen nur die nächsten MAX_ATTACKERS Gegner zuschlagen, von beiden Seiten.
func _assign_attackers() -> void:
	for g in enemies:
		g.may_attack = false
	for p in players:
		var hunters: Array[Enemy] = []
		for g in enemies:
			if g.target == p and g.current_health > 0:
				hunters.append(g)
		hunters.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return _hunter_cost(a, p) < _hunter_cost(b, p))
		var first_side := 1
		for i in hunters.size():
			var g := hunters[i]
			var own_side := 1 if g.pos_x >= p.pos_x else -1
			g.may_attack = i < MAX_ATTACKERS
			if i == 0:
				g.side = own_side
				first_side = own_side
			elif i == 1:
				g.side = -first_side   # der zweite kommt von der anderen Seite
			else:
				g.side = own_side

func _hunter_cost(g: Enemy, p: Fighter) -> float:
	return absf(g.pos_x - p.pos_x) + 2.0 * absf(g.pos_z - p.pos_z) - (60.0 if g.may_attack else 0.0)
