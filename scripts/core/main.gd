class_name Main
extends Node2D
## Startpunkt von Doppelfaust. Stufe 4: Level, zwei Kämpfer, Kampfsystem, Gegner mit Wellen, HUD.

static var waves_enabled := true       # Tests schalten die Wellen ab
static var training_dummy := false     # Trainingspuppe wie in Stufe 3
static var two_players := true
static var props_enabled := true       # Requisiten (Kisten, Fässer ...) aus dem Plan in `Level`

var level: Level
var fighters: Array[Fighter] = []   # Spieler
var dummy: Fighter = null
var camera_rig: CameraRig
var combat: CombatSystem
var items: WorldItems
var director: WaveDirector
var hud: Hud
var game_over := false

func _ready() -> void:
	InputSetup.einrichten()
	level = Level.new()
	add_child(level)

	items = WorldItems.new()
	add_child(items)
	if props_enabled:
		for entry in Level.PROP_PLAN:
			items.add_prop(entry[0], float(entry[1]), float(entry[2]))

	var farben := [Color(0.2, 0.45, 0.9), Color(0.9, 0.25, 0.25)]
	for i in (2 if two_players else 1):
		var fighter := Fighter.new()
		fighter.body_color = farben[i]
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
		dummy.body_color = Color(0.85, 0.6, 0.15)
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
	add_child(combat)

	camera_rig = CameraRig.new()
	camera_rig.targets = fighters
	camera_rig.keep_players_on_screen = waves_enabled
	add_child(camera_rig)
	items.players = fighters
	items.camera = camera_rig
	items.keep_on_screen = waves_enabled
	camera_rig.position = Vector2(480.0, Level.HEIGHT * 0.5)

	var layer := CanvasLayer.new()
	hud = Hud.new()
	hud.players = fighters
	hud.items = items
	hud.camera = camera_rig
	layer.add_child(hud)
	add_child(layer)

	director = WaveDirector.new()
	director.players = fighters
	director.camera = camera_rig
	director.combat = combat
	director.level = level
	director.items = items
	director.two_players = fighters.size() > 1
	director.finished = not waves_enabled
	director.banner.connect(hud.show_banner)
	director.go_hint.connect(hud.show_go)
	director.all_waves_done.connect(func(): hud.message = "GESCHAFFT!")
	add_child(director)

func _physics_process(_delta: float) -> void:
	if game_over or not waves_enabled:
		return
	for f in fighters:
		if f.current_health > 0:
			return
	game_over = true
	hud.message = "GAME OVER"

func _on_dummy_died() -> void:
	await get_tree().create_timer(2.5).timeout
	dummy.revive()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		Fighter.debug_boxes = not Fighter.debug_boxes
