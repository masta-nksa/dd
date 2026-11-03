extends SceneTree
## Headless-Test Kämpferwahl: Werte, Wahl mit Sperre, Start mit den gewählten Figuren, Modelle, Bot-Läufe.
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe7_test.gd
## Optionen: -- normal  → Bot-Läufe mit sterblichen Spielern (Balance-Messung, 8 Läufe je Figur)

const MAX_FRAMES := 60 * 420

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func neue_wahl(spieler: int) -> SelectScreen:
	var sel := SelectScreen.new()
	sel.player_count = spieler
	root.add_child(sel)
	return sel

func _init() -> void:
	SaveData.file_path = "user://doppelfaust_test7.cfg"
	await test_daten()
	await test_wahl()
	await test_app()
	await test_werte_im_kampf()
	await test_modelle()
	await test_laeufe(OS.get_cmdline_user_args().has("normal"))
	if FileAccess.file_exists(SaveData.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.file_path))
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Daten

func test_daten() -> void:
	var ids := FighterData.all_ids()
	pruefe(ids.size() == 8, "Acht Kämpfer")
	pruefe(FighterData.MAIN == [&"bruce", &"chuck", &"jackie", &"jcvd"] and FighterData.EXTRA == [&"kai", &"ria", &"bruno", &"mika"],
		"Hauptauswahl Bruce, Chuck, Jackie, JCVD; zusätzlich Kai, Ria, Bruno, Mika")
	var namen := {}
	for id in ids:
		var d := FighterData.get_data(id)
		namen[d["name"]] = true
		pruefe(d["skin"]["name"] == d["name"], "%s: Aussehen trägt denselben Namen" % id)
		for key in FighterData.RANGES:
			var bereich: Array = FighterData.RANGES[key]
			pruefe(d[key] >= bereich[0] and d[key] <= bereich[1], "%s: %s liegt im Balkenbereich" % [id, key])
	pruefe(namen.size() == 8, "Namen sind eindeutig")
	var kai := FighterData.get_data(&"kai")
	pruefe(kai["hp"] == 100 and kai["speed_x"] == 175.0 and kai["jump_speed"] == 620.0 and kai["weight"] == 1.0, "Kai entspricht den bisherigen Fighter-Werten")
	var bruno := FighterData.get_data(&"bruno")
	pruefe(bruno["hp"] == 108 and bruno["speed_x"] == 150.0 and bruno["weight"] == 1.3 and bruno["damage"] == 1.08, "Bruno nach PROJEKTSTAND Abschnitt 9")
	pruefe(absf(FighterData.bar(&"bruno", "weight") - (0.15 + 0.85 * ((1.3 - 0.85) / 0.5))) < 0.0001, "Wertebalken werden aus der Spanne berechnet")
	pruefe(not ModelFigure.available(&"bruce"), "Headless: kein 3D-Modell, die 2D-Figur bleibt")

# ---------------------------------------------------------------- Wahl

