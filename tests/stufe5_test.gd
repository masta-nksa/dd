extends SceneTree
## Headless-Test Waffen und Requisiten: godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe5_test.gd

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func neue_szene() -> Main:
	Main.waves_enabled = false
	Main.props_enabled = false
	Main.training_dummy = true
	Main.two_players = true
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(2)
	szene.fighters[1].pos_x = 300.0   # P2 weit weg
	return szene

func aufstellen(szene: Main, abstand := 40.0) -> void:
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
	var szene: Main = await neue_szene()
	var f1: Fighter = szene.fighters[0]
	var items: WorldItems = szene.items
	var d: Fighter = szene.dummy

	# 1) Kiste zerschlagen: 3 Treffer, die erste Kiste enthält immer einen Schläger
	await aufstellen(szene, 40.0)
	f1.pos_x = 960.0
	d.pos_x = 1300.0
	var kiste := items.add_prop(&"crate", 1000.0, 420.0)
	for i in 3:
		f1.request_attack(&"punch")
		await frames(30)
		f1.pos_x = 960.0
	pruefe(not is_instance_valid(kiste), "Kiste geht nach 3 Treffern kaputt")
	pruefe(items.weapons.size() == 1, "Erste Kiste enthält garantiert eine Waffe")

	# 2) Aufheben
	for w in items.weapons.duplicate():
		w.remove()
	for p in items.pickups.duplicate():
		p.remove()
	await aufstellen(szene)
	items.spawn_weapon(&"bat", 10, f1.pos_x + 10.0, f1.pos_z)
	await frames(30)
	f1.request_grab()
	await frames(20)
	pruefe(f1.carried != null and f1.carried.kind == &"bat", "Greifen hebt den Schläger auf")
	pruefe(items.weapons.is_empty(), "Waffe liegt nicht mehr am Boden")

	# 3) Schlägerkette: 12 + 18, Haltbarkeit sinkt
	await aufstellen(szene)
	f1.request_attack(&"punch")
	await frames(12)
	f1.request_attack(&"punch")
	await frames(20)
	pruefe(d.current_health == 70, "Schläger: 12 + 18 Schaden (Puppe %d)" % d.current_health)
	pruefe(f1.carried != null and f1.carried.rest == 8, "Haltbarkeit 10 -> 8 (%d)" % f1.carried.rest)
	pruefe(d.state == Fighter.State.KNOCKDOWN, "2. Schlägerschlag wirft um")

	# 4) Homerun kostet 2
	await aufstellen(szene)
	f1.carried.rest = 8
	f1.request_attack(&"special")
	await frames(30)
	pruefe(d.current_health == 82 and f1.carried.rest == 6, "Homerun: 18 Schaden, kostet 2 (Puppe %d, Rest %d)" % [d.current_health, f1.carried.rest])

	# 5) Bruch bei 0
	await aufstellen(szene)
	f1.carried.rest = 1
	f1.request_attack(&"punch")
	await frames(30)
	pruefe(f1.carried == null, "Schläger bricht bei 0 Haltbarkeit")
	pruefe(d.current_health == 88, "Letzter Treffer zählt noch (Puppe %d)" % d.current_health)

	# 6) Schläger werfen: 14 Schaden, landet mit Haltbarkeit - 3
	await aufstellen(szene, 100.0)
	f1.carried = Carry.new(&"bat", 10)
	f1.request_grab()
	await frames(60)
	pruefe(d.current_health == 86, "Geworfener Schläger macht 14 Schaden (Puppe %d)" % d.current_health)
	pruefe(f1.carried == null, "Hände sind leer nach dem Wurf")
	pruefe(items.weapons.size() == 1 and items.weapons[0].rest == 7, "Schläger fällt mit Haltbarkeit 7 zu Boden")
	for w in items.weapons.duplicate():
		w.remove()

	# 7) Kiste tragen: langsamer, kein Sprung, Wurf mit 18 Schaden und Betäubung
	await aufstellen(szene, 200.0)
	d.pos_x = 1100.0
	var kiste2 := items.add_prop(&"crate", f1.pos_x + 30.0, f1.pos_z)
	await frames(2)
	f1.request_grab()
	await frames(20)
	pruefe(f1.is_carrying_heavy() and not items.props.has(kiste2), "Kiste wird getragen")
	f1.request_jump()
	await frames(10)
	pruefe(f1.pos_y == 0.0, "Mit Kiste kein Sprung")
	var x0 := f1.pos_x
	Input.action_press("p1_right")
	await frames(30)
	var weg := f1.pos_x - x0
	Input.action_release("p1_right")
	pruefe(weg < 175.0 * 0.5 * 0.9 and weg > 175.0 * 0.5 * 0.6, "Tragen bremst (%.0f px statt ~66)" % weg)
	f1.pos_x = 1000.0
	f1.request_attack(&"punch")
	await frames(40)
	pruefe(d.current_health == 82, "Geworfene Kiste: 18 Schaden (Puppe %d)" % d.current_health)
	pruefe(d.state == Fighter.State.HIT, "Kiste betäubt")
	pruefe(items.projectiles.is_empty() and f1.carried == null, "Kiste ist weg")

	# 8) Schweres wird bei Treffern fallen gelassen
	await aufstellen(szene, 300.0)
	var kiste3 := items.add_prop(&"crate", 700.0, 420.0)
	f1.pos_x = 680.0
	f1.pos_z = 420.0
	await frames(2)
	f1.request_grab()
	await frames(20)
	pruefe(f1.is_carrying_heavy(), "Kiste aufgenommen")
	f1.take_hit(Attacks.get_attack(&"g_schlag"), d)
	pruefe(f1.carried == null and items.props.has(kiste3), "Treffer: Kiste fällt zurück auf die Strasse")
	for p in items.props.duplicate():
		items.forget(p)
		p.queue_free()

	# 9) Heilung und Geld
	f1.current_health = 50
	items.spawn_pickup(&"chicken", f1.pos_x, f1.pos_z)
	await frames(60)
	pruefe(f1.current_health == 90, "Huhn heilt 40 (%d)" % f1.current_health)
	var punkte := f1.score
	items.spawn_pickup(&"money", f1.pos_x, f1.pos_z)
	await frames(60)
	pruefe(f1.score == punkte + 1000, "Geld gibt 1000 Punkte")

	# 10) Hindernis blockiert
	var sperre := items.add_prop(&"crate", 1500.0, 420.0)
	f1.pos_x = 1400.0
	f1.pos_z = 420.0
	Input.action_press("p1_right")
	await frames(120)
	Input.action_release("p1_right")
	pruefe(f1.pos_x < 1500.0 - 23.0 - 12.0 + 0.5, "Kiste versperrt den Weg (x=%.0f)" % f1.pos_x)
	Input.action_press("p1_right")
	Input.action_press("p1_jump")
	await frames(3)
	Input.action_release("p1_jump")
	await frames(60)
	Input.action_release("p1_right")
	pruefe(f1.pos_x > 1500.0, "Mit Sprung kommt man drüber (x=%.0f)" % f1.pos_x)
	items.forget(sperre)
	sperre.queue_free()

	# 11) Bodenzeit und Todes-Drop
	for w in items.weapons.duplicate():
		w.remove()
	var w2 := items.spawn_weapon(&"bat", 5, 1200.0, 400.0)
	w2.age = 12.1
	await frames(3)
	pruefe(items.weapons.is_empty(), "Waffe verschwindet nach 12 s")
	f1.current_health = 1
	f1.carried = Carry.new(&"bat", 6)
	f1.take_hit(Attacks.get_attack(&"g_schlag"), d)
	pruefe(f1.carried == null and items.weapons.size() == 1 and items.weapons[0].blinking, "Gestorbener lässt die Waffe blinkend liegen")

	# 12) Waffenverteiler: nie mehr Waffen am Boden als Spieler
	for w in items.weapons.duplicate():
		w.remove()
	f1.revive()
	var maximum := 0
	for i in 60:
		items.elapsed += 20.0
		items.roll_weapon(&"brute", 800.0, 420.0)
		maximum = maxi(maximum, items.weapons.size())
	pruefe(maximum >= 1 and maximum <= 2, "Verteiler: höchstens so viele Waffen wie Spieler (max. %d)" % maximum)
	var vorher := items.weapons.size()
	items.roll_weapon(&"brute", 800.0, 420.0)
	pruefe(items.weapons.size() == vorher, "Verteiler: Mindestabstand von 12 s")

	print("Fertig, Fehler: ", fehler)
	quit(fehler)
