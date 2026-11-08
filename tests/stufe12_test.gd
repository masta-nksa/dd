extends SceneTree
## Headless-Test Schläger für alle: Gegner holen und schwingen den Baseballschläger, alle Modelle haben die Schläger-Clips.
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe12_test.gd
## Die Modell-Prüfungen brauchen die `.glb` (erst `blender -b -P tools/blender/build_fighter.py -- --fighter all --no-blend`).

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

## Szene ohne Wellen: ein Spieler (unverwundbar, weit rechts) und ein Gegner, den der Test selbst platziert.
func szene_mit_gegner(typ: StringName) -> Dictionary:
	Main.waves_enabled = false
	Main.props_enabled = false
	Main.training_dummy = false
	Main.two_players = false
	Main.picks = [&"kai", &"ria"]
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(3)
	var spieler: Fighter = szene.fighters[0]
	spieler.max_health = 100000
	spieler.current_health = 100000
	spieler.pos_x = 800.0
	spieler.pos_z = 420.0
	await frames(150)   # die Kamera folgt dem Spieler, damit Gegner und Waffe im Bild stehen
	szene.director._spawn(typ)
	var gegner: Enemy = szene.director.enemies[-1]
	gegner.pos_x = 460.0
	gegner.pos_z = 420.0
	gegner.facing = 1
	gegner.max_health = 100000
	gegner.current_health = 100000
	return {"szene": szene, "spieler": spieler, "gegner": gegner}

func _init() -> void:
	await test_holen()
	await test_nicht_holen()
	await test_schlagen()
	await test_fallen_lassen()
	await test_modelle()
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Gegner holen den Schläger

func test_holen() -> void:
	var s := await szene_mit_gegner(&"thug")
	var szene: Main = s["szene"]
	var g: Enemy = s["gegner"]
	pruefe(g.weapons_only, "Gegner heben nur Waffen auf")
	szene.items.spawn_weapon(&"bat", 10, 560.0, 420.0)
	var kiste := szene.items.add_prop(&"crate", 500.0, 420.0)
	await frames(60 * 6)
	pruefe(g.carried != null and g.carried.kind == &"bat" and not g.carried.heavy, "Der Gegner hebt den Schläger auf (Kiste daneben bleibt liegen)")
	pruefe(szene.items.weapons.is_empty(), "Der Schläger liegt nicht mehr am Boden")
	pruefe(is_instance_valid(kiste) and not kiste.in_hands, "Die Kiste ist unberührt")
	szene.queue_free()
	await frames(2)

func test_nicht_holen() -> void:
	var s := await szene_mit_gegner(&"dasher")
	var szene: Main = s["szene"]
	var sp: Fighter = s["spieler"]
	var g: Enemy = s["gegner"]
	var bat := szene.items.spawn_weapon(&"bat", 10, 560.0, 420.0)
	await frames(60)   # er fällt erst zu Boden
	g.ai = Enemy.Ai.HURT
	pruefe(szene.items.find_weapon_for_enemy(g, Enemy.FETCH_RANGE) == bat, "Ein Schläger in 100 px ist ein Ziel")
	sp.pos_x = 570.0
	pruefe(szene.items.find_weapon_for_enemy(g, Enemy.FETCH_RANGE) == null, "Steht ein Spieler näher dran, holt ihn der Gegner nicht")
	sp.pos_x = 800.0
	g.pos_x = 100.0
	pruefe(szene.items.find_weapon_for_enemy(g, Enemy.FETCH_RANGE) == null, "Zu weit weg: kein Ziel")
	g.pos_x = 460.0
	g.pos_z = 520.0
	pruefe(szene.items.find_weapon_for_enemy(g, Enemy.FETCH_RANGE) == null, "Zu weit in der Tiefe: kein Ziel")
	var eigene := szene.items.find_grabbable(g)
	pruefe(eigene == null, "`find_grabbable` liefert dem Gegner keine Kiste")
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Mit dem Schläger zuschlagen

