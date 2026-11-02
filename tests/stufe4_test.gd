extends SceneTree
## Bot-Läufe bis zum Levelende (Softlock-Test). Start: godot --headless -s tests/stufe4_test.gd
## Optionen: -- normal  → Spieler sind sterblich (Balance-Messung)

var fehler := 0
var SEEDS := [1, 2, 3]
const MAX_FRAMES := 60 * 420

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

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

func lauf(zwei: bool, seed_wert: int, unsterblich: bool) -> Dictionary:
	seed(seed_wert)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	Main.waves_enabled = true
	Main.props_enabled = true
	Main.training_dummy = false
	Main.two_players = zwei
	var szene: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(szene)
	await physics_frame
	if unsterblich:
		for f in szene.fighters:
			f.max_health = 100000
			f.current_health = 100000
	var frame := 0
	var letzter_fortschritt := 0
	var letzter_index := 0
	var max_gegner := 0
	while frame < MAX_FRAMES and not szene.director.finished and not szene.game_over:
		for f in szene.fighters:
			bot(szene, f, rng, frame)
		await physics_frame
		frame += 1
		max_gegner = maxi(max_gegner, szene.director.enemies.size())
		var fortschritt: int = szene.director.index * 1000 + szene.director.enemies.size()
		if szene.director.index != letzter_index:
			letzter_index = szene.director.index
			letzter_fortschritt = frame
		if frame - letzter_fortschritt > 60 * 90:
			break   # 90 s ohne neue Welle: Softlock
	var rest_lp: Array = szene.fighters.map(func(f): return f.current_health)
	var ergebnis := {"lp": rest_lp, "frames": frame, "fertig": szene.director.finished, "tot": szene.game_over,
		"welle": szene.director.index, "max_gegner": max_gegner,
		"punkte": szene.fighters.map(func(f): return f.score)}
	szene.queue_free()
	await physics_frame
	return ergebnis

func _init() -> void:
	var normal := OS.get_cmdline_user_args().has("normal")
	if normal:
		var siege := 0
		var n := 8
		for i in n:
			var r: Dictionary = await lauf(false, 100 + i, false)
			if r["fertig"]:
				siege += 1
			print(r["lp"], " Welle ", r["welle"], " ", r["frames"] / 60, " s")
		print("Einzelspieler, sterblich: Siege %d / %d" % [siege, n])
		quit(0)
		return
	for zwei in [false, true]:
		for sd in SEEDS:
			var r: Dictionary = await lauf(zwei, sd, true)
			print(r)
			pruefe(r["fertig"], "%s, Zufallswert %d: Level bis zum Ende (%.0f s, max. %d Gegner)" %
				["2 Spieler" if zwei else "1 Spieler", sd, r["frames"] / 60.0, r["max_gegner"]])
	print("Fertig, Fehler: ", fehler)
	quit(fehler)
