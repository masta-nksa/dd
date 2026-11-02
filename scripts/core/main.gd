extends Node2D
## Startpunkt von Doppelfaust. Stufe 2: Level, zwei Kämpfer, Kamera.

var level: Level
var fighters: Array[Fighter] = []
var camera_rig: CameraRig

func _ready() -> void:
	InputSetup.einrichten()
	level = Level.new()
	add_child(level)

	var farben := [Color(0.2, 0.45, 0.9), Color(0.9, 0.25, 0.25)]
	for i in 2:
		var fighter := Fighter.new()
		fighter.body_color = farben[i]
		add_child(fighter)
		fighter.setup(200.0 + i * 80.0, 400.0 + i * 20.0, level.lane_bounds())
		fighters.append(fighter)
		var ctrl := PlayerController.new()
		ctrl.player_index = i + 1
		ctrl.fighter = fighter
		add_child(ctrl)

	camera_rig = CameraRig.new()
	camera_rig.targets = fighters
	add_child(camera_rig)
	camera_rig.position = Vector2(480.0, Level.HEIGHT * 0.5)