func test_schlagen() -> void:
	var s := await szene_mit_gegner(&"thug")
	var szene: Main = s["szene"]
	var sp: Fighter = s["spieler"]
	var g: Enemy = s["gegner"]
	var normal := {}
	for i in 60:
		normal[g._pick_attack()] = true
	pruefe(not normal.has(&"w_bat1") and normal.has(&"g_schlag"), "Ohne Schläger wählt er seine eigenen Angriffe")
	var reach_ohne := g._reach()
	g.carried = Carry.new(&"bat", 10)
	var bewaffnet := {}
	for i in 60:
		bewaffnet[g._pick_attack()] = true
	pruefe(bewaffnet.keys().all(func(id): return String(id).begins_with("w_")) and bewaffnet.has(&"w_bat1"), "Mit Schläger wählt er nur Schläger-Angriffe")
	pruefe(g._reach() > reach_ohne, "Mit Schläger schlägt er aus grösserer Entfernung zu (%.0f statt %.0f px)" % [g._reach(), reach_ohne])
	sp.pos_x = 360.0
	sp.pos_z = 420.0
	var gesehen := {}
	var rest_start := g.carried.rest
	for i in 60 * 8:
		g.may_attack = true
		if g.attack != null:
			gesehen[g.attack.id] = true
		await physics_frame
	pruefe(gesehen.has(&"w_bat1") or gesehen.has(&"w_homerun"), "Der Gegner schlägt mit dem Schläger zu (%s)" % [gesehen.keys()])
	pruefe(sp.current_health < 100000, "Der Schlag trifft den Spieler")
	pruefe(g.carried == null or g.carried.rest < rest_start, "Treffer nutzen den Schläger ab")
	szene.queue_free()
	await frames(2)

func test_fallen_lassen() -> void:
	var s := await szene_mit_gegner(&"brute")
	var szene: Main = s["szene"]
	var sp: Fighter = s["spieler"]
	var g: Enemy = s["gegner"]
	g.carried = Carry.new(&"bat", 7)
	g.current_health = 5
	g.max_health = 80
	g.take_hit(Attacks.get_attack(&"punch3"), sp)
	pruefe(g.carried == null, "Ein gefallener Gegner lässt den Schläger los")
	pruefe(szene.items.weapons.size() == 1 and szene.items.weapons[0].rest == 7, "Der Schläger liegt mit seiner Haltbarkeit am Boden")
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Modelle

func test_modelle() -> void:
	ModelFigure.force = true
	if not ResourceLoader.exists(FighterData.model_path(&"bruce")):
		print("SKIP Modelle: assets/characters/*.glb fehlen")
		ModelFigure.force = false
		return
	var namen: Array[StringName] = FighterData.all_ids()
	namen.append_array([&"thug", &"dasher", &"brute", &"boss", &"thug_cap", &"dasher_spiky", &"brute_bare"])
	for id in namen:
		var m := ModelFigure.create(id)
		pruefe(m != null, "%s: Modell lädt" % id)
		if m == null:
			continue
		var alle := true
		for clip in [&"w_bat1", &"w_bat2", &"w_homerun", &"w_block"]:
			alle = alle and m.has_clip(clip)
		pruefe(alle, "%s: Schläger-Clips w_bat1, w_bat2, w_homerun, w_block" % id)
		if id == &"bruce":
			pruefe(m.has_clip(&"kick_high") and m.has_clip(&"punch1"), "Bruce hat weiter alle Kampf-Clips")
		else:
			pruefe(not m.has_clip(&"kick_high"), "%s: übrige Angriffe bleiben bei den Posen" % id)
		root.add_child(m)
		await frames(1)
		m.set_clip(&"w_bat1", 1.2, 1)
		m.show_bat(1.0)
		var faust: Vector2 = m.hands(1.0)[0]
		pruefe(faust.x > 20.0, "%s: Schlag mit dem Schläger zeigt die Faust nach vorn (%.0f px)" % [id, faust.x])
		m.queue_free()
		await frames(1)
	ModelFigure.force = false