func test_wahl() -> void:
	var sel := neue_wahl(2)
	await frames(2)
	var fertig := []
	sel.picked.connect(func(ids: Array): fertig.append(ids))
	pruefe(sel.cursors[0] == 0 and sel.cursors[1] == 1, "1P steht auf Bruce, 2P auf Chuck")
	pruefe(sel.confirm(0) and sel.picks[0] == 0 and sel.owner_of(0) == 0, "1P wählt Bruce")
	sel.cursors[1] = 0
	sel.move_cursor(1, 0, 0)
	pruefe(not sel.confirm(1), "Bruce ist für 2P gesperrt")
	sel.move_cursor(1, 1, 0)
	pruefe(sel.cursors[1] == 1, "Der Cursor von 2P springt über die belegte Figur")
	sel.cursors[1] = 3
	sel.move_cursor(1, 1, 0)
	pruefe(sel.cursors[1] == 1, "Beim Weiterziehen wird Bruce übersprungen")
	sel.cursors[1] = 4
	sel.move_cursor(1, 0, 1)
	pruefe(sel.cursors[1] == 4, "Zeilenwechsel auf eine belegte Figur wird verweigert")
	sel.cursors[1] = 0
	pruefe(sel.confirm(0) == false, "1P kann nicht doppelt bestätigen")
	sel.release(0)
	pruefe(sel.picks[0] == -1 and sel.owner_of(0) == -1, "Zurück gibt Bruce frei")
	pruefe(sel.confirm(1) and sel.picks[1] == 0, "Jetzt gehört Bruce 2P")
	pruefe(sel.cursors[0] != 0 or sel.picks[0] == -1, "Der Cursor von 1P wird mit der Vergabe verdrängt")
	sel.cursors[0] = 0
	sel.move_cursor(0, 0, 0)
	pruefe(not sel.confirm(0), "Jetzt ist Bruce für 1P gesperrt")
	sel.cursors[0] = 6
	pruefe(sel.confirm(0), "1P wählt Bruno aus der zweiten Reihe")
	pruefe(sel.is_ready() and sel._countdown >= 0.0, "Beide bereit: der Start läuft an")
	sel.move_cursor(0, 1, 0)
	pruefe(sel.cursors[0] == 6, "Wer bestätigt hat, bewegt den Cursor nicht mehr")
	await create_timer(SelectScreen.START_DELAY + 0.5).timeout
	pruefe(fertig.size() == 1 and fertig[0] == [&"bruno", &"bruce"], "Start mit den gewählten Figuren in Spielerreihenfolge: %s" % [fertig])
	sel.queue_free()

	# gleichzeitig auf derselben Figur: wer zuerst bestätigt, bekommt sie
	var sel2 := neue_wahl(2)
	await frames(2)
	sel2.cursors[0] = 2
	sel2.cursors[1] = 2
	sel2.confirm(1)
	pruefe(sel2.owner_of(2) == 1 and sel2.cursors[0] != 2, "Beide Cursor auf einer Figur: wer zuerst bestätigt, bekommt sie, der andere Cursor rückt weiter")
	pruefe(sel2.is_taken_by_other(2, 0) and not sel2.is_taken_by_other(2, 1), "Die Figur ist nur für den anderen gesperrt")
	sel2.queue_free()

	# Zeilen und Ränder
	var sel3 := neue_wahl(1)
	await frames(2)
	sel3.move_cursor(0, -1, 0)
	pruefe(sel3.cursors[0] == 3, "Links von der ersten Figur ist die letzte der Reihe")
	sel3.move_cursor(0, 0, 1)
	pruefe(sel3.cursors[0] == 7, "Runter wechselt in die zweite Reihe")
	pruefe(sel3.confirm(0), "1 Spieler: eine Bestätigung genügt")
	await create_timer(SelectScreen.START_DELAY + 0.3).timeout
	sel3.queue_free()

# ---------------------------------------------------------------- App

func test_app() -> void:
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	app.screen.buttons[1].pressed.emit()
	await frames(3)
	var sel := app.screen as SelectScreen
	pruefe(sel != null and sel.player_count == 2 and app.mode == App.Mode.MENU, "«2 Spieler» zeigt die Wahl für zwei")
	sel.cursors[0] = 2
	sel.cursors[1] = 7
	sel.confirm(0)
	sel.confirm(1)
	await create_timer(SelectScreen.START_DELAY + 0.5).timeout
	await frames(3)
	pruefe(app.mode == App.Mode.PLAYING and app.game != null, "Nach der Wahl läuft das Spiel")
	var f1: Fighter = app.game.fighters[0]
	var f2: Fighter = app.game.fighters[1]
	pruefe(f1.fighter_id == &"jackie" and f2.fighter_id == &"mika", "Spieler 1 ist Jackie, Spieler 2 Mika")
	pruefe(f1.skin["name"] == "JACKIE" and f2.skin["name"] == "MIKA", "Das Aussehen kommt mit")
	pruefe(f1.max_health == 100 and f1.speed_x == 180.0 and f1.jump_speed == 670.0, "Werte von Jackie gelten im Spiel")
	pruefe(f2.max_health == 98 and f2.reach_factor == 1.15 and f2.weight == 0.95, "Werte von Mika gelten im Spiel")
	pruefe(f1.current_health == f1.max_health and f2.current_health == 98, "Die Figuren starten mit vollen Lebenspunkten")
	# Neustart behält die Wahl, Menü → Wahl beginnt von vorn
	app.start_game(true)
	await frames(3)
	pruefe(app.game.fighters[0].fighter_id == &"jackie" and app.game.fighters[1].fighter_id == &"mika", "Neustart behält die Figuren")
	app.show_menu()
	await frames(3)
	app.screen.buttons[0].pressed.emit()
	await frames(3)
	var sel1 := app.screen as SelectScreen
	pruefe(sel1.player_count == 1 and sel1.picks[0] == -1, "Die Wahl beginnt ohne Vorgabe")
	sel1.back_requested.emit()
	await frames(3)
	pruefe(app.screen is MenuScreen, "Zurück führt ins Menü")
	app.queue_free()
	await frames(2)
	Main.picks = [&"kai", &"ria"]

