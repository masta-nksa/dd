extends SceneTree
## Headless-Test Baseballschläger: Modell, Griff, Schwung, Abwehr und Konter.
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe9_test.gd
## Die Modell-Prüfungen brauchen `assets/characters/weapon_bat.glb` und überspringen sich ohne Datei.

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	await test_abwehr()
	await test_modell()
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Abwehr

func aufstellen(szene: Main, abstand := 40.0) -> void:
	var f: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy
	Input.action_release("p1_kick")
	d.attack = null              # ein laufender Angriff oder eine gepufferte Taste aus dem Abschnitt davor darf nicht weiterwirken
	d.hit_box.active = false
	d._request = &""
	d.revive()
	d.pos_x = 1000.0
	d.pos_z = 420.0
	d.facing = -1
	f.pos_x = 1000.0 - abstand
	f.pos_z = 420.0
	f.pos_y = 0.0
	f.facing = 1
	f.vel_x = 0.0
	f.attack = null
	f.current_health = f.max_health
	f.state = Fighter.State.IDLE
	f.carried = Carry.new(&"bat", 10)
	await frames(30)

func test_abwehr() -> void:
	Main.waves_enabled = false
	Main.props_enabled = false
	Main.training_dummy = true
	Main.two_players = false
	Main.picks = [&"kai", &"ria"]
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(2)
	var f: Fighter = szene.fighters[0]
	var d: Fighter = szene.dummy

	# Die Tritt-Taste wird mit Schläger zur Abwehr
	await aufstellen(szene)
	Input.action_press("p1_kick")
	await frames(3)
	pruefe(f.state == Fighter.State.BLOCK, "Mit Schläger hebt die Tritt-Taste zur Abwehr")
	var x := f.pos_x
	f.move_input = Vector2.RIGHT
	await frames(10)
	pruefe(is_equal_approx(f.pos_x, x), "In der Abwehr steht man still")
	await frames(20)
	pruefe(f.state == Fighter.State.BLOCK, "Abwehr hält, solange die Taste gedrückt ist")
	Input.action_release("p1_kick")
	await frames(3)
	pruefe(f.state == Fighter.State.IDLE, "Loslassen beendet die Abwehr")

	# Block von vorn: kein Schaden, 1 Haltbarkeit, Angreifer läuft normal weiter
	await aufstellen(szene)
	Input.action_press("p1_kick")
	await frames(20)
	var hp := f.current_health
	d.start_attack(&"g_schlag")
	await frames(30)
	pruefe(f.current_health == hp, "Block von vorn: kein Schaden (%d)" % f.current_health)
	pruefe(f.state == Fighter.State.BLOCK, "Block von vorn: keine Trefferstarre")
	pruefe(f.carried != null and f.carried.rest == 9, "Block kostet 1 Haltbarkeit (%d)" % f.carried.rest)
	pruefe(d.state != Fighter.State.HIT, "Später Block: Angreifer taumelt nicht")
	pruefe(d.hit_box.hit_targets.is_empty(), "Block zählt nicht als Treffer")
	Input.action_release("p1_kick")

	# Gegner-Kette läuft nicht weiter, wenn der erste Schlag abgewehrt wurde
	await aufstellen(szene)
	Input.action_press("p1_kick")
	await frames(20)
	d.start_attack(&"g_schlag")
	d.request_attack(&"punch")
	await frames(24)
	d.request_attack(&"punch")
	await frames(8)
	pruefe(d.attack == null or d.attack.id != &"g_haken", "Abgewehrter Schlag startet keine Gegner-Kette")
	Input.action_release("p1_kick")

	# Konter: Hochnehmen kurz vor dem Treffer lässt den Angreifer taumeln
	await aufstellen(szene)
	d.start_attack(&"g_schlag")
	await frames(13)
	Input.action_press("p1_kick")
	var getaumelt := false
	var zeit := 0.0
	for i in 20:
		await physics_frame
		getaumelt = getaumelt or d.state == Fighter.State.HIT
		zeit = maxf(zeit, d._hit_time)
	pruefe(getaumelt and is_equal_approx(zeit, Fighter.PARRY_STUN), "Konter: Angreifer taumelt %.1f s" % zeit)
	pruefe(d.current_health == d.max_health, "Konter macht keinen Schaden")
	pruefe(f.current_health == f.max_health, "Konter schützt den Verteidiger")
	pruefe(f.carried != null and f.carried.rest == 9, "Konter kostet ebenfalls 1 Haltbarkeit")
	Input.action_release("p1_kick")

	# Von hinten schützt die Abwehr nicht
	await aufstellen(szene)
	d.pos_x = f.pos_x - 40.0
	d.facing = 1
	Input.action_press("p1_kick")
	await frames(20)
	hp = f.current_health
	d.start_attack(&"g_schlag")
	await frames(30)
	pruefe(f.current_health < hp, "Von hinten trifft der Angriff (%d)" % f.current_health)
	Input.action_release("p1_kick")

	# Letzte Haltbarkeit: Der Schläger bricht beim Block, der Angriff prallt noch ab
	await aufstellen(szene)
	f.carried.rest = 1
	Input.action_press("p1_kick")
	await frames(20)
	hp = f.current_health
	d.start_attack(&"g_schlag")
	await frames(30)
	pruefe(f.carried == null and f.current_health == hp, "Letzter Block zerbricht den Schläger, ohne Schaden")
	pruefe(f.state != Fighter.State.BLOCK, "Ohne Schläger endet die Abwehr")
	Input.action_release("p1_kick")

	# Ohne Schläger bleibt die Taste der Low Kick
	await aufstellen(szene)
	f.carried = null
	f.request_attack(&"kick")
	await frames(2)
	pruefe(f.attack != null and f.attack.id == &"kick_low", "Ohne Schläger bleibt es der Low Kick")
	await frames(30)

	# Schwung: Schaden wie bisher, Reichweite klein genug für einen 87-cm-Schläger
	await aufstellen(szene, 60.0)
	f.request_attack(&"punch")
	await frames(30)
	pruefe(d.current_health == d.max_health - 12, "Schwung trifft auf 60 px (Puppe %d)" % d.current_health)
	pruefe(f.carried.rest == 9, "Schwung kostet 1 Haltbarkeit")
	await aufstellen(szene, 100.0)
	f.request_attack(&"punch")
	await frames(30)
	pruefe(d.current_health == d.max_health, "Auf 100 px geht der Schwung vorbei")
	for id: StringName in [&"w_bat1", &"w_bat2", &"w_homerun"]:
		var a := Attacks.get_attack(id)
		pruefe(a.reach <= 74.0 and a.trail == &"bat", "%s: Reichweite %.0f px und Spur am Schlägerkopf" % [id, a.reach])
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Modell

