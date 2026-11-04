extends SceneTree
## Headless-Test Nachschub statt Wellen, stärkere Gegner, zweites Level:
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe11_test.gd

const MAX_FRAMES := 60 * 500

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func neue_szene(zwei: bool, level_zahl: int) -> Main:
	Main.waves_enabled = true
	Main.props_enabled = true
	Main.training_dummy = false
	Main.two_players = zwei
	Main.level_count = level_zahl
	Main.picks = [&"kai", &"ria"]
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await frames(3)
	for f in szene.fighters:
		f.max_health = 100000
		f.current_health = 100000
	return szene

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
	if best == null or absf(best.pos_x - f.pos_x) > 260.0:   # weit weg: einfach weiter nach rechts
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

func boss_in(szene: Main) -> Enemy:
	for g in szene.director.enemies:
		if g.type_id == &"boss":
			return g
	return null

func _init() -> void:
	SaveData.file_path = "user://doppelfaust_test11.cfg"
	await test_nachschub()
	await test_staerke()
	await test_boss_und_levelwechsel()
	await test_lauf()
	if FileAccess.file_exists(SaveData.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.file_path))
	Main.level_count = 2
	print("Fertig, Fehler: ", fehler)
	quit(fehler)

# ---------------------------------------------------------------- Nachschub

func test_nachschub() -> void:
	var szene: Main = await neue_szene(false, 2)
	var d: WaveDirector = szene.director
	pruefe(d.level_index == 1 and not d.finished and not d.last_level, "Start in Level 1, noch nicht das letzte")
	pruefe(szene.hud.banner_text == "LEVEL 1", "Anzeige «LEVEL 1» statt Welle")
	# Stehenbleiben: es kommt nur das Startguthaben plus ein Tröpfeln, kein endloser Strom
	for p in szene.fighters:
		p.max_health = 100000
		p.current_health = 100000
	var gesehen := 0
	var frame := 0
	while frame < 60 * 40:
		await frames(1)
		frame += 1
		gesehen = maxi(gesehen, d._spawned)
		for g in d.enemies:
			g.current_health = 0
			g._set_state(Fighter.State.DEAD)
	pruefe(d._spawned >= 3, "Auch beim Stehenbleiben kommen Gegner (%d in 40 s)" % d._spawned)
	pruefe(float(d._spawned) <= d.budget() + 1.0, "Nie mehr als das Guthaben (höchstens eins drüber) (%d von %.1f)" % [d._spawned, d.budget()])
	pruefe(d._spawned <= 9, "Ohne Fortschritt kein Strom (%d)" % d._spawned)
	# Fortschritt: das Guthaben wächst mit dem Weg
	var vorher := d.budget()
	szene.camera_rig.position.x = 2400.0
	await frames(2)
	pruefe(d.budget() > vorher + 5.0, "Guthaben wächst mit dem Weg (%.1f → %.1f)" % [vorher, d.budget()])
	szene.queue_free()
	await frames(2)
	var szene2: Main = await neue_szene(true, 2)
	pruefe(szene2.director.max_alive() > 3 and szene2.director.budget() >= WaveDirector.START_BUDGET, "Zu zweit sind mehr Gegner gleichzeitig erlaubt")
	pruefe(WaveDirector.MAX_ATTACKERS == 3, "Drei Angreifer pro Spieler")
	szene2.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Stärke

func test_staerke() -> void:
	var szene: Main = await neue_szene(false, 2)
	var d: WaveDirector = szene.director
	d._spawn(&"thug")
	var e1: Enemy = d.enemies[0]
	var basis: int = Enemy.TYPES[&"thug"]["hp"]
	pruefe(e1.max_health >= int(basis * 1.4), "Gegner haben mehr Lebenspunkte (%d statt %d)" % [e1.max_health, basis])
	pruefe(e1.damage_factor >= 1.3 and e1.pause_factor <= 0.7, "Mehr Schaden, kürzere Pausen")
	# Level 2 ist härter als Level 1
	d.level_index = 2
	d._spawn(&"thug")
	var e2: Enemy = d.enemies[1]
	pruefe(e2.max_health > e1.max_health and e2.damage_factor > e1.damage_factor and e2.pause_factor < e1.pause_factor, "Level 2: noch mehr Lebenspunkte und Schaden, kürzere Pausen")
	# Im Level werden sie härter
	szene.camera_rig.position.x = WaveDirector.BOSS_X + 480.0
	d.level_index = 1
	d._spawn(&"thug")
	var e3: Enemy = d.enemies[2]
	pruefe(e3.max_health > e1.max_health, "Gegner werden im Level härter")
	# Der Schaden kommt im Kampf an
	var spieler: Fighter = szene.fighters[0]
	spieler.max_health = 200
	spieler.current_health = 200
	spieler.state = Fighter.State.IDLE
	var angriff := e1._attack_for(&"g_schlag")
	pruefe(angriff.damage > Attacks.get_attack(&"g_schlag").damage, "Gegnerschlag macht mehr Schaden (%d statt %d)" % [angriff.damage, Attacks.get_attack(&"g_schlag").damage])
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Boss und Levelwechsel

