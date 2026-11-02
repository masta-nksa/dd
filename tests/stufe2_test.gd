extends SceneTree
## Headless-Test: godot --headless -s tests/stufe2_test.gd

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("OK   ", text)
	else:
		print("FAIL ", text)
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	Main.waves_enabled = false
	Main.props_enabled = false
	var szene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(2)
	var f1: Fighter = szene.fighters[0]
	var f2: Fighter = szene.fighters[1]

	var x0 := f1.pos_x
	Input.action_press("p1_right")
	await frames(60)
	Input.action_release("p1_right")
	pruefe(f1.pos_x > x0 + 100.0, "P1 läuft nach rechts (%.0f -> %.0f)" % [x0, f1.pos_x])
	pruefe(f2.pos_x < 400.0, "P2 bleibt stehen (unabhängige Steuerung)")

	var z0 := f1.pos_z
	Input.action_press("p1_up")
	await frames(300)
	Input.action_release("p1_up")
	pruefe(f1.pos_z >= szene.level.lane_bounds().position.y - 0.01, "Tiefe nach hinten begrenzt (z=%.0f)" % f1.pos_z)
	pruefe(f1.pos_z < z0, "P1 bewegt sich in die Tiefe")

	var max_h := 0.0
	Input.action_press("p1_jump")
	await frames(2)
	Input.action_release("p1_jump")
	for i in 90:
		await physics_frame
		max_h = maxf(max_h, f1.pos_y)
	pruefe(max_h > 80.0, "Sprung erreicht Höhe %.0f" % max_h)
	pruefe(f1.pos_y == 0.0 and f1.state == Fighter.State.IDLE, "Landet wieder am Boden")

	f1.pos_z = 350.0
	f2.pos_z = 450.0
	await frames(2)
	pruefe(f2.z_index > f1.z_index, "Y-Sortierung: vordere Figur wird später gezeichnet")

	f1.pos_x = 2900.0
	f2.pos_x = 2800.0
	await frames(120)
	pruefe(szene.camera_rig.position.x > 2000.0, "Kamera folgt (x=%.0f)" % szene.camera_rig.position.x)
	pruefe(szene.camera_rig.get_screen_center_position().x <= Level.WIDTH, "Kamera bleibt im Level")

	print("Fertig, Fehler: ", fehler)
	quit(fehler)
