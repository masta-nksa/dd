extends SceneTree
## Headless-Test Grafik-Port, Leben und Combos: godot --headless --fixed-fps 3000 --disable-vsync -s tests/grafik_test.gd
## Das Aussehen selbst prüft dieser Test nicht, dafür braucht es Screenshots neben dem Original.

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func neue_szene(wellen: bool) -> Main:
	Main.waves_enabled = wellen
	Main.props_enabled = false
	Main.training_dummy = not wellen
	Main.two_players = false
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(3)
	return szene

func _init() -> void:
	# 1) Posen: jeder Angriff hat eine Pose mit allen Gelenken
	var alle_posen := true
	for id in Attacks.POSES:
		var pose_name: StringName = Attacks.get_attack(id).pose
		for t: float in [0.0, 0.2, 0.5, 0.99]:
			alle_posen = alle_posen and Poses.attack(pose_name, t, 0.3, 0.55).has_all(Poses.BASE.keys())
	pruefe(alle_posen, "Alle Angriffe haben vollständige Posen")
	pruefe(Attacks.get_attack(&"g_schlag").pose == &"straight", "Ohne Eintrag gilt die Gerade")
	pruefe(Poses.mix(Poses.BASE, Poses.lying(), 1.0)["turn"] == -90.0, "Mischen erreicht die Zielpose")

	# 2) Aussehen: jeder Gegnertyp hat sein eigenes
	var namen := {}
	for typ in Enemy.TYPES:
		var e := Enemy.create(typ)
		namen[e.skin["name"]] = true
		e.free()
	pruefe(namen.size() == Enemy.TYPES.size(), "Jeder Gegnertyp sieht anders aus")

	# 3) Level: Zonen, Ebenen, Parallaxe
	pruefe(LevelPainter.zone_at(100.0) == &"old_town" and LevelPainter.zone_at(2000.0) == &"industry" and LevelPainter.zone_at(5000.0) == &"harbour", "Drei Zonen")
	pruefe((Art.painted_font().base_font as FontFile).oversampling == 1.0, "Gemalter Text hängt nicht von der Fenstergrösse ab")
	var szene: Main = await neue_szene(false)
	var f: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy
	pruefe(szene.level.get_child_count() >= 5, "Level hat Himmel, Skyline und Strassenstücke")
	szene.camera_rig.position.x = 2000.0
	await process_frame
	await process_frame
	var far := szene.level.get_node("far") as Sprite2D
	var left := szene.camera_rig.global_position.x - 480.0
	pruefe(is_equal_approx(far.position.x, left * (1.0 - LevelPainter.PARALLAX)), "Skyline scrollt langsamer als die Strasse")
	pruefe(is_equal_approx((szene.level.get_node("sky") as Sprite2D).position.x, left), "Himmel steht still")

	# 4) Pose passt zum Zustand
	var states := [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.JUMP, Fighter.State.HIT, Fighter.State.KNOCKDOWN,
		Fighter.State.GETUP, Fighter.State.DEAD, Fighter.State.GRAB]
	var vollstaendig := true
	for s in states:
		f.state = s
		vollstaendig = vollstaendig and f.current_pose().has_all(Poses.BASE.keys())
	f.state = Fighter.State.DEAD
	pruefe(vollstaendig and f.current_pose()["turn"] == -90.0, "Jeder Zustand hat eine Pose, Tote liegen")
	f.state = Fighter.State.IDLE
	f.cheer = true
	f.move_input = Vector2(1.0, 0.0)
	var x_vorher := f.pos_x
	await frames(1)
	pruefe(f.current_pose()["fs"] > 100.0 and f.pos_x == x_vorher, "Sieger jubeln und bleiben stehen")
	f.cheer = false

	# 5) Treffer: Combo, Punkte, Funke, Wackeln, Gegneranzeige
	d.revive()
	d.pos_x = 1000.0
	d.pos_z = 420.0
	f.pos_x = 960.0
	f.pos_z = 420.0
	f.facing = 1
	f.score = 0
	f.bounds = Rect2(40, 322, 5320, 200)
	d.bounds = f.bounds
	await frames(2)
	f.request_attack(&"punch")
	var funke := false
	var gewackelt := false
	for i in 20:
		await frames(1)
		await process_frame
		funke = funke or not szene.items.effects._sparks.is_empty()
		gewackelt = gewackelt or szene.camera_rig.offset != Vector2.ZERO
	pruefe(f.combo == 1 and f.score == 100, "Treffer zählt: Combo 1, Schaden × 10 Punkte (%d)" % f.score)
	pruefe(funke, "Treffer macht einen Funken")
	pruefe(gewackelt, "Treffer lässt das Bild wackeln")
	pruefe(szene.hud._last_hit == d, "Getroffener Gegner erscheint in der Anzeige")
	f.count_hit(Attacks.get_attack(&"punch1"))
	pruefe(f.combo == 2 and f.best_combo == 2 and f.score == 205, "Zweiter Treffer gibt 5 Punkte Combo-Zuschlag (%d)" % f.score)
	await frames(int(60 * (Fighter.COMBO_TIME + 0.2)))
	pruefe(f.combo == 0 and f.best_combo == 2, "Combo fällt nach %.1f s zurück, die beste bleibt" % Fighter.COMBO_TIME)
	await frames(60)
	pruefe(szene.items.effects._sparks.is_empty() and szene.camera_rig.offset == Vector2.ZERO, "Funke und Wackeln klingen ab")
	szene.queue_free()
	await frames(2)

	# 6) Leben: zwei Extraleben, Einsteigen von oben, kurz unverwundbar, dann ist Schluss
	szene = await neue_szene(true)
	szene.director.set_physics_process(false)
	f = szene.fighters[0]
	pruefe(f.lives == Main.EXTRA_LIVES, "Spieler beginnt mit %d Extraleben" % Main.EXTRA_LIVES)
	var schlag := Attacks.get_attack(&"g_hammer")
	var gegner := Enemy.create(&"brute")
	f.current_health = 1
	f.take_hit(schlag, gegner)
	pruefe(f.current_health == 0 and not f.is_out() and not szene.game_over, "Erster Tod: noch nicht ausgeschieden")
	await frames(int(60 * (Fighter.RESPAWN_DELAY + 2.0)))
	pruefe(f.lives == 1 and f.current_health == f.max_health, "Nach dem Tod: ein Leben weniger, volle Lebenspunkte")
	pruefe(f.is_invulnerable() and f.pos_y >= 0.0, "Nach dem Einsteigen kurz unverwundbar")
	await frames(60 * 3)
	pruefe(not f.is_invulnerable() and f.pos_y == 0.0 and f.state == Fighter.State.IDLE, "Danach steht die Figur normal am Boden")
	for i in 2:
		f.current_health = 1
		f.state = Fighter.State.IDLE
		f.take_hit(schlag, gegner)
		if i == 0:
			await frames(int(60 * (Fighter.RESPAWN_DELAY + 4.5)))
			pruefe(f.lives == 0 and f.current_health == f.max_health, "Zweites Leben verbraucht")
	pruefe(f.is_out(), "Dritter Tod: ausgeschieden")
	await frames(3)
	pruefe(szene.game_over and szene.hud.message == "GAME OVER", "Erst jetzt ist das Spiel verloren")
	gegner.free()
	szene.queue_free()
	await frames(2)

	print("Fertig, Fehler: ", fehler)
	quit(fehler)