# ---------------------------------------------------------------- Werte im Kampf

func test_werte_im_kampf() -> void:
	var basis := Attacks.get_attack(&"punch1")
	pruefe(Attacks.scaled(basis, 1.0, 1.0, 1.0).damage == basis.damage and Attacks.scaled(basis, 1.0, 1.0, 1.0).startup == basis.startup,
		"Faktor 1 ändert den Angriff nicht")
	var schnell := Attacks.scaled(basis, 1.08, 1.25, 1.15)
	pruefe(schnell.damage == roundi(basis.damage * 1.08) and absf(schnell.startup - basis.startup / 1.25) < 0.0001
		and absf(schnell.reach - basis.reach * 1.15) < 0.0001 and absf(schnell.box_size.x - basis.box_size.x * 1.15) < 0.0001,
		"Schaden, Tempo und Reichweite werden angewandt")
	pruefe(schnell.chain_to == basis.chain_to and schnell.pose == basis.pose and schnell.knockback == basis.knockback, "Alles andere bleibt")
	pruefe(basis.damage == 10 and basis.startup == 0.06, "Die gemeinsame Vorlage bleibt unverändert")
	Main.waves_enabled = false
	Main.props_enabled = false
	Main.training_dummy = true
	Main.two_players = false
	Main.picks = [&"bruno", &"mika"]
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(2)
	var f: Fighter = szene.fighters[0]
	f.start_attack(&"punch1")
	pruefe(f.attack.damage == roundi(10 * 1.08) and absf(f.attack.startup - 0.06 / 0.9) < 0.0001, "Bruno schlägt härter und langsamer")
	pruefe(f.attack != Attacks.get_attack(&"punch1") and Attacks.get_attack(&"punch1").damage == 10, "Bruno nutzt eine eigene Kopie")
	var hb := f.hit_box
	hb.attack = f.attack
	pruefe(absf(hb.world_box().size.x - 40.0 * 0.95) < 0.01, "Die Treffer-Box folgt der Reichweite (Bruno 0,95)")
	var kai := Fighter.new()
	pruefe(kai._attack_for(&"punch1") == Attacks.get_attack(&"punch1"), "Ohne Faktoren gilt die gemeinsame Vorlage")
	kai.free()
	szene.queue_free()
	await frames(2)
	Main.waves_enabled = true
	Main.props_enabled = true
	Main.training_dummy = false
	Main.two_players = true
	Main.picks = [&"kai", &"ria"]

# ---------------------------------------------------------------- Modelle

func test_modelle() -> void:
	ModelFigure.force = true
	var vorhanden := ResourceLoader.exists(FighterData.model_path(&"bruce"))
	if not vorhanden:
		print("SKIP Modelle: assets/characters/*.glb fehlen (erst `tools/blender/build_fighter.py --fighter all`)")
		ModelFigure.force = false
		return
	var stand := Poses.stand(0.0)
	var schlag := Poses.attack(&"straight", 0.5, 0.3, 0.55)
	for id in FighterData.all_ids():
		var m := ModelFigure.create(id)
		pruefe(m != null, "%s: Modell lädt" % id)
		if m == null:
			continue
		root.add_child(m)
		await frames(1)
		pruefe(m.skeleton.get_bone_count() == 17, "%s: 17 Knochen" % id)
		m.set_pose(stand, 1)
		var kopf := m._view_point("head")
		var fuss := minf(m._view_point("foot.L").y, m._view_point("foot.R").y)
		pruefe(kopf.y > 1.2 and kopf.y < 1.9, "%s: Kopf in %.2f m Höhe" % [id, kopf.y])
		pruefe(absf(fuss - m._rest_foot_y) < 0.03, "%s: tiefster Fuss steht auf dem Boden (%.3f)" % [id, fuss])
		var hand_stand := m.hands(1.0)
		pruefe(hand_stand.size() == 4, "%s: vier Handpunkte" % id)
		m.set_pose(schlag, 1)
		var hand_schlag := m.hands(1.0)
		pruefe(hand_schlag[0].x > hand_stand[0].x + 8.0, "%s: Faust geht beim Schlag nach vorn (%.0f → %.0f px)" % [id, hand_stand[0].x, hand_schlag[0].x])
		m.set_pose(schlag, -1)
		pruefe(m.hands(1.0)[0].x < -20.0 and m._front == "L", "%s: nach links gedreht schlägt die linke Seite nach links" % id)
		m.set_pose(Poses.lying(), 1)
		pruefe(m._view_point("head").y < 0.7, "%s: liegend ist der Kopf unten (%.2f m)" % [id, m._view_point("head").y])
		m.queue_free()
	# Fighter mit Modell
	var f := Fighter.new()
	FighterData.apply(f, &"chuck")
	root.add_child(f)
	await frames(2)
	pruefe(f.model != null and f.model.fighter_id == &"chuck", "Fighter bekommt das Modell seiner Figur")
	f.queue_free()
	await frames(1)
	ModelFigure.force = false

