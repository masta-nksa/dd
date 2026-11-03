class_name MenuScreen
extends Screen
## Hauptmenü: Die beiden Helden zeigen, was sie können; dazu Spielerzahl, Musik, Steuerung und Rekord.

signal start_requested(two_players: bool)
signal music_requested

var save: SaveData
var music_button: Button

func _build() -> void:
	dim = 0.47
	add_title("DOPPELFAUST", 104.0)
	add_text("Ein Beat-'em-up für eine oder zwei Personen", 28.0)
	add_gap(4.0)
	add_button("1 Spieler", func(): start_requested.emit(false))
	add_button("2 Spieler", func(): start_requested.emit(true))
	music_button = add_button("", func(): music_requested.emit())
	refresh_music()
	add_gap(4.0)
	var help := add_panel()
	add_text("WASD  ·  Leertaste Sprung  ·  E Greifen", 22.0, Art.PLAYER_COLORS[0], help)
	add_text("F Schlag  ·  G Tritt  ·  R Spezial", 22.0, Art.PLAYER_COLORS[0], help)
	add_text("Pfeile  ·  O Sprung  ·  J Greifen", 22.0, Art.PLAYER_COLORS[1], help)
	add_text("K Schlag  ·  L Tritt  ·  I Spezial", 22.0, Art.PLAYER_COLORS[1], help)
	add_text("Controller: A Sprung · X Schlag · B Tritt · Y Spezial · RB Greifen", 18.0, GRAY, help)
	add_text("Esc, P, Start Pause  ·  M Musik  ·  F1 Hitboxen", 18.0, GRAY, help)
	add_gap(2.0)
	add_text("Rekord:  1 Spieler %d  ·  2 Spieler %d" % [save.best(1), save.best(2)], 24.0, YELLOW)
	_add_heroes()

func _add_heroes() -> void:
	var pads := Input.get_connected_joypads()
	var kai := add_hero(Skins.KAI, Art.PLAYER_COLORS[0], Vector2(120.0, 400.0), 1)
	kai.showcase_attack = &"straight"
	kai.label = "1P KAI"
	kai.caption = "Controller verbunden" if pads.has(0) else "Tastatur"
	var ria := add_hero(Skins.RIA, Art.PLAYER_COLORS[1], Vector2(840.0, 400.0), -1)
	ria.showcase_attack = &"high_kick"
	ria.showcase_offset = 1.0
	ria.label = "2P RIA"
	ria.caption = "Controller verbunden" if pads.has(1) else "Tastatur"

func refresh_music() -> void:
	music_button.text = "Musik: an" if save.music_on else "Musik: aus"
