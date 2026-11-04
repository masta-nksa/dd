class_name WaveDirector
extends Node
## Lässt laufend Gegner nachrücken, verteilt die Angreifer und räumt Tote weg. Muss im Szenenbaum NACH den Fightern stehen.
## Keine Wellen: Wie viele Gegner insgesamt kommen dürfen (`_budget`), wächst mit dem Weg durchs Level und tröpfelt
## auch beim Stehenbleiben nach. Wer vorankommt, trifft also immer wieder auf neue Gegner, wer wartet, bekommt hin und wieder Besuch.
## Am Levelende erscheint der Boss; mit ihm kommen weiter einzelne Gegner. Fällt der Boss, geben die übrigen auf.

signal banner(text: String)
signal level_cleared          # Boss besiegt, es folgt ein weiteres Level
signal all_waves_done         # Boss des letzten Levels besiegt

const MAX_ATTACKERS := 3    # so viele Gegner dürfen gleichzeitig auf denselben Spieler losgehen
const CORPSE_TIME := 1.6
const BOSS_X := Level.WIDTH - 960.0    # linker Bildrand, ab dem der Boss kommt
const START_BUDGET := 3.0
const TRICKLE_TIME := 10.0             # alle so viele Sekunden darf ein weiterer Gegner kommen
## Je Level: Gegner insgesamt bis zum Boss, Faktoren für Lebenspunkte, Schaden und Angriffspausen, Boss-Lebenspunkte.
const LEVELS := {
	1: {"budget": 24.0, "hp": 1.5, "damage": 1.3, "pause": 0.7, "boss_hp": 1.0, "boss": "BOSS: GRANIT"},
	2: {"budget": 30.0, "hp": 1.9, "damage": 1.5, "pause": 0.6, "boss_hp": 1.3, "boss": "BOSS: DRACHE"},
}

var players: Array[Fighter] = []
var enemies: Array[Enemy] = []
var camera: CameraRig
var combat: CombatSystem
var level: Level
var items: WorldItems
var two_players := true
var finished := false
var level_index := 1
var last_level := true
var index := 0                # bisher besiegte Gegner

var _spawned := 0
var _trickle := 0.0
var _next_in := 1.5
var _boss_spawned := false
var _cleared := false
var _side := 1

func screen_left() -> float:
	return camera.position.x - 480.0

func screen_right() -> float:
	return camera.position.x + 480.0

## Fortschritt im Level von 0 (Anfang) bis 1 (Bossbild).
func progress() -> float:
	return clampf(screen_left() / BOSS_X, 0.0, 1.0)

func settings() -> Dictionary:
	return LEVELS[clampi(level_index, 1, LEVELS.size())]

## Wie viele Gegner bis jetzt insgesamt erscheinen durften.
func budget() -> float:
	return START_BUDGET + progress() * float(settings()["budget"]) * (1.4 if two_players else 1.0) + _trickle

func max_alive() -> int:
	if _boss_spawned:
		return 3 + (1 if two_players else 0)
	return 3 + int(progress() * 3.0) + (2 if two_players else 0)

func begin_level(number: int, is_last: bool) -> void:
	level_index = number
	last_level = is_last
	finished = false
	_spawned = 0
	_trickle = 0.0
	_next_in = 1.5
	_boss_spawned = false
	_cleared = false
	banner.emit("LEVEL %d" % number)

func _physics_process(delta: float) -> void:
	_assign_attackers()
	_remove_corpses()
	if finished or _cleared or camera == null:
		return
	_trickle += delta / TRICKLE_TIME
	_next_in -= delta
	if not _boss_spawned and screen_left() >= BOSS_X - 4.0:
		_boss_spawned = true
		_next_in = 6.0
		_spawn(&"boss")
		banner.emit(settings()["boss"])
		return
	if _next_in > 0.0 or _alive_count() >= max_alive():
		return
	if _boss_spawned:
		_next_in = randf_range(6.0, 9.0)
		_spawn(_pick_type())
	elif float(_spawned) < budget():
		_next_in = randf_range(1.0, 2.6) * (1.0 - 0.3 * progress())
		_spawn(_pick_type())

func _pick_type() -> StringName:
	var p := progress()
	var weights := {&"thug": 5.0, &"dasher": 2.0 + 3.0 * p}
	if p > 0.2 or level_index > 1 or _boss_spawned:
		weights[&"brute"] = 0.6 + 2.2 * p + (1.0 if level_index > 1 else 0.0)
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return &"thug"

func _alive_count() -> int:
	var n := 0
	for g in enemies:
		if g.current_health > 0:
			n += 1
	return n

func _spawn(type: StringName) -> void:
	var cfg := settings()
	var is_boss := type == &"boss"
	var enemy := Enemy.create(type, 1 if is_boss and level_index > 1 else -1)
	if is_boss and level_index > 1:
		enemy.skin = enemy.skin.duplicate()
		enemy.skin["name"] = "BOSS DRACHE"
	var hp_scale: float = cfg["hp"] * (1.0 + 0.25 * progress()) * (cfg["boss_hp"] if is_boss else 1.0)
	enemy.max_health = int(round(enemy.max_health * hp_scale))
	enemy.damage_factor = cfg["damage"]
	enemy.pause_factor = cfg["pause"]
	var seite := 1
	if not is_boss:
		seite = _side if randf() < 0.7 else -_side
		_side = -_side
	enemy.director = self
	enemy.items = items
	var lane := level.lane_bounds()
	enemy.setup(screen_left() - 60.0 if seite < 0 else screen_right() + 60.0,
		randf_range(lane.position.y + 15.0, lane.end.y - 15.0), lane)
	enemy.facing = -seite
	enemy.died.connect(_on_enemy_died.bind(enemy))
	get_parent().add_child(enemy)
	enemies.append(enemy)
	combat.fighters.append(enemy)
	if not is_boss:
		_spawned += 1

func _on_enemy_died(enemy: Enemy) -> void:
	index += 1
	if enemy.last_attacker != null:
		enemy.last_attacker.score += enemy.points
		if items != null:
			items.effects.text(enemy.pos_x, enemy.pos_z, FigureArt.HEIGHT * enemy.body_scale + 20.0, "+%d" % enemy.points)
	if items != null:
		items.roll_weapon(enemy.type_id, enemy.pos_x, enemy.pos_z)
	if enemy.type_id == &"boss":
		_end_level()

## Der Boss ist gefallen: Die übrigen Gegner geben auf, und das Level ist geschafft.
func _end_level() -> void:
	_cleared = true
	for g in enemies:
		if g.current_health > 0:
			g.current_health = 0
			g._set_state(Fighter.State.DEAD)
	if last_level:
		_finish()
	else:
		level_cleared.emit()

func _finish() -> void:
	finished = true
	all_waves_done.emit()

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
