extends SceneTree
## Headless-Test Kampfbewegungen: Low Kick und High Kick, Combo-Tabelle, Trefferwirkung, Clips von Bruce.
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe8_test.gd
## Die Clip-Prüfungen brauchen `assets/characters/player_bruce.glb` und überspringen sich ohne Datei.

const CLIPS: Array[StringName] = [&"punch1", &"punch2", &"punch3", &"kick_low", &"kick_high", &"jump_kick", &"spin"]

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	test_daten()
	await test_kampf()
	await test_clips()
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Daten

func test_daten() -> void:
	var low := Attacks.get_attack(&"kick_low")
	var high := Attacks.get_attack(&"kick_high")
	pruefe(low.startup < high.startup and low.total_time() < high.total_time(), "Low Kick ist schneller als High Kick")
	pruefe(low.damage < high.damage and low.knockback < high.knockback, "High Kick trifft kräftiger")
	pruefe(low.reach < high.reach, "High Kick reicht weiter")
	pruefe(low.box_y + low.box_size.y <= 40.0 and high.box_y >= 50.0, "Hitboxen sitzen unten und oben, ohne Überlappung")
	pruefe(low.hit_level == &"low" and high.hit_level == &"high", "Treffer zählen als tief und hoch")
	pruefe(high.hitstop > low.hitstop, "High Kick friert länger ein")
	# phase_at: die drei Abschnitte des Angriffs liegen auf den festen Abschnitten des Clips
	for a: AttackData in [low, high, Attacks.scaled(high, 1.0, 1.15, 1.0)]:
		pruefe(is_zero_approx(a.phase_at(0.0)) and is_equal_approx(a.phase_at(a.startup), 1.0)
			and is_equal_approx(a.phase_at(a.startup + a.active), 2.0) and is_equal_approx(a.phase_at(a.total_time() + 1.0), 3.0),
			"%s: Phasen 0, 1, 2, 3 bei Start, Treffer, Erholung, Ende (Anlauf %.3f s)" % [a.id, a.startup])
	# Combo-Tabelle: Jeder Weg endet; sonst liesse sich ein Gegner endlos festhalten
	var longest := _longest_chain(&"punch1", [])
	pruefe(longest >= 5, "Längste Combo ab dem ersten Schlag: %d Angriffe" % longest)
	pruefe(Attacks.get_attack(&"g_schlag").chains.has(&"punch") and Attacks.get_attack(&"g_schlag").chain_needs_hit, "Gegner-Kette läuft weiter über die Tabelle")
	InputSetup.einrichten()
	pruefe(InputMap.has_action("p1_kick_high") and InputMap.has_action("p2_kick_high"), "High Kick hat eine eigene Aktion")
	pruefe(InputSetup.BELEGUNG[1]["kick_high"] == KEY_T and InputSetup.BELEGUNG[2]["kick_high"] == KEY_U, "Tasten T und U")
	pruefe(not InputSetup.PAD_BUTTONS["punch"].has(JOY_BUTTON_LEFT_SHOULDER) and InputSetup.PAD_BUTTONS["kick_high"].has(JOY_BUTTON_LEFT_SHOULDER), "LB ist am Controller der High Kick")
	var belegt := {}
	for action in InputSetup.BELEGUNG[1]:
		belegt[InputSetup.BELEGUNG[1][action]] = true
	for action in InputSetup.BELEGUNG[2]:
		belegt[InputSetup.BELEGUNG[2][action]] = true
	pruefe(belegt.size() == InputSetup.BELEGUNG[1].size() * 2, "Keine Taste ist doppelt belegt")

func _longest_chain(id: StringName, path: Array) -> int:
	if id in path:
		pruefe(false, "Combo-Schleife: %s" % [path + [id]])
		return 0
	var best := 0
	for next in Attacks.get_attack(id).chains.values():
		best = maxi(best, _longest_chain(next, path + [id]))
	return best + 1

# ---------------------------------------------------------------- Im Kampf

func aufstellen(szene: Main, abstand := 40.0) -> void:
	var f: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy
	d.revive()
	d.pos_x = 1000.0
	d.pos_z = 420.0
	d.facing = -1
	f.pos_x = 1000.0 - abstand
	f.pos_z = 420.0
	f.pos_y = 0.0
	f.facing = 1
	f.attack = null
	f.state = Fighter.State.IDLE
	await frames(30)

