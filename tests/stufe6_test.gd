extends SceneTree
## Headless-Test Menü, Pause, Endbildschirm, Rekord, Töne, Controller:
## godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe6_test.gd

const TEST_FILE := "user://doppelfaust_test.cfg"

var fehler := 0

func pruefe(bedingung: bool, text: String) -> void:
	print(("OK   " if bedingung else "FAIL "), text)
	if not bedingung:
		fehler += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func taste(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	return ev

func knopf(button: JoyButton, device: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	ev.pressed = true
	return ev

func achse(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = device
	return ev

func neue_app() -> App:
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	return app

func aufraeumen() -> void:
	if FileAccess.file_exists(TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))

func _init() -> void:
	SaveData.file_path = TEST_FILE
	aufraeumen()
	var app: App = await neue_app()

	# 1) Menü
	pruefe(app.mode == App.Mode.MENU and app.screen is MenuScreen, "Start zeigt das Menü")
	pruefe(app.screen.buttons.size() == 3, "Menü hat drei Knöpfe")
	pruefe(root.gui_get_focus_owner() == app.screen.buttons[0], "Erster Knopf hat den Fokus (Tastatur, Controller)")
	pruefe(app.screen.size.x > 900.0, "Menü füllt das Bild (Breite %.0f)" % app.screen.size.x)

	# 2) Töne
	var ids := [&"punch", &"kick", &"heavy", &"whoosh", &"thud", &"smash", &"throw", &"crack",
		&"grab", &"jump", &"collect", &"wave", &"win", &"lose"]
	var alle_da := true
	for id in ids:
		var s: AudioStreamWAV = app.sound.sounds.get(id)
		alle_da = alle_da and s != null and s.data.size() > 0
	pruefe(alle_da, "Alle %d Geräusche sind berechnet" % ids.size())
	var musik := app.sound.music_stream
	pruefe(musik != null and musik.loop_mode == AudioStreamWAV.LOOP_FORWARD and musik.loop_end == musik.data.size() / 2,
		"Musik ist eine Schleife über die ganze Länge")
	var spitze := 0
	for i in range(0, musik.data.size(), 2):
		spitze = maxi(spitze, absi(musik.data.decode_s16(i)))
	pruefe(spitze > 3000, "Musik ist nicht stumm (Spitze %d)" % spitze)
	SoundBank.play(&"punch")
	SoundBank.play(&"gibt_es_nicht")
	pruefe(app.sound.play_counts.get(&"punch", 0) == 1 and not app.sound.play_counts.has(&"gibt_es_nicht"), "play() spielt nur bekannte Töne")

	# 3) Musik an/aus bleibt gespeichert
	app._unhandled_input(taste(KEY_M))
	pruefe(not app.save.music_on and not app.sound.music_enabled, "M schaltet die Musik aus")
	pruefe((app.screen as MenuScreen).music_button.text == "Musik: aus", "Knopf zeigt den Musik-Zustand")
	var geladen := SaveData.new()
	geladen.load_file()
	pruefe(not geladen.music_on, "Musik-Zustand ist gespeichert")
	app.toggle_music()

	# 4) Spiel starten über den Knopf
	app.screen.buttons[0].pressed.emit()
	await frames(3)
	pruefe(app.screen is SelectScreen, "«1 Spieler» zeigt die Kämpferwahl")
	(app.screen as SelectScreen).confirm(0)
	await create_timer(SelectScreen.START_DELAY + 0.3).timeout
	pruefe(app.mode == App.Mode.PLAYING and app.screen == null, "Nach der Wahl beginnt das Spiel")
	pruefe(app.game != null and app.game.fighters.size() == 1, "1 Spieler: eine Figur")
	pruefe(app.game.hud.size.x > 900.0, "HUD füllt das Bild (Breite %.0f)" % app.game.hud.size.x)
	pruefe(app.game.camera_rig.is_current(), "Spielkamera ist aktiv")
	var wurf_vorher: int = app.sound.play_counts.get(&"whoosh", 0)
	app.game.fighters[0].request_attack(&"punch")
	await frames(3)
	pruefe(app.sound.play_counts.get(&"whoosh", 0) > wurf_vorher, "Angriff macht ein Geräusch")

	# 5) Pause mit P, Esc und Controller-Start
	var f: Fighter = app.game.fighters[0]
	app._unhandled_input(taste(KEY_P))
	await frames(2)
	pruefe(paused and app.mode == App.Mode.PAUSED and app.screen is PauseScreen, "P pausiert")
	var zeit := f._anim_time
	await frames(20)
	pruefe(f._anim_time == zeit, "In der Pause steht das Spiel")
	app._unhandled_input(taste(KEY_ESCAPE))
	await frames(2)
	pruefe(not paused and app.mode == App.Mode.PLAYING and app.screen == null, "Esc macht weiter")
	await frames(5)
	pruefe(f._anim_time > zeit, "Nach der Pause läuft das Spiel weiter")
	app._unhandled_input(knopf(JOY_BUTTON_START, 1))
	await frames(2)
	pruefe(paused and app.mode == App.Mode.PAUSED, "Start auf jedem Controller pausiert")

	# 6) Neustart und Menü aus der Pause
	var alte_runde := app.game
	app.screen.buttons[1].pressed.emit()
	await frames(3)
	pruefe(not is_instance_valid(alte_runde) and app.game != null and not paused, "Neustart beginnt eine neue Runde")
	pruefe(app.game.fighters.size() == 1, "Neustart behält die Spielerzahl")
	app.pause_game()
	await frames(2)
	app.screen.buttons[2].pressed.emit()
	await frames(3)
	pruefe(app.mode == App.Mode.MENU and app.game == null and not paused, "Menü-Knopf führt zurück ins Menü")

	# 7) Controller-Belegung
	pruefe(knopf(JOY_BUTTON_X, 0).is_action_pressed("p1_punch") and not knopf(JOY_BUTTON_X, 0).is_action_pressed("p2_punch"), "Controller 1 gehört Spieler 1")
	pruefe(knopf(JOY_BUTTON_X, 1).is_action_pressed("p2_punch") and not knopf(JOY_BUTTON_X, 1).is_action_pressed("p1_punch"), "Controller 2 gehört Spieler 2")
	pruefe(knopf(JOY_BUTTON_RIGHT_SHOULDER, 1).is_action_pressed("p2_grab"), "RB greift")
	pruefe(knopf(JOY_BUTTON_A, 0).is_action_pressed("p1_jump") and knopf(JOY_BUTTON_A, 0).is_action_pressed("ui_accept"), "A springt und bestätigt im Menü")
	pruefe(achse(JOY_AXIS_LEFT_X, -1.0, 0).is_action("p1_left") and not achse(JOY_AXIS_LEFT_X, -1.0, 0).is_action("p2_left"), "Stick von Controller 1 bewegt Spieler 1")
	pruefe(InputSetup.key_hint(1, "grab") == "E", "Ohne Controller zeigt der Hinweis die Taste")
	pruefe(taste(KEY_W).is_action_pressed("ui_up") and taste(KEY_S).is_action_pressed("ui_down"), "W und S bedienen die Menüs")

	# 8) Sieg, Rekord
	app.start_game(false)
	await frames(3)
	app.game.fighters[0].score = 1200
	app.game.director._finish()
	await frames(60 * 3)
	pruefe(app.mode == App.Mode.PLAYING and app.game.hud.message == "GESCHAFFT!", "Nach dem Sieg bleibt das Spiel kurz stehen")
	await frames(60 * 2)
	pruefe(app.mode == App.Mode.RESULT and app.screen is ResultScreen and paused, "Sieg zeigt den Endbildschirm")
	var erg := app.screen as ResultScreen
	pruefe(erg.won and erg.total == 1200 and erg.new_record and erg.best == 1200, "Sieg: Punkte und neuer Rekord")
	pruefe(erg.buttons[0].disabled, "Knöpfe sind zuerst gesperrt")
	await create_timer(ResultScreen.LOCK_TIME + 0.2).timeout
	pruefe(not erg.buttons[0].disabled and root.gui_get_focus_owner() == erg.buttons[0], "Nach einer Sekunde sind die Knöpfe frei")
	geladen = SaveData.new()
	geladen.load_file()
	pruefe(geladen.best(1) == 1200 and geladen.best(2) == 0, "Rekord liegt getrennt nach Spielerzahl auf der Platte")

	# 9) Game Over zu zweit, schlechterer Lauf ändert den 1-Spieler-Rekord nicht
	app.screen.buttons[1].pressed.emit()
	await frames(3)
	app.start_game(true)
	await frames(3)
	pruefe(app.game.fighters.size() == 2, "2 Spieler: zwei Figuren")
	app.game.fighters[0].score = 300
	app.game.fighters[1].score = 200
	for g in app.game.fighters:
		g.lives = 0
		g.current_health = 0
	await frames(60 * 2 + 10)
	pruefe(app.mode == App.Mode.RESULT and not (app.screen as ResultScreen).won, "Alle tot: Game Over")
	erg = app.screen as ResultScreen
	pruefe(erg.total == 500 and erg.lines.size() == 2 and erg.new_record, "Gesamtpunktzahl zählt beide Spieler")
	pruefe(app.save.best(1) == 1200 and app.save.best(2) == 500, "Rekorde bleiben getrennt")
	app.show_menu()
	await frames(3)
	app.start_game(false)
	await frames(3)
	app.game.fighters[0].score = 100
	app.game.fighters[0].lives = 0
	app.game.fighters[0].current_health = 0
	await frames(60 * 2 + 10)
	pruefe(not (app.screen as ResultScreen).new_record and app.save.best(1) == 1200, "Schlechterer Lauf ist kein Rekord")

	# 10) Controller getrennt
	app.start_game(false)
	await frames(3)
	app._on_joy_connection_changed(1, false)
	pruefe(app.mode == App.Mode.PLAYING, "Controller 2 weg, nur 1 Spieler: läuft weiter")
	app._on_joy_connection_changed(0, false)
	await frames(2)
	pruefe(app.mode == App.Mode.PAUSED and (app.screen as PauseScreen).reason != "", "Controller des Spielers weg: Pause mit Grund")

	app.queue_free()
	await frames(2)
	paused = false
	aufraeumen()
	print("Fertig, Fehler: ", fehler)
	quit(fehler)
