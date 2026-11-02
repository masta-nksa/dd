class_name PlayerController
extends Node
## Liest die Tastatur für einen Spieler und steuert einen Fighter.

@export var player_index := 1
var fighter: Fighter

func _physics_process(_delta: float) -> void:
	if fighter == null:
		return
	var p := "p%d_" % player_index
	fighter.move_input = Vector2(
		Input.get_axis(p + "left", p + "right"),
		Input.get_axis(p + "up", p + "down"))
	if Input.is_action_just_pressed(p + "jump"):
		fighter.request_jump()
	for kind in [&"punch", &"kick", &"special"]:
		if Input.is_action_just_pressed(p + kind):
			fighter.request_attack(kind)
