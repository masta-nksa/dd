extends SceneTree
## Headless-Test Kampf: godot --headless -s tests/stufe3_test.gd

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func aufstellen(szene: Node, abstand: float = 40.0) -> void:
	var f1: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy
	d.revive()
	d.pos_x = 1000.0
	d.pos_z = 420.0
	d.facing = -1
	f1.pos_x = 1000.0 - abstand
	f1.pos_z = 420.0
	f1.pos_y = 0.0
	f1.facing = 1
	f1.state = Fighter.State.IDLE
	await frames(30)

func _init() -> void:
	Main.waves_enabled = false
	Main.training_dummy = true
	var szene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(2)
	var f1: Fighter = szene.fighters[0]
	var f2: Fighter = szene.fighters[1]
	var d: Fighter = szene.dummy
	f2.pos_x = 300.0   # P2 weit weg

	# 1) Einzelschlag
	await aufstellen(szene)
	f1.request_attack(&"punch")
	await frames(25)
	pruefe(d.current_health == 90, "Schlag macht 10 Schaden (Puppe %d)" % d.current_health)
	pruefe(d.state == Fighter.State.HIT or d.state == Fighter.State.IDLE, "Puppe nicht umgeworfen")

	# 2) Kein Treffer ausser Reichweite / in anderer Spur
	await aufstellen(szene, 200.0)
	f1.request_attack(&"punch")
	await frames(30)
	pruefe(d.current_health == 100, "Ausser Reichweite: kein Treffer")
	await aufstellen(szene)
	f1.pos_z = 470.0
	f1.request_attack(&"punch")
	await frames(30)
	pruefe(d.current_health == 100, "Andere Spur (Tiefe): kein Treffer")

	# 3) Dreier-Combo
	await aufstellen(szene)
	f1.request_attack(&"punch")
	await frames(12)
	f1.request_attack(&"punch")
	await frames(12)
	f1.request_attack(&"punch")
	await frames(14)
	pruefe(d.current_health == 60, "Combo 10+12+18 = 40 Schaden (Puppe %d)" % d.current_health)
	pruefe(d.state == Fighter.State.KNOCKDOWN, "3. Schlag wirft um")
	var x_vor := d.pos_x
	await frames(20)
	pruefe(d.pos_x > x_vor, "Rückstoss schiebt die Puppe nach rechts")

	# 4) Unverwundbar am Boden, danach aufstehen
	d.revive()
	d.current_health = 60
	d.state = Fighter.State.KNOCKDOWN
	d._landed = true
	d._state_time = 0.0
	f1.pos_x = d.pos_x - 40.0
	f1.request_attack(&"punch")
	await frames(20)
	pruefe(d.current_health == 60, "Am Boden unverwundbar")
	await frames(90)
	pruefe(d.state == Fighter.State.IDLE, "Puppe steht wieder auf")

	# 5) Tritt
	await aufstellen(szene)
	f1.request_attack(&"kick")
	await frames(30)
	pruefe(d.current_health == 86, "Tritt macht 14 Schaden (Puppe %d)" % d.current_health)

	# 6) Spezial trifft auch hinter dem Spieler und kostet 4 LP
	await aufstellen(szene)
	d.pos_x = f1.pos_x - 40.0
	var hp := f1.current_health
	f1.request_attack(&"special")
	await frames(40)
	pruefe(d.current_health == 90, "Wirbeltritt trifft von hinten (Puppe %d)" % d.current_health)
	pruefe(f1.current_health == hp - 4, "Wirbeltritt kostet 4 LP")
	pruefe(d.state == Fighter.State.KNOCKDOWN, "Wirbeltritt wirft um")

	# 7) Kein Friendly Fire
	await aufstellen(szene)
	f2.pos_x = f1.pos_x + 40.0
	f2.pos_z = f1.pos_z
	f2.facing = -1
	var hp2 := f2.current_health
	f1.request_attack(&"punch")
	await frames(25)
	pruefe(f2.current_health == hp2, "Kein Friendly Fire")
	f2.pos_x = 300.0

	# 8) Sprungtritt
	await aufstellen(szene)
	f1.request_jump()
	await frames(14)
	f1.request_attack(&"kick")
	await frames(40)
	pruefe(d.current_health <= 86, "Sprungtritt trifft (Puppe %d)" % d.current_health)
	pruefe(f1.state == Fighter.State.IDLE and f1.pos_y == 0.0, "Nach Sprungtritt wieder am Boden")

	# 9) Tod
	await aufstellen(szene)
	d.current_health = 5
	var gestorben := [false]
	d.died.connect(func(): gestorben[0] = true)
	f1.request_attack(&"punch")
	await frames(120)
	pruefe(gestorben[0] and d.state == Fighter.State.DEAD, "Puppe stirbt bei 0 LP")

	# 10) Mehrere Zufallsläufe: wildes Tastendrücken ohne Absturz
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	d.revive()
	for lauf in 600:
		for fx in [f1, f2, d]:
			fx.move_input = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			var r := rng.randi_range(0, 9)
			if r == 0: fx.request_jump()
			elif r == 1: fx.request_attack(&"punch")
			elif r == 2: fx.request_attack(&"kick")
			elif r == 3: fx.request_attack(&"special")
		await physics_frame
		for fx in [f1, f2, d]:
			if fx.current_health <= 0 and fx.state == Fighter.State.DEAD:
				fx.revive()
	pruefe(true, "600 Zufalls-Runden ohne Absturz")

	print("Fertig, Fehler: ", fehler)
	quit(fehler)
