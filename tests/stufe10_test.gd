extends SceneTree
## Headless-Test Gegner als 3D-Modelle: Varianten, Umfärben, Zeichnen nur im Bild, Aussehen ohne Modell.
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe10_test.gd
## Die Modell-Prüfungen brauchen die `enemy_*.glb` und überspringen sich ohne Dateien.

const TYPES: Array[StringName] = [&"thug", &"dasher", &"brute", &"boss"]

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
	await test_gegner_ohne_modell()
	await test_modelle()
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Daten

func test_daten() -> void:
	for type in TYPES:
		pruefe(EnemyLooks.count(type) >= 1, "%s: %d Varianten" % [type, EnemyLooks.count(type)])
		pruefe(EnemyLooks.LOOKS[type][0]["colors"].is_empty(), "%s: Variante 0 ist das Grundmodell ohne Umfärben" % type)
	pruefe(EnemyLooks.count(&"thug") >= 5 and EnemyLooks.count(&"dasher") >= 4 and EnemyLooks.count(&"brute") >= 4, "Schläger, Flitzer und Brocken haben mehrere Varianten")
	var modelle := {}
	var farben := {}
	for type in TYPES:
		for look in EnemyLooks.LOOKS[type]:
			modelle[look["model"]] = true
			farben["%s%s" % [type, look["colors"]]] = true
			for zone in look["colors"]:
				pruefe(look["colors"][zone] is Color, "%s: Zone %s ist eine Farbe" % [look["model"], zone])
	pruefe(modelle.size() == 7, "Sieben Modelle: %s" % [modelle.keys()])
	pruefe(farben.size() == 6 + 5 + 5 + 1, "Alle Varianten sind verschieden (%d)" % farben.size())
	pruefe(ModelFigure.path_for(&"thug_cap") == "res://assets/characters/enemy_thug_cap.glb", "Pfad eines Gegner-Modells")
	pruefe(ModelFigure.path_for(&"bruce") == FighterData.model_path(&"bruce"), "Kämpfer behalten ihren Pfad")
	# Das 2D-Aussehen ohne Modell übernimmt die Farben der Variante
	var look := EnemyLooks.pick(&"thug", 1)
	var skin := EnemyLooks.skin_for(Skins.THUG, &"thug", look)
	pruefe(skin["top"] == Color8(196, 58, 52) and skin["name"] == "SCHLÄGER", "2D: rotes Oberteil, Name bleibt")
	pruefe(Skins.THUG["top"] == Color8(55, 140, 65), "Die gemeinsame Vorlage bleibt unverändert")
	var weste := EnemyLooks.skin_for(Skins.BRUTE, &"brute", EnemyLooks.pick(&"brute", 1))
	pruefe(weste["vest"] == Color8(150, 34, 34) and weste["top"] == null, "2D: beim Brocken färbt `top` die Weste")

func test_gegner_ohne_modell() -> void:
	var gesehen := {}
	for i in 60:
		var e := Enemy.create(&"thug")
		gesehen[e.fighter_id] = true
		e.free()
	pruefe(gesehen.size() == 2, "Zufall wählt aus beiden Modellen des Schlägers: %s" % [gesehen.keys()])
	var e := Enemy.create(&"dasher", 3)
	pruefe(e.fighter_id == &"dasher_spiky" and e.palette["hair"] == Color8(255, 160, 40), "Feste Variante des Flitzers")
	e.free()
	var boss := Enemy.create(&"boss")
	pruefe(boss.fighter_id == &"boss" and boss.palette.is_empty(), "Boss: ein Aussehen")
	boss.free()
	# Zufallswahl darf den Zufall des Spiels nicht verschieben
	seed(1234)
	var a := randi()
	seed(1234)
	for i in 20:
		EnemyLooks.pick(&"brute")
	pruefe(randi() == a, "Wahl der Variante verbraucht keinen Zufall des Spiels")
	# Headless entsteht kein Modell: die Figur bleibt 2D und lässt sich zeichnen
	var f := Enemy.create(&"thug", 4)
	root.add_child(f)
	await frames(2)
	pruefe(f.model == null, "Headless: kein 3D-Modell, die 2D-Figur bleibt")
	f.queue_free()
	await frames(1)

# ---------------------------------------------------------------- Modelle

