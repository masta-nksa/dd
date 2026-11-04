class_name Main
extends Node2D
## Die Spielszene von Doppelfaust: Level, Kämpfer, Kampfsystem, Gegner mit Wellen, HUD.
## Das Menü und der Endbildschirm liegen in `App`; hier wird nur das Ende gemeldet.

signal run_ended(won: bool)

const WIN_DELAY := 4.0
const LOSE_DELAY := 2.0
const EXTRA_LIVES := 2

static var waves_enabled := true       # Tests schalten den Nachschub ab
static var level_count := 2            # Anzahl der Level; Tests mit 1 sind kürzer
static var training_dummy := false     # Trainingspuppe wie in Stufe 3
static var two_players := true
static var props_enabled := true       # Requisiten (Kisten, Fässer ...) aus dem Plan in `Level`
static var picks: Array[StringName] = [&"kai", &"ria"]   # gewählte Kämpfer (`FighterData`), Spieler 1 und 2

var level: Level
var fighters: Array[Fighter] = []   # Spieler
var dummy: Fighter = null
var camera_rig: CameraRig
var combat: CombatSystem
var items: WorldItems
var director: WaveDirector
var hud: Hud
var perf: PerfOverlay
var game_over := false
var play_time := 0.0
var level_index := 1

var _end_wait := 0.0
var _ended := false

func _ready() -> void:
	InputSetup.einrichten()
	level = Level.new()
	add_child(level)
	level_index = 1

	items = WorldItems.new()
	add_child(items)
	if props_enabled:
		for entry in Level.prop_plan(1):
			items.add_prop(entry[0], float(entry[1]), float(entry[2]))

	for i in (2 if two_players else 1):
		var fighter := Fighter.new()
		fighter.body_color = Art.PLAYER_COLORS[i]
		FighterData.apply(fighter, picks[i])
		fighter.player_number = i + 1
		fighter.lives = EXTRA_LIVES if waves_enabled else 0
		fighter.team = 0
		add_child(fighter)
		fighter.setup(200.0 + i * 80.0, 400.0 + i * 20.0, level.lane_bounds())
		fighter.items = items
		fighters.append(fighter)
		var ctrl := PlayerController.new()
		ctrl.player_index = i + 1
		ctrl.fighter = fighter
		add_child(ctrl)

	if training_dummy:
		dummy = Fighter.new()
		dummy.skin = Skins.THUG
		dummy.team = 1
		add_child(dummy)
		dummy.setup(520.0, 410.0, level.lane_bounds())
		dummy.items = items
		dummy.facing = -1
		dummy.died.connect(_on_dummy_died)

	combat = CombatSystem.new()
	for f in fighters:
		combat.fighters.append(f)
	if dummy != null:
		combat.fighters.append(dummy)
	combat.items = items
	combat.hit_landed.connect(_on_hit_landed)
	add_child(combat)

	camera_rig = CameraRig.new()
	camera_rig.targets = fighters
	camera_rig.keep_players_on_screen = waves_enabled
	add_child(camera_rig)
	items.players = fighters
	items.camera = camera_rig
	items.keep_on_screen = waves_enabled
	camera_rig.position = Vector2(480.0, Level.HEIGHT * 0.5)
	for f in fighters:
		f.camera = camera_rig

	var layer := CanvasLayer.new()
	hud = Hud.new()
	hud.players = fighters
	hud.items = items
	hud.camera = camera_rig
	layer.add_child(hud)
	perf = PerfOverlay.new()
	layer.add_child(perf)
	add_child(layer)

	director = WaveDirector.new()
	director.players = fighters
	director.camera = camera_rig
	director.combat = combat
	director.level = level
	director.items = items
	director.two_players = fighters.size() > 1
	director.finished = not waves_enabled
	hud.director = director
	director.banner.connect(hud.show_banner)
	director.banner.connect(func(_text: String): SoundBank.play(&"wave"))
	director.level_cleared.connect(_on_level_cleared)
	director.all_waves_done.connect(_on_all_waves_done)
	add_child(director)
	if waves_enabled:
		director.begin_level(1, level_count <= 1)

func _physics_process(delta: float) -> void:
	if not waves_enabled or _ended:
		return
	if not director.finished and not game_over:
		play_time += delta
		for f in fighters:
			if not f.is_out():
				return
		game_over = true
		hud.message = "GAME OVER"
		SoundBank.play(&"lose")
	_end_wait += delta
	if _end_wait >= (LOSE_DELAY if game_over else WIN_DELAY):
		_ended = true
		run_ended.emit(not game_over)

## Boss besiegt, es folgt das nächste Level: Punkte und Leben bleiben, die Lebenspunkte füllen sich auf.
func _on_level_cleared() -> void:
	hud.message = "LEVEL GESCHAFFT!"
	SoundBank.play(&"win")
	await get_tree().create_timer(3.0, false).timeout
	if game_over or _ended:
		return
	hud.message = ""
	_start_level(level_index + 1)

func _start_level(number: int) -> void:
	level_index = number
	level.queue_free()
	level = Level.new()
	level.level_index = number
	add_child(level)
	move_child(level, 0)
	director.level = level
	items.clear_world()
	for entry in Level.prop_plan(number):
		items.add_prop(entry[0], float(entry[1]), float(entry[2]))
	for i in fighters.size():
		var f := fighters[i]
		f.carried = null
		f.revive()          # wer ausgeschieden war, steigt wieder ein
		f.current_health = f.max_health
		f.pos_x = 200.0 + i * 80.0
		f.pos_z = 400.0 + i * 20.0
		f.pos_y = 0.0
	camera_rig.lock_x = -1.0
	camera_rig.position.x = 480.0
	director.begin_level(number, number >= level_count)

func _on_all_waves_done() -> void:
	if game_over:
		return
	hud.message = "GESCHAFFT!"
	SoundBank.play(&"win")
	for f in fighters:
		f.cheer = true

func _on_hit_landed(attacker: Fighter, target: Fighter, attack: AttackData) -> void:
	var knocked := target.state == Fighter.State.KNOCKDOWN
	if knocked:
		SoundBank.play(&"heavy")
	elif attack.pose in Poses.KICKS:
		SoundBank.play(&"kick")
	else:
		SoundBank.play(&"punch")
	if attacker.team == 0 and target.team != 0:
		attacker.count_hit(attack)
	hud.note_hit(target)
	var heavy := attack.hitstop >= 0.1   # kräftige Treffer rütteln stärker und sprühen mehr Funken
	camera_rig.shake(6.0 if knocked else 4.0 if heavy else 2.0)
	# Der Funke sitzt in der Mitte der Überschneidung von Schlag und Körper, bei Würfen an der Figur
	var at := Vector3(target.pos_x, target.pos_y + 50.0 * target.body_scale, target.pos_z)
	if attacker.hit_box.active:
		var overlap := attacker.hit_box.world_box().intersection(target.hurt_box.world_box())
		if overlap.has_volume():
			at = overlap.get_center()
	items.effects.spark(at.x, at.z, at.y, knocked or heavy)

func _on_dummy_died() -> void:
	await get_tree().create_timer(2.5).timeout
	dummy.revive()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		Fighter.debug_boxes = not Fighter.debug_boxes
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		perf.visible = not perf.visible
		perf.queue_redraw()