func test_kampf() -> void:
	Main.waves_enabled = false
	Main.training_dummy = true
	Main.two_players = false
	Main.picks = [&"bruce", &"kai"]
	var szene: Main = load("res://scenes/main.tscn").instantiate() if ResourceLoader.exists("res://scenes/main.tscn") else Main.new()
	root.add_child(szene)
	await frames(2)
	var f: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy
	var faktor := f.damage_factor

	await aufstellen(szene)
	var vorher := d.current_health
	f.request_attack(&"kick")
	await frames(2)
	pruefe(f.attack != null and f.attack.id == &"kick_low", "Taste Tritt startet den Low Kick")
	await frames(25)
	pruefe(vorher - d.current_health == roundi(10 * faktor), "Low Kick trifft (%d Schaden)" % (vorher - d.current_health))
	pruefe(d._hit_level == &"low", "Getroffener reagiert auf einen tiefen Treffer")

	await aufstellen(szene, 50.0)
	vorher = d.current_health
	f.request_attack(&"kick_high")
	await frames(2)
	pruefe(f.attack != null and f.attack.id == &"kick_high", "Taste High Kick startet den High Kick")
	var eingefroren := 0.0
	for i in 30:
		await physics_frame
		eingefroren = maxf(eingefroren, d._freeze_time)
	pruefe(vorher - d.current_health == roundi(17 * faktor), "High Kick trifft (%d Schaden)" % (vorher - d.current_health))
	pruefe(d._hit_level == &"high", "Getroffener reagiert auf einen hohen Treffer")
	pruefe(eingefroren > 0.08, "Trefferstopp je Angriff (%.3f s)" % eingefroren)
	var hoch := Poses.hit(0.0, &"high")
	var tief := Poses.hit(0.0, &"low")
	pruefe(hoch["head"] < -20.0 and tief["lean"] > 15.0, "Reaktion: oben fliegt der Kopf zurück, unten knickt die Figur ein")

	# Ganze Combo: Schlag, Low Kick, Schlag, High Kick, Schlag
	await aufstellen(szene)
	d.pos_x = 3000.0   # ohne Treffer, damit keine Trefferpause die Zeiten verschiebt
	var folge: Array[StringName] = []
	var tasten: Array[StringName] = [&"punch", &"kick", &"punch", &"kick", &"punch"]
	f.request_attack(tasten[0])
	for i in 240:
		await physics_frame
		if f.attack != null and (folge.is_empty() or folge[-1] != f.attack.id):
			folge.append(f.attack.id)
			if folge.size() < tasten.size():
				f.request_attack(tasten[folge.size()])
	var erwartet: Array[StringName] = [&"punch1", &"kick_low", &"punch2", &"kick_high", &"punch3"]
	pruefe(folge == erwartet, "Combo läuft quer über Schlag und Tritt: %s" % [folge])

	# Dieselbe Combo am Gegner: Kein Glied darf wegen des Rückstosses ins Leere gehen
	await aufstellen(szene)
	folge.clear()
	var treffer := [0]
	var zaehler := func(attacker: Fighter, _t: Fighter, _a: AttackData) -> void:
		if attacker == f:
			treffer[0] += 1
	szene.combat.hit_landed.connect(zaehler)
	f.request_attack(tasten[0])
	for i in 300:
		await physics_frame
		if f.attack != null and (folge.is_empty() or folge[-1] != f.attack.id):
			folge.append(f.attack.id)
			if folge.size() < tasten.size():
				f.request_attack(tasten[folge.size()])
	szene.combat.hit_landed.disconnect(zaehler)
	pruefe(folge == erwartet and treffer[0] == erwartet.size(), "Alle Glieder der Combo treffen (%d von %d)" % [treffer[0], erwartet.size()])

	await aufstellen(szene)
	f.request_jump()
	await frames(14)
	f.request_attack(&"kick_high")
	await frames(2)
	pruefe(f.attack != null and f.attack.id == &"jump_kick", "In der Luft wird auch der High Kick zum Sprungtritt")
	await frames(60)
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Clips