func test_modelle() -> void:
	ModelFigure.force = true
	var fehlend := []
	for type in TYPES:
		for look in EnemyLooks.LOOKS[type]:
			if not ResourceLoader.exists(ModelFigure.path_for(look["model"])):
				fehlend.append(look["model"])
	if not fehlend.is_empty():
		print("SKIP Modelle: assets/characters/enemy_*.glb fehlen ", fehlend)
		ModelFigure.force = false
		return
	var anzahl_start := ModelFigure.active_count
	for type in TYPES:
		for i in EnemyLooks.count(type):
			var e := Enemy.create(type, i)
			root.add_child(e)
			await frames(1)
			pruefe(e.model != null and e.model.fighter_id == e.fighter_id, "%s Variante %d (%s): Modell lädt" % [type, i, e.fighter_id])
			if e.model != null:
				pruefe(e.model.skeleton.get_bone_count() == 17, "%s %d: 17 Knochen" % [type, i])
				var kopf := e.model._view_point("head")
				pruefe(kopf.y > 1.3 and kopf.y < 1.9, "%s %d: Kopf in %.2f m Höhe" % [type, i, kopf.y])
			e.queue_free()
			await frames(1)
	pruefe(ModelFigure.active_count == anzahl_start, "Entfernte Figuren zählen nicht mehr (%d)" % ModelFigure.active_count)

	# Materialnamen: <figur>__<zone>, damit sich die Zonen umfärben lassen
	var m := ModelFigure.create(&"thug")
	root.add_child(m)
	var zonen := _zonen(m._model)
	pruefe(zonen.has("top") and zonen.has("pants") and zonen.has("skin") and zonen.has("hair"), "Zonen des Schlägers: %s" % [zonen.keys()])

	# Umfärben wirkt nur auf dieses Modell
	var vorher := _farbe(m._model, "top")
	m.apply_palette({"top": Color8(196, 58, 52), "skin": Color8(236, 196, 156)})
	pruefe(_farbe(m._model, "top").is_equal_approx(Color8(196, 58, 52)), "Oberteil ist rot")
	pruefe(_farbe(m._model, "skin").is_equal_approx(Color8(236, 196, 156)), "Haut ist heller")
	pruefe(_farbe(m._model, "shade").is_equal_approx(Color8(236, 196, 156).darkened(0.18)) or not zonen.has("shade"), "Schattenlinien folgen der Haut")
	pruefe(_farbe(m._model, "pants").is_equal_approx(_farbe_vorlage(&"thug", "pants")), "Nicht genannte Zonen bleiben")
	var zweites := ModelFigure.create(&"thug")
	root.add_child(zweites)
	pruefe(_farbe(zweites._model, "top").is_equal_approx(vorher) and not vorher.is_equal_approx(Color8(196, 58, 52)), "Ein zweites Modell behält das Original")
	m.queue_free()
	zweites.queue_free()

	# Zeichnen nur im Bild
	var f := Enemy.create(&"brute", 0)
	root.add_child(f)
	f.setup(300.0, 420.0, Rect2(0, 300, 3000, 200))
	await frames(1)
	var davor := ModelFigure.active_count
	pruefe(f.model != null, "Brocken hat ein Modell")
	pruefe(f.model._active, "Neues Modell gilt als aktiv")
	f.model.set_active(false)
	pruefe(ModelFigure.active_count == davor - 1 and f.model._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Ausgeschaltet zählt es nicht und rechnet nichts")
	f.model.set_active(false)
	pruefe(ModelFigure.active_count == davor - 1, "Doppeltes Ausschalten zählt nicht doppelt")
	f.model.set_active(true)
	pruefe(ModelFigure.active_count == davor and f.model._viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Wieder an")
	f.position = Vector2(480.0, 420.0)
	pruefe(f._on_screen(), "Bildmitte gilt als im Bild")
	f.position = Vector2(-200.0, 420.0)
	pruefe(f._on_screen(), "Knapp links neben dem Bild wird schon gezeichnet (Puffer)")
	f.position = Vector2(2500.0, 420.0)
	pruefe(not f._on_screen(), "Weit rechts vom Bild nicht")
	f.position = Vector2(480.0, 1500.0)
	pruefe(not f._on_screen(), "Weit unter dem Bild nicht")
	f.queue_free()
	await frames(1)
	ModelFigure.force = false

func _zonen(node: Node) -> Dictionary:
	var out := {}
	if node is MeshInstance3D:
		for i in (node as MeshInstance3D).mesh.get_surface_count():
			var mat := (node as MeshInstance3D).mesh.surface_get_material(i)
			if mat != null and mat.resource_name.contains("__"):
				out[mat.resource_name.get_slice("__", 1)] = true
	for child in node.get_children():
		out.merge(_zonen(child))
	return out

## Farbe der ersten Fläche einer Zone: Überschreibung, sonst Material des Meshes.
func _farbe(node: Node, zone: String) -> Color:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.resource_name.ends_with("__" + zone):
				var over := mi.get_surface_override_material(i) as BaseMaterial3D
				return (over if over != null else mat).albedo_color
	for child in node.get_children():
		var c := _farbe(child, zone)
		if c != Color(-1, -1, -1, -1):
			return c
	return Color(-1, -1, -1, -1)

func _farbe_vorlage(id: StringName, zone: String) -> Color:
	var scene := load(ModelFigure.path_for(id)) as PackedScene
	var instanz := scene.instantiate()
	var c := _farbe(instanz, zone)
	instanz.free()
	return c
