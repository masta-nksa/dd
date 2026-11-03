class_name App
extends Node
## Startszene: führt von Menü über Spiel und Pause zum Endbildschirm. Die Spielszene `Main` weiss nichts davon
## und meldet nur `run_ended`. Was über mehrere Runden bleibt (Ton, Rekord), liegt hier.

enum Mode { MENU, PLAYING, PAUSED, RESULT }

const GAME_SCENE := preload("res://scenes/main.tscn")
const BACKDROP_SPEED := 40.0

var mode := Mode.MENU
var game: Main = null
var screen: Screen = null
var sound: SoundBank
var save: SaveData
var two_players := false

var _layer: CanvasLayer
var _backdrop: Node2D = null
var _backdrop_camera: Camera2D = null
var _backdrop_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.einrichten()
	save = SaveData.new()
	save.load_file()
	sound = SoundBank.new()
	sound.music_enabled = save.music_on
	add_child(sound)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	show_menu()

func _process(delta: float) -> void:
	if _backdrop_camera != null:
		_backdrop_time += delta
		_backdrop_camera.position.x = 480.0 + fmod(_backdrop_time * BACKDROP_SPEED, Level.WIDTH - 960.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == Mode.PLAYING:
			pause_game()
		elif mode == Mode.PAUSED:
			resume_game()
	elif event.is_action_pressed("music_toggle"):
		toggle_music()

# ------------------------------------------------------------ Abläufe

func show_menu() -> void:
	_remove_game()
	get_tree().paused = false
	mode = Mode.MENU
	_add_backdrop()
	var menu := MenuScreen.new()
	menu.save = save
	menu.start_requested.connect(start_game)
	menu.music_requested.connect(toggle_music)
	_set_screen(menu)

func start_game(two: bool) -> void:
	two_players = two
	_remove_game()
	_remove_backdrop()
	_set_screen(null)
	get_tree().paused = false
	Main.waves_enabled = true
	Main.props_enabled = true
	Main.training_dummy = false
	Main.two_players = two
	game = GAME_SCENE.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.run_ended.connect(_on_run_ended)
	add_child(game)
	mode = Mode.PLAYING

func pause_game(reason := "") -> void:
	get_tree().paused = true
	mode = Mode.PAUSED
	var pause := PauseScreen.new()
	pause.reason = reason
	pause.resume_requested.connect(resume_game)
	pause.restart_requested.connect(func(): start_game(two_players))
	pause.menu_requested.connect(show_menu)
	_set_screen(pause)

func resume_game() -> void:
	_set_screen(null)
	get_tree().paused = false
	mode = Mode.PLAYING

func toggle_music() -> void:
	save.music_on = not save.music_on
	sound.music_enabled = save.music_on
	save.save_file()
	if screen is MenuScreen:
		(screen as MenuScreen).refresh_music()

func _on_run_ended(won: bool) -> void:
	get_tree().paused = true
	mode = Mode.RESULT
	game.hud.message = ""
	game.hud.banner_time = 0.0
	game.hud.go_time = 0.0
	game.hud.queue_redraw()
	var result := ResultScreen.new()
	result.won = won
	result.player_count = game.fighters.size()
	for i in game.fighters.size():
		var f := game.fighters[i]
		result.lines.append("%dP %s:  %d   ·   Beste Combo %d" % [i + 1, f.skin["name"], f.score, f.best_combo])
		result.skins.append(f.skin)
		result.total += f.score
	result.new_record = save.submit(result.player_count, result.total)
	result.best = save.best(result.player_count)
	result.play_time = game.play_time
	result.restart_requested.connect(func(): start_game(two_players))
	result.menu_requested.connect(show_menu)
	_set_screen(result)

## Controller getrennt: wer gerade mitspielt, wird pausiert, damit nichts passiert.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and mode == Mode.PLAYING and device < game.fighters.size():
		pause_game("Controller %d getrennt" % (device + 1))

# ------------------------------------------------------------ Hilfen

func _set_screen(new_screen: Screen) -> void:
	if screen != null:
		screen.queue_free()
	screen = new_screen
	if screen != null:
		_layer.add_child(screen)

func _remove_game() -> void:
	if game != null:
		game.queue_free()
		game = null

func _add_backdrop() -> void:
	_backdrop = Node2D.new()
	_backdrop.add_child(Level.new())
	_backdrop_camera = Camera2D.new()
	_backdrop_camera.position = Vector2(480.0, Level.HEIGHT * 0.5)
	_backdrop.add_child(_backdrop_camera)
	add_child(_backdrop)
	_backdrop_camera.make_current()

func _remove_backdrop() -> void:
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null
		_backdrop_camera = null