func test_modell() -> void:
	ModelFigure.force = true
	if not ResourceLoader.exists(ModelFigure.BAT_PATH):
		print("SKIP Modell: assets/characters/weapon_bat.glb fehlt")
		ModelFigure.force = false
		return
	var m := ModelFigure.create(&"bruce")
	root.add_child(m)
	await frames(1)
	pruefe(m.has_bat() and not m._bat.visible, "Schläger ist geladen und zuerst versteckt")
	m.show_bat(1.0)
	pruefe(m._bat.visible and not m._bat_cracks.visible, "Mit voller Haltbarkeit ohne Risse")
	m.show_bat(0.2)
	pruefe(m._bat_cracks.visible, "Unter 30 % mit Rissen")
	m.show_bat(1.0)
	var mesh := m._bat.find_child("Bat", true, false) as MeshInstance3D
	var box := mesh.get_aabb()
	pruefe(box.size.y > 0.84 and box.size.y < 0.90, "Länge %.3f m wie ein echter Schläger" % box.size.y)
	pruefe(box.size.x < 0.10, "Kopf %.3f m dick" % box.size.x)
	pruefe(absf(box.size.y * ModelFigure.PX_PER_M - WeaponPickup.BAT_GROUND_PX) < 1.0, "Am Boden so lang wie in der Hand (%.1f px)" % (box.size.y * ModelFigure.PX_PER_M))

	for id: StringName in [&"w_bat1", &"w_bat2", &"w_homerun", &"w_block"]:
		pruefe(m.has_clip(id), "%s: Clip vorhanden" % id)

	for id: StringName in [&"w_bat1", &"w_bat2", &"w_homerun"]:
		var a := Attacks.get_attack(id)
		_setze(m, id, 1.5, 1)
		var tip := m.strike_point(&"bat", 1.0)
		var abstand := m._view_point("hand.R").distance_to(m._view_point("hand.L"))
		pruefe(abstand < 0.14, "%s: beide Hände am Griff (%.3f m)" % [id, abstand])
		pruefe(tip.x > a.reach - a.box_size.x and tip.x <= a.reach and -tip.y > a.box_y - 8.0 and -tip.y < a.box_y + a.box_size.y + 8.0,
			"%s: Schlägerkopf (%.0f, %.0f) liegt in der Hitbox bis %.0f px" % [id, tip.x, -tip.y, a.reach])
		var schritt := a.lunge * a.lunge / (2.0 * Fighter.FRICTION)
		pruefe(a.reach - tip.x - schritt < 15.0, "%s: Hitbox ragt wenig über den Kopf hinaus (%.0f px)" % [id, a.reach - tip.x - schritt])
		_setze(m, id, 1.5, -1)
		var links := m.strike_point(&"bat", 1.0)
		pruefe(absf(links.x + tip.x) < 3.0, "%s: nach links gespiegelt (%.0f / %.0f)" % [id, tip.x, links.x])

	# Der Schläger schwingt: erst hinter dem Körper, beim Treffer vorn, danach wieder hinten
	_setze(m, &"w_bat1", 0.45, 1)
	var hinten := m.strike_point(&"bat", 1.0)
	_setze(m, &"w_bat1", 1.0, 1)
	var vorn := m.strike_point(&"bat", 1.0)
	_setze(m, &"w_bat1", 2.5, 1)
	var durch := m.strike_point(&"bat", 1.0)
	pruefe(hinten.x < 0.0 and vorn.x > 50.0 and durch.x < vorn.x - 30.0, "Schwung: Kopf bei %.0f, %.0f, %.0f px" % [hinten.x, vorn.x, durch.x])

	# Abwehr: Der Schläger steht schräg vor dem Körper, die zweite Hand greift oben am Holz
	_setze(m, &"w_block", 1.0, 1)
	var oben := m.strike_point(&"bat", 1.0)
	var griff := m._view_point("hand.R").distance_to(m._view_point("hand.L"))
	pruefe(oben.x > 8.0 and -oben.y > 70.0, "Abwehr: Schlägerkopf vor dem Körper (%.0f, %.0f)" % [oben.x, -oben.y])
	pruefe(griff > 0.2, "Abwehr: Hände weit auseinander (%.2f m)" % griff)
	var ruhig := m._view_point("foot.R")
	_setze(m, &"w_block", 1.3, 1)
	pruefe(m._view_point("foot.R").distance_to(ruhig) < 0.02, "Abwehr: Füsse bleiben beim Rückprall stehen")
	m.queue_free()

	# Figur ohne Clips: Der Schläger folgt dem Unterarm der vorderen Hand
	var c := ModelFigure.create(&"chuck")
	root.add_child(c)
	await frames(1)
	c.show_bat(1.0)
	c.set_pose(Poses.block(), 1)
	var hand := c._view_point("hand.R")
	var ellbogen := c._view_point("forearm.R")
	var spitze := c._skeleton_view(c._bat.transform * Vector3(0.0, ModelFigure.BAT_TIP, 0.0))
	pruefe((spitze - hand).normalized().dot((hand - ellbogen).normalized()) > 0.98, "Chuck: Schläger verlängert den Unterarm")
	c.set_pose(Poses.block(), -1)
	pruefe(c.strike_point(&"bat", 1.0).x < 0.0, "Chuck: nach links gedreht zeigt der Schläger nach links")
	c.show_bat(-1.0)
	pruefe(not c._bat.visible, "Ohne Waffe ist kein Schläger zu sehen")
	c.queue_free()
	await frames(1)
	ModelFigure.force = false

func _setze(m: ModelFigure, id: StringName, phase: float, facing: int) -> void:
	m.set_clip(id, phase, facing)
	m._blend_left = 0
	m.set_clip(id, phase, facing)