# ---------------------------------------------------------------- Bot-Läufe

func bot(szene: Main, f: Fighter, rng: RandomNumberGenerator, frame: int) -> void:
	if f.current_health <= 0:
		f.move_input = Vector2.ZERO
		return
	var best: Enemy = null
	var best_d := INF
	for g in szene.director.enemies:
		if g.current_health <= 0:
			continue
		var d := absf(g.pos_x - f.pos_x) + 2.0 * absf(g.pos_z - f.pos_z)
		if d < best_d:
			best_d = d
			best = g
	if best == null:
		f.move_input = Vector2(1.0, clampf((420.0 - f.pos_z) / 20.0, -1, 1))
		return
	var side := 1 if f.pos_x >= best.pos_x else -1
	var gx := best.pos_x + side * 45.0
	f.move_input = Vector2(clampf((gx - f.pos_x) / 10.0, -1, 1), clampf((best.pos_z - f.pos_z) / 6.0, -1, 1))
	var dx := best.pos_x - f.pos_x
	if absf(dx) < 80.0:
		f.facing = 1 if dx > 0 else -1
	if absf(dx) < 75.0 and absf(best.pos_z - f.pos_z) < 14.0 and frame % 7 == 0:
		var r := rng.randf()
		if r < 0.6: f.request_attack(&"punch")
		elif r < 0.85: f.request_attack(&"kick")
		elif r < 0.9: f.request_attack(&"special")

func lauf(id: StringName, seed_wert: int, unsterblich: bool) -> Dictionary:
	seed(seed_wert)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	Main.waves_enabled = true
	Main.props_enabled = true
	Main.training_dummy = false
	Main.two_players = false
	Main.picks = [id, &"ria"]
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await physics_frame
	if unsterblich:
		for f in szene.fighters:
			f.max_health = 100000
			f.current_health = 100000
	var frame := 0
	var letzter_index := 0
	var letzter_fortschritt := 0
	while frame < MAX_FRAMES and not szene.director.finished and not szene.game_over:
		for f in szene.fighters:
			bot(szene, f, rng, frame)
		await physics_frame
		frame += 1
		if szene.director.index != letzter_index:
			letzter_index = szene.director.index
			letzter_fortschritt = frame
		if frame - letzter_fortschritt > 60 * 90:
			break   # 90 s ohne neue Welle: Softlock
	var ergebnis := {"lp": szene.fighters[0].current_health, "frames": frame, "fertig": szene.director.finished,
		"tot": szene.game_over, "welle": szene.director.index}
	szene.queue_free()
	await physics_frame
	return ergebnis

func test_laeufe(normal: bool) -> void:
	if normal:
		for id in FighterData.all_ids():
			var siege := 0
			var n := 8
			for i in n:
				var r: Dictionary = await lauf(id, 100 + i, false)
				if r["fertig"]:
					siege += 1
			print("%s: Siege %d / %d" % [id, siege, n])
		return
	for id in FighterData.all_ids():
		var r: Dictionary = await lauf(id, 7, true)
		pruefe(r["fertig"], "%s: Level bis zum Ende (%.0f s)" % [id, r["frames"] / 60.0])
	Main.picks = [&"kai", &"ria"]