func test_boss_und_levelwechsel() -> void:
	var szene: Main = await neue_szene(true, 2)
	var d: WaveDirector = szene.director
	var p1: Fighter = szene.fighters[0]
	var p2: Fighter = szene.fighters[1]
	p1.score = 4200
	p1.lives = 1
	szene.camera_rig.position.x = Level.WIDTH - 480.0
	await frames(5)
	var boss := boss_in(szene)
	pruefe(boss != null, "Am Levelende erscheint der Boss")
	pruefe(szene.hud.banner_text == "BOSS: GRANIT", "Bossanzeige")
	pruefe(boss.skin["name"] == "BOSS GRANIT", "Boss von Level 1 heisst Granit")
	# Mit dem Boss kommen weiter Gegner
	await frames(60 * 12)
	var mit_boss := 0
	for g in d.enemies:
		if g.type_id != &"boss" and g.current_health > 0:
			mit_boss += 1
	pruefe(d._spawned > 0 or mit_boss > 0, "Gegner kommen auch während des Bosskampfs")
	# Boss fällt: übrige Gegner geben auf, Level 1 ist geschafft, Level 2 beginnt
	var cleared := [false]
	d.level_cleared.connect(func(): cleared[0] = true)
	boss.current_health = 1
	boss.state = Fighter.State.IDLE
	boss.take_hit(Attacks.get_attack(&"g_hammer"), p1)
	await frames(2)
	pruefe(cleared[0], "Boss besiegt: Level geschafft")
	pruefe(szene.hud.message == "LEVEL GESCHAFFT!", "Meldung «LEVEL GESCHAFFT!»")
	var uebrige := 0
	for g in d.enemies:
		if g.current_health > 0:
			uebrige += 1
	pruefe(uebrige == 0, "Die übrigen Gegner geben auf")
	p2.current_health = 20
	await frames(60 * 4)
	pruefe(szene.level_index == 2 and d.level_index == 2 and d.last_level, "Level 2 läuft, und es ist das letzte")
	pruefe(szene.hud.message == "" and szene.hud.banner_text == "LEVEL 2", "Anzeige «LEVEL 2»")
	pruefe(p1.score >= 4200 and p1.lives == 1, "Punkte und Leben bleiben")
	pruefe(p2.current_health == p2.max_health, "Lebenspunkte sind wieder voll")
	pruefe(p1.pos_x < 400.0 and szene.camera_rig.position.x < 600.0, "Die Spieler stehen wieder am Anfang")
	pruefe(szene.items.props.size() == Level.prop_plan(2).size(), "Level 2 hat seine eigenen Requisiten (%d)" % szene.items.props.size())
	pruefe(szene.level.level_index == 2 and szene.level.get_child_count() >= 5, "Level 2 hat ein eigenes Level mit allen Ebenen")
	pruefe(not d.finished and d.budget() >= WaveDirector.START_BUDGET, "Level 2 beginnt mit frischem Guthaben")
	# Zweiter Boss, dann Sieg
	var gewonnen := [false]
	szene.run_ended.connect(func(won: bool): gewonnen[0] = won)
	szene.camera_rig.position.x = Level.WIDTH - 480.0
	await frames(5)
	boss = boss_in(szene)
	pruefe(boss != null and boss.skin["name"] == "BOSS DRACHE", "Boss von Level 2 heisst Drache")
	pruefe(boss.max_health > 210 * 1.9, "Der zweite Boss hat mehr Lebenspunkte (%d)" % boss.max_health)
	boss.current_health = 1
	boss.state = Fighter.State.IDLE
	boss.take_hit(Attacks.get_attack(&"g_hammer"), p1)
	await frames(2)
	pruefe(d.finished and szene.hud.message == "GESCHAFFT!", "Zweiter Boss besiegt: GESCHAFFT")
	await frames(60 * 5)
	pruefe(gewonnen[0], "Erst jetzt endet der Lauf mit dem Sieg")
	szene.queue_free()
	await frames(2)

# ---------------------------------------------------------------- Ganzer Lauf mit dem Bot

func test_lauf() -> void:
	seed(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var szene: Main = await neue_szene(true, 2)
	var frame := 0
	var letzter := 0
	var letzter_fortschritt := 0
	var level2_gesehen := false
	while frame < MAX_FRAMES and not szene.director.finished and not szene.game_over:
		for f in szene.fighters:
			bot(szene, f, rng, frame)
		await physics_frame
		frame += 1
		level2_gesehen = level2_gesehen or szene.level_index == 2
		if szene.director.index != letzter or szene.level_index != 0:
			if szene.director.index != letzter:
				letzter = szene.director.index
				letzter_fortschritt = frame
		if frame - letzter_fortschritt > 60 * 120:
			break   # 120 s ohne einen besiegten Gegner: Softlock
	pruefe(level2_gesehen, "Der Bot kommt in Level 2")
	pruefe(szene.director.finished, "Beide Level bis zum Ende (%.0f s, %d besiegt)" % [frame / 60.0, szene.director.index])
	szene.queue_free()
	await frames(2)
