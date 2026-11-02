extends Node2D
## Startpunkt von Doppelfaust. Stufe 3: Level, zwei Kämpfer, Kampfsystem, Trainingspuppe, HUD.

var level: Level
var fighters: Array[Fighter] = []   # Spieler
var dummy: Fighter                  # Trainingspuppe (wird in Stufe 4 durch Gegner ersetzt)
var camera_rig: CameraRig
var combat: CombatSystem

func _ready() -> void:
	InputSetup.einrichten()
	level = Level.new()
	add_child(level)

	var farben := [Color(0.2, 0.45, 0.9), Color(0.9, 0.25, 0.25)]
	for i in 2:
		var fighter := Fighter.new()
		fighter.body_color = farben[i]
		fighter.team = 0
		add_child(fighter)
		fighter.setup(200.0 + i * 80.0, 400.0 + i * 20.0, level.lane_bounds())
		fighters.append(fighter)
		var ctrl := PlayerController.new()
		ctrl.player_index = i + 1
		ctrl.fighter = fighter
		add_child(ctrl)

	dummy = Fighter.new()
	dummy.body_color = Color(0.85, 0.6, 0.15)
	dummy.team = 1
	add_child(dummy)
	dummy.setup(520.0, 410.0, level.lane_bounds())
	dummy.facing = -1
	dummy.died.connect(_on_dummy_died)

	combat = CombatSystem.new()
	combat.fighters = [fighters[0], fighters[1], dummy]
	add_child(combat)   # nach den Fightern: läuft nach deren Aktualisierung

	camera_rig = CameraRig.new()
	camera_rig.targets = fighters
	add_child(camera_rig)
	camera_rig.position = Vector2(480.0, Level.HEIGHT * 0.5)

	var layer := CanvasLayer.new()
	var hud := Hud.new()
	hud.players = fighters
	layer.add_child(hud)
	add_child(layer)

func _on_dummy_died() -> void:
	await get_tree().create_timer(2.5).timeout
	dummy.revive()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		Fighter.debug_boxes = not Fighter.debug_boxes