func test_clips() -> void:
	ModelFigure.force = true
	if not ResourceLoader.exists(FighterData.model_path(&"bruce")):
		print("SKIP Clips: assets/characters/player_bruce.glb fehlt")
		ModelFigure.force = false
		return
	var m := ModelFigure.create(&"bruce")
	pruefe(m != null, "Bruce lädt")
	root.add_child(m)
	await frames(1)
	for id in CLIPS:
		pruefe(m.has_clip(id) and m._clips.has("%s_L" % id), "%s: Clip für beide Blickrichtungen" % id)
		var anim: Animation = m._clips["%s_R" % id]["anim"]
		pruefe(absf(anim.length - 3.0) < 0.01, "%s: dauert 3 Abschnitte (%.2f)" % [id, anim.length])
		pruefe(m._clips["%s_R" % id]["hips"] >= 0, "%s: Hüfte bewegt sich" % id)

	# Trefferpunkt liegt in der Hitbox (Spielpixel; etwas Spiel, weil die Hitbox grosszügig bleiben darf)
	for row in [[&"kick_low", &"foot"], [&"kick_high", &"foot"], [&"punch1", &"hand"], [&"punch2", &"hand"], [&"punch3", &"hand"]]:
		var a := Attacks.get_attack(row[0])
		m.set_clip(row[0], 1.5, 1)
		m._blend_left = 0
		m.set_clip(row[0], 1.5, 1)
		var p: Vector2 = m.strike_point(row[1], 1.0)
		var height := -p.y
		var box_x := Vector2(a.reach - a.box_size.x, a.reach)
		var box_y := Vector2(a.box_y, a.box_y + a.box_size.y)
		pruefe(p.x > box_x.x - 2.0 and p.x < box_x.y + 2.0 and height > box_y.x - 8.0 and height < box_y.y + 8.0,
			"%s: Treffpunkt (%.0f, %.0f) passt zur Hitbox x %.0f..%.0f, Höhe %.0f..%.0f" % [row[0], p.x, height, box_x.x, box_x.y, box_y.x, box_y.y])
		# Der Schritt nach vorn (`lunge`) gehört zur Reichweite: bis zum Halt schiebt die Reibung die Figur so weit
		var schritt := a.lunge * a.lunge / (2.0 * Fighter.FRICTION)
		pruefe(box_x.y - p.x - schritt < 18.0, "%s: Hitbox ragt höchstens wenig über das Glied hinaus (%.0f px)" % [row[0], box_x.y - p.x - schritt])
		m.set_clip(row[0], 1.5, -1)
		m._blend_left = 0
		m.set_clip(row[0], 1.5, -1)
		var q: Vector2 = m.strike_point(row[1], 1.0)
		pruefe(absf(q.x + p.x) < 3.0 and absf(q.y - p.y) < 3.0, "%s: nach links gedreht gespiegelt (%.1f / %.1f)" % [row[0], p.x, q.x])

	# Der Standfuss bleibt stehen, das Tretbein hebt ab
	var stand_x := []
	var kick_top := -INF
	for i in 31:
		m.set_clip(&"kick_high", i * 0.1, 1)
		m._blend_left = 0
		m.set_clip(&"kick_high", i * 0.1, 1)
		stand_x.append(m._view_point("foot.R").x)
		kick_top = maxf(kick_top, m._view_point("foot.L").y)
	pruefe(stand_x.max() - stand_x.min() < 0.03, "High Kick: Standfuss bleibt am Platz (%.3f m)" % (stand_x.max() - stand_x.min()))
	pruefe(kick_top > 1.0, "High Kick: Fuss kommt über 1 m hoch (%.2f m)" % kick_top)
	var low_top := -INF
	for i in 31:
		m.set_clip(&"kick_low", i * 0.1, 1)
		m._blend_left = 0
		m.set_clip(&"kick_low", i * 0.1, 1)
		if i >= 10 and i <= 20:
			low_top = maxf(low_top, m._view_point("foot.R").y)
	pruefe(low_top < 0.7, "Low Kick: bleibt beim Treffen unten (%.2f m)" % low_top)

	# Übergang: Beim Wechsel läuft die Figur aus der alten Haltung in den Clip
	m.set_pose(Poses.walk(0.3), 1)
	m._blend_left = 0
	m.set_pose(Poses.walk(0.3), 1)
	var vorher := m._view_point("hand.R")
	m.set_clip(&"punch1", 1.5, 1)
	var erstes := m._view_point("hand.R")
	for i in ModelFigure.BLEND_FRAMES + 1:
		m.set_clip(&"punch1", 1.5, 1)
	var ziel := m._view_point("hand.R")
	pruefe(erstes.distance_to(vorher) < ziel.distance_to(vorher), "Übergang: erstes Bild liegt zwischen alter Haltung und Clip")
	m.set_clip(&"punch1", 1.5, 1)
	pruefe(m._view_point("hand.R").is_equal_approx(ziel), "Übergang endet genau im Clip")

	# Figuren ohne Clips bleiben bei den Posen
	var c := ModelFigure.create(&"chuck")
	root.add_child(c)
	await frames(1)
	pruefe(not c.has_clip(&"kick_high"), "Chuck hat noch keine Clips")
	c.set_pose(Poses.attack(&"high_kick", 0.4, 0.3, 0.5), 1)
	pruefe(c._view_point("foot.R").y > 0.7, "Chuck zeigt den High Kick als Pose")
	c.queue_free()
	m.queue_free()

	# Fighter mit Clip: Bruce spielt ihn im Spielablauf ab
	var f := Fighter.new()
	FighterData.apply(f, &"bruce")
	root.add_child(f)
	await frames(2)
	f.start_attack(&"kick_high")
	await frames(3)
	pruefe(f.model != null and f.model.has_clip(f.attack.id), "Bruce im Spiel: der laufende Angriff hat einen Clip")
	f.queue_free()
	await frames(1)
	ModelFigure.force = false
